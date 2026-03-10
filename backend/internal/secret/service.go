package secret

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"io"
	"os"
	"github.com/google/uuid"
	"github.com/tracely/backend/internal/database"
	"github.com/tracely/backend/internal/models"
)

type Service struct {
	EncryptionKey []byte // 32 bytes for AES-256
}

func NewService() *Service {
	key := os.Getenv("ENCRYPTION_KEY")
	if key == "" {
		panic("ENCRYPTION_KEY environment variable is required")
	}
	// Pad or trim to 32 bytes
	byteKey := []byte(key)
	if len(byteKey) < 32 {
		padding := make([]byte, 32-len(byteKey))
		byteKey = append(byteKey, padding...)
	} else if len(byteKey) > 32 {
		byteKey = byteKey[:32]
	}
	return &Service{EncryptionKey: byteKey}
}



func (s *Service) Encrypt(text string) (string, error) {
	block, err := aes.NewCipher(s.EncryptionKey)
	if err != nil {
		return "", err
	}

	nonce := make([]byte, 12)
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", err
	}

	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	ciphertext := aesgcm.Seal(nil, nonce, []byte(text), nil)
	return base64.StdEncoding.EncodeToString(append(nonce, ciphertext...)), nil
}

func (s *Service) Decrypt(encodedText string) (string, error) {
	data, err := base64.StdEncoding.DecodeString(encodedText)
	if err != nil {
		return "", err
	}

	if len(data) < 12 {
		return "", errors.New("invalid ciphertext")
	}

	nonce, ciphertext := data[:12], data[12:]

	block, err := aes.NewCipher(s.EncryptionKey)
	if err != nil {
		return "", err
	}

	aesgcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}

	plaintext, err := aesgcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}

	return string(plaintext), nil
}

func (s *Service) SaveSecret(workspaceID uuid.UUID, key, value string) error {
	encryptedValue, err := s.Encrypt(value)
	if err != nil {
		return err
	}

	secret := &models.Secret{
		ID:          uuid.New(),
		WorkspaceID: workspaceID,
		Key:         key,
		Value:       encryptedValue,
	}

	return database.DB.Create(secret).Error
}
