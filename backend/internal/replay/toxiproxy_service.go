package replay

import (
	"bytes"
	"encoding/json"
	"net/http"
)

type ToxiProxyService struct {
	BaseURL string
}

func (s *ToxiProxyService) AddLatency(proxyName string, latencyMs int) error {
	payload := map[string]interface{}{
		"type": "latency",
		"attributes": map[string]interface{}{
			"latency": latencyMs,
			"jitter":  latencyMs / 10,
		},
	}
	
	body, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	resp, err := http.Post(s.BaseURL+"/proxies/"+proxyName+"/toxics", "application/json", bytes.NewBuffer(body))

	if err != nil {
		return err
	}
	if resp != nil {
		defer resp.Body.Close()
	}
	return nil
}

func (s *ToxiProxyService) Reset(proxyName string) error {
	req, err := http.NewRequest("DELETE", s.BaseURL+"/proxies/"+proxyName+"/toxics", nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	if resp != nil {
		defer resp.Body.Close()
	}
	return nil
}

