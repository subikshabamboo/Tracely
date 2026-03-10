package websocket

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool {
		allowedOrigin := os.Getenv("ALLOWED_ORIGIN")
		if allowedOrigin == "" {
			allowedOrigin = "http://localhost:3000"
		}
		origin := r.Header.Get("Origin")
		return origin == allowedOrigin
	},
}

type Client struct {
	Hub          *Hub
	Conn         *websocket.Conn
	Send         chan []byte
	UserID       uuid.UUID
	Username     string
	ResourceID   string
	ResourceType string
}

type Message struct {
	Type      string                 `json:"type"`
	Payload   map[string]interface{} `json:"payload"`
	Timestamp time.Time              `json:"timestamp"`
}

type ActiveViewer struct {
	UserID     uuid.UUID `json:"user_id"`
	Username   string    `json:"username"`
	ResourceID string    `json:"resource_id"`
	JoinedAt   time.Time `json:"joined_at"`
	Cursor     string    `json:"cursor,omitempty"`
}

type Hub struct {
	Clients    map[*Client]bool
	Broadcast  chan []byte
	Register   chan *Client
	Unregister chan *Client
	mu         sync.RWMutex

	ActiveViewers map[string]map[*Client]ActiveViewer
}

func NewHub() *Hub {
	return &Hub{
		Broadcast:     make(chan []byte, 256),
		Register:      make(chan *Client, 64),
		Unregister:    make(chan *Client, 64),
		Clients:       make(map[*Client]bool),
		ActiveViewers: make(map[string]map[*Client]ActiveViewer),
	}
}

func (h *Hub) Run(ctx context.Context) {
	for {
		select {
		case <-ctx.Done():
			h.mu.Lock()
			for client := range h.Clients {
				close(client.Send)
				delete(h.Clients, client)
			}
			h.ActiveViewers = make(map[string]map[*Client]ActiveViewer)
			h.mu.Unlock()
			return
		case client := <-h.Register:
			h.mu.Lock()
			h.Clients[client] = true
			resourceKey := client.ResourceType + ":" + client.ResourceID
			if h.ActiveViewers[resourceKey] == nil {
				h.ActiveViewers[resourceKey] = make(map[*Client]ActiveViewer)
			}
			h.ActiveViewers[resourceKey][client] = ActiveViewer{
				UserID:     client.UserID,
				Username:   client.Username,
				ResourceID: client.ResourceID,
				JoinedAt:   time.Now(),
			}
			h.broadcastToResource(resourceKey, Message{
				Type: "viewer_joined",
				Payload: map[string]interface{}{
					"user_id":  client.UserID.String(),
					"username": client.Username,
					"viewers":  h.GetViewerList(resourceKey),
				},
				Timestamp: time.Now(),
			})
			h.mu.Unlock()
			log.Printf("User %s (%s) viewing %s %s", client.Username, client.UserID, client.ResourceType, client.ResourceID)
		case client := <-h.Unregister:
			h.mu.Lock()
			if _, ok := h.Clients[client]; ok {
				delete(h.Clients, client)
				close(client.Send)
				resourceKey := client.ResourceType + ":" + client.ResourceID
				if h.ActiveViewers[resourceKey] != nil {
					delete(h.ActiveViewers[resourceKey], client)
					h.broadcastToResource(resourceKey, Message{
						Type: "viewer_left",
						Payload: map[string]interface{}{
							"user_id":  client.UserID.String(),
							"username": client.Username,
							"viewers":  h.GetViewerList(resourceKey),
						},
						Timestamp: time.Now(),
					})
					if len(h.ActiveViewers[resourceKey]) == 0 {
						delete(h.ActiveViewers, resourceKey)
					}
				}
			}
			h.mu.Unlock()
		case message := <-h.Broadcast:
			h.mu.RLock()
			for client := range h.Clients {
				select {
				case client.Send <- message:
				default:
					close(client.Send)
					delete(h.Clients, client)
				}
			}
			h.mu.RUnlock()
		}
	}
}

func (h *Hub) broadcastToResource(resourceKey string, msg Message) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	if viewers, ok := h.ActiveViewers[resourceKey]; ok {
		data, _ := json.Marshal(msg)
		for client := range viewers {
			select {
			case client.Send <- data:
			default:
			}
		}
	}
}

func (h *Hub) GetViewerList(resourceKey string) []ActiveViewer {
	h.mu.RLock()
	defer h.mu.RUnlock()

	var viewers []ActiveViewer
	if resourceViewers, ok := h.ActiveViewers[resourceKey]; ok {
		for _, viewer := range resourceViewers {
			viewers = append(viewers, viewer)
		}
	}
	return viewers
}

func (h *Hub) GetViewersForResource(resourceType, resourceID string) []ActiveViewer {
	return h.GetViewerList(resourceType + ":" + resourceID)
}

func (h *Hub) BroadcastCursorUpdate(resourceType, resourceID, userID, username, cursor string) {
	resourceKey := resourceType + ":" + resourceID
	msg := Message{
		Type: "cursor_update",
		Payload: map[string]interface{}{
			"user_id":  userID,
			"username": username,
			"cursor":   cursor,
		},
		Timestamp: time.Now(),
	}
	h.broadcastToResource(resourceKey, msg)
}

func (h *Hub) BroadcastAnnotationUpdate(resourceType, resourceID string, annotation map[string]interface{}) {
	resourceKey := resourceType + ":" + resourceID
	msg := Message{
		Type:      "annotation_added",
		Payload:   annotation,
		Timestamp: time.Now(),
	}
	h.broadcastToResource(resourceKey, msg)
}

func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
	}()
	for {
		_, message, err := c.Conn.ReadMessage()
		if err != nil {
			break
		}
		var msg Message
		if json.Unmarshal(message, &msg) == nil {
			switch msg.Type {
			case "cursor_move":
				if cursor, ok := msg.Payload["cursor"].(string); ok {
					c.Hub.BroadcastCursorUpdate(c.ResourceType, c.ResourceID, c.UserID.String(), c.Username, cursor)
				}
			case "ping":
				c.Conn.WriteJSON(Message{Type: "pong", Timestamp: time.Now()})
			}
		}
		c.Hub.Broadcast <- message
	}
}

func (c *Client) WritePump() {
	defer func() {
		c.Conn.Close()
	}()
	for {
		select {
		case message, ok := <-c.Send:
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			c.Conn.WriteMessage(websocket.TextMessage, message)
		}
	}
}

func ServeWs(hub *Hub, w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println(err)
		return
	}

	userIDStr := r.URL.Query().Get("user_id")
	username := r.URL.Query().Get("username")
	resourceID := r.URL.Query().Get("resource_id")
	resourceType := r.URL.Query().Get("resource_type")

	userID := uuid.Nil
	if userIDStr != "" {
		if parsed, err := uuid.Parse(userIDStr); err == nil {
			userID = parsed
		}
	}

	client := &Client{
		Hub:          hub,
		Conn:         conn,
		Send:         make(chan []byte, 256),
		UserID:       userID,
		Username:     username,
		ResourceID:   resourceID,
		ResourceType: resourceType,
	}
	client.Hub.Register <- client

	go client.WritePump()
	go client.ReadPump()
}
