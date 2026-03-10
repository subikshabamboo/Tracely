package trace

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type ShareHandler struct{}

func (h *ShareHandler) Create(c *gin.Context) {
	var shareData struct {
		TraceUUID uuid.UUID  `json:"trace_uuid"`
		IsPublic  bool       `json:"is_public"`
		ExpiresAt *time.Time `json:"expires_at"`
	}

	if err := c.ShouldBindJSON(&shareData); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Generate a unique access key
	bytes := make([]byte, 16)
	rand.Read(bytes)
	accessKey := hex.EncodeToString(bytes)

	share := models.TraceShare{
		ID:        uuid.New(),
		TraceUUID: shareData.TraceUUID,
		IsPublic:  shareData.IsPublic,
		ExpiresAt: shareData.ExpiresAt,
		AccessKey: accessKey,
		CreatedAt: time.Now(),
	}

	if err := database.DB.Create(&share).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, share)
}

func (h *ShareHandler) GetByAccessKey(c *gin.Context) {
	key := c.Param("key")
	var share models.TraceShare
	if err := database.DB.Where("access_key = ?", key).First(&share).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Share link not found"})
		return
	}

	if share.ExpiresAt != nil && time.Now().After(*share.ExpiresAt) {
		c.JSON(http.StatusGone, gin.H{"error": "Share link expired"})
		return
	}

	// Fetch trace data
	var trace models.Trace
	if err := database.DB.Preload("Spans").First(&trace, share.TraceUUID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Trace not found"})
		return
	}

	c.JSON(http.StatusOK, trace)
}
