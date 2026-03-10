package collection

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Handler struct{}

func (h *Handler) List(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, _ := uuid.Parse(workspaceIDStr)

	var colls []models.Collection
	query := database.DB.Preload("Items")
	if workspaceIDStr != "" {
		query = query.Where("workspace_id = ?", workspaceID)
	}
	if err := query.Find(&colls).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, colls)
}

func (h *Handler) Create(c *gin.Context) {
	var coll models.Collection
	if err := c.ShouldBindJSON(&coll); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if coll.ID == uuid.Nil {
		coll.ID = uuid.New()
	}

	if err := database.DB.Create(&coll).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, coll)
}

func (h *Handler) Get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}

	var coll models.Collection
	if err := database.DB.Preload("Items").First(&coll, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "not found"})
		return
	}
	c.JSON(http.StatusOK, coll)
}

func (h *Handler) ListVersions(c *gin.Context) {
	name := c.Query("name")
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, _ := uuid.Parse(workspaceIDStr)

	var colls []models.Collection
	if err := database.DB.Where("workspace_id = ? AND name = ?", workspaceID, name).Order("version DESC").Find(&colls).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, colls)
}

func (h *Handler) ImportPostman(c *gin.Context) {
	workspaceIDStr := c.PostForm("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file is required"})
		return
	}

	f, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to open file"})
		return
	}
	defer f.Close()

	coll, err := ImportPostman(f, workspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if err := database.DB.Create(coll).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, coll)
}
