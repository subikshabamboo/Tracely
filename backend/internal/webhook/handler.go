package webhook

import (
	"github.com/gin-gonic/gin"
)

type Handler struct {
	Service *Service
}

func (h *Handler) HandleCI(c *gin.Context) {
	h.Service.HandleCIWebhook(c)
}
