package validator

import (
	"errors"
	"net/url"
	"regexp"
	"strings"

	"github.com/google/uuid"
)

var emailRegex = regexp.MustCompile(`[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}`)

func ValidateEmail(email string) error {
	if !emailRegex.MatchString(strings.ToLower(email)) {
		return errors.New("invalid email format")
	}
	return nil
}

func ValidateUUID(id string) error {
	_, err := uuid.Parse(id)
	return err
}

func ValidateURL(rawURL string) error {
	_, err := url.ParseRequestURI(rawURL)
	return err
}

func ValidateRequired(v string, name string) error {
	if strings.TrimSpace(v) == "" {
		return errors.New(name + " is required")
	}
	return nil
}

func ValidatePassword(password string) error {
	if len(password) < 8 {
		return errors.New("password must be at least 8 characters long")
	}
	return nil
}
