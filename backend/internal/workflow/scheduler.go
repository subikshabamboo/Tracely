package workflow

import (
	"log"
	"github.com/robfig/cron/v3"
	"github.com/google/uuid"
)


type Scheduler struct {
	Cron    *cron.Cron
	Service *Service
}

func NewScheduler(service *Service) *Scheduler {
	c := cron.New()
	c.Start()
	return &Scheduler{
		Cron:    c,
		Service: service,
	}
}

func (s *Scheduler) ScheduleWorkflow(workflowID uuid.UUID, schedule string) (cron.EntryID, error) {
	id, err := s.Cron.AddFunc(schedule, func() {
		log.Printf("Running scheduled workflow: %s\n", workflowID)
		s.Service.Execute(workflowID)
	})
	return id, err
}

func (s *Scheduler) RemoveSchedule(entryID cron.EntryID) {
	s.Cron.Remove(entryID)
}

