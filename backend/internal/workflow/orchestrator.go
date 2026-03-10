package workflow

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/oliveagle/jsonpath"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/replay"
	"github.com/xeipuuv/gojsonschema"
)

type Orchestrator struct {
	MutationService *replay.MutationService
}

type StepResult struct {
	StepID     string                 `json:"step_id"`
	Status     string                 `json:"status"`
	StatusCode int                    `json:"status_code"`
	Output     map[string]interface{} `json:"output"`
	TraceID    string                 `json:"trace_id"`
}

func (o *Orchestrator) Run(workflowID uuid.UUID) ([]StepResult, error) {
	var wf models.Workflow
	if err := database.DB.First(&wf, workflowID).Error; err != nil {
		return nil, err
	}

	steps, ok := wf.Definition["steps"].([]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid workflow definition: missing steps")
	}

	variables := make(map[string]interface{})
	var results []StepResult
	client := &http.Client{Timeout: 30 * time.Second}

	for _, s := range steps {
		step, _ := s.(map[string]interface{})
		stepID, _ := step["id"].(string)
		condition, _ := step["condition"].(string)

		// 0. Evaluate Condition
		if condition != "" && !o.evaluateCondition(condition, variables) {
			log.Printf("Skipping step %s due to condition: %s", stepID, condition)
			continue
		}

		// 1. Handle Loops & Retries
		loopCount := 1
		if lc, ok := step["loop_count"].(float64); ok {
			loopCount = int(lc)
		}
		retryCount := 0
		if rc, ok := step["retry_count"].(float64); ok {
			retryCount = int(rc)
		}

		for i := 0; i < loopCount; i++ {
			var lastResult StepResult
			for attempt := 0; attempt <= retryCount; attempt++ {
				lastResult = o.executeStep(step, variables, client)
				if lastResult.Status == "success" {
					break
				}
				if attempt < retryCount {
					log.Printf("Retrying step %s (attempt %d/%d)", stepID, attempt+1, retryCount)
					time.Sleep(1 * time.Second)
				}
			}
			results = append(results, lastResult)
			if lastResult.Status == "failed" {
				break // Stop workflow on failure
			}
		}
	}

	return results, nil
}

func (o *Orchestrator) executeStep(step map[string]interface{}, variables map[string]interface{}, client *http.Client) StepResult {
	stepID, _ := step["id"].(string)
	method, _ := step["method"].(string)
	urlTemplate, _ := step["url"].(string)
	bodyTemplate, _ := step["body"].(string)

	url := o.MutationService.InjectVariables(uuid.Nil, stepID, urlTemplate, variables)
	body := o.MutationService.InjectVariables(uuid.Nil, stepID, bodyTemplate, variables)

	traceID := uuid.New().String()
	req, _ := http.NewRequest(method, url, bytes.NewBufferString(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Trace-Id", traceID)

	resp, err := client.Do(req)
	if err != nil {
		return StepResult{StepID: stepID, Status: "failed", Output: map[string]interface{}{"error": err.Error()}}
	}
	defer resp.Body.Close()

	respBody, _ := io.ReadAll(resp.Body)
	var jsonBody interface{}
	json.Unmarshal(respBody, &jsonBody)

	// Extract outputs
	if mapping, ok := step["output_mapping"].(map[string]interface{}); ok {
		for varName, path := range mapping {
			pathStr, _ := path.(string)
			res, err := jsonpath.JsonPathLookup(jsonBody, pathStr)
			if err == nil {
				variables[varName] = res
			}
		}
	}

	result := StepResult{
		StepID:     stepID,
		Status:     "success",
		StatusCode: resp.StatusCode,
		Output:     map[string]interface{}{"body": string(respBody)},
		TraceID:    traceID,
	}

	// Schema Validation
	if schemaRaw, ok := step["expected_schema"].(string); ok && schemaRaw != "" {
		schemaLoader := gojsonschema.NewStringLoader(schemaRaw)
		documentLoader := gojsonschema.NewStringLoader(string(respBody))
		valResult, _ := gojsonschema.Validate(schemaLoader, documentLoader)
		if valResult != nil && !valResult.Valid() {
			result.Status = "failed"
			result.Output["error"] = "Contract validation failed"
		}
	}

	return result
}

func (o *Orchestrator) evaluateCondition(cond string, vars map[string]interface{}) bool {
	if cond == "" || cond == "true" {
		return true
	}

	// Basic parser for "var_name == value" or "status_code == 200"
	parts := strings.Split(cond, " == ")
	if len(parts) == 2 {
		left := strings.TrimSpace(parts[0])
		right := strings.TrimSpace(parts[1])

		val, ok := vars[left]
		if !ok {
			return false
		}
		// Special handling for common types
		return fmt.Sprintf("%v", val) == right
	}

	return false
}
