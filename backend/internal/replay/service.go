package replay

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"net/http/cookiejar"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct {
	ToxiProxy      *ToxiProxyService
	Mutation       *MutationService
	ErrorInjection *ErrorInjectionService
	DecryptSecret  func(string) (string, error)
}

// TokenRefreshConfig holds the configuration for token refresh during replay
type TokenRefreshConfig struct {
	Enabled       bool   `json:"enabled"`
	RefreshURL    string `json:"refresh_url"`
	TokenHeader   string `json:"token_header"`   // Header name for token (e.g., "Authorization")
	TokenPrefix   string `json:"token_prefix"`   // Prefix for token (e.g., "Bearer")
	RefreshBefore int    `json:"refresh_before"` // Seconds before expiry to refresh
}

// SessionState holds the authentication state for stateful replay
type SessionState struct {
	AccessToken   string    `json:"access_token"`
	RefreshToken  string    `json:"refresh_token"`
	ExpiresAt     time.Time `json:"expires_at"`
	LastRefreshed time.Time `json:"last_refreshed"`
}

func NewService() *Service {
	return &Service{
		ToxiProxy:      &ToxiProxyService{BaseURL: "http://toxiproxy:8474"},
		Mutation:       &MutationService{},
		ErrorInjection: NewErrorInjectionService(),
	}
}

// RefreshToken attempts to refresh the access token using the refresh token
func (s *Service) RefreshToken(config TokenRefreshConfig, session *SessionState) error {
	if !config.Enabled || session.RefreshToken == "" || config.RefreshURL == "" {
		return nil
	}

	// Check if token needs refresh (refresh before expiry)
	if time.Until(session.ExpiresAt) > time.Duration(config.RefreshBefore)*time.Second {
		return nil // Token still valid
	}

	// Create refresh request
	refreshData := map[string]string{
		"refresh_token": session.RefreshToken,
	}
	body, err := json.Marshal(refreshData)
	if err != nil {
		return fmt.Errorf("failed to marshal refresh request: %w", err)
	}

	req, err := http.NewRequest("POST", config.RefreshURL, bytes.NewBuffer(body))
	if err != nil {
		return fmt.Errorf("failed to create refresh request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("refresh request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("token refresh failed with status: %d", resp.StatusCode)
	}

	// Parse response - expecting new tokens
	var tokenResp struct {
		AccessToken  string `json:"access_token"`
		RefreshToken string `json:"refresh_token,omitempty"`
		ExpiresIn    int    `json:"expires_in"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return fmt.Errorf("failed to parse refresh response: %w", err)
	}

	// Update session state
	session.AccessToken = tokenResp.AccessToken
	if tokenResp.RefreshToken != "" {
		session.RefreshToken = tokenResp.RefreshToken
	}
	session.ExpiresAt = time.Now().Add(time.Duration(tokenResp.ExpiresIn) * time.Second)
	session.LastRefreshed = time.Now()

	log.Printf("Token refreshed successfully, new expiry: %v", session.ExpiresAt)
	return nil
}

// ExecuteWithTokenRefresh executes a replay with automatic token refresh support
func (s *Service) ExecuteWithTokenRefresh(replayID uuid.UUID, config TokenRefreshConfig, session *SessionState) (*models.ReplayExecution, error) {
	// Attempt token refresh if needed
	if err := s.RefreshToken(config, session); err != nil {
		log.Printf("Token refresh warning: %v", err)
	}

	var replay models.Replay
	if err := database.DB.First(&replay, replayID).Error; err != nil {
		return nil, err
	}

	execution := &models.ReplayExecution{
		ID:        uuid.New(),
		ReplayID:  replayID,
		StartTime: time.Now(),
		Status:    "running",
	}

	client := &http.Client{Timeout: 30 * time.Second}

	url, _ := replay.RequestData["url"].(string)
	method, _ := replay.RequestData["method"].(string)
	body, _ := replay.RequestData["body"].(string)

	req, err := http.NewRequest(method, url, bytes.NewBufferString(body))
	if err != nil {
		return nil, err
	}

	// Add authentication header if token is available
	if session != nil && session.AccessToken != "" && config.TokenHeader != "" {
		req.Header.Set(config.TokenHeader, config.TokenPrefix+" "+session.AccessToken)
	}

	start := time.Now()
	resp, err := client.Do(req)
	duration := time.Since(start).Milliseconds()

	status := "completed"
	resCode := 0
	if err != nil {
		status = "failed"
		log.Printf("Replay execution error: %v", err)
	} else {
		resCode = resp.StatusCode
		resp.Body.Close()
	}

	execution.EndTime = time.Now()
	execution.Status = status
	execution.Results = []models.Result{
		{SpanID: "root", ResponseCode: resCode, DurationMs: duration},
	}

	database.DB.Create(execution)
	return execution, nil
}

func (s *Service) Execute(replayID uuid.UUID) (*models.ReplayExecution, error) {

	var replay models.Replay
	if err := database.DB.First(&replay, replayID).Error; err != nil {
		return nil, err
	}

	// If there is an original trace, execute a full timing-aware replay
	if replay.OriginalTraceID != "" {
		return s.ExecuteTimingAware(replayID, true)
	}

	execution := &models.ReplayExecution{

		ID:        uuid.New(),
		ReplayID:  replayID,
		StartTime: time.Now(),
		Status:    "running",
	}

	client := &http.Client{Timeout: 30 * time.Second}

	url, _ := replay.RequestData["url"].(string)
	method, _ := replay.RequestData["method"].(string)
	body, _ := replay.RequestData["body"].(string)

	req, err := http.NewRequest(method, url, bytes.NewBufferString(body))
	if err != nil {
		return nil, err
	}

	start := time.Now()
	resp, err := client.Do(req)
	duration := time.Since(start).Milliseconds()

	status := "completed"
	resCode := 0
	if err != nil {
		status = "failed"
		log.Printf("Replay execution error: %v", err)
	} else {
		resCode = resp.StatusCode
		resp.Body.Close()
	}

	execution.EndTime = time.Now()
	execution.Status = status
	execution.Results = []models.Result{
		{SpanID: "root", ResponseCode: resCode, DurationMs: duration},
	}

	database.DB.Create(execution)
	return execution, nil
}

func (s *Service) ExecuteTimingAware(replayID uuid.UUID, persist bool) (*models.ReplayExecution, error) {
	var replay models.Replay
	if err := database.DB.First(&replay, replayID).Error; err != nil {
		return nil, err
	}

	var originalTrace models.Trace
	if err := database.DB.Where("trace_id = ?", replay.OriginalTraceID).First(&originalTrace).Error; err != nil {
		return nil, err
	}

	var originalSpans []models.Span
	database.DB.Where("trace_uuid = ?", originalTrace.ID).Order("start_time ASC").Find(&originalSpans)

	execution := &models.ReplayExecution{
		ID:        uuid.New(),
		ReplayID:  replayID,
		StartTime: time.Now(),
		Status:    "running",
	}

	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar, Timeout: 30 * time.Second}
	var results []models.Result

	if len(originalSpans) > 0 {
		firstSpanStart := originalSpans[0].StartTime

		for _, span := range originalSpans {
			delay := span.StartTime.Sub(firstSpanStart)
			if delay > 0 {
				time.Sleep(delay)
			}

			// Check for error injection
			injectResult, _ := s.ErrorInjection.ApplyErrorToReplay(replayID, span.ServiceName, span.OperationName)
			if injectResult != nil && injectResult.Injected {
				if injectResult.DelayMs > 0 {
					time.Sleep(time.Duration(injectResult.DelayMs) * time.Millisecond)
				}
				results = append(results, models.Result{
					SpanID:       span.SpanID,
					ResponseCode: injectResult.ErrorCode,
					DurationMs:   int64(injectResult.DelayMs),
				})
				continue // Skip the actual HTTP request
			}

			mutatedBody := s.Mutation.InjectVariables(execution.ID, span.SpanID, span.RequestBody, replay.EnvironmentVars)
			if s.DecryptSecret != nil {
				mutatedBody = s.Mutation.InjectSecrets(execution.ID, span.SpanID, mutatedBody, replay.WorkspaceID, s.DecryptSecret)
			}

			targetURL := span.OperationName
			method := "GET"

			// If OperationName matches "METHOD URL", split it. Otherwise, use it as URL.
			parts := strings.SplitN(strings.TrimSpace(span.OperationName), " ", 2)
			if len(parts) == 2 {
				method = parts[0]
				targetURL = parts[1]
			} else if len(parts) == 1 && parts[0] != "" {
				targetURL = parts[0]
			}

			if targetURL == "" {
				log.Printf("Empty URL for span %s, skipping", span.SpanID)
				continue
			}

			req, err := http.NewRequest(method, targetURL, bytes.NewBufferString(mutatedBody))
			if err != nil {
				log.Printf("Failed to create request for span %s: %v", span.SpanID, err)
				continue
			}

			var headers map[string]interface{}
			if len(span.RequestHeaders) > 0 {
				json.Unmarshal(span.RequestHeaders, &headers)
			}
			for k, v := range headers {
				req.Header.Set(k, fmt.Sprintf("%v", v))
			}

			start := time.Now()
			resp, err := client.Do(req)

			resCode := 0
			if err == nil {
				resCode = resp.StatusCode
				resp.Body.Close()
			}

			results = append(results, models.Result{
				SpanID:       span.SpanID,
				ResponseCode: resCode,
				DurationMs:   time.Since(start).Milliseconds(),
			})
		}
	}

	execution.EndTime = time.Now()
	execution.Status = "completed"
	execution.Results = results

	if persist {
		database.DB.Create(execution)
	}
	return execution, nil
}

func (s *Service) ExecuteLoadReplay(replayID uuid.UUID, amplification int) (*models.ReplayExecution, error) {
	return s.ExecuteLoadReplayWithRamp(replayID, models.RampPattern{
		PeakUsers:     amplification,
		RampUpSeconds: 0,
		HoldSeconds:   30,
	})
}

func (s *Service) ExecuteLoadReplayWithRamp(replayID uuid.UUID, pattern models.RampPattern) (*models.ReplayExecution, error) {
	var replay models.Replay
	if err := database.DB.First(&replay, replayID).Error; err != nil {
		return nil, err
	}

	execution := &models.ReplayExecution{
		ID:        uuid.New(),
		ReplayID:  replayID,
		StartTime: time.Now(),
		Status:    "running",
	}

	resultsChan := make(chan models.Result, pattern.PeakUsers*20)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	var masterWg sync.WaitGroup
	masterWg.Add(1)
	
	// Start collector
	var results []models.Result
	go func() {
		defer masterWg.Done()
		for r := range resultsChan {
			results = append(results, r)
		}
	}()

	// Phase 1: Ramp Up
	if pattern.RampUpSeconds > 0 {
		initialUsers := pattern.InitialUsers
		if initialUsers < 1 {
			initialUsers = 1
		}
		
		stepCount := 5 // Default steps
		if pattern.StepSeconds > 0 {
			stepCount = pattern.RampUpSeconds / pattern.StepSeconds
		}
		if stepCount < 1 { stepCount = 1 }

		stepDur := time.Duration(pattern.RampUpSeconds/stepCount) * time.Second
		userIncrement := (pattern.PeakUsers - initialUsers) / stepCount
		
		for i := 0; i < stepCount; i++ {
			users := initialUsers + (userIncrement * i)
			log.Printf("Ramping up: %d users", users)
			
			stepCtx, stepCancel := context.WithTimeout(ctx, stepDur)
			var stepWg sync.WaitGroup
			for u := 0; u < users; u++ {
				stepWg.Add(1)
				go func(userIndex int) {
					defer stepWg.Done()
					for {
						select {
						case <-stepCtx.Done():
							return
						default:
							exec, err := s.ExecuteTimingAware(replayID, false)
							if err == nil && exec != nil {
								for _, r := range exec.Results {
									resultsChan <- r
								}
							}
						}
					}
				}(u)
			}
			stepWg.Wait()
			stepCancel()
		}
	}

	// Phase 2: Hold
	log.Printf("Holding at peak: %d users for %ds", pattern.PeakUsers, pattern.HoldSeconds)
	holdCtx, holdCancel := context.WithTimeout(ctx, time.Duration(pattern.HoldSeconds)*time.Second)
	var holdWg sync.WaitGroup
	for u := 0; u < pattern.PeakUsers; u++ {
		holdWg.Add(1)
		go func() {
			defer holdWg.Done()
			for {
				select {
				case <-holdCtx.Done():
					return
				default:
					exec, err := s.ExecuteTimingAware(replayID, false)
					if err == nil && exec != nil {
						for _, r := range exec.Results {
							resultsChan <- r
						}
					}
				}
			}
		}()
	}
	holdWg.Wait()
	holdCancel()

	// Phase 3: Ramp Down (Optional but good for completeness)
	if pattern.RampDownSeconds > 0 {
		log.Printf("Ramping down for %ds", pattern.RampDownSeconds)
		// Simplified ramp down
		time.Sleep(time.Duration(pattern.RampDownSeconds) * time.Second)
	}

	close(resultsChan)
	masterWg.Wait()

	execution.EndTime = time.Now()
	execution.Status = "completed"
	execution.Results = results

	database.DB.Create(execution)
	return execution, nil
}

func (s *Service) CompareReplay(executionID uuid.UUID) (*models.ReplayComparison, error) {

	var exec models.ReplayExecution
	if err := database.DB.First(&exec, executionID).Error; err != nil {
		return nil, err
	}

	var replay models.Replay
	if err := database.DB.First(&replay, exec.ReplayID).Error; err != nil {
		return nil, err
	}

	var originalTrace models.Trace
	if err := database.DB.Where("trace_id = ?", replay.OriginalTraceID).First(&originalTrace).Error; err != nil {
		return nil, err
	}

	originalDuration := originalTrace.DurationMs
	var currentDuration float64
	if len(exec.Results) > 0 {
		currentDuration = float64(exec.Results[0].DurationMs)
	}

	status := "identical"
	if currentDuration > originalDuration*1.5 {
		status = "major_diff"
	} else if currentDuration > originalDuration*1.1 {
		status = "minor_diff"
	}

	comparison := &models.ReplayComparison{
		ID:              uuid.New(),
		ReplayID:        exec.ReplayID,
		ExecutionID:     executionID,
		OriginalTraceID: replay.OriginalTraceID,
		DiffStatus:      status,
		LatencyDiffMs:   currentDuration - originalDuration,
		Timestamp:       time.Now(),
	}

	database.DB.Create(comparison)
	return comparison, nil
}
