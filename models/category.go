package models

import "time"

type Category struct {
	ID        uint      `json:"id" gorm:"primaryKey"`
	Name      string    `json:"name" gorm:"not null;size:20;unique"`
	Icon      string    `json:"icon" gorm:"size:50"`
	Type      string    `json:"type" gorm:"not null;size:10"` // income / expense
	SortOrder int       `json:"sort_order" gorm:"default:0"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}
