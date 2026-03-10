package trace

import (
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type TrendService struct {
	PercentileCalculator *PercentileCalculator
}

type TrendMetrics struct {
	P50       float64 `json:"p50"`
	P95       float64 `json:"p95"`
	P99       float64 `json:"p99"`
	ErrorRate float64 `json:"error_rate"`
}

type TrendReport struct {
	Current  TrendMetrics `json:"current"`
	Previous TrendMetrics `json:"previous"`
	Changes  TrendMetrics `json:"changes_percentage"`
}

func (s *TrendService) AnalyzeTrend(workspaceID uuid.UUID, serviceName string, currentStart, currentEnd, prevStart, prevEnd time.Time) (*TrendReport, error) {
	current, err := s.getMetrics(workspaceID, serviceName, currentStart, currentEnd)
	if err != nil {
		return nil, err
	}

	previous, err := s.getMetrics(workspaceID, serviceName, prevStart, prevEnd)
	if err != nil {
		return nil, err
	}

	report := &TrendReport{
		Current:  current,
		Previous: previous,
		Changes: TrendMetrics{
			P50:       calculateChange(previous.P50, current.P50),
			P95:       calculateChange(previous.P95, current.P95),
			P99:       calculateChange(previous.P99, current.P99),
			ErrorRate: calculateChange(previous.ErrorRate, current.ErrorRate),
		},
	}

	return report, nil
}

func (s *TrendService) getMetrics(workspaceID uuid.UUID, serviceName string, start, end time.Time) (TrendMetrics, error) {
	pcts, err := s.PercentileCalculator.Calculate(workspaceID, serviceName, start, end)
	if err != nil {
		return TrendMetrics{}, err
	}

	var errorCount int64
	var totalCount int64

	database.DB.Model(&models.Trace{}).
		Where("workspace_id = ? AND service_name = ? AND created_at BETWEEN ? AND ?", workspaceID, serviceName, start, end).
		Count(&totalCount)

	database.DB.Model(&models.Trace{}).
		Where("workspace_id = ? AND service_name = ? AND status_code >= 400 AND created_at BETWEEN ? AND ?", workspaceID, serviceName, start, end).
		Count(&errorCount)

	errorRate := 0.0
	if totalCount > 0 {
		errorRate = (float64(errorCount) / float64(totalCount)) * 100
	}

	return TrendMetrics{
		P50:       pcts["p50"],
		P95:       pcts["p95"],
		P99:       pcts["p99"],
		ErrorRate: errorRate,
	}, nil
}

func calculateChange(oldVal, newVal float64) float64 {
	if oldVal == 0 {
		if newVal == 0 {
			return 0
		}
		return 100.0 // 100% increase if started from 0
	}
	return ((newVal - oldVal) / oldVal) * 100.0
}
