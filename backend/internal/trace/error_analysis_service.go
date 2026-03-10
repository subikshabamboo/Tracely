package trace

import (
	"encoding/json"
	"strings"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/models"
)

type ErrorAnalysisService struct{}

type ErrorPattern struct {
	ID            string    `json:"id"`
	Message       string    `json:"message"`
	SampleTraceID uuid.UUID `json:"sample_trace_id"`
	Count         int       `json:"count"`
	Service       string    `json:"service"`
}

func (s *ErrorAnalysisService) AnalyzePatterns(spans []models.Span) []ErrorPattern {
	patterns := make(map[string]*ErrorPattern)

	for _, span := range spans {
		// Parse Tags from json.RawMessage
		var tags map[string]interface{}
		if err := json.Unmarshal(span.Tags, &tags); err != nil {
			continue
		}

		// Look for error tags or high status codes
		errorVal, hasError := tags["error"]
		statusCodeVal, hasStatusCode := tags["status_code"]

		isError := hasError && errorVal == true
		isHighStatusCode := false

		if hasStatusCode {
			if sc, ok := statusCodeVal.(float64); ok {
				isHighStatusCode = sc >= 400
			}
		}

		if isError || isHighStatusCode {
			message := "Unknown error"
			if msg, ok := tags["error.message"].(string); ok {
				message = msg
			} else if msg, ok := tags["message"].(string); ok {
				message = msg
			}

			// Clean message for clustering
			clusterKey := s.getClusterKey(message, span.ServiceName)

			if p, ok := patterns[clusterKey]; ok {
				p.Count++
			} else {
				patterns[clusterKey] = &ErrorPattern{
					ID:            uuid.New().String(),
					Message:       message,
					SampleTraceID: span.TraceUUID,
					Count:         1,
					Service:       span.ServiceName,
				}
			}
		}
	}

	result := make([]ErrorPattern, 0, len(patterns))
	for _, p := range patterns {
		result = append(result, *p)
	}
	return result
}

func (s *ErrorAnalysisService) getClusterKey(msg, service string) string {
	key := strings.ToLower(msg)
	return service + ":" + key
}
