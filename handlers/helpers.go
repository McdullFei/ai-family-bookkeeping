package handlers

import (
	"math"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mcdullfei/ai-family-bookkeeping/database"
	"github.com/mcdullfei/ai-family-bookkeeping/models"
)

// calcChange calculates percentage change between current and previous values
func calcChange(current, previous float64) string {
	if previous == 0 {
		if current == 0 {
			return "0%"
		}
		return "N/A"
	}
	change := math.Round((current-previous)/previous*10000) / 100
	if change > 0 {
		return "+" + strconv.FormatFloat(change, 'f', 1, 64) + "%"
	}
	return strconv.FormatFloat(change, 'f', 1, 64) + "%"
}

// sumAmount returns the total amount for a given type and time range
func sumAmount(typ string, start, end time.Time, member string) float64 {
	var total float64
	db := database.DB.Model(&models.Record{}).Where("type = ? AND record_time >= ? AND record_time < ?", typ, start, end)
	if member != "" {
		db = db.Where("member = ?", member)
	}
	db.Select("COALESCE(SUM(amount), 0)").Scan(&total)
	return total
}

// countRecords returns the number of records in a time range
func countRecords(start, end time.Time, member string) int64 {
	var count int64
	db := database.DB.Model(&models.Record{}).Where("record_time >= ? AND record_time < ?", start, end)
	if member != "" {
		db = db.Where("member = ?", member)
	}
	db.Count(&count)
	return count
}

// categoryBreakdown returns amount breakdown by category
func categoryBreakdown(typ string, start, end time.Time, member string) []gin.H {
	type Result struct {
		CategoryID   uint    `json:"category_id"`
		CategoryName string  `json:"category_name"`
		Total        float64 `json:"total"`
	}

	var results []Result
	db := database.DB.Model(&models.Record{}).
		Select("records.category_id, categories.name as category_name, SUM(records.amount) as total").
		Joins("LEFT JOIN categories ON categories.id = records.category_id").
		Where("records.type = ? AND records.record_time >= ? AND records.record_time < ?", typ, start, end).
		Group("records.category_id, categories.name").
		Order("total DESC")

	if member != "" {
		db = db.Where("records.member = ?", member)
	}

	db.Scan(&results)

	var totalAll float64
	for _, r := range results {
		totalAll += r.Total
	}

	var items []gin.H
	for _, r := range results {
		ratio := "0%"
		if totalAll > 0 {
			ratio = strconv.FormatFloat(math.Round(r.Total/totalAll*1000)/10, 'f', 1, 64) + "%"
		}
		items = append(items, gin.H{
			"category_id":   r.CategoryID,
			"category_name": r.CategoryName,
			"amount":        r.Total,
			"ratio":         ratio,
		})
	}
	return items
}
