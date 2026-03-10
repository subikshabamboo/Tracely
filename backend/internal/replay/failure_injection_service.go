package replay

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
)

type FailureInjectionService struct {
	ToxiProxyEndpoint string
}

func (s *FailureInjectionService) AddLatency(proxyName string, latencyMs int) error {
	url := fmt.Sprintf("%s/proxies/%s/toxics", s.ToxiProxyEndpoint, proxyName)
	payload := map[string]interface{}{
		"name": "latency",
		"type": "latency",
		"attributes": map[string]interface{}{
			"latency": latencyMs,
		},
	}
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
		return fmt.Errorf("toxiproxy error: %d", resp.StatusCode)
	}
	return nil
}

func (s *FailureInjectionService) AddTimeout(proxyName string, timeoutMs int) error {
	url := fmt.Sprintf("%s/proxies/%s/toxics", s.ToxiProxyEndpoint, proxyName)
	payload := map[string]interface{}{
		"name": "timeout",
		"type": "timeout",
		"attributes": map[string]interface{}{
			"timeout": timeoutMs,
		},
	}
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
		return fmt.Errorf("toxiproxy error: %d", resp.StatusCode)
	}
	return nil
}
