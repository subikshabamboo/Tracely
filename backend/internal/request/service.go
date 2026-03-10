package request

import (
	"bytes"
	"context"
	"io"
	"net/http"
	"net/http/cookiejar"
	"sync"
	"time"

	"github.com/google/uuid"
)

type Service struct {
	Client *http.Client
	Mu     sync.RWMutex
	// Request mutations for editing
	Mutations map[uuid.UUID][]RequestMutation
	// Request monitoring
	RequestHistory []RequestRecord
}

type RequestMutation struct {
	Type    string `json:"type"` // "header", "body", "query", "replace"
	Path    string `json:"path"`
	Value   string `json:"value"`
	Enabled bool   `json:"enabled"`
}

type RequestRecord struct {
	ID           uuid.UUID         `json:"id"`
	Method       string            `json:"method"`
	URL          string            `json:"url"`
	StatusCode   int               `json:"status_code"`
	DurationMs   int64             `json:"duration_ms"`
	Timestamp    time.Time         `json:"timestamp"`
	Headers      map[string]string `json:"headers"`
	RequestBody  string            `json:"request_body"`
	ResponseBody string            `json:"response_body"`
}

func NewService() *Service {
	jar, _ := cookiejar.New(nil)
	svc := &Service{
		Client: &http.Client{
			Timeout: 10 * time.Second,
			Jar:     jar,
		},
		Mutations:      make(map[uuid.UUID][]RequestMutation),
		RequestHistory: make([]RequestRecord, 0),
	}
	// Start cleanup goroutine
	go svc.cleanupHistory()
	return svc
}

func (s *Service) cleanupHistory() {
	ticker := time.NewTicker(5 * time.Minute)
	for range ticker.C {
		s.Mu.Lock()
		if len(s.RequestHistory) > 1000 {
			s.RequestHistory = s.RequestHistory[len(s.RequestHistory)-500:]
		}
		s.Mu.Unlock()
	}
}

// AddMutation adds a mutation rule to a request
func (s *Service) AddMutation(requestID uuid.UUID, mutation RequestMutation) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if s.Mutations == nil {
		s.Mutations = make(map[uuid.UUID][]RequestMutation)
	}
	s.Mutations[requestID] = append(s.Mutations[requestID], mutation)
}

// RemoveMutation removes a mutation rule
func (s *Service) RemoveMutation(requestID uuid.UUID, mutationIndex int) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	if mutations, ok := s.Mutations[requestID]; ok {
		if mutationIndex >= 0 && mutationIndex < len(mutations) {
			s.Mutations[requestID] = append(mutations[:mutationIndex], mutations[mutationIndex+1:]...)
		}
	}
}

// GetMutations returns all mutations for a request
func (s *Service) GetMutations(requestID uuid.UUID) []RequestMutation {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	return s.Mutations[requestID]
}

// ApplyMutations applies mutation rules to the request
func (s *Service) ApplyMutations(req *http.Request, body []byte, mutations []RequestMutation) ([]byte, error) {
	modifiedBody := body
	for _, m := range mutations {
		if !m.Enabled {
			continue
		}
		switch m.Type {
		case "header":
			req.Header.Set(m.Path, m.Value)
		case "query":
			q := req.URL.Query()
			q.Add(m.Path, m.Value)
			req.URL.RawQuery = q.Encode()
		case "body":
			modifiedBody = []byte(m.Value)
		case "replace":
			modifiedBody = bytes.ReplaceAll(modifiedBody, []byte(m.Path), []byte(m.Value))
		}
	}
	return modifiedBody, nil
}

func (s *Service) Do(ctx context.Context, method, url string, headers map[string]string, body []byte) ([]byte, int, error) {
	return s.DoWithMutations(ctx, method, url, headers, body, nil)
}

func (s *Service) DoWithMutations(ctx context.Context, method, url string, headers map[string]string, body []byte, requestID *uuid.UUID) ([]byte, int, error) {
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewBuffer(body))
	if err != nil {
		return nil, 0, err
	}

	for k, v := range headers {
		req.Header.Set(k, v)
	}

	// Apply mutations if request ID provided
	if requestID != nil {
		mutations := s.GetMutations(*requestID)
		if len(mutations) > 0 {
			body, err = s.ApplyMutations(req, body, mutations)
			if err != nil {
				return nil, 0, err
			}
			req.Body = nil
			req.GetBody = func() (io.ReadCloser, error) {
				return io.NopCloser(bytes.NewBuffer(body)), nil
			}
		}
	}

	start := time.Now()
	resp, err := s.Client.Do(req)
	duration := time.Since(start).Milliseconds()

	// Record request for monitoring
	record := RequestRecord{
		ID:          uuid.New(),
		Method:      method,
		URL:         url,
		Timestamp:   start,
		DurationMs:  duration,
		Headers:     headers,
		RequestBody: string(body),
	}

	if err != nil {
		record.StatusCode = 0
		s.recordRequest(record)
		return nil, 0, err
	}
	defer resp.Body.Close()

	respBody, err := io.ReadAll(resp.Body)
	record.StatusCode = resp.StatusCode
	record.ResponseBody = string(respBody)
	s.recordRequest(record)

	return respBody, resp.StatusCode, err
}

func (s *Service) recordRequest(record RequestRecord) {
	s.Mu.Lock()
	defer s.Mu.Unlock()
	s.RequestHistory = append(s.RequestHistory, record)
}

// GetRequestHistory returns recent request history
func (s *Service) GetRequestHistory(limit int) []RequestRecord {
	s.Mu.RLock()
	defer s.Mu.RUnlock()
	if limit > len(s.RequestHistory) {
		limit = len(s.RequestHistory)
	}
	if limit == 0 {
		return []RequestRecord{}
	}
	result := make([]RequestRecord, limit)
	copy(result, s.RequestHistory[len(s.RequestHistory)-limit:])
	return result
}

// GetRequestStats returns aggregated request statistics
func (s *Service) GetRequestStats() map[string]interface{} {
	s.Mu.RLock()
	defer s.Mu.RUnlock()

	stats := map[string]interface{}{
		"total_requests":  len(s.RequestHistory),
		"avg_duration_ms": 0.0,
		"success_count":   0,
		"error_count":     0,
		"status_codes":    map[int]int{},
	}

	if len(s.RequestHistory) == 0 {
		return stats
	}

	var totalDuration int64
	for _, r := range s.RequestHistory {
		totalDuration += r.DurationMs
		if r.StatusCode >= 200 && r.StatusCode < 400 {
			stats["success_count"] = stats["success_count"].(int) + 1
		} else {
			stats["error_count"] = stats["error_count"].(int) + 1
		}
		statusCodes := stats["status_codes"].(map[int]int)
		statusCodes[r.StatusCode]++
		stats["status_codes"] = statusCodes
	}

	stats["avg_duration_ms"] = float64(totalDuration) / float64(len(s.RequestHistory))
	return stats
}

func (s *Service) ClearSession() {
	jar, _ := cookiejar.New(nil)
	s.Client.Jar = jar
}
