package middleware

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

var roleHierarchy = map[string]int{
	"Viewer": 1,
	"Member": 2,
	"Admin":  3,
	"Owner":  4,
}

func RBACMiddleware(requiredRole string) gin.HandlerFunc {
	return func(c *gin.Context) {
		role, exists := c.Get("Role")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "User role not found"})
			c.Abort()
			return
		}

		userRole := role.(string)
		log.Printf("RBAC: RequiredRole=%s UserRole=%s", requiredRole, userRole)
		
		if roleHierarchy[userRole] >= roleHierarchy[requiredRole] {
			c.Next()
			return
		}

		log.Printf("RBAC: Access denied for UserRole=%s", userRole)
		c.JSON(http.StatusForbidden, gin.H{"error": "Insufficient permissions"})
		c.Abort()
	}
}


