package trace

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/websocket"
)

type AnnotationHandler struct {
	Hub *websocket.Hub
}

// AnnotationThread represents a thread of annotations (replies)
type AnnotationThread struct {
	RootID   uuid.UUID           `json:"root_id"`
	Replies  []models.Annotation `json:"replies"`
	Resolved bool                `json:"resolved"`
}

func (h *AnnotationHandler) Create(c *gin.Context) {
	var annotation models.Annotation
	if err := c.ShouldBindJSON(&annotation); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	annotation.ID = uuid.New()
	annotation.CreatedAt = time.Now()
	annotation.Resolved = false

	if err := database.DB.Create(&annotation).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if h.Hub != nil {
		msg, _ := json.Marshal(map[string]interface{}{
			"type":    "new_annotation",
			"payload": annotation,
		})
		h.Hub.Broadcast <- msg
	}

	c.JSON(http.StatusCreated, annotation)
}

func (h *AnnotationHandler) CreateReply(c *gin.Context) {
	var replyData struct {
		ParentID  uuid.UUID `json:"parent_id"`
		Content   string    `json:"content"`
		UserID    uuid.UUID `json:"user_id"`
		TraceUUID uuid.UUID `json:"trace_uuid"`
		SpanID    string    `json:"span_id"`
	}

	if err := c.ShouldBindJSON(&replyData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Check if parent annotation exists
	var parent models.Annotation
	if err := database.DB.First(&parent, replyData.ParentID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Parent annotation not found"})
		return
	}

	// Create the reply
	reply := models.Annotation{
		ID:        uuid.New(),
		TraceUUID: replyData.TraceUUID,
		SpanID:    replyData.SpanID,
		ParentID:  &replyData.ParentID,
		UserID:    replyData.UserID,
		Content:   replyData.Content,
		Resolved:  false,
		CreatedAt: time.Now(),
	}

	if err := database.DB.Create(&reply).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if h.Hub != nil {
		msg, _ := json.Marshal(map[string]interface{}{
			"type":    "new_reply",
			"payload": reply,
		})
		h.Hub.Broadcast <- msg
	}

	c.JSON(http.StatusCreated, reply)
}

// ResolveThread marks an annotation thread as resolved
func (h *AnnotationHandler) ResolveThread(c *gin.Context) {
	var resolveData struct {
		RootID   uuid.UUID `json:"root_id"`
		Resolved bool      `json:"resolved"`
	}

	if err := c.ShouldBindJSON(&resolveData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := database.DB.Model(&models.Annotation{}).Where("id = ?", resolveData.RootID).Update("resolved", resolveData.Resolved).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if h.Hub != nil {
		msg, _ := json.Marshal(map[string]interface{}{
			"type":     "thread_resolved",
			"root_id":  resolveData.RootID,
			"resolved": resolveData.Resolved,
		})
		h.Hub.Broadcast <- msg
	}

	c.JSON(http.StatusOK, gin.H{
		"root_id":     resolveData.RootID,
		"resolved":    resolveData.Resolved,
		"resolved_at": time.Now(),
	})
}

func (h *AnnotationHandler) GetThread(c *gin.Context) {
	rootIDStr := c.Param("id")
	rootID, err := uuid.Parse(rootIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid annotation id"})
		return
	}

	var root models.Annotation
	if err := database.DB.First(&root, rootID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "annotation not found"})
		return
	}

	var replies []models.Annotation
	database.DB.Where("parent_id = ?", rootID).Order("created_at ASC").Find(&replies)

	thread := AnnotationThread{
		RootID:   rootID,
		Replies:  replies,
		Resolved: root.Resolved,
	}

	c.JSON(http.StatusOK, thread)
}

func (h *AnnotationHandler) GetByTrace(c *gin.Context) {
	traceUUIDStr := c.Param("id")
	traceUUID, err := uuid.Parse(traceUUIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trace uuid"})
		return
	}
	var annotations []models.Annotation
	database.DB.Where("trace_uuid = ?", traceUUID).Order("created_at DESC").Find(&annotations)
	c.JSON(http.StatusOK, annotations)
}
