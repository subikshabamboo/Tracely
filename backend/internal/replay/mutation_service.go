package replay

import (
	"fmt"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type MutationService struct{}

func (s *MutationService) Mutate(data string, rules map[string]string) string {
	result := data
	for pattern, replacement := range rules {
		// Simple find/replace for demonstration
		// Could be regex or JSONPath based
		result = strings.ReplaceAll(result, pattern, replacement)
	}
	return result
}

func (s *MutationService) InjectVariables(executionID uuid.UUID, spanID string, data string, env map[string]interface{}) string {
	result := data
	for key, value := range env {
		placeholder := "{{" + key + "}}"
		valStr := fmt.Sprintf("%v", value)
		if strings.Contains(result, placeholder) {
			s.RecordMutation(executionID, spanID, key, placeholder, "[ENV_VAR]")
			result = strings.ReplaceAll(result, placeholder, valStr)
		}
	}
	return result
}

func (s *MutationService) InjectSecrets(executionID uuid.UUID, spanID string, data string, workspaceID uuid.UUID, decryptFn func(string) (string, error)) string {
	var secrets []models.Secret
	database.DB.Where("workspace_id = ?", workspaceID).Find(&secrets)

	result := data
	for _, sec := range secrets {
		placeholder := "{{secret:" + sec.Key + "}}"
		if strings.Contains(result, placeholder) {
			val, err := decryptFn(sec.Value)
			if err != nil {
				log.Printf("Failed to decrypt secret %s: %v", sec.Key, err)
				continue
			}
			s.RecordMutation(executionID, spanID, sec.Key, placeholder, "[SECRET_INJECTED]")
			result = strings.ReplaceAll(result, placeholder, val)
		}
	}
	return result
}

func (s *MutationService) RecordMutation(executionID uuid.UUID, spanID, key, original, mutated string) {
	record := models.MutationRecord{
		ID:            uuid.New(),
		ExecutionID:   executionID,
		SpanID:        spanID,
		Key:           key,
		OriginalValue: original,
		MutatedValue:  mutated,
		Timestamp:     time.Now(),
	}
	database.DB.Create(&record)
}

func (s *MutationService) ApplyRules(data string, rules map[string]string) string {
	result := data
	for pattern, replacement := range rules {
		result = strings.ReplaceAll(result, pattern, replacement)
	}
	return result
}

