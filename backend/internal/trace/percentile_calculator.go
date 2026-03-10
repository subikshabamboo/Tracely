package trace

import (
	"sort"
	"time"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
)

type PercentileCalculator struct{}

func (s *PercentileCalculator) Calculate(workspaceID uuid.UUID, serviceName string, startTime, endTime time.Time) (map[string]float64, error) {
	var durations []float64
	query := database.DB.Table("traces").
		Where("workspace_id = ? AND service_name = ?", workspaceID, serviceName)

	if !startTime.IsZero() {
		query = query.Where("created_at >= ?", startTime)
	}
	if !endTime.IsZero() {
		query = query.Where("created_at <= ?", endTime)
	}

	err := query.Pluck("duration_ms", &durations).Error

	if err != nil {
		return nil, err
	}

	if len(durations) == 0 {
		return map[string]float64{"p50": 0, "p95": 0, "p99": 0}, nil
	}

	sort.Float64s(durations)

	return map[string]float64{
		"p50": getPercentile(durations, 50),
		"p95": getPercentile(durations, 95),
		"p99": getPercentile(durations, 99),
	}, nil
}

func getPercentile(data []float64, percentile float64) float64 {
	if len(data) == 0 {
		return 0
	}
	index := int(float64(len(data)-1) * percentile / 100.0)
	return data[index]
}
