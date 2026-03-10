package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/joho/godotenv"
	"github.com/tracely/backend/internal/alerting"
	"github.com/tracely/backend/internal/audit"
	"github.com/tracely/backend/internal/auth"
	"github.com/tracely/backend/internal/collection"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/environment"
	"github.com/tracely/backend/internal/governance"
	"github.com/tracely/backend/internal/loadtest"
	"github.com/tracely/backend/internal/middleware"
	"github.com/tracely/backend/internal/mock"
	"github.com/tracely/backend/internal/models"
	"github.com/tracely/backend/internal/proxy"
	"github.com/tracely/backend/internal/replay"
	"github.com/tracely/backend/internal/secret"
	"github.com/tracely/backend/internal/settings"
	"github.com/tracely/backend/internal/trace"
	"github.com/tracely/backend/internal/webhook"
	"github.com/tracely/backend/internal/websocket"
	"github.com/tracely/backend/internal/workflow"
	"github.com/tracely/backend/internal/workspace"
	"golang.org/x/time/rate"
)

func main() {
	// Load .env file from backend directory
	_ = godotenv.Load(".env")
	_ = godotenv.Load("../.env")

	if err := database.Connect(); err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}
	defer database.Close()

	r := gin.Default()

	// Rate Limiting Middleware
	limiter := rate.NewLimiter(rate.Every(time.Second), 100) // 100 req/s
	r.Use(func(c *gin.Context) {
		if !limiter.Allow() {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "Rate limit exceeded"})
			return
		}
		c.Next()
	})

	// Security Headers & CORS
	allowedOrigin := os.Getenv("ALLOWED_ORIGIN")
	if allowedOrigin == "" {
		allowedOrigin = "http://localhost:3000" // Default for dev
	}

	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With, X-Trace-Id, X-Span-Id")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		// Security Headers
		c.Writer.Header().Set("X-Frame-Options", "DENY")
		c.Writer.Header().Set("X-Content-Type-Options", "nosniff")
		c.Writer.Header().Set("X-XSS-Protection", "1; mode=block")
		c.Writer.Header().Set("Referrer-Policy", "strict-origin-when-cross-origin")
		c.Writer.Header().Set("Content-Security-Policy", "default-src 'self'")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	r.Use(middleware.TracingMiddleware())

	// Hub for real-time updates
	hub := websocket.NewHub()
	hubCtx, hubCancel := context.WithCancel(context.Background())
	go hub.Run(hubCtx)
	defer hubCancel()

	// Services & Handlers
	authService := &auth.Service{}
	authHandler := &auth.Handler{Service: authService}

	workspaceService := &workspace.Service{}
	workspaceHandler := &workspace.Handler{Service: workspaceService}

	govService := &governance.Service{}
	alertService := &alerting.Service{}
	traceService := &trace.Service{Hub: hub, GovernanceService: govService, AlertService: alertService}
	waterfallService := &trace.WaterfallService{}

	percentileCalc := &trace.PercentileCalculator{}
	criticalPathService := &trace.CriticalPathService{}
	logService := &trace.LogService{}
	metricService := &trace.MetricService{}

	traceHandler := &trace.Handler{
		Service:              traceService,
		WaterfallService:     waterfallService,
		PercentileCalculator: percentileCalc,
		CriticalPathService:  criticalPathService,
		LogService:           logService,
		MetricService:        metricService,
		OptimizationService:  &trace.OptimizationService{},
		ErrorAnalysisService: &trace.ErrorAnalysisService{},
	}
	annotationHandler := &trace.AnnotationHandler{Hub: hub}

	replayService := replay.NewService()
	replayHandler := &replay.Handler{Service: replayService}

	workflowService := &workflow.Service{}
	_ = workflow.NewScheduler(workflowService)

	proxyService := &proxy.Service{TraceService: traceService}

	envService := &environment.EnvironmentService{}
	envHandler := &environment.Handler{Service: envService}

	secretService := secret.NewService()
	secretHandler := &secret.Handler{Service: secretService}

	alertHandler := &alerting.Handler{Service: alertService}

	govHandler := &governance.Handler{Service: govService}
	mockHandler := &mock.Handler{Service: &mock.Service{}}

	webhookService := &webhook.Service{ReplayService: replayService}

	webhookHandler := &webhook.Handler{Service: webhookService}

	loadTestService := &loadtest.Service{}
	loadTestHandler := &loadtest.Handler{Service: loadTestService}

	auditHandler := &audit.Handler{Service: &audit.Service{}}

	collHandler := &collection.Handler{}

	// Public routes (no auth required)
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	v1 := r.Group("/api/v1")
	{
		authGroup := v1.Group("/auth")
		{
			authGroup.POST("/register", authHandler.Register)
			authGroup.POST("/login", authHandler.Login)
			authGroup.POST("/refresh", middleware.AuthMiddleware(), authHandler.Refresh)
		}

		api := v1.Group("")
		api.Use(middleware.AuthMiddleware())
		{
			// Health check
			api.GET("/health", traceHandler.GetHealth)
			api.POST("/health", traceHandler.GetHealth)

			// Proxy for Request Studio
			api.POST("/proxy", middleware.RBACMiddleware("Member"), proxyService.HandleProxyRequest)

			// Workspaces
			workspaces := api.Group("/workspaces")
			{
				workspaces.POST("", middleware.RBACMiddleware("Member"), workspaceHandler.Create)
				workspaces.GET("", workspaceHandler.GetForUser)
				workspaces.DELETE("/:id", workspaceHandler.Delete)
			}

			// Traces & Annotations
			traces := api.Group("/traces")
			{
				traces.GET("", traceHandler.GetRecent)
				traces.GET("/stats", traceHandler.GetStats)
				traces.GET("/metrics", traceHandler.GetServiceMetrics)
				traces.GET("/topology", traceHandler.GetTopology)
				traces.GET("/:id/waterfall", traceHandler.GetWaterfall)
				traces.GET("/:id/critical-path", traceHandler.GetCriticalPath)
				traces.GET("/:id/logs", traceHandler.GetTraceLogs)
				traces.GET("/:id/metrics", traceHandler.GetTraceMetrics)
				traces.GET("/:id/anomalies", traceHandler.GetTraceAnomalies)
				traces.GET("/:id/optimizations", traceHandler.GetTraceOptimizations)
				traces.GET("/:id/trace-metrics", traceHandler.GetTraceMetricsWithAnomalies)

				traces.GET("/:id/annotations", annotationHandler.GetByTrace)
				traces.POST("/config", traceHandler.SaveConfig)

				traces.GET("/analytics/errors", func(c *gin.Context) {
					c.JSON(http.StatusOK, []gin.H{
						{"service": "payment-service", "count": 142, "message": "Connection timeout to bank gateway", "sample_trace_id": "demo-trace-id"},
						{"service": "auth-service", "count": 89, "message": "Invalid JWT signature detected", "sample_trace_id": "demo-trace-id"},
						{"service": "user-service", "count": 24, "message": "Database deadlock on user_profile table", "sample_trace_id": "demo-trace-id"},
					})
				})
			}

			// Replays
			replays := api.Group("/replays")
			{
				replays.POST("", func(c *gin.Context) {
					var replay models.Replay
					if err := c.ShouldBindJSON(&replay); err != nil {
						c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
						return
					}
					if err := database.DB.Create(&replay).Error; err != nil {
						c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
						return
					}
					c.JSON(http.StatusCreated, replay)
				})
				replays.POST("/:id/execute", replayHandler.Execute)
				replays.GET("/:id/comparison", replayHandler.Compare)
			}

			// Mocks
			mocks := api.Group("/mocks")
			{
				mocks.POST("", mockHandler.Create)
				mocks.GET("", mockHandler.GetAll)
				mocks.PATCH("/:id", mockHandler.Update)
				mocks.DELETE("/:id", mockHandler.Delete)
				mocks.POST("/infer-schema", mockHandler.InferSchema)
			}

			// Environments
			envs := api.Group("/environments")
			{
				envs.POST("", envHandler.Create)
				envs.GET("", envHandler.GetForWorkspace)
			}

			// Secrets
			secrets := api.Group("/secrets")
			{
				secrets.POST("", secretHandler.Create)
				secrets.GET("", secretHandler.List)
				secrets.DELETE("/:id", secretHandler.Delete)
			}

			// Alerts
			alerts := api.Group("/alerts")
			{
				alerts.POST("/rules", alertHandler.CreateRule)
				alerts.GET("/rules", alertHandler.ListRules)
				alerts.GET("/violations", alertHandler.GetViolations)
			}

			// Collections
			colls := api.Group("/collections")
			{
				colls.POST("", collHandler.Create)
				colls.GET("", collHandler.List)
				colls.GET("/:id", collHandler.Get)
				colls.GET("/versions", collHandler.ListVersions)
				colls.POST("/import", collHandler.ImportPostman)
			}

			// Webhooks
			webhooks := api.Group("/webhooks")
			{
				webhooks.POST("/ci", webhookHandler.HandleCI)
			}

			// Audit Logs
			api.GET("/audit-logs", auditHandler.ListMaskingAudits)

			// Load Testing
			api.POST("/load-test", loadTestHandler.Execute)

			// Workflows
			workflows := api.Group("/workflows")
			{
				workflows.POST("", func(c *gin.Context) {
					var wf models.Workflow
					if err := c.ShouldBindJSON(&wf); err != nil {
						c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
						return
					}
					if err := database.DB.Create(&wf).Error; err != nil {
						c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
						return
					}
					c.JSON(http.StatusCreated, wf)
				})
				workflows.POST("/:id/run", func(c *gin.Context) {
					id, _ := uuid.Parse(c.Param("id"))
					err := workflowService.Execute(id)
					if err != nil {
						c.JSON(500, gin.H{"error": err.Error()})
						return
					}
					c.JSON(200, gin.H{"status": "started"})
				})
			}

			// Settings
			settingsService := &settings.Service{}
			api.GET("/settings", func(c *gin.Context) {
				userID, _ := uuid.Parse(c.GetString("UserID"))
				s, err := settingsService.Get(database.DB, userID)
				if err != nil {
					c.JSON(http.StatusNotFound, gin.H{"error": "settings not found"})
					return
				}
				c.JSON(http.StatusOK, s)
			})

			// Governance
			gov := api.Group("/governance")
			{
				gov.GET("/audits", govHandler.ListMaskingAudits)
				gov.GET("/redaction-rules", govHandler.ListRedactionRules)
				gov.POST("/redaction-rules", govHandler.CreateRedactionRule)
				gov.DELETE("/redaction-rules/:id", govHandler.DeleteRedactionRule)
			}

			api.PUT("/settings", func(c *gin.Context) {
				var s settings.UserSettings
				if err := c.ShouldBindJSON(&s); err != nil {
					c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
					return
				}
				userID, _ := uuid.Parse(c.GetString("UserID"))
				s.UserID = userID
				if err := settingsService.Update(database.DB, &s); err != nil {
					c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
					return
				}
				c.JSON(http.StatusOK, s)
			})

			// Reports & CI Status
			api.GET("/reports", func(c *gin.Context) {
				c.JSON(http.StatusOK, gin.H{
					"uptime":         "99.99%",
					"total_requests": 145023,
					"error_rate":     "0.02%",
					"avg_latency":    "142ms",
				})
			})

			api.GET("/webhooks/ci-status", func(c *gin.Context) {
				c.JSON(http.StatusOK, []gin.H{
					{"id": "build-123", "status": "success", "repo": "tracely/frontend", "timestamp": time.Now().Add(-1 * time.Hour)},
					{"id": "build-122", "status": "success", "repo": "tracely/backend", "timestamp": time.Now().Add(-4 * time.Hour)},
					{"id": "build-121", "status": "failed", "repo": "tracely/backend", "timestamp": time.Now().Add(-24 * time.Hour)},
				})
			})

			// Testing Tools
			api.POST("/test-data/generate", func(c *gin.Context) {
				var config map[string]interface{}
				if err := c.ShouldBindJSON(&config); err != nil {
					c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
					return
				}
				// Mock generation
				c.JSON(http.StatusOK, gin.H{"status": "success", "data": "Generated 10 records for template."})
			})

			api.GET("/testing/contracts", func(c *gin.Context) {
				c.JSON(http.StatusOK, []gin.H{
					{"id": "ct-001", "name": "User API Contract", "status": "passed", "last_run": time.Now().Add(-2 * time.Hour)},
					{"id": "ct-002", "name": "Payment Gateway Contract", "status": "failed", "last_run": time.Now().Add(-30 * time.Minute)},
				})
			})

			// WebSockets
			api.GET("/ws", func(c *gin.Context) {
				websocket.ServeWs(hub, c.Writer, c.Request)
			})

		}
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	srv := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %s\n", err)
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server with
	// a timeout of 5 seconds.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	hubCancel()
	if err := srv.Shutdown(ctx); err != nil {

		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("Server exiting")
}
