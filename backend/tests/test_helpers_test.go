package tests

import (
	"github.com/joho/godotenv"
	"github.com/tracely/backend/internal/database"
)

var (
	baseURL   = "http://localhost:8080/api/v1"
	publicURL = "http://localhost:8080"
)

func init() {
	godotenv.Load("../.env")
	if err := database.Connect(); err != nil {
		panic("Failed to connect to testing database: " + err.Error())
	}
}
