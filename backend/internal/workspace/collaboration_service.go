package workspace

import (
	"log"
	"sync"
	"github.com/google/uuid"
)


type CollaborationService struct {
	mu sync.RWMutex
	ActiveUsers map[uuid.UUID][]uuid.UUID // WorkspaceID -> UserIDs
}

func (s *CollaborationService) UserJoined(workspaceID, userID uuid.UUID) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.ActiveUsers == nil {
		s.ActiveUsers = make(map[uuid.UUID][]uuid.UUID)
	}
	s.ActiveUsers[workspaceID] = append(s.ActiveUsers[workspaceID], userID)
	log.Printf("User %s joined workspace %s\n", userID, workspaceID)
}

func (s *CollaborationService) GetActiveUsers(workspaceID uuid.UUID) []uuid.UUID {
	s.mu.RLock()
	defer s.mu.RUnlock()
	return s.ActiveUsers[workspaceID]
}
