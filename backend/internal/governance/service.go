package governance

import (
	"regexp"
	"time"
	"unicode/utf8"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct{}

func (s *Service) MaskAndAuditPII(workspaceID uuid.UUID, traceID, data string) string {
	if !utf8.ValidString(data) {
		return data // Skip binary data
	}

	// Fetch dynamic rules for the workspace
	var rules []models.RedactionRule
	if err := database.DB.Where("workspace_id = ? AND is_enabled = ?", workspaceID, true).Find(&rules).Error; err != nil {
		return data
	}

	masked := data
	for _, rule := range rules {
		re, err := regexp.Compile(rule.Pattern)
		if err != nil {
			continue
		}
		if re.MatchString(masked) {
			masked = re.ReplaceAllString(masked, rule.Replacement)
			s.logMasking(workspaceID, traceID, rule.Name, "redaction_rule")
		}
	}

	// Fallback to defaults if no rules exist (optional, but keep for safety)
	if len(rules) == 0 {
		emailRegex := regexp.MustCompile(`[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}`)
		cardRegex := regexp.MustCompile(`\b(?:\d[ -]*?){13,16}\b`)

		if emailRegex.MatchString(masked) {
			masked = emailRegex.ReplaceAllString(masked, "[EMAIL_MASKED]")
			s.logMasking(workspaceID, traceID, "email", "regex_email")
		}
		if cardRegex.MatchString(masked) {
			masked = cardRegex.ReplaceAllString(masked, "[CARD_MASKED]")
			s.logMasking(workspaceID, traceID, "credit_card", "regex_card")
		}
	}
	
	return masked
}

func (s *Service) logMasking(workspaceID uuid.UUID, traceID, field, rule string) {
	audit := models.MaskingAudit{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		TraceID:     traceID,
		Field:       field,
		Rule:        rule,
		Timestamp:   time.Now(),
	}
	database.DB.Create(&audit)
}

