// Package json_formatter formats, minifies, escapes and repairs JSON text.
package json_formatter

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strconv"
	"strings"
)

// Format formats valid JSON with the given indentation, keeping key order.
func Format(input string, indent int) (string, error) {
	value, err := parseOrdered(input)
	if err != nil {
		return "", fmt.Errorf("无效的JSON格式: %w", err)
	}
	if indent < 0 {
		indent = 0
	}
	var builder strings.Builder
	writeOrdered(&builder, value, 0, indent, false)
	return builder.String(), nil
}

// Minify removes insignificant whitespace, keeping key order.
func Minify(input string) (string, error) {
	value, err := parseOrdered(input)
	if err != nil {
		return "", fmt.Errorf("无效的JSON格式: %w", err)
	}
	var builder strings.Builder
	writeOrdered(&builder, value, 0, 0, true)
	return builder.String(), nil
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
	return json.Valid([]byte(input))
}

// ErrorMessage returns the validation error, or "" when input is valid.
func ErrorMessage(input string) string {
	var value any
	if err := json.Unmarshal([]byte(input), &value); err != nil {
		return "无效的JSON格式: " + err.Error()
	}
	return ""
}

// SmartRepair tries the same repairs the Flutter version tried, in order.
func SmartRepair(input string) (string, bool) {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" {
		return "", false
	}
	if IsValid(trimmed) {
		return trimmed, true
	}

	repaired := trimmed
	repaired = replaceSingleQuotes(repaired)
	if IsValid(repaired) {
		return repaired, true
	}
	repaired = quoteUnquotedKeys(repaired)
	if IsValid(repaired) {
		return repaired, true
	}
	repaired = removeTrailingCommas(repaired)
	if IsValid(repaired) {
		return repaired, true
	}
	repaired = balanceBrackets(repaired)
	if IsValid(repaired) {
		return repaired, true
	}

	combined := trimmed
	combined = replaceSingleQuotes(combined)
	combined = quoteUnquotedKeys(combined)
	combined = removeTrailingCommas(combined)
	combined = balanceBrackets(combined)
	if IsValid(combined) {
		return combined, true
	}

	if truncated, ok := truncateAtLastValid(combined); ok && IsValid(truncated) {
		return truncated, true
	}
	return "", false
}

func replaceSingleQuotes(input string) string {
	var buffer strings.Builder
	inDouble := false
	escaped := false
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
			j := i + 1
			for j < len(input) && input[j] != '\'' {
				if input[j] == '\\' {
					j++
				}
				j++
			}
			buffer.WriteByte('"')
			if j <= len(input) {
				buffer.WriteString(input[i+1 : min(j, len(input))])
			}
			buffer.WriteByte('"')
			i = j
			continue
		}
		buffer.WriteByte(ch)
	}
	return buffer.String()
}

func quoteUnquotedKeys(input string) string {
	var buffer strings.Builder
	inDouble := false
	escaped := false
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
				buffer.WriteByte('"')
				buffer.WriteString(input[i:j])
				buffer.WriteByte('"')
				i = j - 1
			} else {
				buffer.WriteString(input[i:j])
				i = j - 1
			}
			continue
		}
		buffer.WriteByte(ch)
	}
	return buffer.String()
}

func removeTrailingCommas(input string) string {
	var buffer strings.Builder
	inString := false
	escaped := false
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
				continue
			}
		}
		buffer.WriteByte(ch)
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
	result := strings.TrimRight(input, " \t\r\n")
	if strings.HasSuffix(result, ",") {
		result = result[:len(result)-1]
	}
	var closing strings.Builder
	for i := len(stack) - 1; i >= 0; i-- {
		if stack[i] == '{' {
			closing.WriteByte('}')
		} else {
			closing.WriteByte(']')
		}
	}
	return result + closing.String()
}

func truncateAtLastValid(input string) (string, bool) {
	for i := len(input) - 1; i >= 0; i-- {
		switch input[i] {
		case ',', ':', '"', '}', ']':
			candidate := balanceBrackets(input[:i+1])
			if IsValid(candidate) {
				return candidate, true
			}
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

type orderedKind int

const (
	kindNull orderedKind = iota
	kindBool
	kindNumber
	kindString
	kindArray
	kindObject
)

type orderedPair struct {
	key   string
	value orderedValue
}

type orderedValue struct {
	kind        orderedKind
	boolValue   bool
	numberValue string
	stringValue string
	array       []orderedValue
	object      []orderedPair
}

func parseOrdered(input string) (orderedValue, error) {
	decoder := json.NewDecoder(strings.NewReader(input))
	decoder.UseNumber()
	value, err := parseOrderedValue(decoder)
	if err != nil {
		return orderedValue{}, err
	}
	if _, err := decoder.Token(); err != io.EOF {
		if err == nil {
			return orderedValue{}, fmt.Errorf("unexpected trailing data")
		}
		return orderedValue{}, err
	}
	return value, nil
}

func parseOrderedValue(decoder *json.Decoder) (orderedValue, error) {
	token, err := decoder.Token()
	if err != nil {
		return orderedValue{}, err
	}
	switch typed := token.(type) {
	case json.Delim:
		switch typed {
		case '{':
			return parseOrderedObject(decoder)
		case '[':
			return parseOrderedArray(decoder)
		default:
			return orderedValue{}, fmt.Errorf("unexpected delimiter %q", typed)
		}
	case string:
		return orderedValue{kind: kindString, stringValue: typed}, nil
	case json.Number:
		return orderedValue{kind: kindNumber, numberValue: typed.String()}, nil
	case bool:
		return orderedValue{kind: kindBool, boolValue: typed}, nil
	case nil:
		return orderedValue{kind: kindNull}, nil
	default:
		return orderedValue{}, fmt.Errorf("unexpected token %v", token)
	}
}

func parseOrderedObject(decoder *json.Decoder) (orderedValue, error) {
	pairs := make([]orderedPair, 0, 8)
	for decoder.More() {
		token, err := decoder.Token()
		if err != nil {
			return orderedValue{}, err
		}
		key, ok := token.(string)
		if !ok {
			return orderedValue{}, fmt.Errorf("object key is not a string")
		}
		value, err := parseOrderedValue(decoder)
		if err != nil {
			return orderedValue{}, err
		}
		pairs = append(pairs, orderedPair{key: key, value: value})
	}
	end, err := decoder.Token()
	if err != nil {
		return orderedValue{}, err
	}
	if delimiter, ok := end.(json.Delim); !ok || delimiter != '}' {
		return orderedValue{}, fmt.Errorf("unterminated object")
	}
	return orderedValue{kind: kindObject, object: pairs}, nil
}

func parseOrderedArray(decoder *json.Decoder) (orderedValue, error) {
	items := make([]orderedValue, 0, 8)
	for decoder.More() {
		value, err := parseOrderedValue(decoder)
		if err != nil {
			return orderedValue{}, err
		}
		items = append(items, value)
	}
	end, err := decoder.Token()
	if err != nil {
		return orderedValue{}, err
	}
	if delimiter, ok := end.(json.Delim); !ok || delimiter != ']' {
		return orderedValue{}, fmt.Errorf("unterminated array")
	}
	return orderedValue{kind: kindArray, array: items}, nil
}

func writeOrdered(builder *strings.Builder, value orderedValue, depth, indent int, minify bool) {
	switch value.kind {
	case kindNull:
		builder.WriteString("null")
	case kindBool:
		if value.boolValue {
			builder.WriteString("true")
		} else {
			builder.WriteString("false")
		}
	case kindNumber:
		builder.WriteString(value.numberValue)
	case kindString:
		builder.WriteString(encodeJSONString(value.stringValue))
	case kindArray:
		if len(value.array) == 0 {
			builder.WriteString("[]")
			return
		}
		builder.WriteByte('[')
		if !minify {
			builder.WriteByte('\n')
		}
		for index, item := range value.array {
			if !minify {
				writeIndent(builder, depth+1, indent)
			}
			writeOrdered(builder, item, depth+1, indent, minify)
			if index != len(value.array)-1 {
				builder.WriteByte(',')
			}
			if !minify {
				builder.WriteByte('\n')
			}
		}
		if !minify {
			writeIndent(builder, depth, indent)
		}
		builder.WriteByte(']')
	case kindObject:
		if len(value.object) == 0 {
			builder.WriteString("{}")
			return
		}
		builder.WriteByte('{')
		if !minify {
			builder.WriteByte('\n')
		}
		for index, pair := range value.object {
			if !minify {
				writeIndent(builder, depth+1, indent)
			}
			builder.WriteString(encodeJSONString(pair.key))
			if minify {
				builder.WriteByte(':')
			} else {
				builder.WriteString(": ")
			}
			writeOrdered(builder, pair.value, depth+1, indent, minify)
			if index != len(value.object)-1 {
				builder.WriteByte(',')
			}
			if !minify {
				builder.WriteByte('\n')
			}
		}
		if !minify {
			writeIndent(builder, depth, indent)
		}
		builder.WriteByte('}')
	}
}

func writeIndent(builder *strings.Builder, depth, indent int) {
	for i := 0; i < depth*indent; i++ {
		builder.WriteByte(' ')
	}
}

func encodeJSONString(value string) string {
	var buffer bytes.Buffer
	encoder := json.NewEncoder(&buffer)
	encoder.SetEscapeHTML(false)
	if err := encoder.Encode(value); err != nil {
		return `""`
	}
	return strings.TrimSuffix(buffer.String(), "\n")
}
