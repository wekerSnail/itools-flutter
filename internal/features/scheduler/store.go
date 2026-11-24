package scheduler

import (
	"encoding/json"

	corestore "itools/internal/core/store"
)

const (
	tasksPath = "scheduler/tasks.json"
	logsPath  = "scheduler/logs.json"
)

// Store reads and writes the scheduler's files.
type Store struct {
	store *corestore.Store
}

// NewStore returns a scheduler store.
func NewStore(st *corestore.Store) *Store {
	return &Store{store: st}
}

// LoadTasks reads the task list, skipping corrupted entries.
func (s *Store) LoadTasks() ([]Task, error) {
	data, err := s.store.Read(tasksPath)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, nil
	}
	var entries []json.RawMessage
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil, nil
	}
	tasks := make([]Task, 0, len(entries))
	for _, entry := range entries {
		var task Task
		if err := json.Unmarshal(entry, &task); err != nil || task.ID == "" {
			continue
		}
		tasks = append(tasks, task)
	}
	return tasks, nil
}

// SaveTasks writes the task list.
func (s *Store) SaveTasks(tasks []Task) error {
	if tasks == nil {
		tasks = []Task{}
	}
	data, err := json.MarshalIndent(tasks, "", "  ")
	if err != nil {
		return err
	}
	return s.store.Write(tasksPath, data)
}

// LoadLogs reads the run log.
func (s *Store) LoadLogs() ([]LogEntry, error) {
	data, err := s.store.Read(logsPath)
	if err != nil {
		return nil, err
	}
	if len(data) == 0 {
		return nil, nil
	}
	var entries []LogEntry
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil, nil
	}
	return entries, nil
}

// SaveLogs writes the run log.
func (s *Store) SaveLogs(entries []LogEntry) error {
	if entries == nil {
		entries = []LogEntry{}
	}
	data, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return err
	}
	return s.store.Write(logsPath, data)
}
