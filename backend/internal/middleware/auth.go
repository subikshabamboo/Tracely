package middleware

import (
	"log"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/tracely/backend/internal/auth"
)

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		authHeader := c.GetHeader("Authorization")
		if authHeader == "" {
			c.AbortWithStatusJSON(401, gin.H{"error": "Authorization header required"})
			return
		}

		tokenString := strings.Replace(authHeader, "Bearer ", "", 1)
		token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
			return auth.GetJwtSecret(), nil
		})

		if err != nil || !token.Valid {
			c.AbortWithStatusJSON(401, gin.H{"error": "Invalid token"})
			return
		}

		claims, ok := token.Claims.(jwt.MapClaims)
		if !ok {
			log.Printf("Auth: Invalid token claims for UserID: %v", claims["user_id"])
			c.AbortWithStatusJSON(401, gin.H{"error": "Invalid token claims"})
			return
		}

		log.Printf("Auth: UserID=%v Role=%v", claims["user_id"], claims["role"])
		c.Set("UserID", claims["user_id"].(string))
		c.Set("Role", claims["role"].(string))
		c.Next()
	}
}
