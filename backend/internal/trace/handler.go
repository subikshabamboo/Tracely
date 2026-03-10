package trace

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Handler struct {
	Service              *Service
	WaterfallService     *WaterfallService
	PercentileCalculator *PercentileCalculator
	CriticalPathService  *CriticalPathService
	LogService           *LogService
	MetricService        *MetricService
	OptimizationService  *OptimizationService
	ErrorAnalysisService *ErrorAnalysisService
	TrendService         *TrendService
}

func (h *Handler) GetTopology(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	serviceName := c.Query("service_name")

	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	deps, err := h.Service.GetServiceTopology(workspaceID, serviceName)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// If no topology data, return mock data for demo purposes
	if len(deps) == 0 {
		deps = []Dependency{
			{Parent: "api-gateway", Child: "auth-service"},
			{Parent: "api-gateway", Child: "user-service"},
			{Parent: "api-gateway", Child: "payment-service"},
			{Parent: "auth-service", Child: "database"},
			{Parent: "user-service", Child: "database"},
			{Parent: "payment-service", Child: "bank-api"},
		}
	}

	c.JSON(http.StatusOK, deps)
}

func (h *Handler) GetTraceLogs(c *gin.Context) {

	traceID := c.Param("id")
	logs, err := h.LogService.GetLogsByTraceID(traceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, logs)
}

func (h *Handler) GetServiceMetrics(c *gin.Context) {
	serviceName := c.Query("service_name")
	startTime, _ := strconv.ParseInt(c.Query("start_time"), 10, 64)
	endTime, _ := strconv.ParseInt(c.Query("end_time"), 10, 64)

	metrics, err := h.MetricService.GetSystemMetrics(serviceName, startTime, endTime)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, metrics)
}

func (h *Handler) GetCriticalPath(c *gin.Context) {
	traceIDStr := c.Param("id")
	traceID, err := uuid.Parse(traceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trace_id"})
		return
	}

	spans, err := h.Service.GetWaterfall(traceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	path := h.CriticalPathService.Identify(spans)
	c.JSON(http.StatusOK, gin.H{"critical_path": path})
}

func (h *Handler) GetWaterfall(c *gin.Context) {

	traceIDStr := c.Param("id")
	traceID, err := uuid.Parse(traceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trace id"})
		return
	}

	spans, err := h.Service.GetWaterfall(traceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	tree := h.WaterfallService.BuildTree(spans)
	path := h.CriticalPathService.Identify(spans)
	savings, rec := h.CriticalPathService.CalculatePotentialSavings(spans, path)
	optimizations := h.OptimizationService.Analyze(spans)
	logs, _ := h.LogService.GetLogsByTraceID(traceID.String())

	c.JSON(http.StatusOK, gin.H{
		"tree":                 tree,
		"critical_path":        path,
		"potential_savings_ms": savings,
		"recommendation":       rec,
		"optimizations":        optimizations,
		"logs":                 logs,
	})
}

func (h *Handler) GetStats(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	serviceName := c.Query("service_name")
	startTimeStr := c.Query("start_time")
	endTimeStr := c.Query("end_time")

	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}
	startTime, _ := time.Parse(time.RFC3339, startTimeStr)
	endTime, _ := time.Parse(time.RFC3339, endTimeStr)

	stats, err := h.PercentileCalculator.Calculate(workspaceID, serviceName, startTime, endTime)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, stats)
}

func (h *Handler) GetTrendAnalysis(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	serviceName := c.Query("service_name")
	currStartStr := c.Query("current_start")
	currEndStr := c.Query("current_end")
	prevStartStr := c.Query("previous_start")
	prevEndStr := c.Query("previous_end")

	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	currStart, _ := time.Parse(time.RFC3339, currStartStr)
	currEnd, _ := time.Parse(time.RFC3339, currEndStr)
	prevStart, _ := time.Parse(time.RFC3339, prevStartStr)
	prevEnd, _ := time.Parse(time.RFC3339, prevEndStr)

	report, err := h.TrendService.AnalyzeTrend(workspaceID, serviceName, currStart, currEnd, prevStart, prevEnd)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, report)
}

func (h *Handler) GetRecent(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	traces, err := h.Service.GetRecentTraces(workspaceID, 50)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Transform to match frontend expectations (service, operation, duration, timestamp)
	type TraceResponse struct {
		ID         string  `json:"id"`
		TraceID    string  `json:"trace_id"`
		Service    string  `json:"service"`
		Operation  string  `json:"operation"`
		Duration   float64 `json:"duration"`
		StatusCode int     `json:"status_code"`
		Timestamp  string  `json:"timestamp"`
		StartTime  string  `json:"start_time"`
		EndTime    string  `json:"end_time"`
	}

	var response []TraceResponse
	for _, t := range traces {
		response = append(response, TraceResponse{
			ID:         t.ID.String(),
			TraceID:    t.TraceID,
			Service:    t.ServiceName,
			Operation:  t.OperationName,
			Duration:   t.DurationMs,
			StatusCode: t.StatusCode,
			Timestamp:  t.CreatedAt.Format("2006-01-02T15:04:05Z"),
			StartTime:  t.StartTime.Format("2006-01-02T15:04:05Z"),
			EndTime:    t.EndTime.Format("2006-01-02T15:04:05Z"),
		})
	}

	c.JSON(http.StatusOK, response)
}

func (h *Handler) GetHealth(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	var workspaceID uuid.UUID
	if workspaceIDStr != "" {
		workspaceID, _ = uuid.Parse(workspaceIDStr)
	}

	var activeTraces int64
	qTraces := database.DB.Model(&models.Trace{})
	if workspaceID != uuid.Nil {
		qTraces = qTraces.Where("workspace_id = ?", workspaceID)
	}
	qTraces.Count(&activeTraces)

	var avgLatency float64
	qLatency := database.DB.Model(&models.Trace{}).Select("AVG(duration_ms)")
	if workspaceID != uuid.Nil {
		qLatency = qLatency.Where("workspace_id = ?", workspaceID)
	}
	qLatency.Row().Scan(&avgLatency)

	var errorCount int64
	qErrors := database.DB.Model(&models.Span{}).Where("status_code >= 400")
	if workspaceID != uuid.Nil {
		qErrors = qErrors.Where("workspace_id = ?", workspaceID)
	}
	qErrors.Count(&errorCount)

	var totalSpans int64
	qSpans := database.DB.Model(&models.Span{})
	if workspaceID != uuid.Nil {
		qSpans = qSpans.Where("workspace_id = ?", workspaceID)
	}
	qSpans.Count(&totalSpans)

	errorRate := 0.0
	if totalSpans > 0 {
		errorRate = (float64(errorCount) / float64(totalSpans)) * 100
	}

	c.JSON(http.StatusOK, gin.H{
		"active_traces":  activeTraces,
		"avg_latency_ms": avgLatency,
		"error_rate":     errorRate,
	})
}

func (h *Handler) GetErrorAnalytics(c *gin.Context) {
	workspaceIDStr := c.Query("workspace_id")
	workspaceID, err := uuid.Parse(workspaceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid workspace_id"})
		return
	}

	var spans []models.Span
	database.DB.Where("workspace_id = ? AND status_code >= 400", workspaceID).Limit(1000).Find(&spans)

	patterns := h.ErrorAnalysisService.AnalyzePatterns(spans)
	c.JSON(http.StatusOK, patterns)
}

func (h *Handler) SaveConfig(c *gin.Context) {
	var config models.TracingConfig
	if err := c.ShouldBindJSON(&config); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := database.DB.Save(&config).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save config"})
		return
	}

	c.JSON(http.StatusOK, config)
}

// GetTraceMetricsWithAnomalies returns metrics aligned with a trace including anomaly detection
func (h *Handler) GetTraceMetricsWithAnomalies(c *gin.Context) {
	traceIDStr := c.Param("id")
	traceID, err := uuid.Parse(traceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trace_id"})
		return
	}

	// Get the trace
	var trace models.Trace
	if err := database.DB.First(&trace, traceID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "trace not found"})
		return
	}

	startTime := trace.StartTime.UnixMilli()
	endTime := trace.EndTime.UnixMilli()

	// Get system metrics
	metrics, err := h.MetricService.GetSystemMetrics(trace.ServiceName, startTime, endTime)
	if err != nil {
		// Return mock data if Prometheus unavailable
		metrics = h.MetricService.GetMockMetrics(startTime, endTime)
	}

	// Detect anomalies
	anomalies, _ := h.MetricService.DetectAnomalies(trace.ServiceName, startTime, endTime)

	// Get summary
	summary, _ := h.MetricService.GetMetricsSummary(trace.ServiceName, startTime, endTime)

	c.JSON(http.StatusOK, gin.H{
		"trace_id":     trace.TraceID,
		"service_name": trace.ServiceName,
		"start_time":   startTime,
		"end_time":     endTime,
		"metrics":      metrics,
		"anomalies":    anomalies,
		"summary":      summary,
	})
}
