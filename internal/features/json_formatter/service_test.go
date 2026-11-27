package json_formatter

import (
	"strconv"
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
	if _, err := Format(`{"a":1} x`, 2); err == nil {
		t.Fatal("expected an error for trailing data")
	}
}

func TestFormatKeepsEscapes(t *testing.T) {
	got, err := Format(`{"a":"\u4e2d","b":"a\/b"}`, 2)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(got, `\u4e2d`) || !strings.Contains(got, `a\/b`) {
		t.Fatalf("escapes changed:\n%s", got)
	}
}

func TestCheck(t *testing.T) {
	if valid, message := Check(`{"a":1}`); !valid || message != "" {
		t.Fatalf("Check(valid) = %v, %q", valid, message)
	}
	if valid, message := Check(`{"a":}`); valid || !strings.Contains(message, "无效的JSON格式") {
		t.Fatalf("Check(invalid) = %v, %q", valid, message)
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
		{`{"a":1 "b":2}`, `{"a":1, "b":2}`, true},
		{`[1 2]`, `[1, 2]`, true},
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

// A payload that lost the comma between a value and the next key is the
// case the truncation fallback cannot recover: every cut point after the
// missing comma still holds the break. The comma pass has to repair it
// in place and keep the members on both sides.
func TestSmartRepairMissingComma(t *testing.T) {
	input := `{
  "code": "200",
  "data": [
    {
      "configOptionKey": "1",
      "configOptionValue": "40mmx30mm"
      "id": "5702396381628795494",
      "sortNo": 1
    }
  ],
  "success": true
}`
	repaired, ok := SmartRepair(input)
	if !ok {
		t.Fatal("SmartRepair could not repair a missing comma")
	}
	if !IsValid(repaired) {
		t.Fatalf("repaired JSON is invalid:\n%s", repaired)
	}
	if !strings.Contains(repaired, `"40mmx30mm",`+"\n      \"id\"") {
		t.Fatalf("the comma was not inserted between the two members:\n%s", repaired)
	}
	if !strings.Contains(repaired, `"sortNo": 1`) {
		t.Fatalf("a member after the missing comma was dropped:\n%s", repaired)
	}
}

// A value whose closing quote was lost swallows the line break and the
// member after it, so the string has to be closed at the break: the
// member on the next line is kept, and the missing comma follows it.
func TestSmartRepairUnterminatedString(t *testing.T) {
	input := `{
  "code": "200",
  "data": [
    {
      "configItemCode": "LABEL_PNT_SI
      "configOptionDesc": "40x30",
      "sortNo": 1
    }
  ],
  "success": true
}`
	repaired, ok := SmartRepair(input)
	if !ok {
		t.Fatal("SmartRepair could not repair an unterminated string")
	}
	if !IsValid(repaired) {
		t.Fatalf("repaired JSON is invalid:\n%s", repaired)
	}
	if !strings.Contains(repaired, "\"configItemCode\": \"LABEL_PNT_SI\",\n") {
		t.Fatalf("the string was not closed at the line break:\n%s", repaired)
	}
	if !strings.Contains(repaired, `"configOptionDesc": "40x30"`) ||
		!strings.Contains(repaired, `"sortNo": 1`) {
		t.Fatalf("a member after the break was dropped:\n%s", repaired)
	}

	// A line ending in a lone backslash loses the dangling escape, not
	// the string's last character or the member below it.
	if got, ok := SmartRepair("{\"a\":\"x\\\n\"b\":2}"); !ok || got != "{\"a\":\"x\",\n\"b\":2}" {
		t.Fatalf("dangling escape repaired to %q, %v", got, ok)
	}
}

// A truncated large document must still be repaired, by cutting back to
// the last complete value, and it must not take the quadratic scan over
// every character the old fallback made.
func TestSmartRepairLargeTruncated(t *testing.T) {
	var broken strings.Builder
	broken.WriteByte('[')
	for i := 0; i < 2000; i++ {
		if i > 0 {
			broken.WriteByte(',')
		}
		broken.WriteString(`{"id":`)
		broken.WriteString(strconv.Itoa(i))
		broken.WriteString(`,"name":"item-`)
		broken.WriteString(strconv.Itoa(i))
		broken.WriteString(`"}`)
	}
	broken.WriteString(`,{"id":2000,"name":"`)
	broken.WriteString(strings.Repeat("x", 4096))
	input := broken.String()
	input = input[:len(input)-2048]
	if IsValid(input) {
		t.Fatal("test input is unexpectedly valid")
	}

	repaired, ok := SmartRepair(input)
	if !ok {
		t.Fatal("SmartRepair could not repair a truncated document")
	}
	if !IsValid(repaired) {
		t.Fatalf("repaired JSON is invalid: %.120q", repaired)
	}
	if !strings.HasPrefix(repaired, `[{"id":0,`) {
		t.Fatal("the repair did not keep the document's head")
	}
	if !strings.Contains(repaired, `{"id":1999,"name":"item-1999"}`) {
		t.Fatal("the last complete element was dropped")
	}
}

func TestParseLineProperty(t *testing.T) {
	tests := []struct {
		line     string
		name     string
		value    string
		hasName  bool
		hasValue bool
	}{
		{`"code": "200",`, "code", `"200"`, true, true},
		{`  "discountAmt": 3,`, "discountAmt", `3`, true, true},
		{`"flag": false`, "flag", `false`, true, true},
		{`"n": null,`, "n", `null`, true, true},
		{`"str": "a\"b",`, "str", `"a\"b"`, true, true},
		{`"empty": "",`, "empty", `""`, true, true},
		{`"obj": {"a": 1},`, "obj", `{"a": 1}`, true, true},
		{`"obj": {"a": "}"},`, "obj", `{"a": "}"}`, true, true},
		{`"arr": [1, 2],`, "arr", `[1, 2]`, true, true},
		{`"arr": ["]"],`, "arr", `["]"]`, true, true},
		{`"exp": 1e5,`, "exp", `1e5`, true, true},
		{`"neg": -2.5,`, "neg", `-2.5`, true, true},
		{"\t\"key\": 1", "key", `1`, true, true},
		{`"": 1`, "", `1`, true, true},
		{`"key":,`, "key", "", true, false},
		{`"key":`, "key", "", true, false},
		{`"key": ,`, "key", "", true, false},
		{`{"a": 1}`, "", "", false, false},
		{`foo: 1`, "", "", false, false},
		{`"unterminated: 1`, "", "", false, false},
		{`no colon here`, "", "", false, false},
		{`   `, "", "", false, false},
	}
	for _, test := range tests {
		got := ParseLineProperty(test.line)
		if got.Name != test.name || got.Value != test.value ||
			got.HasName != test.hasName || got.HasValue != test.hasValue {
			t.Errorf("ParseLineProperty(%q) = %+v, want name=%q value=%q hasName=%v hasValue=%v",
				test.line, got, test.name, test.value, test.hasName, test.hasValue)
		}
	}
}
