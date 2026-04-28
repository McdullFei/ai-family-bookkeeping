package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mcdullfei/ai-family-bookkeeping/database"
	"github.com/mcdullfei/ai-family-bookkeeping/models"
)

// DailyStats returns daily statistics
func DailyStats(c *gin.Context) {
	dateStr := c.Query("date")
	member := c.Query("member")

	loc, _ := time.LoadLocation("Asia/Shanghai")
	var date time.Time
	if dateStr == "" {
		date = time.Now().In(loc)
	} else {
		var err error
		date, err = time.ParseInLocation("2006-01-02", dateStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid date format, use YYYY-MM-DD"})
			return
		}
	}

	startOfDay := time.Date(date.Year(), date.Month(), date.Day(), 0, 0, 0, 0, loc)
	endOfDay := startOfDay.AddDate(0, 0, 1)

	income := sumAmount("income", startOfDay, endOfDay, member)
	expense := sumAmount("expense", startOfDay, endOfDay, member)
	count := countRecords(startOfDay, endOfDay, member)

	// Yesterday
	yesterdayStart := startOfDay.AddDate(0, 0, -1)
	yesterdayIncome := sumAmount("income", yesterdayStart, startOfDay, member)
	yesterdayExpense := sumAmount("expense", yesterdayStart, startOfDay, member)

	// Same day last month
	lastMonthDay := startOfDay.AddDate(0, -1, 0)
	lastMonthDayEnd := lastMonthDay.AddDate(0, 0, 1)
	lastMonthIncome := sumAmount("income", lastMonthDay, lastMonthDayEnd, member)
	lastMonthExpense := sumAmount("expense", lastMonthDay, lastMonthDayEnd, member)

	c.JSON(http.StatusOK, gin.H{
		"date":          date.Format("2006-01-02"),
		"income":        income,
		"expense":       expense,
		"balance":       income - expense,
		"records_count": count,
		"compare": gin.H{
			"yesterday": gin.H{
				"income_change":  calcChange(income, yesterdayIncome),
				"expense_change": calcChange(expense, yesterdayExpense),
			},
			"same_day_last_month": gin.H{
				"income_change":  calcChange(income, lastMonthIncome),
				"expense_change": calcChange(expense, lastMonthExpense),
			},
		},
	})
}

// WeeklyStats returns weekly statistics
func WeeklyStats(c *gin.Context) {
	startStr := c.Query("start")
	endStr := c.Query("end")
	member := c.Query("member")

	loc, _ := time.LoadLocation("Asia/Shanghai")
	var start, end time.Time

	if startStr != "" {
		var err error
		start, err = time.ParseInLocation("2006-01-02", startStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid start date"})
			return
		}
	} else {
		now := time.Now().In(loc)
		weekday := int(now.Weekday())
		if weekday == 0 {
			weekday = 7
		}
		start = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc).AddDate(0, 0, 1-weekday)
	}

	if endStr != "" {
		var err error
		end, err = time.ParseInLocation("2006-01-02", endStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid end date"})
			return
		}
		end = end.AddDate(0, 0, 1)
	} else {
		end = start.AddDate(0, 0, 7)
	}

	income := sumAmount("income", start, end, member)
	expense := sumAmount("expense", start, end, member)
	count := countRecords(start, end, member)
	categories := categoryBreakdown("expense", start, end, member)

	// Last week
	lastWeekStart := start.AddDate(0, 0, -7)
	lastWeekEnd := start
	lastWeekIncome := sumAmount("income", lastWeekStart, lastWeekEnd, member)
	lastWeekExpense := sumAmount("expense", lastWeekStart, lastWeekEnd, member)

	// Same week last year
	lastYearStart := start.AddDate(-1, 0, 0)
	lastYearEnd := end.AddDate(-1, 0, 0)
	lastYearIncome := sumAmount("income", lastYearStart, lastYearEnd, member)
	lastYearExpense := sumAmount("expense", lastYearStart, lastYearEnd, member)

	c.JSON(http.StatusOK, gin.H{
		"start":         start.Format("2006-01-02"),
		"end":           end.AddDate(0, 0, -1).Format("2006-01-02"),
		"income":        income,
		"expense":       expense,
		"balance":       income - expense,
		"records_count": count,
		"categories":    categories,
		"compare": gin.H{
			"mom": gin.H{
				"income_change":  calcChange(income, lastWeekIncome),
				"expense_change": calcChange(expense, lastWeekExpense),
			},
			"yoy": gin.H{
				"income_change":  calcChange(income, lastYearIncome),
				"expense_change": calcChange(expense, lastYearExpense),
			},
		},
	})
}

// MonthlyStats returns monthly statistics
func MonthlyStats(c *gin.Context) {
	monthStr := c.Query("month")
	member := c.Query("member")

	loc, _ := time.LoadLocation("Asia/Shanghai")
	var year, month int

	if monthStr != "" {
		t, err := time.ParseInLocation("2006-01", monthStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid month format, use YYYY-MM"})
			return
		}
		year = t.Year()
		month = int(t.Month())
	} else {
		now := time.Now().In(loc)
		year = now.Year()
		month = int(now.Month())
	}

	startOfMonth := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, loc)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	income := sumAmount("income", startOfMonth, endOfMonth, member)
	expense := sumAmount("expense", startOfMonth, endOfMonth, member)
	count := countRecords(startOfMonth, endOfMonth, member)
	categories := categoryBreakdown("expense", startOfMonth, endOfMonth, member)

	// Last month (环比)
	lastMonthStart := startOfMonth.AddDate(0, -1, 0)
	lastMonthEnd := startOfMonth
	lastMonthIncome := sumAmount("income", lastMonthStart, lastMonthEnd, member)
	lastMonthExpense := sumAmount("expense", lastMonthStart, lastMonthEnd, member)

	// Same month last year (同比)
	lastYearStart := startOfMonth.AddDate(-1, 0, 0)
	lastYearEnd := endOfMonth.AddDate(-1, 0, 0)
	lastYearIncome := sumAmount("income", lastYearStart, lastYearEnd, member)
	lastYearExpense := sumAmount("expense", lastYearStart, lastYearEnd, member)

	c.JSON(http.StatusOK, gin.H{
		"month":         time.Date(year, time.Month(month), 1, 0, 0, 0, 0, loc).Format("2006-01"),
		"income":        income,
		"expense":       expense,
		"balance":       income - expense,
		"records_count": count,
		"categories":    categories,
		"compare": gin.H{
			"mom": gin.H{
				"income_change":  calcChange(income, lastMonthIncome),
				"expense_change": calcChange(expense, lastMonthExpense),
			},
			"yoy": gin.H{
				"income_change":  calcChange(income, lastYearIncome),
				"expense_change": calcChange(expense, lastYearExpense),
			},
		},
	})
}

// StatsByMember returns per-member summary
func StatsByMember(c *gin.Context) {
	monthStr := c.Query("month")

	loc, _ := time.LoadLocation("Asia/Shanghai")
	var year, month int

	if monthStr != "" {
		t, err := time.ParseInLocation("2006-01", monthStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid month format"})
			return
		}
		year = t.Year()
		month = int(t.Month())
	} else {
		now := time.Now().In(loc)
		year = now.Year()
		month = int(now.Month())
	}

	startOfMonth := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, loc)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	// Get all members first
	var members []models.Member
	database.DB.Find(&members)

	type MemberStat struct {
		Member       string  `json:"member"`
		Income       float64 `json:"income"`
		Expense      float64 `json:"expense"`
		RecordsCount int64   `json:"records_count"`
	}

	var stats []MemberStat
	for _, m := range members {
		inc := sumAmount("income", startOfMonth, endOfMonth, m.Name)
		exp := sumAmount("expense", startOfMonth, endOfMonth, m.Name)
		cnt := countRecords(startOfMonth, endOfMonth, m.Name)
		stats = append(stats, MemberStat{
			Member:       m.Name,
			Income:       inc,
			Expense:      exp,
			RecordsCount: cnt,
		})
	}

	c.JSON(http.StatusOK, gin.H{
		"month": time.Date(year, time.Month(month), 1, 0, 0, 0, 0, loc).Format("2006-01"),
		"data":  stats,
	})
}

// StatsByCategory returns category summary
func StatsByCategory(c *gin.Context) {
	monthStr := c.Query("month")
	member := c.Query("member")

	loc, _ := time.LoadLocation("Asia/Shanghai")
	var year, month int

	if monthStr != "" {
		t, err := time.ParseInLocation("2006-01", monthStr, loc)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid month format"})
			return
		}
		year = t.Year()
		month = int(t.Month())
	} else {
		now := time.Now().In(loc)
		year = now.Year()
		month = int(now.Month())
	}

	startOfMonth := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, loc)
	endOfMonth := startOfMonth.AddDate(0, 1, 0)

	expenseCategories := categoryBreakdown("expense", startOfMonth, endOfMonth, member)
	incomeCategories := categoryBreakdown("income", startOfMonth, endOfMonth, member)

	c.JSON(http.StatusOK, gin.H{
		"month":   time.Date(year, time.Month(month), 1, 0, 0, 0, 0, loc).Format("2006-01"),
		"expense": expenseCategories,
		"income":  incomeCategories,
	})
}
