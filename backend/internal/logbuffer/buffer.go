package logbuffer

import (
	"sync"
	"github.com/tracely/backend/internal/models"
)

var (
	buffer = make(map[string][]models.SpanLog)
	mu     sync.RWMutex
)

func Add(traceID string, log models.SpanLog) {
	mu.Lock()
	defer mu.Unlock()
	buffer[traceID] = append(buffer[traceID], log)
}

func Get(traceID string) []models.SpanLog {
	mu.RLock()
	defer mu.RUnlock()
	return buffer[traceID]
}

func Clear(traceID string) {
	mu.Lock()
	defer mu.Unlock()
	delete(buffer, traceID)
}
