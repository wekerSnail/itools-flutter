// Package json_formatter formats, minifies, escapes and repairs JSON text.
package json_formatter

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unsafe"
)

// Format formats valid JSON with the given indentation, keeping key order.
// The standard library's indenter scans once and copies strings and
// numbers as written, so a large document is not turned into a tree of
// values first.
func Format(input string, indent int) (string, error) {
	if indent < 0 {
		indent = 0
	}
	var buffer bytes.Buffer
	// Indented JSON is about three times the minified text, and growing
	// once here keeps json.Indent from reallocating its output.
	buffer.Grow(3 * len(input))
	if err := json.Indent(&buffer, unsafeBytes(input), "", strings.Repeat(" ", indent)); err != nil {
		return "", fmt.Errorf("无效的JSON格式: %w", err)
	}
	return buffer.String(), nil
}

// Minify removes insignificant whitespace, keeping key order.
func Minify(input string) (string, error) {
	var buffer bytes.Buffer
	if err := json.Compact(&buffer, unsafeBytes(input)); err != nil {
		return "", fmt.Errorf("无效的JSON格式: %w", err)
	}
	return buffer.String(), nil
}

// unsafeBytes returns s's bytes to the JSON scanners, which only read
// them. It spares a large document a full copy just to be parsed.
func unsafeBytes(s string) []byte {
	if s == "" {
		return nil
	}
	return unsafe.Slice(unsafe.StringData(s), len(s))
}

// Escape escapes a string for embedding in JSON.
func Escape(input string) string {
	var buffer strings.Builder
	for _, r := range input {
		switch r {
		case '"':
			buffer.WriteString(`\"`)
		case '\\':
			buffer.WriteString(`\\`)
		case '\n':
			buffer.WriteString(`\n`)
		case '\r':
			buffer.WriteString(`\r`)
		case '\t':
			buffer.WriteString(`\t`)
		case '\b':
			buffer.WriteString(`\b`)
		case '\f':
			buffer.WriteString(`\f`)
		default:
			if r < 0x20 {
				buffer.WriteString(fmt.Sprintf(`\u%04x`, r))
			} else {
				buffer.WriteRune(r)
			}
		}
	}
	return buffer.String()
}

// Unescape restores JSON escape sequences.
func Unescape(input string) string {
	var buffer strings.Builder
	for i := 0; i < len(input); {
		if input[i] != '\\' || i+1 >= len(input) {
			buffer.WriteByte(input[i])
			i++
			continue
		}
		switch input[i+1] {
		case '"':
			buffer.WriteByte('"')
			i += 2
		case '\\':
			buffer.WriteByte('\\')
			i += 2
		case 'n':
			buffer.WriteByte('\n')
			i += 2
		case 'r':
			buffer.WriteByte('\r')
			i += 2
		case 't':
			buffer.WriteByte('\t')
			i += 2
		case 'b':
			buffer.WriteByte('\b')
			i += 2
		case 'f':
			buffer.WriteByte('\f')
			i += 2
		case 'u':
			if i+5 < len(input) {
				value, err := strconv.ParseUint(input[i+2:i+6], 16, 32)
				if err == nil {
					buffer.WriteRune(rune(value))
					i += 6
					continue
				}
			}
			buffer.WriteByte(input[i])
			i++
		default:
			buffer.WriteByte(input[i])
			i++
		}
	}
	return buffer.String()
}

// IsValid reports whether input is valid JSON.
func IsValid(input string) bool {
	return json.Valid(unsafeBytes(input))
}

// Check reports whether input is valid JSON and, when it is not, why. A
// document that fails is scanned again only up to the first error, so a
// large broken one is not turned into a tree of values to be rejected.
func Check(input string) (bool, string) {
	if IsValid(input) {
		return true, ""
	}
	return false, ErrorMessage(input)
}

// ErrorMessage returns the validation error, or "" when input is valid.
func ErrorMessage(input string) string {
	decoder := json.NewDecoder(strings.NewReader(input))
	for {
		if _, err := decoder.Token(); err != nil {
			if err == io.EOF {
				return ""
			}
			return "无效的JSON格式: " + err.Error()
		}
	}
}

// LineProperty is the JSON property of one formatted line, for the
// context menu's copy actions.
type LineProperty struct {
	Name     string
	Value    string
	HasName  bool
	HasValue bool
}

// ParseLineProperty reads the "key": value pair of one formatted JSON
// line, as the Flutter version's context menu did: a line whose key is
// not a quoted string holds no property at all.
func ParseLineProperty(line string) LineProperty {
	trimmed := strings.TrimRight(line, " \t\r\n")
	if trimmed == "" {
		return LineProperty{}
	}
	colon := strings.IndexByte(trimmed, ':')
	if colon < 0 {
		return LineProperty{}
	}
	keyPart := strings.TrimSpace(trimmed[:colon])
	valuePart := strings.TrimSpace(trimmed[colon+1:])
	if len(keyPart) < 2 || keyPart[0] != '"' || keyPart[len(keyPart)-1] != '"' {
		return LineProperty{}
	}
	prop := LineProperty{Name: keyPart[1 : len(keyPart)-1], HasName: true}
	if valuePart != "" {
		if value, ok := extractLineValue(valuePart); ok {
			prop.Value, prop.HasValue = value, true
		}
	}
	return prop
}

// extractLineValue reads the single value at the head of s, dropping a
// trailing comma.
func extractLineValue(s string) (string, bool) {
	trimmed := strings.TrimRight(s, " \t\r\n")
	if trimmed == "" {
		return "", false
	}
	if trimmed[len(trimmed)-1] == ',' {
		trimmed = strings.TrimRight(trimmed[:len(trimmed)-1], " \t\r\n")
		if trimmed == "" {
			return "", false
		}
	}
	return parseSingleLineValue(trimmed), true
}

// parseSingleLineValue returns the string, number, literal, object or
// array at the head of v.
func parseSingleLineValue(v string) string {
	if v == "" {
		return ""
	}
	if v[0] == '"' {
		if end := matchingQuote(v, 0); end > 0 {
			return v[:end+1]
		}
		return v
	}
	if v == "true" || v == "false" || v == "null" {
		return v
	}
	if match := lineNumberPattern.FindString(v); match != "" {
		return match
	}
	if v[0] == '{' {
		if end := matchingBrace(v, 0); end > 0 {
			return v[:end+1]
		}
		return v
	}
	if v[0] == '[' {
		if end := matchingBracket(v, 0); end > 0 {
			return v[:end+1]
		}
		return v
	}
	return v
}

var lineNumberPattern = regexp.MustCompile(`^-?\d+(\.\d+)?([eE][+-]?\d+)?`)

// matchingQuote returns where the string starting at start closes, or -1.
func matchingQuote(text string, start int) int {
	for i := start + 1; i < len(text); i++ {
		if text[i] == '\\' {
			i++
			continue
		}
		if text[i] == '"' {
			return i
		}
	}
	return -1
}

// matchingBrace returns where the object starting at start closes, or -1.
func matchingBrace(text string, start int) int {
	depth := 0
	inString := false
	for i := start; i < len(text); i++ {
		if text[i] == '\\' {
			i++
			continue
		}
		if text[i] == '"' {
			inString = !inString
			continue
		}
		if !inString {
			if text[i] == '{' {
				depth++
			}
			if text[i] == '}' {
				depth--
				if depth == 0 {
					return i
				}
			}
		}
	}
	return -1
}

// matchingBracket returns where the array starting at start closes, or -1.
func matchingBracket(text string, start int) int {
	depth := 0
	inString := false
	for i := start; i < len(text); i++ {
		if text[i] == '\\' {
			i++
			continue
		}
		if text[i] == '"' {
			inString = !inString
			continue
		}
		if !inString {
			if text[i] == '[' {
				depth++
			}
			if text[i] == ']' {
				depth--
				if depth == 0 {
					return i
				}
			}
		}
	}
	return -1
}

// SmartRepair tries the same repairs the Flutter version tried, in order.
// The passes run in sequence and the result is checked once: a valid
// document leaves every later pass alone, so the text of the first pass
// that would have repaired it is what comes out, without re-scanning the
// document after each step.
func SmartRepair(input string) (string, bool) {
	return smartRepair(input, truncateBudget)
}

func smartRepair(input string, budget time.Duration) (string, bool) {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" {
		return "", false
	}
	if IsValid(trimmed) {
		return trimmed, true
	}

	repaired := replaceSingleQuotes(trimmed)
	repaired = quoteUnquotedKeys(repaired)
	repaired = removeTrailingCommas(repaired)
	repaired = balanceBrackets(repaired)
	if IsValid(repaired) {
		return repaired, true
	}
	if truncated, ok := truncateAtLastValid(repaired, budget); ok {
		return truncated, true
	}
	return "", false
}

func replaceSingleQuotes(input string) string {
	var buffer strings.Builder
	buffer.Grow(len(input) + len(input)/8)
	inDouble := false
	escaped := false
	changed := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			buffer.WriteByte(ch)
			escaped = false
			continue
		}
		if ch == '\\' {
			buffer.WriteByte(ch)
			escaped = true
			continue
		}
		if ch == '"' {
			inDouble = !inDouble
			buffer.WriteByte(ch)
			continue
		}
		if ch == '\'' && !inDouble {
			changed = true
			j := i + 1
			for j < len(input) && input[j] != '\'' {
				if input[j] == '\\' {
					j++
				}
				j++
			}
			buffer.WriteByte('"')
			buffer.WriteString(input[i+1 : min(j, len(input))])
			buffer.WriteByte('"')
			i = j
			continue
		}
		buffer.WriteByte(ch)
	}
	if !changed {
		return input
	}
	return buffer.String()
}

func quoteUnquotedKeys(input string) string {
	var buffer strings.Builder
	buffer.Grow(len(input) + len(input)/8)
	inDouble := false
	escaped := false
	changed := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			buffer.WriteByte(ch)
			escaped = false
			continue
		}
		if ch == '\\' {
			buffer.WriteByte(ch)
			escaped = true
			continue
		}
		if ch == '"' {
			inDouble = !inDouble
			buffer.WriteByte(ch)
			continue
		}
		if !inDouble && isIdentStart(ch) {
			j := i
			for j < len(input) && isIdentChar(input[j]) {
				j++
			}
			k := j
			for k < len(input) && (input[k] == ' ' || input[k] == '\t') {
				k++
			}
			if k < len(input) && input[k] == ':' {
				changed = true
				buffer.WriteByte('"')
				buffer.WriteString(input[i:j])
				buffer.WriteByte('"')
			} else {
				buffer.WriteString(input[i:j])
			}
			i = j - 1
			continue
		}
		buffer.WriteByte(ch)
	}
	if !changed {
		return input
	}
	return buffer.String()
}

func removeTrailingCommas(input string) string {
	var buffer strings.Builder
	buffer.Grow(len(input))
	inString := false
	escaped := false
	changed := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			buffer.WriteByte(ch)
			escaped = false
			continue
		}
		if ch == '\\' {
			buffer.WriteByte(ch)
			escaped = true
			continue
		}
		if ch == '"' {
			inString = !inString
			buffer.WriteByte(ch)
			continue
		}
		if !inString && ch == ',' {
			j := i + 1
			for j < len(input) && isSpace(input[j]) {
				j++
			}
			if j < len(input) && (input[j] == '}' || input[j] == ']') {
				changed = true
				continue
			}
		}
		buffer.WriteByte(ch)
	}
	if !changed {
		return input
	}
	return buffer.String()
}

func balanceBrackets(input string) string {
	stack := make([]byte, 0, 16)
	inString := false
	escaped := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			escaped = false
			continue
		}
		if ch == '\\' {
			escaped = true
			continue
		}
		if ch == '"' {
			inString = !inString
			continue
		}
		if inString {
			continue
		}
		switch ch {
		case '{', '[':
			stack = append(stack, ch)
		case '}':
			if len(stack) > 0 && stack[len(stack)-1] == '{' {
				stack = stack[:len(stack)-1]
			}
		case ']':
			if len(stack) > 0 && stack[len(stack)-1] == '[' {
				stack = stack[:len(stack)-1]
			}
		}
	}
	end := len(input)
	for end > 0 && isSpace(input[end-1]) {
		end--
	}
	if end > 0 && input[end-1] == ',' {
		end--
	}
	if len(stack) == 0 && end == len(input) {
		return input
	}
	var buffer strings.Builder
	buffer.Grow(end + len(stack))
	buffer.WriteString(input[:end])
	for i := len(stack) - 1; i >= 0; i-- {
		if stack[i] == '{' {
			buffer.WriteByte('}')
		} else {
			buffer.WriteByte(']')
		}
	}
	return buffer.String()
}

// The fallback below cuts a broken document back to its last complete
// value. Trying every character, as the Flutter version did, costs
// O(n²) on a large truncated document and froze the window; only the
// last few cut points are tried now, within a time budget.
const (
	truncateCandidateCount = 32
	truncateBudget         = 200 * time.Millisecond
	// heavyTruncateBudget is for documents large enough that a single
	// candidate scan outlasts truncateBudget. The work runs in the
	// background, so a longer search costs no frame.
	heavyTruncateBudget = 2 * time.Second
)

func truncateAtLastValid(input string, budget time.Duration) (string, bool) {
	candidates := make([]int, 0, truncateCandidateCount)
	add := func(end int) {
		if len(candidates) == truncateCandidateCount {
			copy(candidates, candidates[1:])
			candidates = candidates[:len(candidates)-1]
		}
		candidates = append(candidates, end)
	}
	inString := false
	escaped := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			escaped = false
			continue
		}
		if ch == '\\' {
			escaped = true
			continue
		}
		if ch == '"' {
			inString = !inString
			if !inString {
				add(i + 1)
			}
			continue
		}
		if inString {
			continue
		}
		switch ch {
		case ',', '}', ']':
			add(i + 1)
		}
	}

	deadline := time.Now().Add(budget)
	for i := len(candidates) - 1; i >= 0; i-- {
		// The newest cut point is always tried, however large the
		// document: cutting back to the last complete value is the common
		// repair, and one pass over it is worth the wait in the
		// background.
		if i != len(candidates)-1 && time.Now().After(deadline) {
			return "", false
		}
		candidate := balanceBrackets(input[:candidates[i]])
		if IsValid(candidate) {
			return candidate, true
		}
	}
	return "", false
}

func isSpace(ch byte) bool {
	return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
}

func isIdentStart(ch byte) bool {
	return ch == '_' || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

func isIdentChar(ch byte) bool {
	return isIdentStart(ch) || (ch >= '0' && ch <= '9')
}
