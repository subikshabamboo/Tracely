package environment

import (
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type EnvironmentService struct{}

func (s *EnvironmentService) GetForWorkspace(workspaceID uuid.UUID) ([]models.Environment, error) {
	var envs []models.Environment
	err := database.DB.Where("workspace_id = ?", workspaceID).Find(&envs).Error
	return envs, err
}

