package main

import (
	"log"
	"time"

	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

func main() {
	_ = godotenv.Load(".env")
	_ = godotenv.Load("../../.env")

	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	log.Println("Seeding database...")

	// 1. Create a Demo User
	hashedPassword, _ := bcrypt.GenerateFromPassword([]byte("password123"), bcrypt.DefaultCost)
	user := models.User{
		ID:           uuid.New(),
		Email:        "demo@tracely.io",
		PasswordHash: string(hashedPassword),
		FullName:     "Demo User",
		Role:         "Admin",
	}
	database.DB.Where(models.User{Email: user.Email}).FirstOrCreate(&user)

	// 2. Create a Demo Workspace
	workspace := models.Workspace{
		ID:   uuid.New(),
		Name: "Production Cluster",
	}
	database.DB.Where(models.Workspace{Name: workspace.Name}).FirstOrCreate(&workspace)

	// Link user to workspace
	wsUser := models.WorkspaceUser{
		WorkspaceID: workspace.ID,
		UserID:      user.ID,
		Role:        "Owner",
	}
	database.DB.FirstOrCreate(&wsUser)

	// 3. Create Demo Traces
	services := []string{"auth-service", "gateway-service", "user-service", "payment-service"}
	operations := []string{"GET /users", "POST /login", "GET /balance", "POST /pay"}

	for i := 0; i < 20; i++ {
		duration := float64(10 + i*15)
		status := 200
		if i%7 == 0 {
			status = 500
			duration = 1500.0 // Slow error
		}

		trace := models.Trace{
			ID:            uuid.New(),
			TraceID:       uuid.New().String(),
			WorkspaceID:   workspace.ID,
			ServiceName:   services[i%len(services)],
			OperationName: operations[i%len(operations)],
			StartTime:     time.Now().Add(time.Duration(-i) * time.Hour),
			EndTime:       time.Now().Add(time.Duration(-i) * time.Hour).Add(time.Duration(duration) * time.Millisecond),
			DurationMs:    duration,
			StatusCode:    status,
			CreatedAt:     time.Now(),
		}
		database.DB.Create(&trace)
	}

	// 4. Create Alert Rules & Violations
	rule := models.AlertRule{
		ID:          uuid.New(),
		WorkspaceID: workspace.ID,
		Metric:      "duration_ms",
		Threshold:   1000.0,
		Severity:    "Critical",
		IsEnabled:   true,
	}
	database.DB.Create(&rule)

	violation := models.ThresholdViolation{
		ID:          uuid.New(),
		WorkspaceID: workspace.ID,
		AlertRuleID: rule.ID,
		TraceID:     "demo-trace-id",
		Value:       1500.0,
		Timestamp:   time.Now(),
	}
	database.DB.Create(&violation)

	// 5. Create Environments
	environments := []string{"Staging", "Production", "Development"}
	for _, envName := range environments {
		env := models.Environment{
			ID:          uuid.New(),
			WorkspaceID: workspace.ID,
			Name:        envName,
			Variables:   map[string]interface{}{"API_KEY": "tracely_" + envName, "VERSION": "1.0.0"},
		}
		database.DB.Create(&env)
	}

	// 6. Create Secrets
	secret := models.Secret{
		ID:          uuid.New(),
		WorkspaceID: workspace.ID,
		Key:         "GITHUB_TOKEN",
		Value:       "ghp_demo_token_123456789",
	}
	database.DB.Create(&secret)

	// 7. Create Collections
	collection := models.Collection{
		ID:          uuid.New(),
		WorkspaceID: workspace.ID,
		Name:        "Public API",
		Description: "External facing API endpoints",
	}
	database.DB.Create(&collection)

	items := []models.CollectionItem{
		{
			ID:           uuid.New(),
			CollectionID: collection.ID,
			Name:         "Get Status",
			Method:       "GET",
			URL:          "https://api.example.com/status",
		},
		{
			ID:           uuid.New(),
			CollectionID: collection.ID,
			Name:         "Heartbeat",
			Method:       "GET",
			URL:          "https://api.example.com/heartbeat",
		},
	}
	for _, item := range items {
		database.DB.Create(&item)
	}

	log.Println("Seeding completed successfully!")
}
