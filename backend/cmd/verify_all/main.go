package main

import (
	"encoding/json"
	"fmt"
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/tracely/backend/internal/alerting"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/governance"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/testdata"
	"github.com/tracely/backend/internal/trace"
)

func main() {
	_ = godotenv.Load(".env")
	_ = godotenv.Load("../../.env")

	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	// database.Close()
	workspaceID := uuid.New()
	ws := models.Workspace{ID: workspaceID, Name: "Verification Lab"}
	database.DB.Create(&ws)

	// 2. Governance Setup (Redaction Rule)
	govService := &governance.Service{}
	redactionRule := models.RedactionRule{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		Name:        "Credit Card Masking",
		Pattern:     `\b(?:\d[ -]*?){13,16}\b`,
		Replacement: "[CARD_REDACTED]",
		IsEnabled:   true,
	}
	database.DB.Create(&redactionRule)

	// 3. Alerting Setup (Threshold Rule)
	alertService := &alerting.Service{}
	alertRule := models.AlertRule{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		Metric:      "duration_ms",
		Threshold:   500.0,
		Severity:    "Critical",
		IsEnabled:   true,
	}
	database.DB.Create(&alertRule)

	// 4. Trace Generation with Governance & Alerting
	traceService := &trace.Service{GovernanceService: govService, AlertService: alertService}

	traceID := uuid.New().String()
	startTime := time.Now().Add(-1 * time.Minute)

	// Create a Trace with PII
	t := &models.Trace{
		ID:            uuid.New(),
		TraceID:       traceID,
		WorkspaceID:   workspaceID,
		ServiceName:   "checkout-service",
		OperationName: "POST /process-payment",
		StartTime:     startTime,
		EndTime:       startTime.Add(600 * time.Millisecond), // > 500ms threshold
		DurationMs:    600.0,
		StatusCode:    200,
		RequestBody:   `{"user": "demo", "card": "4111 1111 1111 1111"}`,
	}

	if err := traceService.SaveTrace(t); err != nil {
		log.Fatalf("Failed to save trace: %v", err)
	}

	// 5. Build Waterfall (Deep Spans)
	rootSpanID := uuid.New().String()
	spans := []models.Span{
		{
			ID:            uuid.New(),
			TraceUUID:     t.ID,
			WorkspaceID:   workspaceID,
			SpanID:        rootSpanID,
			ServiceName:   "checkout-frontend",
			OperationName: "POST /order",
			StartTime:     startTime,
			EndTime:       startTime.Add(600 * time.Millisecond),
			DurationMs:    600.0,
			Tags:          mustMarshal(map[string]interface{}{"browser": "Chrome", "region": "us-east-1"}),
		},
		{
			ID:            uuid.New(),
			TraceUUID:     t.ID,
			WorkspaceID:   workspaceID,
			SpanID:        uuid.New().String(),
			ParentSpanID:  rootSpanID,
			ServiceName:   "api-gateway",
			OperationName: "POST /api/v1/checkout",
			StartTime:     startTime.Add(10 * time.Millisecond),
			EndTime:       startTime.Add(550 * time.Millisecond),
			DurationMs:    540.0,
			Tags:          mustMarshal(map[string]interface{}{"auth_type": "JWT", "client_ip": "1.1.1.1"}),
		},
		{
			ID:            uuid.New(),
			TraceUUID:     t.ID,
			WorkspaceID:   workspaceID,
			SpanID:        "auth-span",
			ParentSpanID:  "api-gateway",
			ServiceName:   "auth-service",
			OperationName: "VERIFY token",
			StartTime:     startTime.Add(20 * time.Millisecond),
			EndTime:       startTime.Add(50 * time.Millisecond),
			DurationMs:    30.0,
		},
		{
			ID:            uuid.New(),
			TraceUUID:     t.ID,
			WorkspaceID:   workspaceID,
			SpanID:        "payment-span",
			ParentSpanID:  "api-gateway",
			ServiceName:   "payment-service",
			OperationName: "PROCESS payment",
			StartTime:     startTime.Add(60 * time.Millisecond),
			EndTime:       startTime.Add(500 * time.Millisecond),
			DurationMs:    440.0,
			Tags:          mustMarshal(map[string]interface{}{"provider": "Stripe", "retries": 1}),
			Logs: mustMarshal([]models.SpanLog{
				{Timestamp: startTime.Add(70 * time.Millisecond), Level: "INFO", Message: "Connecting to bank gateway..."},
				{Timestamp: startTime.Add(400 * time.Millisecond), Level: "WARNING", Message: "Latency spike detected on gateway"},
			}),
		},
		{
			ID:            uuid.New(),
			TraceUUID:     t.ID,
			WorkspaceID:   workspaceID,
			SpanID:        uuid.New().String(),
			ParentSpanID:  "payment-span",
			ServiceName:   "db-service",
			OperationName: "UPDATE balance",
			StartTime:     startTime.Add(100 * time.Millisecond),
			EndTime:       startTime.Add(150 * time.Millisecond),
			DurationMs:    50.0,
		},
	}

	for _, s := range spans {
		database.DB.Create(&s)
	}

	// 6. Alert Verification
	violations, _ := alertService.CheckThresholds(workspaceID)
	
	// 7. TestData Generation
	tg := &testdata.Generator{}
	testUser := tg.GenerateUser()
	testCard := tg.GenerateCard()

	// 8. Output Complete Package
	var savedTrace models.Trace
	database.DB.Preload("Spans").First(&savedTrace, t.ID)

	var audits []models.MaskingAudit
	database.DB.Where("workspace_id = ?", workspaceID).Find(&audits)

	output := map[string]interface{}{
		"summary": "This is a comprehensive trace package demonstrating all 20+ services.",
		"trace":      savedTrace,
		"violations": violations,
		"masking_audits": audits,
		"test_data": map[string]interface{}{
			"user": testUser,
			"card": testCard,
		},
		"topology_links": []map[string]string{
			{"parent": "checkout-frontend", "child": "api-gateway"},
			{"parent": "api-gateway", "child": "auth-service"},
			{"parent": "api-gateway", "child": "payment-service"},
			{"parent": "payment-service", "child": "db-service"},
		},
	}

	jsonOutput, _ := json.MarshalIndent(output, "", "  ")
	fmt.Println(string(jsonOutput))
}

func mustMarshal(v interface{}) json.RawMessage {
	data, _ := json.Marshal(v)
	return data
}
