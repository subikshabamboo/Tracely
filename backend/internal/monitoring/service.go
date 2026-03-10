package monitoring

import (
	"runtime"
	"time"
)

type Service struct{}

type HealthStatus struct {
	RAMUsage     uint64    `json:"ram_usage_mb"`
	NumGoroutine int       `json:"num_goroutine"`
	UpTime       float64   `json:"uptime_seconds"`
	Timestamp    time.Time `json:"timestamp"`
}

var startTime = time.Now()

func (s *Service) GetStatus() HealthStatus {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)
	
	return HealthStatus{
		RAMUsage:     m.Alloc / 1024 / 1024,
		NumGoroutine: runtime.NumGoroutine(),
		UpTime:       time.Since(startTime).Seconds(),
		Timestamp:    time.Now(),
	}
}
