package middleware

import (
	"fmt"
	"time"
	"github.com/gin-gonic/gin"
	"github.com/tracely/backend/internal/logbuffer"
	"github.com/tracely/backend/internal/models"
)

func LogInfo(c *gin.Context, message string, fields map[string]interface{}) {
	logToBuffer(c, "INFO", message, fields)
}

func LogError(c *gin.Context, err error, fields map[string]interface{}) {
	logToBuffer(c, "ERROR", err.Error(), fields)
}

func logToBuffer(c *gin.Context, level, message string, fields map[string]interface{}) {
	traceID := c.GetString("TraceID")
	if traceID == "" {
		return
	}

	logbuffer.Add(traceID, models.SpanLog{
		Timestamp: time.Now(),
		Level:     level,
		Message:   message,
		Fields:    fields,
	})


	// Also print to standard log for visibility
	fmt.Printf("[%s] [%s] %s %v\n", level, traceID, message, fields)
}
