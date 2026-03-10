package auth

import (
	"errors"
	"log"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
	"golang.org/x/crypto/bcrypt"
)

func GetJwtSecret() []byte {
	secret := os.Getenv("JWT_SECRET")
	if secret == "" {
		log.Fatal("JWT_SECRET environment variable is required and was not found after loading .env")
	}
	return []byte(secret)
}

type Service struct{}

func (s *Service) Register(email, password, fullName string) (*models.User, error) {
	hashedPassword, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, err
	}

	// Check if user already exists
	var existingUser models.User
	if err := database.DB.Where("email = ?", email).First(&existingUser).Error; err == nil {
		return nil, errors.New("user already registered")
	}

	user := &models.User{
		ID:           uuid.New(),
		Email:        email,
		PasswordHash: string(hashedPassword),
		FullName:     fullName,
		Role:         "Member",
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}

	if err := database.DB.Create(user).Error; err != nil {
		return nil, err
	}

	// Auto-link to seeded "Production Cluster" workspace for demo purposes
	var workspace models.Workspace
	if err := database.DB.Where("name = ?", "Production Cluster").First(&workspace).Error; err == nil {
		wsUser := models.WorkspaceUser{
			WorkspaceID: workspace.ID,
			UserID:      user.ID,
			Role:        "Member",
		}
		database.DB.Create(&wsUser)
	}

	return user, nil
}

func (s *Service) Login(email, password string) (string, *models.User, error) {
	var user models.User
	if err := database.DB.Where("email = ?", email).First(&user).Error; err != nil {
		return "", nil, errors.New("invalid credentials")
	}

	err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password))
	if err != nil {
		return "", nil, errors.New("invalid credentials")
	}

	tokenString, err := s.GenerateToken(user.ID, user.Role)
	if err != nil {
		return "", nil, err
	}

	return tokenString, &user, nil
}

func (s *Service) GenerateToken(userID uuid.UUID, role string) (string, error) {
	if role == "" {
		role = "Member"
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user_id": userID.String(),
		"role":    role,
		"exp":     time.Now().Add(time.Hour).Unix(),
	})

	return token.SignedString(GetJwtSecret())
}

func (s *Service) RefreshToken(userID uuid.UUID, role string) (string, error) {
	return s.GenerateToken(userID, role)
}

