package mock

import (
	"encoding/json"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct{}

func (s *Service) CreateMockFromTrace(traceID uuid.UUID) (*models.Mock, error) {
	var t models.Trace
	if err := database.DB.Preload("Spans").First(&t, traceID).Error; err != nil {
		return nil, err
	}

	// Convert json.RawMessage to map[string]interface{}
	var respHeaders map[string]interface{}
	if len(t.ResponseHeaders) > 0 {
		_ = json.Unmarshal(t.ResponseHeaders, &respHeaders)
	}

	mock := &models.Mock{
		ID:              uuid.New(),
		WorkspaceID:     t.WorkspaceID,
		Endpoint:        t.OperationName, // Often path
		Method:          "GET",
		ResponseCode:    t.StatusCode,
		ResponseBody:    t.ResponseBody,
		ResponseHeaders: respHeaders,
		IsActive:        true,
	}

	err := database.DB.Create(mock).Error
	return mock, err
}

func (s *Service) InferSchema(body []byte) (string, error) {
	var data interface{}
	if err := json.Unmarshal(body, &data); err != nil {
		return "", err
	}

	schema := s.generateSchema(data)
	schemaJSON, _ := json.MarshalIndent(schema, "", "  ")
	return string(schemaJSON), nil
}

func (s *Service) generateSchema(data interface{}) map[string]interface{} {
	switch v := data.(type) {
	case map[string]interface{}:
		properties := make(map[string]interface{})
		for k, val := range v {
			properties[k] = s.generateSchema(val)
		}
		return map[string]interface{}{
			"type":       "object",
			"properties": properties,
		}
	case []interface{}:
		items := interface{}(map[string]interface{}{"type": "string"})
		if len(v) > 0 {
			items = s.generateSchema(v[0])
		}
		return map[string]interface{}{
			"type":  "array",
			"items": items,
		}
	case string:
		return map[string]interface{}{"type": "string"}
	case float64:
		return map[string]interface{}{"type": "number"}
	case bool:
		return map[string]interface{}{"type": "boolean"}
	default:
		return map[string]interface{}{"type": "null"}
	}
}
