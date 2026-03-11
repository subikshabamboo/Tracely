package database

import (
	"fmt"
	"os"
	"time"

	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/session"
	"github.com/tracely/backend/internal/settings"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)


var DB *gorm.DB

func Connect() error {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		return fmt.Errorf("DATABASE_URL environment variable is required")
	}

	var err error
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return fmt.Errorf("failed to connect to database: %v", err)
	}

	sqlDB, err := DB.DB()
	if err == nil {
		sqlDB.SetMaxIdleConns(10)
		sqlDB.SetMaxOpenConns(100)
		sqlDB.SetConnMaxLifetime(time.Hour)
	}

	// Auto Migration
	err = DB.AutoMigrate(
		&models.User{},
		&models.Workspace{},
		&models.WorkspaceUser{},
		&models.Trace{},
		&models.Span{},
		&models.Replay{},
		&models.ReplayExecution{},
		&models.Mock{},
		&models.Secret{},
		&models.Workflow{},
		&settings.UserSettings{},
		&session.DebugSession{},
		&models.Annotation{},
		&models.AlertRule{},
		&models.ThresholdViolation{},
		&models.MaskingAudit{},
		&models.ReplayComparison{},
		&models.Collection{},
		&models.CollectionItem{},
		&models.Notification{},
		&models.OnCallSchedule{},
		&models.RedactionRule{},
		&models.TracingConfig{},
		&models.AuditLog{},
		&models.Environment{},
		&models.MutationRecord{},
		&models.CascadeResult{},
		&models.ErrorInjectionConfig{},
		&models.ErrorCascadeSimulation{},
		&models.TraceShare{},
		&models.RampPattern{},
		&models.LoadTestProgress{},
	)




	if err != nil {
		return fmt.Errorf("failed to migrate database: %v", err)
	}

	return nil
}

func Close() {
	if DB != nil {
		sqlDB, err := DB.DB()
		if err == nil {
			sqlDB.Close()
		}
	}
}

