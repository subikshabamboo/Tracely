package loadtest

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	Service *Service
}

func (h *Handler) Execute(c *gin.Context) {
	var req struct {
		URL         string `json:"url" binding:"required"`
		Concurrency int    `json:"concurrency" binding:"required"`
		DurationSec int    `json:"duration_sec" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	duration := time.Duration(req.DurationSec) * time.Second
	result := h.Service.Execute(req.URL, req.Concurrency, duration)
	
	c.JSON(http.StatusOK, result)
}
