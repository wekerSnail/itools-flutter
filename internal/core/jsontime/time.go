// Package jsontime reads and writes the timestamp format the Flutter app used.
package jsontime

import (
	"encoding/json"
	"time"
)

const layout = "2006-01-02T15:04:05.000"

// Time is a time.Time that marshals with millisecond precision and no zone,
// as Dart's DateTime.toIso8601String does.
type Time struct {
	time.Time
}

// Now returns the current local time.
func Now() Time {
	return Time{Time: time.Now()}
}

// From converts a time.Time.
func From(t time.Time) Time {
	return Time{Time: t}
}

// MarshalJSON writes "2006-01-02T15:04:05.000".
func (t Time) MarshalJSON() ([]byte, error) {
	return json.Marshal(t.Time.Format(layout))
}

// UnmarshalJSON accepts the Dart format, RFC 3339 and a date without
// milliseconds.
func (t *Time) UnmarshalJSON(data []byte) error {
	var raw string
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	return t.parse(raw)
}

func (t *Time) parse(raw string) error {
	layouts := []string{
		layout,
		"2006-01-02T15:04:05",
		time.RFC3339Nano,
		time.RFC3339,
	}
	var lastErr error
	for _, candidate := range layouts {
		parsed, err := time.ParseInLocation(candidate, raw, time.Local)
		if err == nil {
			t.Time = parsed
			return nil
		}
		lastErr = err
	}
	return lastErr
}
