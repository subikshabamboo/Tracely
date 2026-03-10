package secret

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Handler struct {
	Service *Service
}

func (h *Handler) Create(c *gin.Context) {
	var req struct {
		WorkspaceID uuid.UUID `json:"workspace_id" binding:"required"`
		Key         string    `json:"key" binding:"required"`
		Value       string    `json:"value" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.Service.SaveSecret(req.WorkspaceID, req.Key, req.Value); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"status": "secret saved"})
}

func (h *Handler) List(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	var secrets []models.Secret
	if err := database.DB.Where("workspace_id = ?", workspaceID).Find(&secrets).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Note: We don't return the encrypted values in the list for security, 
	// or we return them if that's the intended use case.
	c.JSON(http.StatusOK, secrets)
}

func (h *Handler) Delete(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid secret id"})
		return
	}

	if err := database.DB.Delete(&models.Secret{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"status": "secret deleted"})
}
