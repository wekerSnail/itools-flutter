package backup

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"itools/internal/core/store"
)

func TestExportImportRoundTrip(t *testing.T) {
	dir := t.TempDir()
	dataStore := store.New(filepath.Join(dir, "data"))
	if err := dataStore.Write("settings/theme.json", []byte(`{"themeStyle":"modern"}`)); err != nil {
		t.Fatal(err)
	}
	if err := dataStore.Write("scheduler/tasks.json", []byte(`[]`)); err != nil {
		t.Fatal(err)
	}
	service := New(dataStore)
	backupPath := filepath.Join(dir, "backup.json")
	if _, err := service.Export(backupPath); err != nil {
		t.Fatal(err)
	}

	target := store.New(filepath.Join(dir, "target"))
	targetService := New(target)
	if _, err := targetService.Import(backupPath); err != nil {
		t.Fatal(err)
	}
	data, err := target.Read("settings/theme.json")
	if err != nil {
		t.Fatal(err)
	}
	if string(data) != `{"themeStyle":"modern"}` {
		t.Fatalf("theme = %q", data)
	}
}

func TestImportRejectsNewerSchema(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "backup.json")
	content := `{"schemaVersion":99,"files":{}}`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	service := New(store.New(dir))
	if _, err := service.Import(path); err == nil {
		t.Fatal("expected an error")
	}
}

func TestImportSkipsUnknownAndNonString(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "backup.json")
	content := `{
		"schemaVersion": 2,
		"files": {
			"settings/theme.json": "{\"themeStyle\":\"luxury\"}",
			"../outside.json": "nope",
			"settings/hotkeys.json": 3
		}
	}`
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}
	dataStore := store.New(filepath.Join(dir, "data"))
	service := New(dataStore)
	summary, err := service.Import(path)
	if err != nil {
		t.Fatal(err)
	}
	if len(summary.Files) != 1 || summary.Files[0] != "settings/theme.json" {
		t.Fatalf("files = %v", summary.Files)
	}
	if _, err := os.Stat(filepath.Join(dir, "outside.json")); err == nil {
		t.Fatal("path traversal wrote outside the data directory")
	}
}

func TestExportShape(t *testing.T) {
	dir := t.TempDir()
	dataStore := store.New(dir)
	if err := dataStore.Write("settings/theme.json", []byte(`{}`)); err != nil {
		t.Fatal(err)
	}
	service := New(dataStore)
	path := filepath.Join(dir, "backup.json")
	if _, err := service.Export(path); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var decoded map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	if decoded["schemaVersion"] != float64(2) || decoded["app"] != "itools-flutter" {
		t.Fatalf("payload = %v", decoded)
	}
}
