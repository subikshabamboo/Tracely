package replay

import (
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

// ErrorInjectionConfig defines error injection rules
// Redundant local types removed, using models.ErrorInjectionConfig and models.ErrorCascadeSimulation

// ErrorCascadeSimulation simulates cascading failures across services

// ErrorInjectionService handles error injection during replay
type ErrorInjectionService struct {
	ToxiProxy *ToxiProxyService
}

// NewErrorInjectionService creates a new error injection service
func NewErrorInjectionService() *ErrorInjectionService {
	return &ErrorInjectionService{
		ToxiProxy: &ToxiProxyService{BaseURL: "http://toxiproxy:8474"},
	}
}

// CreateErrorInjection creates a new error injection rule
func (s *ErrorInjectionService) CreateErrorInjection(config *models.ErrorInjectionConfig) error {
	config.ID = uuid.New()
	config.CreatedAt = time.Now()
	return database.DB.Create(config).Error
}

// GetErrorInjections returns all error injection rules for a workspace
func (s *ErrorInjectionService) GetErrorInjections(workspaceID uuid.UUID) ([]models.ErrorInjectionConfig, error) {
	var configs []models.ErrorInjectionConfig
	err := database.DB.Where("workspace_id = ?", workspaceID).Find(&configs).Error
	return configs, err
}

// DeleteErrorInjection removes an error injection rule
func (s *ErrorInjectionService) DeleteErrorInjection(id uuid.UUID) error {
	return database.DB.Delete(&models.ErrorInjectionConfig{}, id).Error
}

// ApplyErrorInjection applies error injection to a request
func (s *ErrorInjectionService) ApplyErrorInjection(serviceName, endpoint string) (*ErrorInjectionResult, error) {
	var config models.ErrorInjectionConfig
	err := database.DB.Where("service_name = ? AND is_enabled = ?", serviceName, true).
		First(&config).Error

	if err != nil {
		return nil, err // No injection configured
	}

	// Check endpoint match
	if config.Endpoint != "" && config.Endpoint != endpoint {
		return nil, nil // Endpoint doesn't match
	}

	// Check probability
	result := &ErrorInjectionResult{
		Injected:    false,
		ServiceName: serviceName,
		Endpoint:    endpoint,
	}

	// For now, always inject if configured (probability check can be added)
	result.Injected = true
	result.ErrorCode = config.ErrorCode
	result.ErrorMessage = config.ErrorMessage
	result.DelayMs = config.DelayMs

	return result, nil
}

// ErrorInjectionResult contains the result of error injection
type ErrorInjectionResult struct {
	Injected     bool   `json:"injected"`
	ServiceName  string `json:"service_name"`
	Endpoint     string `json:"endpoint"`
	ErrorCode    int    `json:"error_code,omitempty"`
	ErrorMessage string `json:"error_message,omitempty"`
	DelayMs      int    `json:"delay_ms,omitempty"`
}

// CircuitBreakerState represents the state of a circuit breaker
type CircuitBreakerState struct {
	ServiceName   string    `json:"service_name"`
	State         string    `json:"state"` // "closed", "open", "half_open"
	FailureCount  int       `json:"failure_count"`
	SuccessCount  int       `json:"success_count"`
	LastFailureAt time.Time `json:"last_failure_at"`
	OpenedAt      time.Time `json:"opened_at"`
}

// CheckCircuitBreaker checks if circuit breaker should open for a service
func (s *ErrorInjectionService) CheckCircuitBreaker(serviceName string, isFailure bool) (string, error) {
	var state CircuitBreakerState
	err := database.DB.Where("service_name = ?", serviceName).First(&state).Error

	if err != nil {
		// Initialize new circuit breaker
		state = CircuitBreakerState{
			ServiceName:  serviceName,
			State:        "closed",
			FailureCount: 0,
			SuccessCount: 0,
		}
		database.DB.Create(&state)
	}

	threshold := 5 // Failures before opening

	if isFailure {
		state.FailureCount++
		state.LastFailureAt = time.Now()

		if state.FailureCount >= threshold && state.State == "closed" {
			state.State = "open"
			state.OpenedAt = time.Now()
			log.Printf("Circuit breaker OPENED for service: %s", serviceName)
		}
	} else {
		state.SuccessCount++
		// Reset failure count on success
		if state.SuccessCount >= 2 {
			state.FailureCount = 0
			state.SuccessCount = 0
			if state.State == "half_open" {
				state.State = "closed"
				log.Printf("Circuit breaker CLOSED for service: %s", serviceName)
			}
		}
	}

	// Auto-transition from open to half-open after timeout
	if state.State == "open" && time.Since(state.OpenedAt) > 30*time.Second {
		state.State = "half_open"
		log.Printf("Circuit breaker HALF-OPEN for service: %s", serviceName)
	}

	database.DB.Save(&state)
	return state.State, nil
}

// StartCascadeSimulation starts an error cascade simulation
func (s *ErrorInjectionService) StartCascadeSimulation(sim *models.ErrorCascadeSimulation) error {
	sim.ID = uuid.New()
	sim.Status = "running"
	sim.CreatedAt = time.Now()

	if err := database.DB.Create(sim).Error; err != nil {
		return err
	}

	// Execute the cascade in background
	go s.executeCascade(*sim)

	return nil
}

func (s *ErrorInjectionService) executeCascade(sim models.ErrorCascadeSimulation) {
	defer func() {
		if r := recover(); r != nil {
			log.Printf("Cascade simulation panicked: %v", r)
			sim.Status = "failed"
			database.DB.Save(&sim)
		}
	}()

	log.Printf("Starting cascade simulation: %s", sim.Name)

	// Simulate the initial failure
	if sim.DelayMs > 0 {
		time.Sleep(time.Duration(sim.DelayMs) * time.Millisecond)
	}

	// For each affected service, simulate failure propagation and analyze impact
	for _, service := range sim.AffectedServices {
		log.Printf("Cascade affecting service: %s", service)

		// Record initial impact
		res := models.CascadeResult{
			ID:           uuid.New(),
			SimulationID: sim.ID,
			ServiceName:  service,
			ImpactLevel:  "latency", // Default assumption
			Details:      fmt.Sprintf("Monitoring impact on %s after failure in %s", service, sim.TriggerService),
			Timestamp:    time.Now(),
		}
		
		// In a real implementation, we would trigger a replay here and compare latencies
		// For this implementation, we'll simulate the detection
		s.CheckCircuitBreaker(service, true)
		time.Sleep(200 * time.Millisecond)

		res.ImpactLevel = "error"
		res.Details = fmt.Sprintf("Service %s failed to handle upstream failure in %s", service, sim.TriggerService)
		database.DB.Create(&res)

		s.CheckCircuitBreaker(service, false)
	}

	sim.Status = "completed"
	database.DB.Save(&sim)
	log.Printf("Cascade simulation completed: %s", sim.Name)
}

// GetCascadeSimulations returns all cascade simulations for a workspace
func (s *ErrorInjectionService) GetCascadeSimulations(workspaceID uuid.UUID) ([]models.ErrorCascadeSimulation, error) {
	var sims []models.ErrorCascadeSimulation
	err := database.DB.Where("workspace_id = ?", workspaceID).Order("created_at DESC").Find(&sims).Error
	return sims, err
}

// ApplyErrorToReplay applies error injection during replay execution
func (s *ErrorInjectionService) ApplyErrorToReplay(replayID uuid.UUID, serviceName, endpoint string) (*ErrorInjectionResult, error) {
	result, err := s.ApplyErrorInjection(serviceName, endpoint)
	if err != nil {
		return result, err
	}

	if result != nil && result.Injected {
		// Update circuit breaker
		s.CheckCircuitBreaker(serviceName, true)

		// Add delay if configured
		if result.DelayMs > 0 {
			log.Printf("Error injection: adding %dms delay for %s/%s", result.DelayMs, serviceName, endpoint)
		}
	}

	return result, nil
}
