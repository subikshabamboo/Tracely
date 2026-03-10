package trace

import (
	"sort"
	"github.com/tracely/backend/internal/models"
)

type WaterfallService struct{}

type WaterfallNode struct {
	Span     models.Span     `json:"span"`
	Children []WaterfallNode `json:"children"`
}

func (s *WaterfallService) BuildTree(spans []models.Span) []WaterfallNode {
	spanMap := make(map[string]*WaterfallNode)
	var roots []WaterfallNode

	// Sort spans by start time for consistent tree building
	sort.Slice(spans, func(i, j int) bool {
		return spans[i].StartTime.Before(spans[j].StartTime)
	})

	for _, span := range spans {
		node := &WaterfallNode{Span: span, Children: []WaterfallNode{}}
		spanMap[span.SpanID] = node
	}

	for _, span := range spans {
		node := spanMap[span.SpanID]
		if span.ParentSpanID != "" {
			if parent, ok := spanMap[span.ParentSpanID]; ok {
				parent.Children = append(parent.Children, *node)
				continue
			}
		}
		roots = append(roots, *node)
	}

	return roots
}
