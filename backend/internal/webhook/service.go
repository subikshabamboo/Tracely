package webhook

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/replay"
)

type Service struct {
	ReplayService *replay.Service
}

// PagerDutyConfig holds the configuration for PagerDuty integration
type PagerDutyConfig struct {
	Enabled        bool   `json:"enabled"`
	IntegrationKey string `json:"integration_key"` // PagerDuty Events API key
	APIURL         string `json:"api_url"`         // PagerDuty API URL
}

// PagerDutyEvent represents a PagerDuty event
type PagerDutyEvent struct {
	RoutingKey  string      `json:"routing_key"`
	EventAction string      `json:"event_action"`
	Payload     interface{} `json:"payload"`
}

// PagerDutyPayload represents the payload of a PagerDuty event
type PagerDutyPayload struct {
	Summary   string `json:"summary"`
	Severity  string `json:"severity"`
	Source    string `json:"source"`
	Timestamp string `json:"timestamp,omitempty"`
}

func (s *Service) HandleCIWebhook(c *gin.Context) {
	var event struct {
		Action            string `json:"action"` // e.g., "push", "merge"
		Repo              string `json:"repo"`   // e.g., "org/repo"
		Ref               string `json:"ref"`    // e.g., "refs/heads/main"
		StatusCallbackURL string `json:"status_callback_url"`
		IsMerge           bool   `json:"is_merge"`
	}
	if err := c.ShouldBindJSON(&event); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid payload"})
		return
	}

	// Trigger logic
	go func() {
		defer func() {
			if r := recover(); r != nil {
				log.Printf("Recovered from panic in CI processing: %v", r)
			}
		}()

		log.Printf("Processing CI event: %s for %s (%s)", event.Action, event.Repo, event.Ref)

		// 1. Find all replays for this repo with CI enabled
		var targetReplays []models.Replay
		query := database.DB.Where("repository = ? AND ci_trigger_enabled = ?", event.Repo, true)
		if err := query.Find(&targetReplays).Error; err != nil || len(targetReplays) == 0 {
			log.Printf("No CI-enabled replays found for repo: %s", event.Repo)
			s.reportStatus(event.StatusCallbackURL, "success", "No Tracely deployment gates configured for this repo.")
			return
		}

		// 2. Execute Suite
		failedCount := 0
		for _, r := range targetReplays {
			log.Printf("Executing CI replay: %s (%s)", r.Name, r.ID)
			execution, err := s.ReplayService.Execute(r.ID)
			if err != nil || (execution != nil && execution.Status == "failed") {
				failedCount++
			}
		}

		// 3. Report Results
		if failedCount > 0 {
			s.reportStatus(event.StatusCallbackURL, "failed", fmt.Sprintf("%d Tracely deployment gates failed. Regression detected.", failedCount))
		} else {
			s.reportStatus(event.StatusCallbackURL, "success", fmt.Sprintf("All %d Tracely deployment gates passed.", len(targetReplays)))
		}
	}()

	c.JSON(http.StatusOK, gin.H{"status": "ci_suite_queued", "replay_count": 0}) // count is unknown until async starts but for now OK
}

func (s *Service) reportStatus(url, status, message string) {
	if url == "" {
		return
	}
	payload := map[string]string{
		"state":       status, // "success" or "failed"
		"description": message,
		"context":     "Tracely/Deployment-Gate",
	}
	s.SendGeneric(url, payload)
}

func (s *Service) SendSlack(webhookURL, message string) error {
	payload := map[string]string{"text": message}
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("slack notification failed with status: %d", resp.StatusCode)
	}
	return nil
}

func (s *Service) SendGeneric(url string, payload interface{}) error {
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	resp, err := http.Post(url, "application/json", bytes.NewBuffer(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("webhook call failed with status: %d", resp.StatusCode)
	}
	return nil
}

// SendPagerDutyNotification sends a notification to PagerDuty
func (s *Service) SendPagerDutyNotification(config PagerDutyConfig, summary, severity, source string) error {
	if !config.Enabled || config.IntegrationKey == "" {
		return nil
	}

	apiURL := config.APIURL
	if apiURL == "" {
		apiURL = "https://events.pagerduty.com/v2/enqueue"
	}

	event := PagerDutyEvent{
		RoutingKey:  config.IntegrationKey,
		EventAction: "trigger",
		Payload: PagerDutyPayload{
			Summary:  summary,
			Severity: severity,
			Source:   source,
		},
	}

	body, err := json.Marshal(event)
	if err != nil {
		return fmt.Errorf("failed to marshal PagerDuty event: %w", err)
	}

	req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(body))
	if err != nil {
		return fmt.Errorf("failed to create PagerDuty request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return fmt.Errorf("PagerDuty request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		return fmt.Errorf("PagerDuty notification failed with status: %d", resp.StatusCode)
	}

	log.Printf("PagerDuty notification sent: %s (severity: %s)", summary, severity)
	return nil
}

// SendPagerDutyAlert sends a PagerDuty alert for an alert rule violation
func (s *Service) SendPagerDutyAlert(config PagerDutyConfig, violation models.ThresholdViolation, rule models.AlertRule) error {
	summary := fmt.Sprintf("Tracely Alert: %s threshold exceeded (value: %.2f)", rule.Metric, violation.Value)
	severity := "warning"
	if rule.Metric == "error_rate" {
		severity = "error"
	}
	source := "tracely"

	return s.SendPagerDutyNotification(config, summary, severity, source)
}
