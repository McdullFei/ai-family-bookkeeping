package handlers

import (
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/mcdullfei/ai-family-bookkeeping/database"
	"github.com/mcdullfei/ai-family-bookkeeping/models"
)

// Auto-match category based on note content
func autoMatchCategory(note string, typ string) uint {
	var categories []models.Category
	database.DB.Where("type = ?", typ).Find(&categories)

	keywords := map[string][]string{
		"餐饮":   {"午餐", "晚餐", "早餐", "外卖", "饭", "吃", "餐", "火锅", "烧烤", "奶茶", "咖啡", "面", "粉", "饺子", "包子", "水果", "零食", "饮料", "啤酒", "酒", "菜", "超市"},
		"交通":   {"打车", "滴滴", "地铁", "公交", "高铁", "火车", "飞机", "加油", "停车", "过路", "骑行", "单车", "出租", "机票", "车票"},
		"居住":   {"房租", "水电", "物业", "燃气", "网费", "宽带", "维修", "装修", "家具", "家电"},
		"购物":   {"衣服", "鞋", "包", "化妆", "护肤", "日用", "超市采购", "网购", "淘宝", "京东", "拼多多"},
		"娱乐":   {"电影", "游戏", "KTV", "唱歌", "旅游", "门票", "健身", "运动", "书", "会员", "视频"},
		"医疗":   {"医院", "药", "体检", "挂号", "看病", "牙", "眼科", "手术"},
		"教育":   {"培训", "课程", "学费", "考试", "书", "教材"},
		"通讯":   {"话费", "流量", "手机", "充值"},
		"日用":   {"纸巾", "洗衣", "清洁", "沐浴", "洗发", "牙膏", "毛巾"},
	}

	for _, cat := range categories {
		if kws, ok := keywords[cat.Name]; ok {
			for _, kw := range kws {
				if strings.Contains(note, kw) {
					return cat.ID
				}
			}
		}
	}

	// Fallback to "其他" category
	var fallback models.Category
	db := database.DB.Where("type = ? AND name IN ?", typ, []string{"其他", "其他收入"}).First(&fallback)
	if db.Error == nil {
		return fallback.ID
	}

	// Last resort: first category of that type
	database.DB.Where("type = ?", typ).First(&fallback)
	return fallback.ID
}

// CreateRecord creates a new record (public, no auth required)
func CreateRecord(c *gin.Context) {
	var req models.CreateRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request: " + err.Error()})
		return
	}

	// Default member
	if req.Member == "" {
		req.Member = "飞哥"
	}

	// Default source
	if req.Source == "" {
		req.Source = "manual"
	}

	// Default record_time = now
	var recordTime time.Time
	if req.RecordTime == "" {
		recordTime = time.Now()
	} else {
		loc, _ := time.LoadLocation("Asia/Shanghai")
		var err error
		recordTime, err = time.ParseInLocation("2006-01-02T15:04:05+08:00", req.RecordTime, loc)
		if err != nil {
			recordTime, err = time.ParseInLocation("2006-01-02T15:04:05Z07:00", req.RecordTime, loc)
			if err != nil {
				recordTime, err = time.ParseInLocation("2006-01-02 15:04:05", req.RecordTime, loc)
				if err != nil {
					recordTime = time.Now()
				}
			}
		}
	}

	// Auto-match category if not provided
	categoryID := req.CategoryID
	if categoryID == 0 {
		categoryID = autoMatchCategory(req.Note, req.Type)
	}

	record := models.Record{
		Amount:     req.Amount,
		Type:       req.Type,
		CategoryID: categoryID,
		Member:     req.Member,
		Note:       req.Note,
		RecordTime: recordTime,
		ImagePath:  req.ImagePath,
		OCRResult:  req.OCRResult,
		Source:     req.Source,
	}

	if err := database.DB.Create(&record).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Reload with category
	database.DB.Preload("Category").First(&record, record.ID)

	c.JSON(http.StatusCreated, gin.H{"data": record})
}

// GetRecords returns a paginated list of records
func GetRecords(c *gin.Context) {
	var query models.RecordListQuery
	if err := c.ShouldBindQuery(&query); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid query"})
		return
	}

	if query.Page < 1 {
		query.Page = 1
	}
	if query.PageSize < 1 || query.PageSize > 100 {
		query.PageSize = 20
	}

	db := database.DB.Model(&models.Record{}).Preload("Category")

	if query.Type != "" {
		db = db.Where("type = ?", query.Type)
	}
	if query.Member != "" {
		db = db.Where("member = ?", query.Member)
	}
	if query.CategoryID > 0 {
		db = db.Where("category_id = ?", query.CategoryID)
	}

	loc, _ := time.LoadLocation("Asia/Shanghai")
	if query.StartDate != "" {
		if t, err := time.ParseInLocation("2006-01-02", query.StartDate, loc); err == nil {
			db = db.Where("record_time >= ?", t)
		}
	}
	if query.EndDate != "" {
		if t, err := time.ParseInLocation("2006-01-02", query.EndDate, loc); err == nil {
			db = db.Where("record_time <= ?", t.Add(24*time.Hour))
		}
	}

	var total int64
	db.Count(&total)

	var records []models.Record
	offset := (query.Page - 1) * query.PageSize
	db.Order("record_time DESC, id DESC").Offset(offset).Limit(query.PageSize).Find(&records)

	c.JSON(http.StatusOK, gin.H{
		"data": records,
		"pagination": gin.H{
			"total":     total,
			"page":      query.Page,
			"page_size": query.PageSize,
		},
	})
}

// UpdateRecord updates a record
func UpdateRecord(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))

	var record models.Record
	if err := database.DB.First(&record, id).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Record not found"})
		return
	}

	var req models.UpdateRecordRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid request"})
		return
	}

	updates := make(map[string]interface{})
	if req.Amount != nil {
		updates["amount"] = *req.Amount
	}
	if req.Type != nil {
		updates["type"] = *req.Type
	}
	if req.CategoryID != nil {
		updates["category_id"] = *req.CategoryID
	}
	if req.Member != nil {
		updates["member"] = *req.Member
	}
	if req.Note != nil {
		updates["note"] = *req.Note
	}
	if req.RecordTime != nil {
		loc, _ := time.LoadLocation("Asia/Shanghai")
		if t, err := time.ParseInLocation("2006-01-02T15:04:05+08:00", *req.RecordTime, loc); err == nil {
			updates["record_time"] = t
		} else if t, err := time.ParseInLocation("2006-01-02 15:04:05", *req.RecordTime, loc); err == nil {
			updates["record_time"] = t
		}
	}
	if req.ImagePath != nil {
		updates["image_path"] = *req.ImagePath
	}
	if req.OCRResult != nil {
		updates["ocr_result"] = *req.OCRResult
	}
	if req.Source != nil {
		updates["source"] = *req.Source
	}

	if len(updates) > 0 {
		database.DB.Model(&record).Updates(updates)
	}

	database.DB.Preload("Category").First(&record, id)
	c.JSON(http.StatusOK, gin.H{"data": record})
}

// DeleteRecord deletes a record
func DeleteRecord(c *gin.Context) {
	id, _ := strconv.Atoi(c.Param("id"))

	if err := database.DB.Delete(&models.Record{}, id).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Deleted"})
}
