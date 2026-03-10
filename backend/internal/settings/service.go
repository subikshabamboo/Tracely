package settings

import (
	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Service struct{}

type UserSettings struct {
	UserID   uuid.UUID `gorm:"primaryKey" json:"user_id"`
	Theme    string    `gorm:"default:'dark'" json:"theme"`
	TimeZone string    `gorm:"default:'UTC'" json:"time_zone"`
	Language string    `gorm:"default:'en'" json:"language"`
}

func (s *Service) Update(db *gorm.DB, settings *UserSettings) error {
	return db.Save(settings).Error
}

func (s *Service) Get(db *gorm.DB, userID uuid.UUID) (*UserSettings, error) {
	var settings UserSettings
	err := db.First(&settings, "user_id = ?", userID).Error
	if err == gorm.ErrRecordNotFound {
		return &UserSettings{
			UserID:   userID,
			Theme:    "dark",
			TimeZone: "UTC",
			Language: "en",
		}, nil
	}
	return &settings, err
}

