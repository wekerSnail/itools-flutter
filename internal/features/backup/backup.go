// Package backup exports and imports the app's managed JSON files.
package backup

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"itools/internal/core/jsontime"
	"itools/internal/core/store"
)

const schemaVersion = 2

// ManagedFiles are the files a backup contains.
var ManagedFiles = []string{
	"scheduler/tasks.json",
	"scheduler/logs.json",
	"folder_mapping/collections.json",
	"settings/theme.json",
	"settings/hotkeys.json",
}

// Summary describes a backup or the current data.
type Summary struct {
	ExportedAt jsontime.Time
	Files      []string
}

type payload struct {
	SchemaVersion int               `json:"schemaVersion"`
	App           string            `json:"app"`
	ExportedAt    jsontime.Time     `json:"exportedAt"`
	Files         map[string]string `json:"files"`
}

// Service reads and writes backups.
type Service struct {
	store *store.Store
}

// New returns a backup service.
func New(st *store.Store) *Service {
	return &Service{store: st}
}

// Current lists the managed files that exist.
func (s *Service) Current() ([]string, error) {
	files := make([]string, 0, len(ManagedFiles))
	for _, name := range ManagedFiles {
		data, err := s.store.Read(name)
		if err != nil {
			return nil, err
		}
		if len(data) > 0 {
			files = append(files, name)
		}
	}
	return files, nil
}

// SuggestedName returns the default export file name.
func (s *Service) SuggestedName() string {
	now := time.Now()
	return fmt.Sprintf("itools_backup_%04d%02d%02d_%02d%02d%02d.json",
		now.Year(), now.Month(), now.Day(), now.Hour(), now.Minute(), now.Second())
}

// Export writes a backup to path.
func (s *Service) Export(path string) (Summary, error) {
	files := make(map[string]string, len(ManagedFiles))
	for _, name := range ManagedFiles {
		data, err := s.store.Read(name)
		if err != nil {
			return Summary{}, err
		}
		if len(data) > 0 {
			files[name] = string(data)
		}
	}
	data, err := json.MarshalIndent(payload{
		SchemaVersion: schemaVersion,
		App:           "itools-flutter",
		ExportedAt:    jsontime.Now(),
		Files:         files,
	}, "", "  ")
	if err != nil {
		return Summary{}, err
	}
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return Summary{}, err
	}
	return Summary{ExportedAt: jsontime.Now(), Files: keys(files)}, nil
}

// Import validates and writes a backup from path.
func (s *Service) Import(path string) (Summary, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return Summary{}, err
	}
	var raw struct {
		SchemaVersion *int                       `json:"schemaVersion"`
		ExportedAt    jsontime.Time              `json:"exportedAt"`
		Files         map[string]json.RawMessage `json:"files"`
	}
	if err := json.Unmarshal(data, &raw); err != nil {
		return Summary{}, fmt.Errorf("备份文件格式不正确")
	}
	version := 1
	if raw.SchemaVersion != nil {
		version = *raw.SchemaVersion
	}
	if version > schemaVersion {
		return Summary{}, fmt.Errorf("备份文件版本不受支持")
	}
	if raw.Files == nil {
		return Summary{}, fmt.Errorf("备份文件缺少数据内容")
	}

	pending := make(map[string]string, len(raw.Files))
	for name, value := range raw.Files {
		if !managed(name) {
			continue
		}
		var text string
		if err := json.Unmarshal(value, &text); err != nil {
			continue
		}
		pending[name] = text
	}
	imported := make([]string, 0, len(pending))
	for name, text := range pending {
		if err := s.store.Write(name, []byte(text)); err != nil {
			return Summary{}, err
		}
		imported = append(imported, name)
	}
	return Summary{ExportedAt: raw.ExportedAt, Files: imported}, nil
}

func managed(name string) bool {
	for _, candidate := range ManagedFiles {
		if candidate == name {
			return true
		}
	}
	return false
}

func keys(files map[string]string) []string {
	result := make([]string, 0, len(files))
	for name := range files {
		result = append(result, name)
	}
	return result
}
