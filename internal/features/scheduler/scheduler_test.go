package scheduler

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"itools/internal/core/jsontime"
	"itools/internal/core/store"
)

func TestFixedOccurrence(t *testing.T) {
	start := time.Date(2026, 1, 1, 0, 0, 0, 0, time.Local)
	task := Task{
		StartAt:       jsontime.From(start),
		IntervalValue: 5,
		IntervalUnit:  UnitMinute,
	}
	if got := occurrenceIndex(task, start.Add(12*time.Minute)); got != 2 {
		t.Fatalf("occurrence = %d, want 2", got)
	}
	if got := occurrenceIndex(task, start.Add(-time.Minute)); got != -1 {
		t.Fatalf("occurrence before start = %d, want -1", got)
	}
}

func TestMonthOccurrenceClampsMonthEnd(t *testing.T) {
	start := time.Date(2026, 1, 31, 9, 0, 0, 0, time.Local)
	task := Task{
		StartAt:       jsontime.From(start),
		IntervalValue: 1,
		IntervalUnit:  UnitMonth,
	}
	february := time.Date(2026, 2, 28, 10, 0, 0, 0, time.Local)
	if got := occurrenceIndex(task, february); got != 1 {
		t.Fatalf("february occurrence = %d, want 1", got)
	}
	march := time.Date(2026, 3, 31, 10, 0, 0, 0, time.Local)
	if got := occurrenceIndex(task, march); got != 2 {
		t.Fatalf("march occurrence = %d, want 2", got)
	}
}

func TestApplyCmdVariables(t *testing.T) {
	got := applyCmdVariables(`echo "{{name}}"`, map[string]any{"name": `a&b`})
	if got != `echo "a&b"` {
		t.Fatalf("command = %q", got)
	}
	got = applyCmdVariables(`echo {{value}}`, map[string]any{"value": 100})
	if got != `echo "100"` {
		t.Fatalf("number command = %q", got)
	}
}

func TestEscapeCmdLiteral(t *testing.T) {
	got := escapeCmdLiteral("100%\n\"x\"!y")
	want := `"100%% ""x""^!y"`
	if got != want {
		t.Fatalf("escape = %q, want %q", got, want)
	}
}

func TestTaskJSONCompatibility(t *testing.T) {
	old := `{
		"id":"t1",
		"name":"旧任务",
		"type":"terminalCommand",
		"command":"echo hi",
		"startAt":"2026-01-01T09:00:00.000",
		"intervalMinutes":5,
		"intervalUnit":"minute",
		"variables":{"name":"Ada"},
		"script":null
	}`
	var task Task
	if err := json.Unmarshal([]byte(old), &task); err != nil {
		t.Fatal(err)
	}
	if task.IntervalValue != 5 || !task.Enabled {
		t.Fatalf("task = %+v", task)
	}
	if len(task.Variables) != 1 || task.Variables[0].Name != "name" || task.Variables[0].Value != "Ada" {
		t.Fatalf("variables = %+v", task.Variables)
	}
	data, err := json.Marshal(task)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(data), `"startAt":"2026-01-01T09:00:00.000"`) {
		t.Fatalf("startAt format changed: %s", data)
	}
}

func TestTaskRejectsMissingFields(t *testing.T) {
	var task Task
	if err := json.Unmarshal([]byte(`{"id":"x"}`), &task); err == nil {
		t.Fatal("expected an error")
	}
}

func TestRunCommand(t *testing.T) {
	engine := NewEngine(store.New(t.TempDir()), nil)
	defer engine.Stop()
	task := Task{
		ID:            "t1",
		Name:          "echo",
		Type:          TypeTerminal,
		Command:       "echo hello",
		StartAt:       jsontime.Now(),
		IntervalValue: 1,
		IntervalUnit:  UnitMinute,
		Enabled:       true,
	}
	code, timedOut, err := engine.run(task)
	if err != nil || timedOut || code != 0 {
		t.Fatalf("run = code %d timedOut %v err %v", code, timedOut, err)
	}
	found := false
	for _, line := range engine.Logs() {
		if strings.Contains(line, "[echo] hello") {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("log does not contain output: %v", engine.Logs())
	}
}

func TestIntervalClamped(t *testing.T) {
	var task Task
	if err := json.Unmarshal([]byte(`{
		"id":"x","name":"n","startAt":"2026-01-01T09:00:00.000",
		"intervalValue":0,"intervalUnit":"minute"
	}`), &task); err != nil {
		t.Fatal(err)
	}
	if task.IntervalValue != 1 {
		t.Fatalf("interval = %d, want 1", task.IntervalValue)
	}
}
