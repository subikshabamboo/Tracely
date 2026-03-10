package alerting

import (
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/webhook"
)

// EscalationPolicy defines an escalation workflow
type EscalationPolicy struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	Name          string    `json:"name"`
	WorkspaceID   uuid.UUID `gorm:"index" json:"workspace_id"`
	NumLevels     int       `json:"num_levels"`             // Number of escalation levels
	EscalateAfter int       `json:"escalate_after_minutes"` // Minutes before escalating
	IsEnabled     bool      `gorm:"default:true" json:"is_enabled"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// EscalationLevel defines each level in the escalation chain
type EscalationLevel struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey" json:"id"`
	PolicyID     uuid.UUID `gorm:"index" json:"policy_id"`
	Level        int       `json:"level"`         // 1 = Primary, 2 = Secondary, etc.
	UserID       uuid.UUID `json:"user_id"`       // User to notify
	NotifyMethod string    `json:"notify_method"` // "email", "sms", "slack", "pagerduty"
	DelayMinutes int       `json:"delay_minutes"`
	CreatedAt    time.Time `json:"created_at"`
}

// AlertEscalation tracks the current state of an alert's escalation
type AlertEscalation struct {
	ID               uuid.UUID  `gorm:"type:uuid;primaryKey" json:"id"`
	AlertID          uuid.UUID  `gorm:"index" json:"alert_id"`
	PolicyID         uuid.UUID  `json:"policy_id"`
	CurrentLevel     int        `json:"current_level"`
	LastEscalatedAt  time.Time  `json:"last_escalated_at"`
	NextEscalationAt time.Time  `json:"next_escalation_at"`
	Status           string     `json:"status"` // "active", "acknowledged", "resolved"
	AcknowledgedAt   *time.Time `json:"acknowledged_at,omitempty"`
	AcknowledgedBy   *uuid.UUID `json:"acknowledged_by,omitempty"`
	ResolvedAt       *time.Time `json:"resolved_at,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
}

type EscalationService struct {
	WebhookService  *webhook.Service
	PagerDutyConfig webhook.PagerDutyConfig
}

// NewEscalationService creates a new escalation service
func NewEscalationService() *EscalationService {
	return &EscalationService{
		WebhookService: &webhook.Service{},
	}
}

// CreatePolicy creates a new escalation policy
func (s *EscalationService) CreatePolicy(policy *EscalationPolicy) error {
	policy.ID = uuid.New()
	policy.CreatedAt = time.Now()
	policy.UpdatedAt = time.Now()
	return database.DB.Create(policy).Error
}

// AddLevel adds an escalation level to a policy
func (s *EscalationService) AddLevel(level *EscalationLevel) error {
	level.ID = uuid.New()
	level.CreatedAt = time.Now()
	return database.DB.Create(level).Error
}

// StartEscalation begins the escalation process for an alert
func (s *EscalationService) StartEscalation(alertID, policyID uuid.UUID) error {
	var policy EscalationPolicy
	if err := database.DB.First(&policy, policyID).Error; err != nil {
		return fmt.Errorf("policy not found: %w", err)
	}

	now := time.Now()
	escalation := &AlertEscalation{
		ID:               uuid.New(),
		AlertID:          alertID,
		PolicyID:         policyID,
		CurrentLevel:     1,
		LastEscalatedAt:  now,
		NextEscalationAt: now.Add(time.Duration(policy.EscalateAfter) * time.Minute),
		Status:           "active",
		CreatedAt:        now,
	}

	return database.DB.Create(escalation).Error
}

// ProcessEscalations checks and processes pending escalations
func (s *EscalationService) ProcessEscalations() {
	var escalations []AlertEscalation
	now := time.Now()

	// Find escalations that need to be processed
	database.DB.Where("status = ? AND next_escalation_at <= ?", "active", now).
		Find(&escalations)

	for _, escalation := range escalations {
		s.processEscalation(escalation)
	}
}

func (s *EscalationService) processEscalation(escalation AlertEscalation) {
	// Get the policy and levels
	var policy EscalationPolicy
	if err := database.DB.First(&policy, escalation.PolicyID).Error; err != nil {
		log.Printf("Error finding policy: %v", err)
		return
	}

	var levels []EscalationLevel
	database.DB.Where("policy_id = ?", escalation.PolicyID).
		Order("level ASC").
		Find(&levels)

	if escalation.CurrentLevel > len(levels) {
		// All levels exhausted, mark as maxed out
		escalation.Status = "max_escalated"
		database.DB.Save(&escalation)
		return
	}

	level := levels[escalation.CurrentLevel-1]

	// Get user contact info
	var user models.User
	if err := database.DB.First(&user, level.UserID).Error; err != nil {
		log.Printf("Error finding user: %v", err)
		return
	}

	// Send notification based on method
	s.sendNotification(level.NotifyMethod, user.Email, escalation.AlertID)

	// Update escalation state
	escalation.LastEscalatedAt = time.Now()
	escalation.CurrentLevel++
	if escalation.CurrentLevel <= len(levels) {
		nextLevel := levels[escalation.CurrentLevel-1]
		escalation.NextEscalationAt = time.Now().Add(time.Duration(nextLevel.DelayMinutes) * time.Minute)
	}

	database.DB.Save(&escalation)
}

func (s *EscalationService) sendNotification(method, contact string, alertID uuid.UUID) {
	switch method {
	case "email":
		// Email notification would go here
		log.Printf("Sending email escalation to %s for alert %s", contact, alertID)
	case "slack":
		// Slack notification
		log.Printf("Sending slack escalation to %s for alert %s", contact, alertID)
	case "pagerduty":
		summary := fmt.Sprintf("Escalated Alert: %s", alertID)
		s.WebhookService.SendPagerDutyNotification(s.PagerDutyConfig, summary, "critical", "tracely")
	case "sms":
		log.Printf("Sending SMS escalation to %s for alert %s", contact, alertID)
	default:
		log.Printf("Unknown notification method: %s", method)
	}
}

// AcknowledgeAlert acknowledges an alert, stopping escalation
func (s *EscalationService) AcknowledgeAlert(escalationID uuid.UUID, userID uuid.UUID) error {
	var escalation AlertEscalation
	if err := database.DB.First(&escalation, escalationID).Error; err != nil {
		return err
	}

	now := time.Now()
	escalation.Status = "acknowledged"
	escalation.AcknowledgedAt = &now
	escalation.AcknowledgedBy = &userID

	return database.DB.Save(&escalation).Error
}

// ResolveAlert resolves an alert
func (s *EscalationService) ResolveAlert(escalationID uuid.UUID) error {
	var escalation AlertEscalation
	if err := database.DB.First(&escalation, escalationID).Error; err != nil {
		return err
	}

	now := time.Now()
	escalation.Status = "resolved"
	escalation.ResolvedAt = &now

	return database.DB.Save(&escalation).Error
}

// GetOnCallSchedule returns the current on-call user for a workspace
func (s *EscalationService) GetOnCallSchedule(workspaceID uuid.UUID) (*models.OnCallSchedule, error) {
	var schedule models.OnCallSchedule
	now := time.Now()

	err := database.DB.Where("workspace_id = ? AND start_time <= ? AND end_time >= ?",
		workspaceID, now, now).
		Order("level ASC").
		First(&schedule).Error

	if err != nil {
		return nil, err
	}

	return &schedule, nil
}

// StartEscalationFromViolation starts escalation from a threshold violation
func (s *EscalationService) StartEscalationFromViolation(violation models.ThresholdViolation, workspaceID uuid.UUID) error {
	// Get the first enabled escalation policy for this workspace
	var policy EscalationPolicy
	err := database.DB.Where("workspace_id = ? AND is_enabled = ?", workspaceID, true).
		First(&policy).Error

	if err != nil {
		log.Printf("No escalation policy found for workspace %s: %v", workspaceID, err)
		return nil // Don't fail if no policy
	}

	// Get on-call user for primary level
	_, err = s.GetOnCallSchedule(workspaceID)
	if err != nil {
		log.Printf("No on-call schedule found: %v", err)
		return nil
	}

	// Create the alert first (would integrate with existing alert system)
	alertID := uuid.New()

	// Start escalation
	return s.StartEscalation(alertID, policy.ID)
}
