package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/mcdullfei/ai-family-bookkeeping/database"
	"github.com/mcdullfei/ai-family-bookkeeping/models"
)

// GetCategories returns all categories
func GetCategories(c *gin.Context) {
	var categories []models.Category
	query := database.DB.Order("type, sort_order")

	if typ := c.Query("type"); typ != "" {
		query = query.Where("type = ?", typ)
	}

	if err := query.Find(&categories).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": categories})
}

// CreateCategory creates a new category
func CreateCategory(c *gin.Context) {
	var category models.Category
	if err := c.ShouldBindJSON(&category); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}

	if err := database.DB.Create(&category).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": category})
}

// UpdateCategory updates a category
func UpdateCategory(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))

	var category models.Category
	if err := database.DB.First(&category, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Category not found"})
		return
	}

	var updates map[string]interface{}
	if err := c.ShouldBindJSON(&updates); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	if err := database.DB.Model(&category).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": category})
}

// DeleteCategory deletes a category
func DeleteCategory(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))

	// Check if category has records
	var count int64
	database.DB.Model(&models.Record{}).Where("category_id = ?", id).Count(&count)
	if count > 0 {
		c.JSON(http.StatusConflict, gin.H{"error": "该分类下有 " + strconv.FormatInt(count, 10) + " 条记录，无法删除，请先转移记录"})
		return
	}

	if err := database.DB.Delete(&models.Category{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}
