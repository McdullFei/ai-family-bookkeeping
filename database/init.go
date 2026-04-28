package database

import (
	"log"

	"github.com/mcdullfei/ai-family-bookkeeping/config"
	"github.com/mcdullfei/ai-family-bookkeeping/models"

	"github.com/glebarez/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

func Init() {
	var err error
	DB, err = gorm.Open(sqlite.Open(config.C.DBPath), &gorm.Config{})
	if err != nil {
		log.Fatalf("Failed to connect to database: %v", err)
	}

	// Auto migrate
	DB.AutoMigrate(&models.Record{}, &models.Category{}, &models.Member{})

	// Seed data
	seedCategories()
	seedMembers()

	log.Println("Database initialized successfully")
}

func seedCategories() {
	var count int64
	DB.Model(&models.Category{}).Count(&count)
	if count > 0 {
		return
	}

	expenseCategories := []models.Category{
		{Name: "餐饮", Icon: "🍜", Type: "expense", SortOrder: 1},
		{Name: "交通", Icon: "🚗", Type: "expense", SortOrder: 2},
		{Name: "居住", Icon: "🏠", Type: "expense", SortOrder: 3},
		{Name: "购物", Icon: "🛍️", Type: "expense", SortOrder: 4},
		{Name: "娱乐", Icon: "🎮", Type: "expense", SortOrder: 5},
		{Name: "医疗", Icon: "🏥", Type: "expense", SortOrder: 6},
		{Name: "教育", Icon: "📚", Type: "expense", SortOrder: 7},
		{Name: "通讯", Icon: "📱", Type: "expense", SortOrder: 8},
		{Name: "日用", Icon: "🧴", Type: "expense", SortOrder: 9},
		{Name: "其他", Icon: "📦", Type: "expense", SortOrder: 10},
	}

	incomeCategories := []models.Category{
		{Name: "工资", Icon: "💰", Type: "income", SortOrder: 1},
		{Name: "兼职", Icon: "💼", Type: "income", SortOrder: 2},
		{Name: "理财", Icon: "📈", Type: "income", SortOrder: 3},
		{Name: "其他收入", Icon: "📦", Type: "income", SortOrder: 4},
	}

	for _, c := range expenseCategories {
		DB.Create(&c)
	}
	for _, c := range incomeCategories {
		DB.Create(&c)
	}
	log.Println("Seed categories created")
}

func seedMembers() {
	var count int64
	DB.Model(&models.Member{}).Count(&count)
	if count > 0 {
		return
	}

	members := []models.Member{
		{Name: "飞哥"},
		{Name: "丽丽"},
	}

	for _, m := range members {
		DB.Create(&m)
	}
	log.Println("Seed members created")
}
