package trace

import (
	"fmt"
	"sort"
	"github.com/tracely/backend/internal/models"
)

type OptimizationService struct{}

type OptimizationRecommendation struct {
	Type        string  `json:"type"`
	Severity    string  `json:"severity"`
	Title       string  `json:"title"`
	Description string  `json:"description"`
	Potential   float64 `json:"potential_ms"`
}

func (s *OptimizationService) Analyze(spans []models.Span) []OptimizationRecommendation {
	var recs []OptimizationRecommendation

	// 1. N+1 Query Detection
	recs = append(recs, s.detectNPlusOne(spans)...)

	// 2. Linear Execution Detection
	recs = append(recs, s.detectSerialExecution(spans)...)

	return recs
}

func (s *OptimizationService) detectNPlusOne(spans []models.Span) []OptimizationRecommendation {
	counts := make(map[string]int)
	durations := make(map[string]float64)

	for _, span := range spans {
		if span.OperationName != "" {
			key := span.ServiceName + ":" + span.OperationName
			counts[key]++
			durations[key] += span.DurationMs
		}
	}

	var recs []OptimizationRecommendation
	for key, count := range counts {
		if count > 5 { // Threshold for N+1
			recs = append(recs, OptimizationRecommendation{
				Type:        "N+1 Query",
				Severity:    "HIGH",
				Title:       fmt.Sprintf("Detected redundant %s calls", key),
				Description: fmt.Sprintf("This endpoint makes %d calls to the same resource. Consider batching or caching.", count),
				Potential:   durations[key] * 0.8, // Estimate 80% savings from batching
			})
		}
	}
	return recs
}

func (s *OptimizationService) detectSerialExecution(spans []models.Span) []OptimizationRecommendation {
	// Group children by parent
	children := make(map[string][]models.Span)
	for _, span := range spans {
		if span.ParentSpanID != "" {
			children[span.ParentSpanID] = append(children[span.ParentSpanID], span)
		}
	}

	var recs []OptimizationRecommendation
	for parentID, childSpans := range children {
		if len(childSpans) < 3 {
			continue
		}

		// Sort by start time
		sort.Slice(childSpans, func(i, j int) bool {
			return childSpans[i].StartTime.Before(childSpans[j].StartTime)
		})

		// Check overlap
		serialCount := 0
		totalSerialDuration := 0.0
		for i := 0; i < len(childSpans)-1; i++ {
			if childSpans[i].EndTime.Before(childSpans[i+1].StartTime) || childSpans[i].EndTime.Equal(childSpans[i+1].StartTime) {
				serialCount++
				totalSerialDuration += childSpans[i].DurationMs
			}
		}

		if serialCount > 2 {
			recs = append(recs, OptimizationRecommendation{
				Type:        "Serial Execution",
				Severity:    "MEDIUM",
				Title:       "Sequential operations detected",
				Description: fmt.Sprintf("Sub-spans of %s are executing one after another. Consider parallelizing these operations.", parentID),
				Potential:   totalSerialDuration * 0.5, // Estimate 50% savings from parallelization
			})
		}
	}

	return recs
}
