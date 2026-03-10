package schema

import (
	"encoding/json"
	"fmt"
	"io"
	"strings"
)

// OpenAPISpec represents an OpenAPI 3.0 specification
type OpenAPISpec struct {
	OpenAPI    string                 `json:"openapi"`
	Info       OpenAPIInfo            `json:"info"`
	Paths      map[string]OpenAPIPath `json:"paths"`
	Components OpenAPIComponents      `json:"components,omitempty"`
}

type OpenAPIInfo struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Version     string `json:"version"`
}

type OpenAPIPath map[string]OpenAPIOperation

type OpenAPIOperation struct {
	Summary     string                     `json:"summary"`
	Description string                     `json:"description"`
	OperationID string                     `json:"operationId"`
	Parameters  []OpenAPIParameter         `json:"parameters,omitempty"`
	RequestBody *OpenAPIRequestBody        `json:"requestBody,omitempty"`
	Responses   map[string]OpenAPIResponse `json:"responses"`
	Tags        []string                   `json:"tags"`
}

type OpenAPIParameter struct {
	Name        string                 `json:"name"`
	In          string                 `json:"in"`
	Description string                 `json:"description"`
	Required    bool                   `json:"required"`
	Schema      map[string]interface{} `json:"schema"`
}

type OpenAPIRequestBody struct {
	Description string                      `json:"description"`
	Content     map[string]OpenAPIMediaType `json:"content"`
	Required    bool                        `json:"required"`
}

type OpenAPIMediaType struct {
	Schema  map[string]interface{} `json:"schema"`
	Example interface{}            `json:"example,omitempty"`
}

type OpenAPIResponse struct {
	Description string                      `json:"description"`
	Content     map[string]OpenAPIMediaType `json:"content,omitempty"`
}

type OpenAPIComponents struct {
	Schemas map[string]map[string]interface{} `json:"schemas,omitempty"`
}

// ValidationResult holds the result of an OpenAPI validation
type ValidationResult struct {
	Valid  bool     `json:"valid"`
	Errors []string `json:"errors"`
	Path   string   `json:"path"`
	Method string   `json:"method"`
}

// OpenAPIValidator handles OpenAPI validation
type OpenAPIValidator struct {
	spec *OpenAPISpec
}

// NewOpenAPIValidator creates a new OpenAPI validator from an io.Reader
func NewOpenAPIValidator(r io.Reader) (*OpenAPIValidator, error) {
	var spec OpenAPISpec
	if err := json.NewDecoder(r).Decode(&spec); err != nil {
		return nil, fmt.Errorf("failed to parse OpenAPI spec: %w", err)
	}
	return &OpenAPIValidator{spec: &spec}, nil
}

// ValidateRequest validates a request against the OpenAPI spec
func (v *OpenAPIValidator) ValidateRequest(method, path, body string) ValidationResult {
	result := ValidationResult{
		Valid:  true,
		Path:   path,
		Method: method,
		Errors: []string{},
	}

	// Find matching path
	pathItem, exists := v.spec.Paths[path]
	if !exists {
		// Try to find with path parameters
		for p, pi := range v.spec.Paths {
			if matchPathParams(p, path) {
				pathItem = pi
				path = p
				break
			}
		}
		if !exists {
			result.Valid = false
			result.Errors = append(result.Errors, fmt.Sprintf("Path %s not found in spec", path))
			return result
		}
	}

	// Find matching operation
	op, exists := pathItem[strings.ToLower(method)]
	if !exists {
		result.Valid = false
		result.Errors = append(result.Errors, fmt.Sprintf("Method %s not found for path %s", method, path))
		return result
	}

	// Validate required parameters
	for _, param := range op.Parameters {
		if param.Required && param.In == "path" {
			result.Errors = append(result.Errors, fmt.Sprintf("Required path parameter '%s' not provided", param.Name))
			result.Valid = false
		}
	}

	// Validate request body
	if op.RequestBody != nil && body != "" {
		for contentType, _ := range op.RequestBody.Content {
			if strings.Contains(contentType, "json") {
				var jsonBody interface{}
				if err := json.Unmarshal([]byte(body), &jsonBody); err != nil {
					result.Valid = false
					result.Errors = append(result.Errors, fmt.Sprintf("Invalid JSON body: %v", err))
				}
				break
			}
		}
	}

	return result
}

// ValidateResponse validates a response against the OpenAPI spec
func (v *OpenAPIValidator) ValidateResponse(method, path string, statusCode int, responseBody string) ValidationResult {
	result := ValidationResult{
		Valid:  true,
		Path:   path,
		Method: method,
		Errors: []string{},
	}

	pathItem, exists := v.spec.Paths[path]
	if !exists {
		result.Valid = false
		result.Errors = append(result.Errors, fmt.Sprintf("Path %s not found", path))
		return result
	}

	op, exists := pathItem[strings.ToLower(method)]
	if !exists {
		result.Valid = false
		result.Errors = append(result.Errors, fmt.Sprintf("Method %s not found", method))
		return result
	}

	// Find matching response
	statusStr := fmt.Sprintf("%d", statusCode)
	response, exists := op.Responses[statusStr]
	if !exists {
		// Check for default response
		if response, exists = op.Responses["default"]; !exists {
			result.Valid = false
			result.Errors = append(result.Errors, fmt.Sprintf("No response defined for status code %d", statusCode))
			return result
		}
	}

	// Validate response body against schema
	if responseBody != "" && response.Content != nil {
		for contentType, _ := range response.Content {
			if strings.Contains(contentType, "json") {
				var jsonBody interface{}
				if err := json.Unmarshal([]byte(responseBody), &jsonBody); err != nil {
					result.Valid = false
					result.Errors = append(result.Errors, fmt.Sprintf("Invalid JSON in response: %v", err))
				}
				break
			}
		}
	}

	return result
}

func matchPathParams(pattern, actual string) bool {
	patternParts := strings.Split(pattern, "/")
	actualParts := strings.Split(actual, "/")
	if len(patternParts) != len(actualParts) {
		return false
	}
	for i, part := range patternParts {
		if strings.HasPrefix(part, "{") && strings.HasSuffix(part, "}") {
			continue
		}
		if part != actualParts[i] {
			return false
		}
	}
	return true
}

// GetSpecInfo returns basic info about the loaded spec
func (v *OpenAPIValidator) GetSpecInfo() map[string]string {
	return map[string]string{
		"title":       v.spec.Info.Title,
		"description": v.spec.Info.Description,
		"version":     v.spec.Info.Version,
		"openapi":     v.spec.OpenAPI,
	}
}

// GetEndpoints returns all available endpoints
func (v *OpenAPIValidator) GetEndpoints() []map[string]string {
	endpoints := []map[string]string{}
	for path, methods := range v.spec.Paths {
		for method := range methods {
			endpoints = append(endpoints, map[string]string{
				"path":   path,
				"method": method,
			})
		}
	}
	return endpoints
}
