package middleware

import (
	"log"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/trace"
)


func TracingMiddleware() gin.HandlerFunc {
	configService := &trace.TracingConfigService{}

	return func(c *gin.Context) {
		workspaceID := uuid.Nil 
		config, err := configService.GetConfig(workspaceID)
		if err != nil {
			log.Printf("Error fetching tracing config: %v", err)
		}


		if config != nil && !config.IsEnabled {
			c.Next()
			return
		}

		// Extract Context
		traceID, parentSpanID := extractTraceContext(c)
		if traceID == "" {
			traceID = uuid.New().String()
		}

		spanID := uuid.New().String()
		startTime := time.Now()

		// Set Context
		c.Set("TraceID", traceID)
		c.Set("SpanID", spanID)
		c.Set("ParentSpanID", parentSpanID)
		c.Set("StartTime", startTime)

		c.Header("X-Trace-Id", traceID)
		c.Header("X-Span-Id", spanID)

		c.Next()
	}
}

func extractTraceContext(c *gin.Context) (string, string) {
	// 1. W3C traceparent (00-4bf92f3577b34d6a52a96f3c25938109-00f067aa0ba902b7-01)
	if tp := c.GetHeader("traceparent"); tp != "" {
		parts := strings.Split(tp, "-")
		if len(parts) >= 3 {
			return parts[1], parts[2]
		}
	}

	// 2. B3 (X-B3-TraceId, X-B3-SpanId)
	tid := c.GetHeader("X-B3-TraceId")
	sid := c.GetHeader("X-B3-SpanId")
	if tid != "" {
		return tid, sid
	}

	// 3. Custom X-Trace-Id
	if tid := c.GetHeader("X-Trace-Id"); tid != "" {
		return tid, c.GetHeader("X-Parent-Span-Id")
	}

	return "", ""
}


