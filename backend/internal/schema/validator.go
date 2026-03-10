package schema

import (
	"fmt"
	"github.com/xeipuuv/gojsonschema"
)

type Validator struct{}

func (v *Validator) ValidateJSON(schemaStr, documentStr string) error {
	schemaLoader := gojsonschema.NewStringLoader(schemaStr)
	documentLoader := gojsonschema.NewStringLoader(documentStr)

	result, err := gojsonschema.Validate(schemaLoader, documentLoader)
	if err != nil {
		return err
	}

	if result.Valid() {
		return nil
	} else {
		var errorMsgs []string
		for _, desc := range result.Errors() {
			errorMsgs = append(errorMsgs, desc.String())
		}
		return fmt.Errorf("schema validation failed: %v", errorMsgs)
	}
}
