// Package store persists the app's JSON files under its user data directory.
package store

import (
	"errors"
	"os"
	"path/filepath"
	"sync"
)

// Store reads and writes files under one root directory. Writes to the same
// path are serialized and replace the target atomically through a temporary
// file, so a crash cannot leave a half-written file.
type Store struct {
	base  string
	mu    sync.Mutex
	locks map[string]*sync.Mutex
}

// New returns a store rooted at base.
func New(base string) *Store {
	return &Store{base: base, locks: make(map[string]*sync.Mutex)}
}

// Base returns the root directory.
func (s *Store) Base() string { return s.base }

func (s *Store) path(relative string) string {
	return filepath.Join(s.base, filepath.FromSlash(relative))
}

// Read returns the file's bytes, or nil when it does not exist.
func (s *Store) Read(relative string) ([]byte, error) {
	data, err := os.ReadFile(s.path(relative))
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	return data, err
}

// Exists reports whether the file exists.
func (s *Store) Exists(relative string) bool {
	_, err := os.Stat(s.path(relative))
	return err == nil
}

// Write replaces the file's contents atomically.
func (s *Store) Write(relative string, data []byte) error {
	lock := s.lock(relative)
	lock.Lock()
	defer lock.Unlock()

	target := s.path(relative)
	if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil {
		return err
	}
	tmp := target + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return err
	}
	if err := os.Rename(tmp, target); err != nil {
		_ = os.Remove(tmp)
		return err
	}
	return nil
}

func (s *Store) lock(relative string) *sync.Mutex {
	s.mu.Lock()
	defer s.mu.Unlock()
	lock := s.locks[relative]
	if lock == nil {
		lock = &sync.Mutex{}
		s.locks[relative] = lock
	}
	return lock
}
