package audit

import (
	"time"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct{}

func (s *Service) Log(workspaceID, userID uuid.UUID, action, resource, metadata string) error {
	log := &models.AuditLog{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		UserID:      userID,
		Action:      action,
		Resource:    resource,
		Timestamp:   time.Now(),
		Metadata:    metadata,
	}
	// Add AuditLog to AutoMigrate in db.go
	return database.DB.Create(log).Error
}
