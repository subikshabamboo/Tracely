package workflow

import (
	"context"
	"errors"

	"github.com/google/uuid"

	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/request"
	"github.com/tracely/backend/internal/schema"
)

type Service struct {
	Extractor       *ExtractionService
	RequestService  *request.Service
	SchemaValidator *schema.Validator
}

func (s *Service) Execute(workflowID uuid.UUID) error {
	var wf models.Workflow
	if err := database.DB.First(&wf, workflowID).Error; err != nil {
		return err
	}

	variables := make(map[string]interface{})
	steps, ok := wf.Definition["steps"].([]interface{})
	if !ok {
		return errors.New("invalid workflow definition: missing steps")
	}

	for _, step := range steps {
		sMap, ok := step.(map[string]interface{})
		if !ok {
			continue
		}

		stepType, _ := sMap["type"].(string)

		switch stepType {
		case "request":
			if err := s.handleRequestStep(sMap, variables); err != nil {
				return err
			}
		case "conditional":
			if err := s.handleConditionalStep(sMap, variables); err != nil {
				return err
			}
		}
	}

	return nil
}

func (s *Service) handleRequestStep(step map[string]interface{}, vars map[string]interface{}) error {
	method, _ := step["method"].(string)
	url, _ := step["url"].(string)
	if url == "" {
		return errors.New("url is required for request step")
	}
	url = s.Extractor.SubVariables(url, vars)

	resp, status, err := s.RequestService.Do(context.Background(), method, url, nil, nil)
	if err != nil {
		return err
	}

	// Extract variables if defined
	if extract, ok := step["extract"].([]interface{}); ok {
		for _, e := range extract {
			eMap, ok := e.(map[string]interface{})
			if !ok {
				continue
			}
			name, _ := eMap["name"].(string)
			path, _ := eMap["path"].(string)
			if name != "" && path != "" {
				val, _ := s.Extractor.Extract(string(resp), path)
				vars[name] = val
			}
		}
	}
	vars["last_status"] = status
	return nil

}

func (s *Service) handleConditionalStep(step map[string]interface{}, vars map[string]interface{}) error {
	// Simple evaluation logic for demo
	if vars["last_status"] == 200 {
		if _, ok := step["then"].([]interface{}); ok {
			// Execute sub-steps (stub)
		}
	}

	return nil
}
