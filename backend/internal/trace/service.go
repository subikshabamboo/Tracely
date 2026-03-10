package trace

import (
	"encoding/json"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/alerting"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/governance"
	"github.com/tracely/backend/internal/logbuffer"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/websocket"
)

type Service struct {
	Hub               *websocket.Hub
	GovernanceService *governance.Service
	AlertService      *alerting.Service
}

// TopologyFilter holds filtering options for topology queries
type TopologyFilter struct {
	ServiceName    string    `json:"service_name,omitempty"`
	TimeRangeStart time.Time `json:"time_range_start,omitempty"`
	TimeRangeEnd   time.Time `json:"time_range_end,omitempty"`
	MinLatencyMs   float64   `json:"min_latency_ms,omitempty"`
	MaxLatencyMs   float64   `json:"max_latency_ms,omitempty"`
	IncludeErrors  bool      `json:"include_errors,omitempty"`
	Limit          int       `json:"limit,omitempty"`
}

// TopologyUpdate represents a real-time topology change
type TopologyUpdate struct {
	Type       string      `json:"type"` // "new_service", "new_dependency", "removed"
	Service    string      `json:"service,omitempty"`
	Dependency *Dependency `json:"dependency,omitempty"`
	Timestamp  time.Time   `json:"timestamp"`
}

func (s *Service) SaveTrace(trace *models.Trace) error {
	if s.GovernanceService != nil {
		trace.RequestBody = s.GovernanceService.MaskAndAuditPII(trace.WorkspaceID, trace.TraceID, trace.RequestBody)
		trace.ResponseBody = s.GovernanceService.MaskAndAuditPII(trace.WorkspaceID, trace.TraceID, trace.ResponseBody)
	}

	err := database.DB.Create(trace).Error
	if err == nil {
		if s.Hub != nil {
			msg, _ := json.Marshal(map[string]interface{}{
				"type":    "new_trace",
				"payload": trace,
			})
			s.Hub.Broadcast <- msg
		}

		// Real-time violation detection
		if s.AlertService != nil {
			go s.AlertService.CheckThresholds(trace.WorkspaceID)
		}
	}
	return err
}

func (s *Service) SaveSpan(span *models.Span) error {
	if s.GovernanceService != nil {
		span.RequestBody = s.GovernanceService.MaskAndAuditPII(span.WorkspaceID, span.SpanID, span.RequestBody)
		span.ResponseBody = s.GovernanceService.MaskAndAuditPII(span.WorkspaceID, span.SpanID, span.ResponseBody)
	}

	// Attach logs - convert []models.SpanLog to json.RawMessage
	logs := logbuffer.Get(span.TraceUUID.String())
	logsJSON, _ := json.Marshal(logs)
	span.Logs = logsJSON

	return database.DB.Create(span).Error
}

func (s *Service) GetTrace(traceUUID uuid.UUID) (*models.Trace, error) {
	var trace models.Trace
	err := database.DB.First(&trace, "id = ?", traceUUID).Error
	if err != nil {
		return nil, err
	}
	return &trace, nil
}

func (s *Service) GetWaterfall(traceUUID uuid.UUID) ([]models.Span, error) {
	var spans []models.Span
	err := database.DB.Where("trace_uuid = ?", traceUUID).Order("start_time ASC").Find(&spans).Error
	return spans, err
}

func (s *Service) GetRecentTraces(workspaceID uuid.UUID, limit int) ([]models.Trace, error) {
	var traces []models.Trace
	err := database.DB.Where("workspace_id = ?", workspaceID).Order("created_at DESC").Limit(limit).Find(&traces).Error
	return traces, err
}

type Dependency struct {
	Parent string `json:"parent"`
	Child  string `json:"child"`
}

func (s *Service) GetServiceTopology(workspaceID uuid.UUID, serviceName string) ([]Dependency, error) {
	var results []Dependency
	query := `
		SELECT DISTINCT p.service_name as parent, c.service_name as child 
		FROM spans c
		JOIN spans p ON c.parent_span_id = p.span_id AND c.trace_uuid = p.trace_uuid
		WHERE c.workspace_id = ?
	`
	args := []interface{}{workspaceID}

	if serviceName != "" {
		query += " AND (p.service_name = ? OR c.service_name = ?)"
		args = append(args, serviceName, serviceName)
	}

	err := database.DB.Raw(query, args...).Scan(&results).Error
	return results, err
}

// broadcastTopologyUpdate broadcasts new service discovery to connected clients
func (s *Service) broadcastTopologyUpdate(workspaceID uuid.UUID, serviceName string) {
	if s.Hub == nil || serviceName == "" {
		return
	}

	// Check if this is a new service
	var count int64
	database.DB.Model(&models.Span{}).
		Where("workspace_id = ? AND service_name = ?", workspaceID, serviceName).
		Count(&count)

	// If this is a new service (first span), broadcast the topology update
	if count <= 1 {
		update := TopologyUpdate{
			Type:      "new_service",
			Service:   serviceName,
			Timestamp: time.Now(),
		}
		msg, _ := json.Marshal(map[string]interface{}{
			"type":    "topology_update",
			"payload": update,
		})
		s.Hub.Broadcast <- msg
	}
}

// GetFilteredTopology retrieves topology with advanced filtering options
func (s *Service) GetFilteredTopology(workspaceID uuid.UUID, filter TopologyFilter) ([]Dependency, error) {
	var results []Dependency

	query := `
		SELECT DISTINCT p.service_name as parent, c.service_name as child 
		FROM spans c
		JOIN spans p ON c.parent_span_id = p.span_id AND c.trace_uuid = p.trace_uuid
		WHERE c.workspace_id = ?
	`
	args := []interface{}{workspaceID}

	// Apply filters
	if filter.ServiceName != "" {
		query += " AND (p.service_name = ? OR c.service_name = ?)"
		args = append(args, filter.ServiceName, filter.ServiceName)
	}

	if !filter.TimeRangeStart.IsZero() {
		query += " AND c.start_time >= ?"
		args = append(args, filter.TimeRangeStart)
	}

	if !filter.TimeRangeEnd.IsZero() {
		query += " AND c.start_time <= ?"
		args = append(args, filter.TimeRangeEnd)
	}

	// Order by parent, child
	query += " ORDER BY parent, child"

	// Apply limit
	if filter.Limit > 0 {
		query += " LIMIT ?"
		args = append(args, filter.Limit)
	} else {
		query += " LIMIT 100" // default limit
	}

	err := database.DB.Raw(query, args...).Scan(&results).Error
	return results, err
}

// GetServiceList returns all unique services in the workspace
func (s *Service) GetServiceList(workspaceID uuid.UUID, filter TopologyFilter) ([]string, error) {
	var services []string

	query := "SELECT DISTINCT service_name FROM spans WHERE workspace_id = ?"
	args := []interface{}{workspaceID}

	if filter.ServiceName != "" {
		query += " AND service_name LIKE ?"
		args = append(args, "%"+filter.ServiceName+"%")
	}

	if !filter.TimeRangeStart.IsZero() {
		query += " AND start_time >= ?"
		args = append(args, filter.TimeRangeStart)
	}

	if !filter.TimeRangeEnd.IsZero() {
		query += " AND start_time <= ?"
		args = append(args, filter.TimeRangeEnd)
	}

	query += " ORDER BY service_name"

	err := database.DB.Raw(query, args...).Scan(&services).Error
	return services, err
}

// GetServiceMetrics returns aggregated metrics for a service
func (s *Service) GetServiceMetrics(workspaceID uuid.UUID, serviceName string, filter TopologyFilter) (map[string]interface{}, error) {
	metrics := make(map[string]interface{})

	// Base query
	baseQuery := "SELECT COUNT(*) as total_requests, AVG(duration_ms) as avg_latency, MAX(duration_ms) as max_latency FROM spans WHERE workspace_id = ? AND service_name = ?"
	args := []interface{}{workspaceID, serviceName}

	if !filter.TimeRangeStart.IsZero() {
		baseQuery += " AND start_time >= ?"
		args = append(args, filter.TimeRangeStart)
	}

	if !filter.TimeRangeEnd.IsZero() {
		baseQuery += " AND start_time <= ?"
		args = append(args, filter.TimeRangeEnd)
	}

	type metricsResult struct {
		TotalRequests int64   `json:"total_requests"`
		AvgLatency    float64 `json:"avg_latency"`
		MaxLatency    float64 `json:"max_latency"`
	}

	var result []metricsResult
	err := database.DB.Raw(baseQuery, args...).Scan(&result).Error
	if err != nil {
		return nil, err
	}

	if len(result) > 0 {
		metrics["total_requests"] = result[0].TotalRequests
		metrics["avg_latency_ms"] = result[0].AvgLatency
		metrics["max_latency_ms"] = result[0].MaxLatency
	}

	return metrics, nil
}

// DependencyGraphNode represents a node in the dependency graph
type DependencyGraphNode struct {
	ID       string                 `json:"id"`
	Label    string                 `json:"label"`
	Type     string                 `json:"type"` // "service", "database", "external"
	Metrics  map[string]interface{} `json:"metrics,omitempty"`
	Metadata map[string]interface{} `json:"metadata,omitempty"`
}

// DependencyGraphEdge represents an edge in the dependency graph
type DependencyGraphEdge struct {
	Source     string                 `json:"source"`
	Target     string                 `json:"target"`
	Type       string                 `json:"type"` // "sync", "async", "external"
	CallCount  int                    `json:"call_count"`
	AvgLatency float64                `json:"avg_latency_ms"`
	ErrorRate  float64                `json:"error_rate"`
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
}

// DependencyGraph represents the full dependency graph for visualization
type DependencyGraph struct {
	Nodes []DependencyGraphNode `json:"nodes"`
	Edges []DependencyGraphEdge `json:"edges"`
}

// GetDependencyGraph returns a complete dependency graph with node and edge data for visualization
func (s *Service) GetDependencyGraph(workspaceID uuid.UUID, filter TopologyFilter) (*DependencyGraph, error) {
	graph := &DependencyGraph{
		Nodes: []DependencyGraphNode{},
		Edges: []DependencyGraphEdge{},
	}

	// Get all unique services first
	services, err := s.GetServiceList(workspaceID, filter)
	if err != nil {
		return nil, err
	}

	// Track seen nodes and edges
	seenNodes := make(map[string]bool)
	seenEdges := make(map[string]bool)

	// Add service nodes with metrics
	for _, svc := range services {
		if seenNodes[svc] {
			continue
		}
		seenNodes[svc] = true

		metrics, _ := s.GetServiceMetrics(workspaceID, svc, filter)
		node := DependencyGraphNode{
			ID:      svc,
			Label:   svc,
			Type:    "service",
			Metrics: metrics,
		}
		graph.Nodes = append(graph.Nodes, node)
	}

	// Build base query for edges
	edgeQuery := `
		SELECT 
			p.service_name as parent,
			c.service_name as child,
			COUNT(*) as call_count,
			AVG(c.duration_ms) as avg_latency,
			CAST(SUM(CASE WHEN c.status_code >= 400 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 as error_rate
		FROM spans c
		JOIN spans p ON c.parent_span_id = p.span_id AND c.trace_uuid = p.trace_uuid
		WHERE c.workspace_id = ?
	`
	edgeArgs := []interface{}{workspaceID}

	if filter.ServiceName != "" {
		edgeQuery += " AND (p.service_name = ? OR c.service_name = ?)"
		edgeArgs = append(edgeArgs, filter.ServiceName, filter.ServiceName)
	}

	if !filter.TimeRangeStart.IsZero() {
		edgeQuery += " AND c.start_time >= ?"
		edgeArgs = append(edgeArgs, filter.TimeRangeStart)
	}

	if !filter.TimeRangeEnd.IsZero() {
		edgeQuery += " AND c.start_time <= ?"
		edgeArgs = append(edgeArgs, filter.TimeRangeEnd)
	}

	edgeQuery += " GROUP BY p.service_name, c.service_name ORDER BY call_count DESC"

	type edgeResult struct {
		Parent     string  `json:"parent"`
		Child      string  `json:"child"`
		CallCount  int     `json:"call_count"`
		AvgLatency float64 `json:"avg_latency"`
		ErrorRate  float64 `json:"error_rate"`
	}

	var edges []edgeResult
	err = database.DB.Raw(edgeQuery, edgeArgs...).Scan(&edges).Error
	if err != nil {
		return nil, err
	}

	// Process edges and add external nodes
	for _, e := range edges {
		edgeKey := e.Parent + "->" + e.Child
		if seenEdges[edgeKey] {
			continue
		}
		seenEdges[edgeKey] = true

		// Add child as external if not seen
		if !seenNodes[e.Child] {
			seenNodes[e.Child] = true
			graph.Nodes = append(graph.Nodes, DependencyGraphNode{
				ID:    e.Child,
				Label: e.Child,
				Type:  "external",
			})
		}

		// Determine edge type
		edgeType := "sync"
		if strings.HasPrefix(e.Child, "http://") || strings.HasPrefix(e.Child, "https://") {
			edgeType = "external"
		}

		graph.Edges = append(graph.Edges, DependencyGraphEdge{
			Source:     e.Parent,
			Target:     e.Child,
			Type:       edgeType,
			CallCount:  e.CallCount,
			AvgLatency: e.AvgLatency,
			ErrorRate:  e.ErrorRate,
		})
	}

	return graph, nil
}

// GetServiceDependencyDetails returns detailed dependency information for a specific service
func (s *Service) GetServiceDependencyDetails(workspaceID uuid.UUID, serviceName string, filter TopologyFilter) (map[string]interface{}, error) {
	details := make(map[string]interface{})

	// Get direct dependencies (services this service calls)
	depQuery := `
		SELECT DISTINCT c.service_name as service, COUNT(*) as calls, AVG(c.duration_ms) as latency
		FROM spans c
		WHERE c.workspace_id = ? AND c.parent_span_id IN (
			SELECT span_id FROM spans WHERE workspace_id = ? AND service_name = ?
		)
	`
	depArgs := []interface{}{workspaceID, workspaceID, serviceName}

	if !filter.TimeRangeStart.IsZero() {
		depQuery += " AND c.start_time >= ?"
		depArgs = append(depArgs, filter.TimeRangeStart)
	}

	if !filter.TimeRangeEnd.IsZero() {
		depQuery += " AND c.start_time <= ?"
		depArgs = append(depArgs, filter.TimeRangeEnd)
	}

	depQuery += " GROUP BY c.service_name"

	type depResult struct {
		Service string  `json:"service"`
		Calls   int     `json:"calls"`
		Latency float64 `json:"latency"`
	}

	var dependencies []depResult
	err := database.DB.Raw(depQuery, depArgs...).Scan(&dependencies).Error
	if err != nil {
		return nil, err
	}

	details["dependencies"] = dependencies

	// Get dependents (services that call this service)
	revDepQuery := `
		SELECT DISTINCT p.service_name as service, COUNT(*) as calls
		FROM spans p
		WHERE p.workspace_id = ? AND p.span_id IN (
			SELECT parent_span_id FROM spans WHERE workspace_id = ? AND service_name = ? AND parent_span_id IS NOT NULL
		)
	`
	revDepArgs := []interface{}{workspaceID, workspaceID, serviceName}

	if !filter.TimeRangeStart.IsZero() {
		revDepQuery += " AND p.start_time >= ?"
		revDepArgs = append(revDepArgs, filter.TimeRangeStart)
	}

	if !filter.TimeRangeEnd.IsZero() {
		revDepQuery += " AND p.start_time <= ?"
		revDepArgs = append(revDepArgs, filter.TimeRangeEnd)
	}

	revDepQuery += " GROUP BY p.service_name"

	var dependents []depResult
	err = database.DB.Raw(revDepQuery, revDepArgs...).Scan(&dependents).Error
	if err != nil {
		return nil, err
	}

	details["dependents"] = dependents
	return details, nil
}
