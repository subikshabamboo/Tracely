package alerting

import (
	"time"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct{}

func (s *Service) CheckThresholds(workspaceID uuid.UUID) ([]models.ThresholdViolation, error) {
	var rules []models.AlertRule
	if err := database.DB.Where("workspace_id = ? AND is_enabled = ?", workspaceID, true).Find(&rules).Error; err != nil {
		return nil, err
	}

	var violations []models.ThresholdViolation

	for _, rule := range rules {
		var slowTraces []models.Trace
		// Check last 5 minutes
		query := database.DB.Where("workspace_id = ? AND created_at > ?", workspaceID, time.Now().Add(-5*time.Minute))
		
		if rule.Metric == "duration_ms" {
			query = query.Where("duration_ms > ?", rule.Threshold)
		} else if rule.Metric == "error_rate" {
			// Complex error rate logic here
		}

		if err := query.Find(&slowTraces).Error; err == nil {
			for _, t := range slowTraces {
				v := models.ThresholdViolation{
					ID:          uuid.New(),
					WorkspaceID: workspaceID,
					AlertRuleID: rule.ID,
					TraceID:     t.TraceID,
					Value:       t.DurationMs,
					Timestamp:   time.Now(),
				}
				database.DB.Create(&v)
				violations = append(violations, v)
			}
		}
	}

	return violations, nil
}

