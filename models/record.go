package models

import "time"

type Record struct {
	ID         uint      `json:"id" gorm:"primaryKey"`
	Amount     float64   `json:"amount" gorm:"not null"`
	Type       string    `json:"type" gorm:"not null;size:10"` // income / expense
	CategoryID uint      `json:"category_id" gorm:"not null"`
	Category   Category  `json:"category" gorm:"foreignKey:CategoryID"`
	Member     string    `json:"member" gorm:"not null;size:20"`
	Note       string    `json:"note" gorm:"size:200"`
	RecordTime time.Time `json:"record_time" gorm:"not null;index"`
	ImagePath  string    `json:"image_path" gorm:"size:500"`
	OCRResult  string    `json:"ocr_result" gorm:"type:text"`
	Source     string    `json:"source" gorm:"size:10"` // manual / ocr
	CreatedAt  time.Time `json:"created_at"`
	UpdatedAt  time.Time `json:"updated_at"`
}

// CreateRecordRequest is the API request body for creating a record
type CreateRecordRequest struct {
	Amount     float64  `json:"amount" binding:"required"`
	Type       string   `json:"type" binding:"required,oneof=income expense"`
	CategoryID uint     `json:"category_id"`
	Member     string   `json:"member"`
	Note       string   `json:"note"`
	RecordTime string   `json:"record_time"`
	ImagePath  string   `json:"image_path"`
	OCRResult  string   `json:"ocr_result"`
	Source     string   `json:"source"`
}

// UpdateRecordRequest is the API request body for updating a record
type UpdateRecordRequest struct {
	Amount     *float64 `json:"amount"`
	Type       *string  `json:"type"`
	CategoryID *uint    `json:"category_id"`
	Member     *string  `json:"member"`
	Note       *string  `json:"note"`
	RecordTime *string  `json:"record_time"`
	ImagePath  *string  `json:"image_path"`
	OCRResult  *string  `json:"ocr_result"`
	Source     *string  `json:"source"`
}

// RecordListQuery is the query parameters for listing records
type RecordListQuery struct {
	Type       string `form:"type"`
	Member     string `form:"member"`
	CategoryID uint   `form:"category_id"`
	StartDate  string `form:"start_date"`
	EndDate    string `form:"end_date"`
	Page       int    `form:"page,default=1"`
	PageSize   int    `form:"page_size,default=20"`
}
