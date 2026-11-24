package scheduler

import (
	"sync"
	"time"

	"itools/internal/core/jsontime"
)

// LogEntry is one line of task output.
type LogEntry struct {
	CreatedAt jsontime.Time `json:"createdAt"`
	Message   string        `json:"message"`
}

const (
	maxLogEntries  = 2000
	logRetention   = 5 * 24 * time.Hour
	notifyThrottle = 120 * time.Millisecond
	saveDebounce   = 300 * time.Millisecond
)

// logBuffer keeps recent log entries in memory and persists them with a
// debounce.
type logBuffer struct {
	store    *Store
	onChange func()

	mu      sync.Mutex
	entries []LogEntry
	dirty   bool

	notifyTimer *time.Timer
	saveTimer   *time.Timer
	closed      bool
}

func newLogBuffer(store *Store, onChange func()) *logBuffer {
	return &logBuffer{store: store, onChange: onChange}
}

// Load reads the log from disk.
func (b *logBuffer) Load() {
	entries, err := b.store.LoadLogs()
	if err != nil {
		return
	}
	b.mu.Lock()
	b.entries = entries
	b.trimLocked(time.Now())
	b.mu.Unlock()
	b.notify()
}

// Append adds a line and schedules a save.
func (b *logBuffer) Append(message string) {
	b.mu.Lock()
	b.entries = append(b.entries, LogEntry{CreatedAt: jsontime.Now(), Message: message})
	b.trimLocked(time.Now())
	b.dirty = true
	b.mu.Unlock()
	b.scheduleNotify()
	b.scheduleSave()
}

// Messages returns the log oldest first.
func (b *logBuffer) Messages() []string {
	b.mu.Lock()
	defer b.mu.Unlock()
	messages := make([]string, len(b.entries))
	for i, entry := range b.entries {
		messages[i] = entry.Message
	}
	return messages
}

// Close flushes the log and stops timers.
func (b *logBuffer) Close() {
	b.mu.Lock()
	b.closed = true
	if b.notifyTimer != nil {
		b.notifyTimer.Stop()
		b.notifyTimer = nil
	}
	if b.saveTimer != nil {
		b.saveTimer.Stop()
		b.saveTimer = nil
	}
	entries := append([]LogEntry(nil), b.entries...)
	b.mu.Unlock()
	_ = b.store.SaveLogs(entries)
}

func (b *logBuffer) trimLocked(now time.Time) {
	cutoff := now.Add(-logRetention)
	start := 0
	for start < len(b.entries) && b.entries[start].CreatedAt.Time.Before(cutoff) {
		start++
	}
	if start > 0 {
		b.entries = append([]LogEntry(nil), b.entries[start:]...)
	}
	if len(b.entries) > maxLogEntries {
		b.entries = append([]LogEntry(nil), b.entries[len(b.entries)-maxLogEntries:]...)
	}
}

func (b *logBuffer) scheduleNotify() {
	b.mu.Lock()
	if b.closed {
		b.mu.Unlock()
		return
	}
	if b.notifyTimer == nil {
		b.notifyTimer = time.AfterFunc(notifyThrottle, func() {
			b.mu.Lock()
			b.notifyTimer = nil
			b.mu.Unlock()
			b.notify()
		})
	}
	b.mu.Unlock()
}

func (b *logBuffer) scheduleSave() {
	b.mu.Lock()
	if b.closed {
		b.mu.Unlock()
		return
	}
	if b.saveTimer == nil {
		b.saveTimer = time.AfterFunc(saveDebounce, func() {
			b.mu.Lock()
			b.saveTimer = nil
			entries := append([]LogEntry(nil), b.entries...)
			dirty := b.dirty
			b.dirty = false
			b.mu.Unlock()
			if dirty {
				_ = b.store.SaveLogs(entries)
			}
		})
	}
	b.mu.Unlock()
}

func (b *logBuffer) notify() {
	if b.onChange != nil {
		b.onChange()
	}
}
