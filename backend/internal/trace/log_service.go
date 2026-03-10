package trace

import (
	"encoding/json"

	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type LogService struct{}

type LogEntry struct {
	TraceID   string `json:"trace_id"`
	Level     string `json:"level"`
	Message   string `json:"message"`
	Timestamp string `json:"timestamp"`
	Service   string `json:"service"`
}

func (s *LogService) GetLogsByTraceID(traceID string) ([]models.SpanLog, error) {
	var spans []models.Span
	err := database.DB.Where("trace_uuid = ?", traceID).Find(&spans).Error
	if err != nil {
		return nil, err
	}

	var allLogs []models.SpanLog
	for _, span := range spans {
		// Parse Logs from json.RawMessage
		var logs []models.SpanLog
		if err := json.Unmarshal(span.Logs, &logs); err != nil {
			continue
		}
		allLogs = append(allLogs, logs...)
	}

	return allLogs, nil
}
