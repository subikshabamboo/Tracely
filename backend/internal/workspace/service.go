package workspace

import (
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"gorm.io/gorm"
)

type Service struct{}

func (s *Service) Create(name string, ownerID uuid.UUID) (*models.Workspace, error) {
	workspace := &models.Workspace{
		ID:        uuid.New(),
		Name:      name,
		CreatedAt: time.Now(),
		UpdatedAt: time.Now(),
	}

	err := database.DB.Transaction(func(tx *gorm.DB) error {
		if err := tx.Create(workspace).Error; err != nil {
			return err
		}

		workspaceUser := &models.WorkspaceUser{
			WorkspaceID: workspace.ID,
			UserID:      ownerID,
			Role:        "Owner",
		}

		return tx.Create(workspaceUser).Error
	})

	return workspace, err
}

func (s *Service) GetForUser(userID uuid.UUID) ([]models.Workspace, error) {
	var workspaces []models.Workspace
	err := database.DB.Table("workspaces").
		Joins("JOIN workspace_users ON workspace_users.user_id = ?", userID).
		Where("workspaces.id = workspace_users.workspace_id").
		Find(&workspaces).Error
	return workspaces, err
}

func (s *Service) Delete(id uuid.UUID) error {
	return database.DB.Transaction(func(tx *gorm.DB) error {
		// Delete associations first
		if err := tx.Where("workspace_id = ?", id).Delete(&models.WorkspaceUser{}).Error; err != nil {
			return err
		}
		// Delete the workspace
		return tx.Delete(&models.Workspace{}, id).Error
	})
}
