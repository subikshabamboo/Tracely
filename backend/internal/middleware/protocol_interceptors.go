package middleware

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc"
	"google.golang.org/grpc/metadata"
)

// GraphQL constants
const (
	GraphQLContentType       = "application/json"
	GraphQLBatchContentType  = "application/json"
	GraphQLTransportWS       = "websocket"
	GraphQLSubscriptionsPath = "/graphql subscriptions"
)

// GraphQL operation types
const (
	OperationTypeQuery        = "query"
	OperationTypeMutation     = "mutation"
	OperationTypeSubscription = "subscription"
)

// GraphQLRequest represents a standard GraphQL request
type GraphQLRequest struct {
	Query         string                 `json:"query"`
	OperationName string                 `json:"operationName"`
	Variables     map[string]interface{} `json:"variables"`
	Extensions    map[string]interface{} `json:"extensions"`
}

// GraphQLResponse represents a standard GraphQL response
type GraphQLResponse struct {
	Data   interface{}    `json:"data,omitempty"`
	Errors []GraphQLError `json:"errors,omitempty"`
}

// GraphQLError represents a GraphQL error
type GraphQLError struct {
	Message   string                 `json:"message"`
	Locations []GraphQLErrorLocation `json:"locations,omitempty"`
	Path      []interface{}          `json:"path,omitempty"`
}

// GraphQLErrorLocation represents location in GraphQL query
type GraphQLErrorLocation struct {
	Line   int `json:"line"`
	Column int `json:"column"`
}

// GraphQLOperationInfo contains parsed operation information
type GraphQLOperationInfo struct {
	Type            string
	Name            string
	Query           string
	Variables       map[string]interface{}
	IsIntrospection bool
}

// GraphQLMetrics holds GraphQL operation metrics
type GraphQLMetrics struct {
	OperationType string
	OperationName string
	QueryLength   int
	Complexity    int
	DurationMs    float64
	HasErrors     bool
	Timestamp     time.Time
}

// Simple schema registry for introspection
var (
	schemaMutex   sync.RWMutex
	graphqlSchema *GraphQLSchema
)

// GraphQLSchema represents a basic GraphQL schema
type GraphQLSchema struct {
	Types            map[string]*GraphQLType
	QueryType        *GraphQLType
	MutationType     *GraphQLType
	SubscriptionType *GraphQLType
}

// GraphQLType represents a GraphQL type
type GraphQLType struct {
	Name        string
	Description string
	Fields      map[string]*GraphQLField
	Kind        string // OBJECT, SCALAR, ENUM, etc.
}

// GraphQLField represents a GraphQL field
type GraphQLField struct {
	Name        string
	Description string
	Type        string
	Args        []GraphQLArg
	IsNonNull   bool
	IsList      bool
}

// GraphQLArg represents a GraphQL argument
type GraphQLArg struct {
	Name         string
	Type         string
	Description  string
	DefaultValue string
}

// GraphQL subscription connection
type GraphQLSubscription struct {
	ID        string
	TraceID   string
	Query     string
	Variables map[string]interface{}
	Done      chan struct{}
}

// SubscriptionManager manages active GraphQL subscriptions
type SubscriptionManager struct {
	subscriptions map[string]*GraphQLSubscription
	mu            sync.RWMutex
	hub           *WebSocketHub
}

// WebSocketHub interface for sending subscription messages
type WebSocketHub interface {
	BroadcastToUser(userID, msgType string, data interface{})
}

var subManager = &SubscriptionManager{
	subscriptions: make(map[string]*GraphQLSubscription),
}

// RegisterSchema registers a GraphQL schema for introspection
func RegisterSchema(schema *GraphQLSchema) {
	schemaMutex.Lock()
	defer schemaMutex.Unlock()
	graphqlSchema = schema
}

// GetSchema returns the registered GraphQL schema
func GetSchema() *GraphQLSchema {
	schemaMutex.RLock()
	defer schemaMutex.RUnlock()
	return graphqlSchema
}

// InitDefaultSchema initializes a default schema with common types
func InitDefaultSchema() {
	schema := &GraphQLSchema{
		Types: make(map[string]*GraphQLType),
		QueryType: &GraphQLType{
			Name: "Query",
			Kind: "OBJECT",
			Fields: map[string]*GraphQLField{
				"health": {
					Name:      "health",
					Type:      "String",
					IsNonNull: false,
				},
				"trace": {
					Name:      "trace",
					Type:      "Trace",
					IsNonNull: false,
					Args: []GraphQLArg{
						{Name: "id", Type: "ID!", Description: "Trace ID"},
					},
				},
				"traces": {
					Name:      "traces",
					Type:      "[Trace]",
					IsNonNull: false,
					Args: []GraphQLArg{
						{Name: "limit", Type: "Int", Description: "Limit results"},
						{Name: "offset", Type: "Int", Description: "Offset results"},
					},
				},
			},
		},
		MutationType: &GraphQLType{
			Name: "Mutation",
			Kind: "OBJECT",
			Fields: map[string]*GraphQLField{
				"createTrace": {
					Name:      "createTrace",
					Type:      "Trace",
					IsNonNull: true,
				},
			},
		},
		SubscriptionType: &GraphQLType{
			Name: "Subscription",
			Kind: "OBJECT",
			Fields: map[string]*GraphQLField{
				"traceUpdated": {
					Name:      "traceUpdated",
					Type:      "Trace",
					IsNonNull: false,
				},
			},
		},
	}

	// Add built-in types
	schema.Types["Query"] = schema.QueryType
	schema.Types["Mutation"] = schema.MutationType
	schema.Types["Subscription"] = schema.SubscriptionType
	schema.Types["Trace"] = &GraphQLType{
		Name: "Trace",
		Kind: "OBJECT",
		Fields: map[string]*GraphQLField{
			"id":        {Name: "id", Type: "ID!", IsNonNull: true},
			"traceID":   {Name: "traceID", Type: "String", IsNonNull: true},
			"duration":  {Name: "duration", Type: "Float", IsNonNull: false},
			"timestamp": {Name: "timestamp", Type: "String", IsNonNull: false},
			"spans":     {Name: "spans", Type: "[Span]", IsNonNull: false},
		},
	}
	schema.Types["Span"] = &GraphQLType{
		Name: "Span",
		Kind: "OBJECT",
		Fields: map[string]*GraphQLField{
			"id":        {Name: "id", Type: "ID!", IsNonNull: true},
			"name":      {Name: "name", Type: "String", IsNonNull: true},
			"service":   {Name: "service", Type: "String", IsNonNull: false},
			"duration":  {Name: "duration", Type: "Float", IsNonNull: false},
			"startTime": {Name: "startTime", Type: "String", IsNonNull: false},
		},
	}
	schema.Types["String"] = &GraphQLType{Name: "String", Kind: "SCALAR"}
	schema.Types["Int"] = &GraphQLType{Name: "Int", Kind: "SCALAR"}
	schema.Types["Float"] = &GraphQLType{Name: "Float", Kind: "SCALAR"}
	schema.Types["Boolean"] = &GraphQLType{Name: "Boolean", Kind: "SCALAR"}
	schema.Types["ID"] = &GraphQLType{Name: "ID", Kind: "SCALAR"}

	RegisterSchema(schema)
}

// gRPC Interceptor for Trace Propagation
func UnaryServerInterceptor() grpc.UnaryServerInterceptor {
	return func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
		md, ok := metadata.FromIncomingContext(ctx)
		var traceID string
		if ok {
			if t, ok := md["x-trace-id"]; ok && len(t) > 0 {
				traceID = t[0]
			}
		}

		if traceID == "" {
			traceID = uuid.New().String()
		}

		// Inject into outgoing context
		newCtx := metadata.AppendToOutgoingContext(ctx, "x-trace-id", traceID)

		return handler(newCtx, req)
	}
}

// parseGraphQLRequest parses a GraphQL request body
func parseGraphQLRequest(body []byte) (*GraphQLRequest, error) {
	var req GraphQLRequest
	if err := json.Unmarshal(body, &req); err != nil {
		return nil, fmt.Errorf("failed to parse GraphQL request: %w", err)
	}
	return &req, nil
}

// parseGraphQLOperation parses the GraphQL query and extracts operation info
func parseGraphQLOperation(query string) *GraphQLOperationInfo {
	info := &GraphQLOperationInfo{
		Query: query,
	}

	// Check for introspection query
	stringsLower := strings.ToLower(query)
	if strings.Contains(stringsLower, "__schema") || strings.Contains(stringsLower, "__typename") {
		info.IsIntrospection = true
	}

	// Simple operation type detection
	if strings.HasPrefix(strings.TrimSpace(query), "query") || strings.Contains(query, "query ") {
		info.Type = OperationTypeQuery
	} else if strings.HasPrefix(strings.TrimSpace(query), "mutation") || strings.Contains(query, "mutation ") {
		info.Type = OperationTypeMutation
	} else if strings.HasPrefix(strings.TrimSpace(query), "subscription") || strings.Contains(query, "subscription ") {
		info.Type = OperationTypeSubscription
	}

	// Extract operation name if present
	if idx := strings.Index(query, "query "); idx >= 0 {
		rest := query[idx+6:]
		if endIdx := strings.IndexAny(rest, " {"); endIdx > 0 {
			info.Name = strings.TrimSpace(rest[:endIdx])
		}
	} else if idx := strings.Index(query, "mutation "); idx >= 0 {
		rest := query[idx+9:]
		if endIdx := strings.IndexAny(rest, " {"); endIdx > 0 {
			info.Name = strings.TrimSpace(rest[:endIdx])
		}
	} else if idx := strings.Index(query, "subscription "); idx >= 0 {
		rest := query[idx+13:]
		if endIdx := strings.IndexAny(rest, " {"); endIdx > 0 {
			info.Name = strings.TrimSpace(rest[:endIdx])
		}
	}

	return info
}

// calculateQueryComplexity provides a basic complexity analysis
func calculateQueryComplexity(query string) int {
	complexity := 1

	// Count nested selections
	depth := 0
	maxDepth := 0
	for _, r := range query {
		switch r {
		case '{':
			depth++
			if depth > maxDepth {
				maxDepth = depth
			}
		case '}':
			depth--
		}
	}

	// Weight by operation type
	stringsLower := strings.ToLower(query)
	if strings.Contains(stringsLower, "mutation") {
		complexity *= 3
	} else if strings.Contains(stringsLower, "subscription") {
		complexity *= 5
	}

	// Factor in query length
	complexity += len(query) / 100

	// Factor in depth
	complexity += maxDepth * 2

	return complexity
}

// handleGraphQLIntrospection handles GraphQL schema introspection
func handleGraphQLIntrospection(w http.ResponseWriter, r *http.Request) {
	schema := GetSchema()
	if schema == nil {
		w.Header().Set("Content-Type", GraphQLContentType)
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(GraphQLResponse{
			Errors: []GraphQLError{{Message: "No schema registered"}},
		})
		return
	}

	// Build introspection response
	introspection := map[string]interface{}{
		"__schema": map[string]interface{}{
			"queryType": map[string]string{"name": "Query"},
			"mutationType": func() interface{} {
				if schema.MutationType != nil {
					return map[string]string{"name": "Mutation"}
				}
				return nil
			}(),
			"subscriptionType": func() interface{} {
				if schema.SubscriptionType != nil {
					return map[string]string{"name": "Subscription"}
				}
				return nil
			}(),
			"types": buildIntrospectionTypes(schema),
		},
	}

	w.Header().Set("Content-Type", GraphQLContentType)
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(GraphQLResponse{Data: introspection})
}

// buildIntrospectionTypes builds type definitions for introspection
func buildIntrospectionTypes(schema *GraphQLSchema) []map[string]interface{} {
	types := make([]map[string]interface{}, 0)

	for name, t := range schema.Types {
		// Skip introspection types
		if strings.HasPrefix(name, "__") {
			continue
		}

		typeDef := map[string]interface{}{
			"kind":        t.Kind,
			"name":        name,
			"description": t.Description,
		}

		if len(t.Fields) > 0 && (t.Kind == "OBJECT" || t.Kind == "INTERFACE") {
			fields := make([]map[string]interface{}, 0)
			for _, f := range t.Fields {
				fieldMap := map[string]interface{}{
					"name": f.Name,
					"type": map[string]interface{}{
						"name":   f.Type,
						"kind":   getTypeKind(f.Type),
						"ofType": getNonNullListOf(f.Type),
					},
				}
				if len(f.Args) > 0 {
					args := make([]map[string]interface{}, 0)
					for _, a := range f.Args {
						args = append(args, map[string]interface{}{
							"name":         a.Name,
							"type":         map[string]string{"name": a.Type},
							"defaultValue": a.DefaultValue,
						})
					}
					fieldMap["args"] = args
				}
				fields = append(fields, fieldMap)
			}
			typeDef["fields"] = fields
		}

		types = append(types, typeDef)
	}

	return types
}

// getTypeKind determines the kind for a type reference
func getTypeKind(typeName string) string {
	if strings.HasSuffix(typeName, "!") {
		return "NON_NULL"
	}
	if strings.HasPrefix(typeName, "[") {
		return "LIST"
	}
	return "NAMED"
}

// getNonNullListOf handles complex type references
func getNonNullListOf(typeName string) interface{} {
	if strings.HasSuffix(typeName, "!") {
		baseType := strings.TrimSuffix(typeName, "!")
		if strings.HasPrefix(baseType, "[") && strings.HasSuffix(baseType, "]") {
			return map[string]interface{}{
				"kind": "NON_NULL",
				"ofType": map[string]interface{}{
					"kind": "LIST",
					"ofType": map[string]interface{}{
						"kind": "NAMED",
						"name": strings.Trim(baseType, "[]"),
					},
				},
			}
		}
		return map[string]interface{}{
			"kind": "NON_NULL",
			"ofType": map[string]interface{}{
				"kind": "NAMED",
				"name": baseType,
			},
		}
	}
	return nil
}

// GraphQLMiddleware provides comprehensive GraphQL request handling
func GraphQLMiddleware(next http.Handler) http.Handler {
	// Initialize default schema
	InitDefaultSchema()

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		startTime := time.Now()
		traceID := r.Header.Get("X-Trace-Id")

		// Handle GraphQL WebSocket connections for subscriptions
		if isGraphQLWebSocket(r) {
			handleGraphQLWebSocket(w, r, traceID)
			return
		}

		// Handle regular GraphQL HTTP requests
		if isGraphQLRequest(r) {
			handleGraphQLRequest(w, r, &traceID, startTime, next)
			return
		}

		// Fall back to regular HTTP handling
		next.ServeHTTP(w, r)
	})
}

// isGraphQLRequest checks if the request is a GraphQL request
func isGraphQLRequest(r *http.Request) bool {
	contentType := r.Header.Get("Content-Type")
	return r.Method == http.MethodPost && strings.Contains(contentType, "application/json")
}

// isGraphQLWebSocket checks if this is a GraphQL WebSocket connection
func isGraphQLWebSocket(r *http.Request) bool {
	return r.Header.Get("Upgrade") == "websocket" &&
		strings.Contains(r.URL.Path, "subscriptions")
}

// handleGraphQLWebSocket handles GraphQL subscription WebSocket connections
func handleGraphQLWebSocket(w http.ResponseWriter, r *http.Request, traceID string) {
	// Generate subscription ID
	subID := uuid.New().String()

	// Create subscription context
	sub := &GraphQLSubscription{
		ID:        subID,
		TraceID:   traceID,
		Query:     r.URL.Query().Get("query"),
		Variables: make(map[string]interface{}),
		Done:      make(chan struct{}),
	}

	// Register subscription
	subManager.mu.Lock()
	subManager.subscriptions[subID] = sub
	subManager.mu.Unlock()

	// Set up WebSocket connection
	hijacker, ok := w.(http.Hijacker)
	if !ok {
		http.Error(w, "WebSocket upgrade not supported", http.StatusInternalServerError)
		return
	}

	conn, _, err := hijacker.Hijack()
	if err != nil {
		http.Error(w, "Failed to hijack connection", http.StatusInternalServerError)
		return
	}

	defer func() {
		subManager.mu.Lock()
		delete(subManager.subscriptions, subID)
		subManager.mu.Unlock()
		conn.Close()
	}()

	// Send connection acknowledgment
	conn.Write([]byte(fmt.Sprintf(`{"type":"connection_ack","id":"%s"}`, subID)))

	// Handle incoming messages
	buf := make([]byte, 4096)
	for {
		n, err := conn.Read(buf)
		if err != nil {
			break
		}

		var msg map[string]interface{}
		if err := json.Unmarshal(buf[:n], &msg); err != nil {
			continue
		}

		msgType, _ := msg["type"].(string)
		switch msgType {
		case "start":
			// Start subscription - would typically set up data stream here
			payload, _ := msg["payload"].(map[string]interface{})
			if payload != nil {
				if query, ok := payload["query"].(string); ok {
					sub.Query = query
				}
				if vars, ok := payload["variables"].(map[string]interface{}); ok {
					sub.Variables = vars
				}
			}
			conn.Write([]byte(fmt.Sprintf(`{"id":"%s","type":"start_ack"}`, subID)))

		case "stop":
			conn.Write([]byte(fmt.Sprintf(`{"id":"%s","type":"complete"}`, subID)))
			return

		case "connection_terminate":
			return
		}
	}
}

// handleGraphQLRequest processes GraphQL HTTP requests
func handleGraphQLRequest(w http.ResponseWriter, r *http.Request, traceID *string, startTime time.Time, next http.Handler) {
	// Read request body
	body, err := io.ReadAll(r.Body)
	if err != nil {
		sendGraphQLError(w, "Failed to read request body", http.StatusBadRequest)
		return
	}

	// Restore body for downstream handlers
	r.Body = io.NopCloser(bytes.NewBuffer(body))

	// Parse GraphQL request
	graphqlReq, err := parseGraphQLRequest(body)
	if err != nil {
		sendGraphQLError(w, err.Error(), http.StatusBadRequest)
		return
	}

	// Extract trace ID from GraphQL extensions if not in header
	if *traceID == "" {
		if graphqlReq.Extensions != nil {
			if tid, ok := graphqlReq.Extensions["trace_id"].(string); ok {
				*traceID = tid
			} else if tid, ok := graphqlReq.Extensions["traceId"].(string); ok {
				*traceID = tid
			}
		}
	}

	// Generate new trace ID if still not present
	if *traceID == "" {
		*traceID = uuid.New().String()
	}

	// Parse operation info
	opInfo := parseGraphQLOperation(graphqlReq.Query)

	// Handle introspection queries directly
	if opInfo.IsIntrospection {
		handleGraphQLIntrospection(w, r)
		// Log metrics for introspection
		logGraphQLMetrics(*traceID, opInfo, 0, false, startTime)
		return
	}

	// Set trace ID in header for downstream handlers
	r.Header.Set("X-Trace-Id", *traceID)

	// Calculate query complexity
	complexity := calculateQueryComplexity(graphqlReq.Query)

	// Create a response wrapper to capture the response
	wrapper := &GraphQLResponseWriter{
		ResponseWriter: w,
		Data:           nil,
		Errors:         nil,
	}

	// Call next handler
	next.ServeHTTP(wrapper, r)

	// Log metrics
	logGraphQLMetrics(*traceID, opInfo, complexity, len(wrapper.Errors) > 0, startTime)
}

// sendGraphQLError sends a GraphQL error response
func sendGraphQLError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", GraphQLContentType)
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(GraphQLResponse{
		Errors: []GraphQLError{{Message: message}},
	})
}

// GraphQLResponseWriter wraps http.ResponseWriter to capture GraphQL response
type GraphQLResponseWriter struct {
	http.ResponseWriter
	Data   interface{}
	Errors []GraphQLError
}

// Write captures the response data
func (w *GraphQLResponseWriter) Write(b []byte) (int, error) {
	// Try to parse the response
	var resp GraphQLResponse
	if err := json.Unmarshal(b, &resp); err == nil {
		w.Data = resp.Data
		w.Errors = resp.Errors
	}
	return w.ResponseWriter.Write(b)
}

// logGraphQLMetrics logs GraphQL operation metrics
func logGraphQLMetrics(traceID string, opInfo *GraphQLOperationInfo, complexity int, hasErrors bool, startTime time.Time) {
	metrics := GraphQLMetrics{
		OperationType: opInfo.Type,
		OperationName: opInfo.Name,
		QueryLength:   len(opInfo.Query),
		Complexity:    complexity,
		DurationMs:    float64(time.Since(startTime).Milliseconds()),
		HasErrors:     hasErrors,
		Timestamp:     startTime,
	}

	// In production, these metrics would be sent to a metrics service
	// For now, we log to stdout
	fmt.Printf("[GraphQL Metrics] trace_id=%s type=%s name=%s complexity=%d duration_ms=%.2f errors=%v\n",
		traceID, metrics.OperationType, metrics.OperationName, metrics.Complexity, metrics.DurationMs, metrics.HasErrors)
}

// GetSubscription returns a subscription by ID
func GetSubscription(id string) *GraphQLSubscription {
	subManager.mu.RLock()
	defer subManager.mu.RUnlock()
	return subManager.subscriptions[id]
}

// BroadcastToSubscription sends data to a specific subscription
func BroadcastToSubscription(subID string, data interface{}) bool {
	subManager.mu.RLock()
	sub, ok := subManager.subscriptions[subID]
	subManager.mu.RUnlock()

	if !ok || sub == nil {
		return false
	}

	// In production, this would send via WebSocket
	// For now, we just log
	fmt.Printf("[GraphQL Subscription] id=%s data=%v\n", subID, data)
	return true
}

// CleanupSubscription removes a subscription
func CleanupSubscription(subID string) {
	subManager.mu.Lock()
	defer subManager.mu.Unlock()
	if sub, ok := subManager.subscriptions[subID]; ok && sub != nil {
		close(sub.Done)
	}
	delete(subManager.subscriptions, subID)
}
