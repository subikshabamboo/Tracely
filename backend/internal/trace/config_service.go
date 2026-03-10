package trace

import (
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type TracingConfigService struct{}

func (s *TracingConfigService) GetConfig(workspaceID uuid.UUID) (*models.TracingConfig, error) {
	if workspaceID == uuid.Nil {
		return &models.TracingConfig{
			WorkspaceID: workspaceID,
			SamplingRules: map[string]float64{
				"*": 1.0,
			},
			IsEnabled: true,
		}, nil
	}

	var config models.TracingConfig
	if err := database.DB.Where("workspace_id = ?", workspaceID).First(&config).Error; err != nil {
		// Return default if not found
		return &models.TracingConfig{
			WorkspaceID: workspaceID,
			SamplingRules: map[string]float64{
				"*": 1.0,
			},
			IsEnabled: true,
		}, nil
	}
	return &config, nil
}
