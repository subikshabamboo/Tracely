package trace

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GetTraceMetrics returns system metrics overlaid on a trace timeline
func (h *Handler) GetTraceMetrics(c *gin.Context) {
	traceIDStr := c.Param("id")
	traceID, err := uuid.Parse(traceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trace_id"})
		return
	}

	trace, err := h.Service.GetTrace(traceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "trace not found"})
		return
	}

	startTime := trace.StartTime.UnixMilli()
	endTime := trace.EndTime.UnixMilli()

	metrics, err := h.MetricService.GetSystemMetrics(trace.ServiceName, startTime, endTime)
	if err != nil {
		metrics = h.MetricService.GetMockMetrics(startTime, endTime)
	}

	anomalies, _ := h.MetricService.DetectAnomalies(trace.ServiceName, startTime, endTime)
	summary, _ := h.MetricService.GetMetricsSummary(trace.ServiceName, startTime, endTime)

	c.JSON(http.StatusOK, gin.H{
		"trace_id":     traceID.String(),
		"service_name": trace.ServiceName,
		"start_time":   startTime,
		"end_time":     endTime,
		"metrics":      metrics,
		"anomalies":    anomalies,
		"summary":      summary,
	})
}

// GetTraceAnomalies returns anomalies detected during a trace
func (h *Handler) GetTraceAnomalies(c *gin.Context) {
	traceIDStr := c.Param("id")
	traceID, err := uuid.Parse(traceIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trace_id"})
		return
	}

	trace, err := h.Service.GetTrace(traceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "trace not found"})
		return
	}

	startTime := trace.StartTime.UnixMilli()
	endTime := trace.EndTime.UnixMilli()

	anomalies, err := h.MetricService.DetectAnomalies(trace.ServiceName, startTime, endTime)
	if err != nil {
		// Ignore metric service errors and return empty anomalies if unavailable
		anomalies = []map[string]interface{}{}
	}

	c.JSON(http.StatusOK, gin.H{
		"trace_id":  traceID.String(),
		"anomalies": anomalies,
	})
}

// GetTraceOptimizations returns optimization recommendations for a trace
func (h *Handler) GetTraceOptimizations(c *gin.Context) {
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
	savings, recommendations := h.CriticalPathService.CalculatePotentialSavings(spans, path)
	optimizations := h.OptimizationService.Analyze(spans)

	c.JSON(http.StatusOK, gin.H{
		"trace_id":             traceID.String(),
		"critical_path":        path,
		"potential_savings_ms": savings,
		"recommendations":      recommendations,
		"optimizations":        optimizations,
	})
}
