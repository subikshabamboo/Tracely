package proxy

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/trace"
)

type Service struct {
	TraceService *trace.Service
}

func (s *Service) HandleProxyRequest(c *gin.Context) {
	var reqBody map[string]interface{}
	if err := c.ShouldBindJSON(&reqBody); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request body"})
		return
	}

	method, _ := reqBody["method"].(string)
	url, _ := reqBody["url"].(string)
	if method == "" || url == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "method and url are required"})
		return
	}

	headers, _ := reqBody["headers"].(map[string]interface{})
	body, _ := reqBody["body"].(string)

	traceID := c.GetString("TraceID")
	if traceID == "" {
		traceID = c.GetHeader("X-Trace-Id")
	}
	if traceID == "" {
		traceID = uuid.New().String()
	}

	client := &http.Client{Timeout: 30 * time.Second}
	proxyReq, err := http.NewRequest(method, url, bytes.NewBufferString(body))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("failed to create request: %v", err)})
		return
	}

	for k, v := range headers {
		if val, ok := v.(string); ok {
			proxyReq.Header.Set(k, val)
		}
	}

	// Inject Trace ID for propagation
	proxyReq.Header.Set("X-Trace-Id", traceID)

	log.Printf("Proxy: Sending %s request to %s (TraceID: %s)", method, url, traceID)
	startTime := time.Now()
	resp, err := client.Do(proxyReq)
	duration := time.Since(startTime).Seconds() * 1000

	if err != nil {
		log.Printf("Proxy Error: Request to %s failed: %v", url, err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("request failed: %v", err)})
		return
	}
	defer resp.Body.Close()
	log.Printf("Proxy: Received %d from %s in %.2fms", resp.StatusCode, url, duration)

	respBody, err := io.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Proxy Warning: failed to read response body from %s: %v", url, err)
	}

	respHeaders := make(map[string]interface{})
	for k, v := range resp.Header {
		respHeaders[k] = v
	}

	// Capture request headers too
	reqHeaders := make(map[string]interface{})
	for k, v := range proxyReq.Header {
		reqHeaders[k] = v
	}

	workspaceIDStr, _ := reqBody["workspace_id"].(string)
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	userIDString := c.GetString("UserID")
	userID, _ := uuid.Parse(userIDString)

	// Authorization check
	var workspaceUser models.WorkspaceUser
	if err := database.DB.Where("workspace_id = ? AND user_id = ?", workspaceID, userID).First(&workspaceUser).Error; err != nil {
		c.JSON(http.StatusForbidden, gin.H{"error": "access to workspace denied"})
		return
	}

	// Convert headers to json.RawMessage
	reqHeadersJSON, _ := json.Marshal(reqHeaders)
	respHeadersJSON, _ := json.Marshal(respHeaders)

	// Log the trace to DB
	traceModel := &models.Trace{
		ID:          uuid.New(),
		TraceID:     traceID,
		WorkspaceID: workspaceID,

		ServiceName:     "Request Studio",
		OperationName:   method + " " + url,
		StartTime:       startTime,
		EndTime:         time.Now(),
		DurationMs:      duration,
		StatusCode:      resp.StatusCode,
		RequestBody:     body,
		RequestHeaders:  json.RawMessage(reqHeadersJSON),
		ResponseBody:    string(respBody),
		ResponseHeaders: json.RawMessage(respHeadersJSON),
	}

	// Create a root span for visualization too
	spanModel := &models.Span{
		ID:              uuid.New(),
		TraceUUID:       traceModel.ID,
		WorkspaceID:     workspaceID,
		SpanID:          uuid.New().String(),
		ServiceName:     "Request Studio",
		OperationName:   method + " " + url,
		StartTime:       startTime,
		EndTime:         traceModel.EndTime,
		DurationMs:      duration,
		StatusCode:      resp.StatusCode,
		RequestBody:     body,
		RequestHeaders:  json.RawMessage(reqHeadersJSON),
		ResponseBody:    string(respBody),
		ResponseHeaders: json.RawMessage(respHeadersJSON),
	}

	// Ensure TraceService is not nil
	if s.TraceService != nil {
		if err := s.TraceService.SaveTrace(traceModel); err != nil {
			log.Printf("failed to save proxy trace: %v", err)
		}
		if err := s.TraceService.SaveSpan(spanModel); err != nil {
			log.Printf("failed to save proxy span: %v", err)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"status":   resp.StatusCode,
		"body":     string(respBody),
		"headers":  resp.Header,
		"time":     fmt.Sprintf("%.2fms", duration),
		"trace_id": traceID,
	})
}
