package trace

import (
	"fmt"
	"github.com/tracely/backend/internal/models"
)

type CriticalPathService struct{}

func (s *CriticalPathService) Identify(spans []models.Span) []string {
	if len(spans) == 0 {
		return []string{}
	}

	// Critical path is the longest sequence of spans that are causal
	// In a simple waterfall, it's often the root and its longest children
	// This is a naive implementation: longest duration path
	
	spanMap := make(map[string]models.Span)
	childrenMap := make(map[string][]string)
	var rootID string

	for _, s := range spans {
		spanMap[s.SpanID] = s
		if s.ParentSpanID == "" {
			rootID = s.SpanID
		} else {
			childrenMap[s.ParentSpanID] = append(childrenMap[s.ParentSpanID], s.SpanID)
		}
	}

	if rootID == "" {
		return []string{}
	}

	return s.findMaxPath(rootID, childrenMap, spanMap)
}

func (s *CriticalPathService) findMaxPath(currentID string, childrenMap map[string][]string, spanMap map[string]models.Span) []string {
	children := childrenMap[currentID]
	if len(children) == 0 {
		return []string{currentID}
	}

	var maxPath []string
	var maxDuration float64

	for _, childID := range children {
		path := s.findMaxPath(childID, childrenMap, spanMap)
		duration := 0.0
		for _, id := range path {
			duration += spanMap[id].DurationMs
		}

		if duration > maxDuration {
			maxDuration = duration
			maxPath = path
		}
	}

	return append([]string{currentID}, maxPath...)
}
func (s *CriticalPathService) CalculatePotentialSavings(spans []models.Span, criticalPath []string) (float64, string) {
	if len(criticalPath) == 0 {
		return 0, "No critical path identified."
	}

	spanMap := make(map[string]models.Span)
	for _, span := range spans {
		spanMap[span.SpanID] = span
	}

	totalCriticalDuration := 0.0
	var bottleneckSpan models.Span
	maxDuration := 0.0

	for _, id := range criticalPath {
		if span, ok := spanMap[id]; ok {
			totalCriticalDuration += span.DurationMs
			if span.DurationMs > maxDuration {
				maxDuration = span.DurationMs
				bottleneckSpan = span
			}
		}
	}

	// Heuristic: If we optimize the slowest span by 50%, we save that amount
	savings := maxDuration * 0.5
	recommendation := "No bottleneck found."
	if bottleneckSpan.SpanID != "" {
		recommendation = fmt.Sprintf("Optimize %s:%s to save up to %.2f ms.", bottleneckSpan.ServiceName, bottleneckSpan.OperationName, savings)
	}

	return savings, recommendation
}
