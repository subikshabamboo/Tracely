package replay

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

func (h *Handler) Execute(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid replay id"})
		return
	}

	exec, err := h.Service.Execute(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, exec)
}

func (h *Handler) Compare(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid execution id"})
		return
	}

	comp, err := h.Service.CompareReplay(id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, comp)
}

func (h *Handler) Create(c *gin.Context) {
	var r models.Replay
	if err := c.ShouldBindJSON(&r); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := database.DB.Create(&r).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, r)
}

func (h *Handler) GetForWorkspace(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	var replays []models.Replay
	database.DB.Where("workspace_id = ?", workspaceID).Find(&replays)
	c.JSON(http.StatusOK, replays)
}
func (h *Handler) GetMutationHistory(c *gin.Context) {
	executionIDStr := c.Param("id")
	executionID, err := uuid.Parse(executionIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid execution id"})
		return
	}

	var records []models.MutationRecord
	database.DB.Where("execution_id = ?", executionID).Order("timestamp DESC").Find(&records)
	c.JSON(http.StatusOK, records)
}

func (h *Handler) GetCascadeResults(c *gin.Context) {
	simIDStr := c.Param("id")
	simID, err := uuid.Parse(simIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid simulation id"})
		return
	}

	var results []models.CascadeResult
	database.DB.Where("simulation_id = ?", simID).Order("timestamp ASC").Find(&results)
	c.JSON(http.StatusOK, results)
}

func (h *Handler) StartCascadeSimulation(c *gin.Context) {
	var sim models.ErrorCascadeSimulation
	if err := c.ShouldBindJSON(&sim); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	workspaceIDStr := c.Query("workspace_id")
	if workspaceIDStr != "" {
		if wid, err := uuid.Parse(workspaceIDStr); err == nil {
			sim.WorkspaceID = wid
		}
	}

	if err := h.Service.ErrorInjection.StartCascadeSimulation(&sim); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusAccepted, sim)
}

func (h *Handler) GetCascadeSimulations(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	sims, err := h.Service.ErrorInjection.GetCascadeSimulations(workspaceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, sims)
}
func (h *Handler) GetErrorInjections(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	var configs []models.ErrorInjectionConfig
	database.DB.Where("workspace_id = ?", workspaceID).Find(&configs)
	c.JSON(http.StatusOK, configs)
}
func (h *Handler) ExecuteLoadWithRamp(c *gin.Context) {
	idStr := c.Param("id")
	id, err := uuid.Parse(idStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid replay id"})
		return
	}

	var pattern models.RampPattern
	if err := c.ShouldBindJSON(&pattern); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	exec, err := h.Service.ExecuteLoadReplayWithRamp(id, pattern)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, exec)
}
