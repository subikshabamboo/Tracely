package loadtest

import (
	"context"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct{}

type LoadTestResult struct {
	TotalRequests int           `json:"total_requests"`
	SuccessRate   float64       `json:"success_rate"`
	AvgLatency    time.Duration `json:"avg_latency"`
	PeakUsers     int           `json:"peak_users"`
	Duration      time.Duration `json:"duration"`
}

func (s *Service) Execute(url string, concurrency int, duration time.Duration) LoadTestResult {
	var wg sync.WaitGroup
	resultsChan := make(chan struct {
		latency time.Duration
		success bool
	}, concurrency*100)

	ctx, cancel := context.WithTimeout(context.Background(), duration)
	defer cancel()

	for i := 0; i < concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			client := &http.Client{Timeout: 5 * time.Second}
			for {
				select {
				case <-ctx.Done():
					return
				default:
					start := time.Now()
					resp, err := client.Get(url)

					// Immediate exit if context cancelled during request
					if ctx.Err() != nil {
						if err == nil {
							resp.Body.Close()
						}
						return
					}

					latency := time.Since(start)
					success := err == nil && resp.StatusCode < 400
					if err == nil && resp != nil {
						resp.Body.Close()
					}

					resultsChan <- struct {
						latency time.Duration
						success bool
					}{latency, success}
				}
			}

		}()
	}

	go func() {
		wg.Wait()
		close(resultsChan)
	}()

	successCount := 0
	totalLatency := time.Duration(0)
	totalRequests := 0

	for res := range resultsChan {
		totalRequests++
		if res.success {
			successCount++
		}
		totalLatency += res.latency
	}

	if totalRequests == 0 {
		return LoadTestResult{}
	}

	return LoadTestResult{
		TotalRequests: totalRequests,
		SuccessRate:   float64(successCount) / float64(totalRequests) * 100,
		AvgLatency:    totalLatency / time.Duration(totalRequests),
	}
}

// ExecuteWithRamp executes a load test with ramp-up and ramp-down patterns
func (s *Service) ExecuteWithRamp(url string, pattern models.RampPattern) LoadTestResult {
	log.Printf("Starting ramp load test: initial=%d, peak=%d, rampUp=%ds, hold=%ds, rampDown=%ds",
		pattern.InitialUsers, pattern.PeakUsers, pattern.RampUpSeconds, pattern.HoldSeconds, pattern.RampDownSeconds)

	startTime := time.Now()
	totalRequests := 0
	successCount := 0
	totalLatency := time.Duration(0)
	peakUsers := 0

	resultsChan := make(chan struct {
		latency time.Duration
		success bool
	}, pattern.PeakUsers*100)

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Phase 1: Ramp Up
	currentUsers := pattern.InitialUsers
	stepDuration := time.Duration(pattern.StepSeconds) * time.Second

	if pattern.StepSeconds > 0 {
		stepDuration = time.Duration(pattern.StepSeconds) * time.Second
	} else {
		// Default: divide ramp up into 10 steps
		stepDuration = time.Duration(pattern.RampUpSeconds*100) * time.Millisecond
	}

	stepSize := (pattern.PeakUsers - pattern.InitialUsers) * pattern.StepSeconds / pattern.RampUpSeconds
	if stepSize < 1 {
		stepSize = 1
	}

	for currentUsers <= pattern.PeakUsers {
		if peakUsers < currentUsers {
			peakUsers = currentUsers
		}

		log.Printf("Ramp up: %d users", currentUsers)

		// Start workers for current level
		var wg sync.WaitGroup
		for i := 0; i < currentUsers; i++ {
			wg.Add(1)
			go s.worker(ctx, url, resultsChan, &wg)
		}

		// Hold at this level
		time.Sleep(stepDuration)

		// Stop workers for this level
		cancel()
		wg.Wait()

		// Collect results so far
		resultsChan = make(chan struct {
			latency time.Duration
			success bool
		}, pattern.PeakUsers*100)
		ctx, cancel = context.WithCancel(context.Background())

		currentUsers += stepSize
	}

	// Phase 2: Hold at Peak
	log.Printf("Holding at peak: %d users", pattern.PeakUsers)
	peakUsers = pattern.PeakUsers

	var holdWg sync.WaitGroup
	for i := 0; i < pattern.PeakUsers; i++ {
		holdWg.Add(1)
		go s.worker(ctx, url, resultsChan, &holdWg)
	}

	time.Sleep(time.Duration(pattern.HoldSeconds) * time.Second)
	cancel()
	holdWg.Wait()

	// Phase 3: Ramp Down
	currentUsers = pattern.PeakUsers
	stepSize = pattern.PeakUsers * pattern.StepSeconds / pattern.RampDownSeconds
	if stepSize < 1 {
		stepSize = 1
	}

	for currentUsers > pattern.InitialUsers {
		log.Printf("Ramp down: %d users", currentUsers)

		var wg sync.WaitGroup
		for i := 0; i < currentUsers; i++ {
			wg.Add(1)
			go s.worker(ctx, url, resultsChan, &wg)
		}

		time.Sleep(stepDuration)
		cancel()
		wg.Wait()

		resultsChan = make(chan struct {
			latency time.Duration
			success bool
		}, pattern.PeakUsers*100)
		ctx, cancel = context.WithCancel(context.Background())

		currentUsers -= stepSize
	}

	close(resultsChan)

	// Collect all results
	for res := range resultsChan {
		totalRequests++
		if res.success {
			successCount++
		}
		totalLatency += res.latency
	}

	duration := time.Since(startTime)

	if totalRequests == 0 {
		return LoadTestResult{
			PeakUsers: peakUsers,
			Duration:  duration,
		}
	}

	return LoadTestResult{
		TotalRequests: totalRequests,
		SuccessRate:   float64(successCount) / float64(totalRequests) * 100,
		AvgLatency:    totalLatency / time.Duration(totalRequests),
		PeakUsers:     peakUsers,
		Duration:      duration,
	}
}

func (s *Service) worker(ctx context.Context, url string, resultsChan chan struct {
	latency time.Duration
	success bool
}, wg *sync.WaitGroup) {
	defer wg.Done()

	client := &http.Client{Timeout: 10 * time.Second}

	for {
		select {
		case <-ctx.Done():
			return
		default:
			start := time.Now()
			resp, err := client.Get(url)

			latency := time.Since(start)
			success := err == nil && resp.StatusCode < 400
			if err == nil && resp != nil {
				resp.Body.Close()
			}

			select {
			case resultsChan <- struct {
				latency time.Duration
				success bool
			}{latency, success}:
			case <-ctx.Done():
				return
			}
		}
	}
}

// SaveRampPattern saves a ramp pattern configuration
func (s *Service) SaveRampPattern(pattern *models.RampPattern) error {
	pattern.ID = uuid.New()
	pattern.CreatedAt = time.Now()
	return database.DB.Create(pattern).Error
}

// GetRampPatterns returns all ramp patterns for a workspace
func (s *Service) GetRampPatterns(workspaceID uuid.UUID) ([]models.RampPattern, error) {
	var patterns []models.RampPattern
	err := database.DB.Where("workspace_id = ?", workspaceID).Find(&patterns).Error
	return patterns, err
}

// DeleteRampPattern removes a ramp pattern
func (s *Service) DeleteRampPattern(id uuid.UUID) error {
	return database.DB.Delete(&models.RampPattern{}, id).Error
}
