package scheduler

import (
	"encoding/json"
	"strings"
)

// applyCmdVariables substitutes {{key}} with a cmd-safe quoted literal.
func applyCmdVariables(command string, variables map[string]any) string {
	result := command
	for name, value := range variables {
		replacement := escapeCmdLiteral(stringify(value))
		result = strings.ReplaceAll(result, `"{{`+name+`}}"`, replacement)
		result = strings.ReplaceAll(result, "{{"+name+"}}", replacement)
	}
	return result
}

// escapeCmdLiteral escapes a value for a batch file body and quotes it.
func escapeCmdLiteral(raw string) string {
	cleaned := strings.NewReplacer("\r", " ", "\n", " ", "\x00", " ").Replace(raw)
	cleaned = strings.ReplaceAll(cleaned, "%", "%%")
	cleaned = strings.ReplaceAll(cleaned, `"`, `""`)
	cleaned = strings.ReplaceAll(cleaned, "!", "^!")
	return `"` + cleaned + `"`
}

func marshalVariable(value any) string {
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
