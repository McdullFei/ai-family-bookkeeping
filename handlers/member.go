package handlers

import (
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/mcdullfei/ai-family-bookkeeping/database"
	"github.com/mcdullfei/ai-family-bookkeeping/models"
)

// GetMembers returns all members
func GetMembers(c *gin.Context) {
	var members []models.Member
	if err := database.DB.Find(&members).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"data": members})
}
