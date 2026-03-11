package models

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Email        string    `gorm:"uniqueIndex;not null" json:"email"`
	PasswordHash string    `gorm:"not null" json:"-"`
	FullName     string    `gorm:"not null" json:"full_name"`
	Role         string    `gorm:"default:'Member'" json:"role"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

type Workspace struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	Name      string    `gorm:"not null" json:"name"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
	Users     []User    `gorm:"many2many:workspace_users;" json:"users,omitempty"`
}

type WorkspaceUser struct {
	WorkspaceID uuid.UUID `gorm:"type:uuid;primaryKey" json:"workspace_id"`
	UserID      uuid.UUID `gorm:"type:uuid;primaryKey" json:"user_id"`
	Role        string    `gorm:"default:'Member'" json:"role"`
}

type Trace struct {
	ID              uuid.UUID       `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	TraceID         string          `gorm:"index;not null" json:"trace_id"`
	WorkspaceID     uuid.UUID       `gorm:"index;not null" json:"workspace_id"`
	ServiceName     string          `gorm:"not null" json:"service_name"`
	OperationName   string          `gorm:"not null" json:"operation_name"`
	StartTime       time.Time       `gorm:"not null" json:"start_time"`
	EndTime         time.Time       `gorm:"not null" json:"end_time"`
	DurationMs      float64         `gorm:"not null" json:"duration_ms"`
	StatusCode      int             `json:"status_code"`
	RequestBody     string          `json:"request_body"`
	RequestHeaders  json.RawMessage `gorm:"type:jsonb" json:"request_headers"`
	ResponseBody    string          `json:"response_body"`
	ResponseHeaders json.RawMessage `gorm:"type:jsonb" json:"response_headers"`
	Metadata        json.RawMessage `gorm:"type:jsonb" json:"metadata"`
	CreatedAt       time.Time       `json:"created_at"`
	Spans           []Span          `gorm:"foreignKey:TraceUUID" json:"spans,omitempty"`
}

type Span struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	TraceUUID     uuid.UUID `gorm:"index;not null" json:"trace_uuid"`
	WorkspaceID   uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	SpanID        string    `gorm:"index;not null" json:"span_id"`
	ParentSpanID  string    `json:"parent_span_id"`
	ServiceName   string    `gorm:"not null" json:"service_name"`
	OperationName string    `gorm:"not null" json:"operation_name"`
	StartTime     time.Time `gorm:"not null" json:"start_time"`
	EndTime       time.Time `gorm:"not null" json:"end_time"`

	DurationMs      float64         `gorm:"not null" json:"duration_ms"`
	StatusCode      int             `json:"status_code"`
	RequestBody     string          `json:"request_body"`
	RequestHeaders  json.RawMessage `gorm:"type:jsonb" json:"request_headers"`
	ResponseBody    string          `json:"response_body"`
	ResponseHeaders json.RawMessage `gorm:"type:jsonb" json:"response_headers"`
	Tags            json.RawMessage `gorm:"type:jsonb" json:"tags"`
	Logs            json.RawMessage `gorm:"type:jsonb" json:"logs"`
	CreatedAt       time.Time       `json:"created_at"`
}

type SpanLog struct {
	Timestamp time.Time              `json:"timestamp"`
	Level     string                 `json:"level"`
	Message   string                 `json:"message"`
	Fields    map[string]interface{} `json:"fields,omitempty"`
}

type Replay struct {
	ID               uuid.UUID              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID      uuid.UUID              `gorm:"index;not null" json:"workspace_id"`
	OriginalTraceID  string                 `json:"original_trace_id"`
	Name             string                 `gorm:"not null" json:"name"`
	Repository       string                 `json:"repository"`         // Repo URL or name
	CITriggerEnabled bool                   `json:"ci_trigger_enabled"` // Flag to auto-run on webhooks
	RequestData      map[string]interface{} `gorm:"type:jsonb;serializer:json;not null" json:"request_data"`
	EnvironmentVars  map[string]interface{} `gorm:"type:jsonb;serializer:json" json:"environment_vars"`
	CreatedAt        time.Time              `json:"created_at"`
	Executions       []ReplayExecution      `gorm:"foreignKey:ReplayID" json:"executions,omitempty"`
}

type ReplayExecution struct {
	ID        uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReplayID  uuid.UUID `gorm:"index;not null" json:"replay_id"`
	StartTime time.Time `gorm:"not null" json:"start_time"`
	EndTime   time.Time `json:"end_time"`
	Status    string    `json:"status"` // "running", "completed", "failed"
	Results   []Result  `gorm:"type:jsonb" json:"results"`
	CreatedAt time.Time `json:"created_at"`
}

type Result struct {
	SpanID       string `json:"span_id"`
	ResponseCode int    `json:"response_code"`
	DurationMs   int64  `json:"duration_ms"`
}

type Mock struct {
	ID              uuid.UUID              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID     uuid.UUID              `gorm:"index;not null" json:"workspace_id"`
	Endpoint        string                 `gorm:"not null" json:"endpoint"`
	Method          string                 `gorm:"not null" json:"method"`
	ResponseCode    int                    `gorm:"not null" json:"response_code"`
	ResponseBody    string                 `json:"response_body"`
	ResponseHeaders map[string]interface{} `gorm:"type:jsonb" json:"response_headers"`
	IsActive        bool                   `gorm:"default:true" json:"is_active"`
	CreatedAt       time.Time              `json:"created_at"`
}

type Secret struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	Key         string    `gorm:"not null" json:"key"`
	Value       string    `gorm:"not null" json:"value"` // Encrypted
	CreatedAt   time.Time `json:"created_at"`
}

type Workflow struct {
	ID          uuid.UUID              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID              `gorm:"index;not null" json:"workspace_id"`
	Name        string                 `gorm:"not null" json:"name"`
	Definition  map[string]interface{} `gorm:"type:jsonb;serializer:json;not null" json:"definition"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}

type AlertRule struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	Metric      string    `json:"metric"` // "duration_ms", "error_rate"
	Threshold   float64   `json:"threshold"`
	Severity    string    `json:"severity"`
	IsEnabled   bool      `gorm:"default:true" json:"is_enabled"`
}

type ThresholdViolation struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	AlertRuleID uuid.UUID `json:"alert_rule_id"`
	TraceID     string    `json:"trace_id"`
	Value       float64   `json:"value"`
	Timestamp   time.Time `json:"timestamp"`
}

type MaskingAudit struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	TraceID     string    `json:"trace_id"`
	Field       string    `json:"field"`
	Rule        string    `json:"rule"`
	Timestamp   time.Time `json:"timestamp"`
}

type RedactionRule struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	Name        string    `gorm:"not null" json:"name"`
	Description string    `json:"description"`
	Pattern     string    `gorm:"not null" json:"pattern"` // Regex pattern
	Replacement string    `gorm:"default:'[REDACTED]'" json:"replacement"`
	IsEnabled   bool      `gorm:"default:true" json:"is_enabled"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type ReplayComparison struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ReplayID        uuid.UUID `json:"replay_id"`
	ExecutionID     uuid.UUID `json:"execution_id"`
	OriginalTraceID string    `json:"original_trace_id"`
	DiffStatus      string    `json:"diff_status"`   // "identical", "minor_diff", "major_diff"
	ResponseDiff    string    `json:"response_diff"` // JSON diff summary
	LatencyDiffMs   float64   `json:"latency_diff_ms"`
	Timestamp       time.Time `json:"timestamp"`
}

type MutationRecord struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	ExecutionID   uuid.UUID `gorm:"index;not null" json:"execution_id"`
	SpanID        string    `json:"span_id"`
	Key           string    `json:"key"`
	OriginalValue string    `json:"original_value"`
	MutatedValue  string    `json:"mutated_value"`
	Timestamp     time.Time `json:"timestamp"`
}

type CascadeResult struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	SimulationID uuid.UUID `gorm:"index;not null" json:"simulation_id"`
	ServiceName  string    `json:"service_name"`
	ImpactLevel  string    `json:"impact_level"` // "none", "latency", "error"
	Details      string    `json:"details"`
	Timestamp    time.Time `json:"timestamp"`
}

type ErrorInjectionConfig struct {
	ID           uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID  uuid.UUID `gorm:"index" json:"workspace_id"`
	Name         string    `json:"name"`
	ServiceName  string    `json:"service_name"`
	Endpoint     string    `json:"endpoint"`
	ErrorCode    int       `json:"error_code"`
	ErrorMessage string    `json:"error_message"`
	Probability  float64   `json:"probability"`
	DelayMs      int       `json:"delay_ms"`
	IsEnabled    bool      `gorm:"default:true" json:"is_enabled"`
	CreatedAt    time.Time `json:"created_at"`
}

type ErrorCascadeSimulation struct {
	ID               uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID      uuid.UUID `gorm:"index" json:"workspace_id"`
	Name             string    `json:"name"`
	TriggerService   string    `json:"trigger_service"`
	FailureType      string    `json:"failure_type"`
	DelayMs          int       `json:"delay_ms"`
	AffectedServices []string  `gorm:"type:jsonb" json:"affected_services"`
	Status           string    `json:"status"`
	CreatedAt        time.Time `json:"created_at"`
}

type Annotation struct {
	ID        uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	TraceUUID uuid.UUID  `gorm:"index;not null" json:"trace_uuid"`
	SpanID    string     `json:"span_id"`   // Link to a specific span
	ParentID  *uuid.UUID `json:"parent_id"` // For threading
	UserID    uuid.UUID  `json:"user_id"`
	Content   string     `gorm:"not null" json:"content"`
	Resolved  bool       `gorm:"default:false" json:"resolved"`
	CreatedAt time.Time  `json:"created_at"`
}

type TraceShare struct {
	ID          uuid.UUID  `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	TraceUUID   uuid.UUID  `gorm:"index;not null" json:"trace_uuid"`
	WorkspaceID uuid.UUID  `json:"workspace_id"`
	SharedBy    uuid.UUID  `json:"shared_by"`
	IsPublic    bool       `gorm:"default:false" json:"is_public"`
	ExpiresAt   *time.Time `json:"expires_at"`
	AccessKey   string     `gorm:"uniqueIndex" json:"access_key"`
	CreatedAt   time.Time  `json:"created_at"`
}

type Collection struct {
	ID          uuid.UUID        `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID        `gorm:"index;not null" json:"workspace_id"`
	ParentID    *uuid.UUID       `gorm:"index" json:"parent_id,omitempty"`
	Version     int              `gorm:"default:1" json:"version"`
	Name        string           `gorm:"not null" json:"name"`
	Description string           `json:"description"`
	CreatedAt   time.Time        `json:"created_at"`
	UpdatedAt   time.Time        `json:"updated_at"`
	Items       []CollectionItem `gorm:"foreignKey:CollectionID" json:"items,omitempty"`
}

type CollectionItem struct {
	ID           uuid.UUID              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	CollectionID uuid.UUID              `gorm:"index;not null" json:"collection_id"`
	Name         string                 `gorm:"not null" json:"name"`
	Method       string                 `gorm:"not null" json:"method"`
	URL          string                 `gorm:"not null" json:"url"`
	Headers      map[string]interface{} `gorm:"type:jsonb;serializer:json" json:"headers"`
	Body         string                 `json:"body"`
	CreatedAt    time.Time              `json:"created_at"`
}

type Notification struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	UserID      uuid.UUID `json:"user_id"`
	Title       string    `json:"title"`
	Message     string    `json:"message"`
	IsRead      bool      `gorm:"default:false" json:"is_read"`
	CreatedAt   time.Time `json:"created_at"`
}

type OnCallSchedule struct {
	ID          uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index;not null" json:"workspace_id"`
	UserID      uuid.UUID `json:"user_id"`
	StartTime   time.Time `json:"start_time"`
	EndTime     time.Time `json:"end_time"`
	Level       int       `json:"level"` // 1 = Primary, 2 = Secondary
}

type Environment struct {
	ID          uuid.UUID              `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID              `gorm:"index;not null" json:"workspace_id"`
	Name        string                 `gorm:"not null" json:"name"` // "Staging", "Production"
	Variables   map[string]interface{} `gorm:"type:jsonb;serializer:json" json:"variables"`
	CreatedAt   time.Time              `json:"created_at"`
	UpdatedAt   time.Time              `json:"updated_at"`
}
type TracingConfig struct {
	ID            uuid.UUID          `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID   uuid.UUID          `gorm:"index;not null" json:"workspace_id"`
	SamplingRules map[string]float64 `gorm:"type:jsonb" json:"sampling_rules"`
	IsEnabled     bool               `gorm:"default:true" json:"is_enabled"`
	CreatedAt     time.Time          `json:"created_at"`
	UpdatedAt     time.Time          `json:"updated_at"`
}

type RampPattern struct {
	ID              uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	WorkspaceID     uuid.UUID `gorm:"index" json:"workspace_id"`
	Name            string    `json:"name"`
	InitialUsers    int       `json:"initial_users"`     // Starting concurrency
	PeakUsers       int       `json:"peak_users"`        // Maximum concurrency
	RampUpSeconds   int       `json:"ramp_up_seconds"`   // Time to reach peak
	HoldSeconds     int       `json:"hold_seconds"`      // Time to hold at peak
	RampDownSeconds int       `json:"ramp_down_seconds"` // Time to decrease
	StepSeconds     int       `json:"step_seconds"`      // Time between each step
	CreatedAt       time.Time `json:"created_at"`
}

type LoadTestProgress struct {
	ID            uuid.UUID `gorm:"type:uuid;primaryKey;default:gen_random_uuid()" json:"id"`
	TestID        uuid.UUID `json:"test_id"`
	CurrentUsers  int       `json:"current_users"`
	TotalRequests int       `json:"total_requests"`
	SuccessCount  int       `json:"success_count"`
	FailedCount   int       `json:"failed_count"`
	Status        string    `json:"status"` // "ramping_up", "holding", "ramping_down", "completed"
	StartedAt     time.Time `json:"started_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type AuditLog struct {
	ID          uuid.UUID `gorm:"primaryKey;type:uuid;default:gen_random_uuid()" json:"id"`
	WorkspaceID uuid.UUID `gorm:"index" json:"workspace_id"`
	UserID      uuid.UUID `json:"user_id"`
	Action      string    `json:"action"` // e.g., "DELETE_WORKFLOW"
	Resource    string    `json:"resource"`
	Timestamp   time.Time `json:"timestamp"`
	Metadata    string    `json:"metadata"` // JSON string
}
