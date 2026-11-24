// Package scheduler runs commands and scripts on a repeating schedule.
package scheduler

import (
	"encoding/json"
	"fmt"

	"itools/internal/core/jsontime"
)

// TaskType is what a task runs.
type TaskType string

const (
	TypeTerminal TaskType = "terminalCommand"
	TypeJS       TaskType = "jsScript"
)

// Unit is the unit of a task's interval.
type Unit string

const (
	UnitSecond Unit = "second"
	UnitMinute Unit = "minute"
	UnitHour   Unit = "hour"
	UnitDay    Unit = "day"
	UnitWeek   Unit = "week"
	UnitMonth  Unit = "month"
)

// Variable is one placeholder the task's command or script receives.
type Variable struct {
	Name  string `json:"name"`
	Type  string `json:"type"`
	Value any    `json:"value"`
}

// Task is one scheduled task, compatible with the Flutter app's tasks.json.
type Task struct {
	ID             string        `json:"id"`
	Name           string        `json:"name"`
	Type           TaskType      `json:"type"`
	Command        string        `json:"command"`
	StartAt        jsontime.Time `json:"startAt"`
	IntervalValue  int           `json:"intervalValue"`
	IntervalUnit   Unit          `json:"intervalUnit"`
	Variables      []Variable    `json:"variables"`
	Enabled        bool          `json:"enabled"`
	Script         *string       `json:"script"`
	TimeoutSeconds *int          `json:"timeoutSeconds"`
}

type taskWire struct {
	ID              string          `json:"id"`
	Name            string          `json:"name"`
	Type            TaskType        `json:"type"`
	Command         string          `json:"command"`
	StartAt         jsontime.Time   `json:"startAt"`
	IntervalValue   *int            `json:"intervalValue"`
	IntervalMinutes *int            `json:"intervalMinutes"`
	IntervalUnit    Unit            `json:"intervalUnit"`
	Variables       json.RawMessage `json:"variables"`
	Enabled         *bool           `json:"enabled"`
	Script          *string         `json:"script"`
	TimeoutSeconds  *int            `json:"timeoutSeconds"`
}

// UnmarshalJSON accepts the old variable map, intervalMinutes and a missing
// enabled flag.
func (t *Task) UnmarshalJSON(data []byte) error {
	var wire taskWire
	if err := json.Unmarshal(data, &wire); err != nil {
		return err
	}
	if wire.ID == "" || wire.Name == "" || wire.StartAt.IsZero() {
		return fmt.Errorf("scheduler: task is missing id, name or startAt")
	}
	t.ID = wire.ID
	t.Name = wire.Name
	t.Type = wire.Type
	if t.Type != TypeJS {
		t.Type = TypeTerminal
	}
	t.Command = wire.Command
	t.StartAt = wire.StartAt
	interval := 5
	if wire.IntervalValue != nil {
		interval = *wire.IntervalValue
	} else if wire.IntervalMinutes != nil {
		interval = *wire.IntervalMinutes
	}
	if interval < 1 {
		interval = 1
	}
	t.IntervalValue = interval
	t.IntervalUnit = wire.IntervalUnit
	switch t.IntervalUnit {
	case UnitSecond, UnitMinute, UnitHour, UnitDay, UnitWeek, UnitMonth:
	default:
		t.IntervalUnit = UnitMinute
	}
	t.Variables = parseVariables(wire.Variables)
	t.Enabled = true
	if wire.Enabled != nil {
		t.Enabled = *wire.Enabled
	}
	t.Script = wire.Script
	t.TimeoutSeconds = wire.TimeoutSeconds
	return nil
}

// RuntimeVariables returns the variables as a map for substitution.
func (t Task) RuntimeVariables() map[string]any {
	values := make(map[string]any, len(t.Variables))
	for _, variable := range t.Variables {
		values[variable.Name] = variable.Value
	}
	return values
}

func parseVariables(raw json.RawMessage) []Variable {
	if len(raw) == 0 {
		return nil
	}
	var list []Variable
	if err := json.Unmarshal(raw, &list); err == nil {
		return list
	}
	var object map[string]any
	if err := json.Unmarshal(raw, &object); err == nil {
		variables := make([]Variable, 0, len(object))
		for name, value := range object {
			variables = append(variables, Variable{
				Name:  name,
				Type:  "string",
				Value: stringify(value),
			})
		}
		return variables
	}
	return nil
}

func stringify(value any) string {
	if value == nil {
		return ""
	}
	if text, ok := value.(string); ok {
		return text
	}
	data, err := json.Marshal(value)
	if err != nil {
		return ""
	}
	return string(data)
}
