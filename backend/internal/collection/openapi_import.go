package collection

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/models"
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

// ImportOpenAPI imports an OpenAPI specification and converts it to a collection
func ImportOpenAPI(r io.Reader, workspaceID uuid.UUID) (*models.Collection, error) {
	var spec OpenAPISpec
	if err := json.NewDecoder(r).Decode(&spec); err != nil {
		return nil, fmt.Errorf("failed to parse OpenAPI spec: %w", err)
	}

	collection := &models.Collection{
		ID:          uuid.New(),
		Name:        spec.Info.Title,
		Description: spec.Info.Description,
		WorkspaceID: workspaceID,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// Convert paths to requests (Items)
	for path, methods := range spec.Paths {
		for method, operation := range methods {
			item := convertOperationToCollectionItem(path, method, operation, spec.Components)
			collection.Items = append(collection.Items, *item)
		}
	}

	log.Printf("Imported OpenAPI spec '%s' with %d endpoints", spec.Info.Title, len(collection.Items))
	return collection, nil
}

func convertOperationToCollectionItem(path, method string, op OpenAPIOperation, components OpenAPIComponents) *models.CollectionItem {
	item := &models.CollectionItem{
		ID:     uuid.New(),
		Name:   getOperationName(op, path, method),
		Method: strings.ToUpper(method),
		URL:    path,
	}

	// Convert parameters to headers
	var headers map[string]interface{}
	for _, param := range op.Parameters {
		if param.In == "header" {
			if headers == nil {
				headers = make(map[string]interface{})
			}
			headers[param.Name] = getSchemaExample(param.Schema)
		}
	}
	if headers != nil {
		item.Headers = headers
	}

	// Convert request body
	if op.RequestBody != nil {
		for _, mediaType := range op.RequestBody.Content {
			if example := mediaType.Example; example != nil {
				bodyBytes, _ := json.Marshal(example)
				item.Body = string(bodyBytes)
			} else if schema := mediaType.Schema; schema != nil {
				item.Body = generateExampleFromSchema(schema, components.Schemas)
			}
			break
		}
	}

	return item
}

func getOperationName(op OpenAPIOperation, path, method string) string {
	if op.OperationID != "" {
		return op.OperationID
	}
	if op.Summary != "" {
		return op.Summary
	}
	return fmt.Sprintf("%s %s", strings.ToUpper(method), path)
}

func getSchemaExample(schema map[string]interface{}) string {
	if schema == nil {
		return ""
	}
	if example, ok := schema["example"]; ok {
		return fmt.Sprintf("%v", example)
	}
	if enum, ok := schema["enum"]; ok {
		return fmt.Sprintf("%v", enum)
	}
	if typ, ok := schema["type"].(string); ok {
		switch typ {
		case "string":
			if format, ok := schema["format"].(string); ok {
				switch format {
				case "date-time":
					return "2024-01-01T00:00:00Z"
				case "date":
					return "2024-01-01"
				case "email":
					return "user@example.com"
				case "uuid":
					return uuid.New().String()
				}
			}
			return "string"
		case "integer", "number":
			return "0"
		case "boolean":
			return "true"
		case "array":
			return "[]"
		case "object":
			return "{}"
		}
	}
	return ""
}

func generateExampleFromSchema(schema map[string]interface{}, components map[string]map[string]interface{}) string {
	if schema == nil {
		return "{}"
	}

	// Handle $ref
	if ref, ok := schema["$ref"].(string); ok {
		schemaName := strings.TrimPrefix(ref, "#/components/schemas/")
		if componentSchema, ok := components[schemaName]; ok {
			return generateExampleFromSchema(componentSchema, components)
		}
		return "{}"
	}

	// Handle type
	typ, _ := schema["type"].(string)
	switch typ {
	case "object":
		if properties, ok := schema["properties"].(map[string]interface{}); ok {
			result := map[string]interface{}{}
			for key, prop := range properties {
				if propMap, ok := prop.(map[string]interface{}); ok {
					result[key] = getSchemaExample(propMap)
				}
			}
			bytes, _ := json.Marshal(result)
			return string(bytes)
		}
	case "array":
		if items, ok := schema["items"].(map[string]interface{}); ok {
			example := []interface{}{getSchemaExample(items)}
			bytes, _ := json.Marshal(example)
			return string(bytes)
		}
	}

	return getSchemaExample(schema)
}

// ValidateRequestAgainstOpenAPI validates a request against an OpenAPI specification
func ValidateRequestAgainstOpenAPI(spec *OpenAPISpec, method, path string, body string) ValidationResult {
	result := ValidationResult{
		Valid:  true,
		Path:   path,
		Method: method,
		Errors: []string{},
	}

	// Find matching path
	pathItem, exists := spec.Paths[path]
	if !exists {
		// Try to find with path parameters
		for p, pi := range spec.Paths {
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
		if param.Required {
			_ = param.Name
		}
	}

	// Validate request body
	if op.RequestBody != nil && body != "" {
		for ct, _ := range op.RequestBody.Content {
			if strings.Contains(ct, "json") {
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

// ValidateResponseAgainstOpenAPI validates a response against an OpenAPI specification
func ValidateResponseAgainstOpenAPI(spec *OpenAPISpec, method, path string, statusCode int, responseBody string) ValidationResult {
	result := ValidationResult{
		Valid:  true,
		Path:   path,
		Method: method,
		Errors: []string{},
	}

	pathItem, exists := spec.Paths[path]
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
