package workflow

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/oliveagle/jsonpath"
)

type ExtractionService struct{}

func (s *ExtractionService) Extract(jsonData, path string) (interface{}, error) {
	var data interface{}
	if err := json.Unmarshal([]byte(jsonData), &data); err != nil {
		return nil, err
	}

	res, err := jsonpath.JsonPathLookup(data, path)
	if err != nil {
		return nil, fmt.Errorf("jsonpath error: %v", err)
	}

	return res, nil
}

func (s *ExtractionService) SubVariables(text string, vars map[string]interface{}) string {
	for k, v := range vars {
		placeholder := "{{" + k + "}}"
		valStr := fmt.Sprintf("%v", v)
		text = strings.ReplaceAll(text, placeholder, valStr)
	}
	return text
}
