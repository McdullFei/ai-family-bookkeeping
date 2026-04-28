package main

import (
	"log"

	"github.com/gin-gonic/gin"
	"github.com/mcdullfei/ai-family-bookkeeping/database"
	"github.com/mcdullfei/ai-family-bookkeeping/handlers"
	"github.com/mcdullfei/ai-family-bookkeeping/middleware"
)

func main() {
	// Init database
	database.Init()

	// Setup router
	r := gin.Default()

	// CORS middleware
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Content-Type, Authorization")
		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Public routes (no auth required - for 萌客AI to call)
	api := r.Group("/api")
	{
		api.POST("/records", handlers.CreateRecord)
		api.GET("/categories", handlers.GetCategories)
		api.GET("/members", handlers.GetMembers)
		api.POST("/auth/login", handlers.Login)
	}

	// Protected routes (auth required - for admin panel)
	auth := api.Group("")
	auth.Use(middleware.AuthRequired())
	{
		// Records
		auth.GET("/records", handlers.GetRecords)
		auth.PUT("/records/:id", handlers.UpdateRecord)
		auth.DELETE("/records/:id", handlers.DeleteRecord)

		// Stats
		auth.GET("/stats/daily", handlers.DailyStats)
		auth.GET("/stats/weekly", handlers.WeeklyStats)
		auth.GET("/stats/monthly", handlers.MonthlyStats)
		auth.GET("/stats/by-member", handlers.StatsByMember)
		auth.GET("/stats/by-category", handlers.StatsByCategory)

		// Categories
		auth.POST("/categories", handlers.CreateCategory)
		auth.PUT("/categories/:id", handlers.UpdateCategory)
		auth.DELETE("/categories/:id", handlers.DeleteCategory)
	}

	log.Println("Server starting on :8090")
	if err := r.Run(":8090"); err != nil {
		log.Fatalf("Failed to start server: %v", err)
	}
}
