package session

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"
)

type Service struct {
	Mu       sync.RWMutex
	Sessions map[uuid.UUID]*StatefulSession
}

type DebugSession struct {
	ID          uuid.UUID `json:"id"`
	WorkspaceID uuid.UUID `json:"workspace_id"`
	TraceID     string    `json:"trace_id"`
	StartedAt   time.Time `json:"started_at"`
	IsActive    bool      `json:"is_active"`
}

// StatefulSession represents a full session state for replay
type StatefulSession struct {
	ID           uuid.UUID              `json:"id"`
	WorkspaceID  uuid.UUID              `json:"workspace_id"`
	TraceID      string                 `json:"trace_id"`
	StartedAt    time.Time              `json:"started_at"`
	IsActive     bool                   `json:"is_active"`
	Cookies      map[string]string      `json:"cookies"`         // Session cookies
	Headers      map[string]string      `json:"headers"`         // Auth headers
	AuthToken    string                 `json:"auth_token"`   // Current auth token
	RefreshToken string                 `json:"refresh_token"`   // Refresh token
	TokenExpiry  time.Time              `json:"token_expiry"`    // Token expiry time
	Variables    map[string]interface{} `json:"variables"`       // Custom session variables
	SpanContext  map[string]string      `json:"span_context"`    // Trace context for replay
}

// SessionConfig holds configuration for stateful session replay
type SessionConfig struct {
	CaptureCookies   bool `json:"capture_cookies"`
	CaptureHeaders   bool `json:"capture_headers"`
	CaptureAuth      bool `json:"capture_auth"`
	AutoRefreshToken bool `json:"auto_refresh_token"`
	RefreshBeforeSec int  `json:"refresh_before_sec"` // Seconds before expiry to refresh
}

func NewService() *Service {
	return &Service{
		Sessions: make(map[uuid.UUID]*StatefulSession),
	}
}

func (s *Service) Start(workspaceID uuid.UUID, traceID string) *DebugSession {
	return &DebugSession{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		TraceID:     traceID,
		StartedAt:   time.Now(),
		IsActive:    true,
	}
}

// CreateStatefulSession creates a new stateful session for replay
func (s *Service) CreateStatefulSession(workspaceID uuid.UUID, traceID string, config SessionConfig) *StatefulSession {
	session := &StatefulSession{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		TraceID:     traceID,
		StartedAt:   time.Now(),
		IsActive:    true,
		Cookies:     make(map[string]string),
		Headers:     make(map[string]string),
		Variables:   make(map[string]interface{}),
		SpanContext: make(map[string]string),
	}

	s.Mu.Lock()
	s.Sessions[session.ID] = session
	s.Mu.Unlock()

	return session
}

// GetSession retrieves a session by ID
func (s *Service) GetSession(sessionID uuid.UUID) (*StatefulSession, bool) {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	session, ok := s.Sessions[sessionID]
	return session, ok
}

// StoreCookie stores a cookie in the session
func (s *Service) StoreCookie(sessionID uuid.UUID, name, value string) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if session, ok := s.Sessions[sessionID]; ok {
		session.Cookies[name] = value
	}
}

// StoreHeader stores a header in the session
func (s *Service) StoreHeader(sessionID uuid.UUID, name, value string) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if session, ok := s.Sessions[sessionID]; ok {
		session.Headers[name] = value
	}
}

// StoreAuth stores authentication tokens in the session
func (s *Service) StoreAuth(sessionID uuid.UUID, authToken, refreshToken string, expiry time.Time) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if session, ok := s.Sessions[sessionID]; ok {
		session.AuthToken = authToken
		session.RefreshToken = refreshToken
		session.TokenExpiry = expiry
	}
}

// GetAuthHeaders returns the current auth headers for requests
func (s *Service) GetAuthHeaders(sessionID uuid.UUID) map[string]string {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	if session, ok := s.Sessions[sessionID]; ok {
		headers := make(map[string]string)
		for k, v := range session.Headers {
			headers[k] = v
		}
		if session.AuthToken != "" {
			headers["Authorization"] = "Bearer " + session.AuthToken
		}
		return headers
	}
	return nil
}

// StoreVariable stores a custom variable in the session
func (s *Service) StoreVariable(sessionID uuid.UUID, key string, value interface{}) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if session, ok := s.Sessions[sessionID]; ok {
		session.Variables[key] = value
	}
}

// GetVariable retrieves a custom variable from the session
func (s *Service) GetVariable(sessionID uuid.UUID, key string) (interface{}, bool) {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	if session, ok := s.Sessions[sessionID]; ok {
		val, ok := session.Variables[key]
		return val, ok
	}
	return nil, false
}

// StoreSpanContext stores trace context for replay continuity
func (s *Service) StoreSpanContext(sessionID uuid.UUID, traceID, spanID string) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if session, ok := s.Sessions[sessionID]; ok {
		session.SpanContext["trace_id"] = traceID
		session.SpanContext["span_id"] = spanID
	}
}

// GetSpanContext retrieves trace context for replay
func (s *Service) GetSpanContext(sessionID uuid.UUID) map[string]string {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	if session, ok := s.Sessions[sessionID]; ok {
		ctx := make(map[string]string)
		for k, v := range session.SpanContext {
			ctx[k] = v
		}
		return ctx
	}
	return nil
}

// IsTokenExpiring checks if the token needs refresh
func (s *Service) IsTokenExpiring(sessionID uuid.UUID, bufferSec int) bool {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	if session, ok := s.Sessions[sessionID]; ok {
		return time.Until(session.TokenExpiry) < time.Duration(bufferSec)*time.Second
	}
	return false
}

// EndSession ends a session
func (s *Service) EndSession(sessionID uuid.UUID) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if session, ok := s.Sessions[sessionID]; ok {
		session.IsActive = false
	}
}

// SerializeSession serializes session state for persistence
func (s *Service) SerializeSession(sessionID uuid.UUID) ([]byte, error) {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	session, ok := s.Sessions[sessionID]
	if !ok {
		return nil, nil
	}
	return json.Marshal(session)
}

// DeserializeSession deserializes and restores session state
func (s *Service) DeserializeSession(data []byte) (*StatefulSession, error) {
	var session StatefulSession
	if err := json.Unmarshal(data, &session); err != nil {
		return nil, err
	}
	s.Mu.Lock()
	s.Sessions[session.ID] = &session
	s.Mu.Unlock()
	return &session, nil
}

// ExecuteStatefulReplay executes a replay with full session state
func (s *Service) ExecuteStatefulReplay(ctx context.Context, sessionID uuid.UUID, url, method string, body []byte) ([]byte, int, error) {
	session, ok := s.GetSession(sessionID)
	if !ok || !session.IsActive {
		return nil, 0, nil
	}

	// Check token expiry
	if session.TokenExpiry.IsZero() == false && s.IsTokenExpiring(sessionID, 60) {
		// Token needs refresh - in production would call token refresh endpoint
		return nil, 401, nil
	}

	// Build request with session state
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewBuffer(body))
	if err != nil {
		return nil, 0, err
	}

	// Add session headers
	for k, v := range session.Headers {
		req.Header.Set(k, v)
	}

	// Add auth token
	if session.AuthToken != "" {
		req.Header.Set("Authorization", "Bearer "+session.AuthToken)
	}

	// Add trace context
	if traceID, ok := session.SpanContext["trace_id"]; ok {
		req.Header.Set("X-Trace-ID", traceID)
	}
	if spanID, ok := session.SpanContext["span_id"]; ok {
		req.Header.Set("X-Span-ID", spanID)
	}

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return nil, 0, err
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	return respBody, resp.StatusCode, nil
}
