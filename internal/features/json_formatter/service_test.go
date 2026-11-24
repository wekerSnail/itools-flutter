package json_formatter

import (
	"strings"
	"testing"
)

func TestFormatPreservesKeyOrder(t *testing.T) {
	got, err := Format(`{"b":1,"a":2}`, 2)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Index(got, `"b"`) > strings.Index(got, `"a"`) {
		t.Fatalf("keys were reordered:\n%s", got)
	}
	if !strings.Contains(got, "\n  \"b\": 1") {
		t.Fatalf("not indented with two spaces:\n%s", got)
	}
}

func TestFormatKeepsLargeIntegers(t *testing.T) {
	got, err := Format(`{"n":9007199254740993}`, 2)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, "9007199254740993") {
		t.Fatalf("large integer changed:\n%s", got)
	}
}

func TestMinify(t *testing.T) {
	got, err := Minify("{\n  \"a\": 1,\n  \"b\": [1, 2]\n}")
	if err != nil {
		t.Fatal(err)
	}
	if got != `{"a":1,"b":[1,2]}` {
		t.Fatalf("minify = %q", got)
	}
}

func TestFormatRejectsInvalid(t *testing.T) {
	if _, err := Format(`{"a":}`, 2); err == nil {
		t.Fatal("expected an error")
	}
}

func TestEscapeUnescape(t *testing.T) {
	input := "line1\nline2\t\"quoted\"\\"
	escaped := Escape(input)
	if !strings.Contains(escaped, `\n`) || !strings.Contains(escaped, `\"`) {
		t.Fatalf("escaped = %q", escaped)
	}
	if got := Unescape(escaped); got != input {
		t.Fatalf("unescape = %q, want %q", got, input)
	}
}

func TestSmartRepair(t *testing.T) {
	tests := []struct {
		input string
		want  string
		ok    bool
	}{
		{`{name: 'John', age: 30,}`, `{"name": "John", "age": 30}`, true},
		{`{"a":1,`, `{"a":1}`, true},
		{`{"a":1,"b":2,}`, `{"a":1,"b":2}`, true},
		{`not json at all`, "", false},
		{`{"ok":true}`, `{"ok":true}`, true},
	}
	for _, test := range tests {
		got, ok := SmartRepair(test.input)
		if ok != test.ok {
			t.Errorf("SmartRepair(%q) ok = %v, want %v", test.input, ok, test.ok)
			continue
		}
		if ok && got != test.want {
			t.Errorf("SmartRepair(%q) = %q, want %q", test.input, got, test.want)
		}
	}
}

func TestErrorMessage(t *testing.T) {
	if got := ErrorMessage(`{"a":}`); !strings.Contains(got, "无效的JSON格式") {
		t.Fatalf("message = %q", got)
	}
	if got := ErrorMessage(`{"a":1}`); got != "" {
		t.Fatalf("valid message = %q", got)
	}
}
