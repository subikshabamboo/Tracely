package collection

import (
	"encoding/json"
	"io"
	"github.com/tracely/backend/internal/models"
	"github.com/google/uuid"
)

type PostmanCollection struct {
	Info struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	} `json:"info"`
	Item []struct {
		Name    string `json:"name"`
		Request struct {
			Method string `json:"method"`
			URL    struct {
				Raw string `json:"raw"`
			} `json:"url"`
			Header []struct {
				Key   string `json:"key"`
				Value string `json:"value"`
			} `json:"header"`
			Body struct {
				Mode string `json:"mode"`
				Raw  string `json:"raw"`
			} `json:"body"`
		} `json:"request"`
	} `json:"item"`
}

func ImportPostman(r io.Reader, workspaceID uuid.UUID) (*models.Collection, error) {
	var pc PostmanCollection
	if err := json.NewDecoder(r).Decode(&pc); err != nil {
		return nil, err
	}

	collectionID := uuid.New()
	collection := &models.Collection{
		ID:          collectionID,
		WorkspaceID: workspaceID,
		Name:        pc.Info.Name,
		Description: pc.Info.Description,
		Version:     1,
	}

	var items []models.CollectionItem
	for _, it := range pc.Item {
		headers := make(map[string]interface{})
		for _, h := range it.Request.Header {
			headers[h.Key] = h.Value
		}

		item := models.CollectionItem{
			ID:           uuid.New(),
			CollectionID: collectionID,
			Name:         it.Name,
			Method:       it.Request.Method,
			URL:          it.Request.URL.Raw,
			Headers:      headers,
			Body:         it.Request.Body.Raw,
		}
		items = append(items, item)
	}
	collection.Items = items

	return collection, nil
}

