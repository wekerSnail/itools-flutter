// Package json_formatter formats, minifies, escapes and repairs JSON text.
package json_formatter

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"
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

// Issue is where a JSON document stops being valid.
type Issue struct {
	// Start and End are the bytes to mark, End after the character at
	// fault, which is a whole rune.
	Start, End int
	// Line and Col are the 1-based position of Start, Col counted in
	// bytes as the editor's Pos does.
	Line, Col int
	// Message says what is wrong, in Chinese where the case is known.
	Message string
}

// Locate reports the first error of input, at the byte it is about. A
// document that merely ends too early is marked at the quote or bracket
// left open, which is where the missing part belongs.
func Locate(input string) (Issue, bool) {
	if input == "" || IsValid(input) {
		return Issue{}, false
	}
	// The decoder validates the whole text before it builds a value, so a
	// broken document costs a scan rather than a tree of values; only a
	// document that parses would be built, and that one was already valid.
	var value any
	err := json.Unmarshal(unsafeBytes(input), &value)
	offset, message := 0, "无效的JSON格式"
	var syntax *json.SyntaxError
	if errors.As(err, &syntax) {
		offset, message = int(syntax.Offset), syntax.Error()
	} else if err != nil {
		message = err.Error()
	}
	if message == "unexpected end of JSON input" {
		// The text ran out: the decoder reports no byte for that, so the
		// construct still open is marked instead. An offset one past the
		// last byte, as a trailing comma also reports, is still a byte.
		if start, what, ok := unclosedConstruct(input); ok {
			return issueAt(input, start, "JSON 内容不完整："+what), true
		}
		return issueAt(input, max(offset-1, 0), "JSON 内容不完整：意外结束"), true
	}
	return issueAt(input, max(offset-1, 0), localizeMessage(message)), true
}

// issueAt marks the rune at start, with the 1-based position of start.
func issueAt(input string, start int, message string) Issue {
	start = max(0, min(start, len(input)-1))
	end := start + 1
	if _, size := utf8.DecodeRuneInString(input[start:]); size > 1 {
		end = start + size
	}
	line, col := lineCol(input, start)
	return Issue{Start: start, End: end, Line: line, Col: col, Message: message}
}

// lineCol returns the 1-based line and byte column of offset.
func lineCol(input string, offset int) (line, col int) {
	line, start := 1, 0
	for i := 0; i < offset && i < len(input); i++ {
		if input[i] == '\n' {
			line++
			start = i + 1
		}
	}
	return line, offset - start + 1
}

// unclosedConstruct returns what a text that ends too early left open:
// the string whose closing quote is missing, or the innermost object or
// array whose closing bracket is.
func unclosedConstruct(input string) (int, string, bool) {
	stack := make([]int, 0, 16)
	inString, stringStart, escaped := false, -1, false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			escaped = false
			continue
		}
		if inString && ch == '\\' {
			escaped = true
			continue
		}
		if ch == '"' {
			inString = !inString
			if inString {
				stringStart = i
			} else {
				stringStart = -1
			}
			continue
		}
		if inString {
			continue
		}
		switch ch {
		case '{', '[':
			stack = append(stack, i)
		case '}', ']':
			if n := len(stack); n > 0 {
				open := input[stack[n-1]]
				if open == '{' && ch == '}' || open == '[' && ch == ']' {
					stack = stack[:n-1]
				}
			}
		}
	}
	if inString && stringStart >= 0 {
		return stringStart, "字符串缺少结束引号", true
	}
	if n := len(stack); n > 0 {
		start := stack[n-1]
		if input[start] == '{' {
			return start, "对象没有闭合，缺少 }", true
		}
		return start, "数组没有闭合，缺少 ]", true
	}
	return 0, "", false
}

// localizeMessage turns the decoder's message into Chinese for the cases
// a hand-edited payload usually hits, and keeps it as it is otherwise.
func localizeMessage(message string) string {
	const prefix = "invalid character "
	if !strings.HasPrefix(message, prefix) {
		if message == "unexpected end of JSON input" {
			return "JSON 内容不完整：意外结束"
		}
		return message
	}
	rest := message[len(prefix):]
	char, reason := rest, ""
	if strings.HasPrefix(rest, "'") {
		if j := strings.IndexByte(rest[1:], '\''); j >= 0 {
			char = rest[:j+2]
			reason = strings.TrimSpace(rest[j+2:])
		}
	}
	phrases := []struct{ prefix, text string }{
		{"looking for beginning of object key string", "此处应为用双引号括起来的键"},
		{"looking for beginning of value", "此处应为值"},
		{"after object key:value pair", "此处缺少逗号，或值后有多余字符"},
		{"after object key", "键后缺少值"},
		{"after array element", "此处缺少逗号，或元素后有多余字符"},
		{"after top-level value", "顶层内容之后还有多余字符"},
		{"in string", "字符串中出现非法字符"},
		{"in literal", "字面量写错了"},
		{"in numeric literal", "数字格式错误"},
		{"after decimal point", "数字格式错误"},
		{"in exponent", "数字格式错误"},
	}
	for _, p := range phrases {
		if strings.HasPrefix(reason, p.prefix) {
			return p.text + "（出现 " + char + "）"
		}
	}
	return message
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

	repaired := closeUnterminatedStrings(trimmed)
	repaired = replaceSingleQuotes(repaired)
	repaired = quoteUnquotedKeys(repaired)
	repaired = removeTrailingCommas(repaired)
	repaired = insertMissingCommas(repaired)
	repaired = balanceBrackets(repaired)
	if IsValid(repaired) {
		return repaired, true
	}
	if truncated, ok := truncateAtLastValid(repaired, budget); ok {
		return truncated, true
	}
	return "", false
}

// closeUnterminatedStrings closes a string that runs past the end of its
// line. A raw line break inside a JSON string is always an error, and a
// payload that lost a closing quote continues on the next line with the
// next member, so the string is closed right before the break: escaping
// the break instead would swallow that member into the value. It runs
// first, because every later pass tracks string boundaries to stay out
// of them, and a string that never closes leaves them all guessing.
func closeUnterminatedStrings(input string) string {
	var buffer strings.Builder
	buffer.Grow(len(input) + 16)
	inString := false
	escaped := false
	changed := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			escaped = false
			if inString && isLineBreak(ch) {
				// A line that ends in a lone backslash: drop the dangling
				// escape and close the string, keeping the break.
				buffer.WriteByte('"')
				inString = false
				changed = true
			} else {
				buffer.WriteByte('\\')
			}
			buffer.WriteByte(ch)
			continue
		}
		if ch == '\\' {
			// Held back, so a backslash that only escapes the line break
			// can be dropped instead of written.
			escaped = true
			continue
		}
		if ch == '"' {
			inString = !inString
			buffer.WriteByte(ch)
			continue
		}
		if inString && isLineBreak(ch) {
			buffer.WriteByte('"')
			inString = false
			changed = true
		}
		buffer.WriteByte(ch)
	}
	if escaped {
		buffer.WriteByte('\\')
	}
	if !changed {
		return input
	}
	return buffer.String()
}

func isLineBreak(ch byte) bool {
	return ch == '\n' || ch == '\r'
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

// insertMissingCommas adds the commas left out between two members or
// elements, as a hand-edited or patched payload often does: a value line
// followed by the next key with no comma between them. It must run
// before balanceBrackets, which closes the containers, and it is what
// repairs such a document at all: cutting back to the last complete
// value cannot help, because every cut point after the missing comma
// still contains the break.
func insertMissingCommas(input string) string {
	var buffer strings.Builder
	buffer.Grow(len(input) + len(input)/16)
	stack := make([]byte, 0, 16)
	inString := false
	escaped := false
	// needComma is set once a value is complete: the next key, element
	// or object without a comma in between is where one is missing.
	needComma := false
	changed := false
	// Whitespace is held back until the next token, so an inserted comma
	// ends the value's line instead of opening the next one.
	pending := ""
	flush := func() {
		buffer.WriteString(pending)
		pending = ""
	}
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if escaped {
			flush()
			buffer.WriteByte(ch)
			escaped = false
			continue
		}
		if ch == '\\' {
			flush()
			buffer.WriteByte(ch)
			escaped = true
			continue
		}
		if inString {
			buffer.WriteByte(ch)
			if ch == '"' {
				inString = false
				needComma = true
			}
			continue
		}
		if isSpace(ch) {
			start := i
			for i+1 < len(input) && isSpace(input[i+1]) {
				i++
			}
			pending = input[start : i+1]
			continue
		}
		if needComma && len(stack) > 0 && startsValue(ch) {
			buffer.WriteByte(',')
			changed = true
			needComma = false
		}
		flush()
		switch ch {
		case '"':
			inString = true
			needComma = false
			buffer.WriteByte(ch)
		case '{', '[':
			stack = append(stack, ch)
			needComma = false
			buffer.WriteByte(ch)
		case '}':
			if len(stack) > 0 && stack[len(stack)-1] == '{' {
				stack = stack[:len(stack)-1]
			}
			needComma = true
			buffer.WriteByte(ch)
		case ']':
			if len(stack) > 0 && stack[len(stack)-1] == '[' {
				stack = stack[:len(stack)-1]
			}
			needComma = true
			buffer.WriteByte(ch)
		case ',', ':':
			// The separator is there, so nothing is missing here. A
			// comma also means the value before it is complete.
			needComma = false
			buffer.WriteByte(ch)
		default:
			if !isValueChar(ch) {
				// Nothing a comma could separate: keep the byte as is.
				buffer.WriteByte(ch)
				needComma = false
				continue
			}
			// A number or literal: copy the whole run, since only its
			// end starts a new token that a comma would have to precede.
			j := i
			for j < len(input) && isValueChar(input[j]) {
				j++
			}
			buffer.WriteString(input[i:j])
			i = j - 1
			needComma = true
		}
	}
	flush()
	if !changed {
		return input
	}
	return buffer.String()
}

// startsValue reports whether ch can begin a key, element or value.
func startsValue(ch byte) bool {
	return ch == '"' || ch == '{' || ch == '[' || ch == '-' ||
		(ch >= '0' && ch <= '9') || isIdentStart(ch)
}

// isValueChar reports whether ch belongs to a number or literal run.
func isValueChar(ch byte) bool {
	return isIdentChar(ch) || ch == '.' || ch == '+' || ch == '-'
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
