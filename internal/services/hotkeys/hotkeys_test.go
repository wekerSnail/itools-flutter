package hotkeys

import (
	"testing"

	"github.com/egoist/mygo/ui"
)

func TestAccelerator(t *testing.T) {
	tests := []struct {
		modifiers []string
		key       string
		want      string
	}{
		{[]string{"ctrl", "shift"}, "J", "Ctrl+Shift+J"},
		{[]string{"alt"}, "Space", "Alt+Space"},
		{[]string{"meta"}, "F5", "Super+F5"},
		{[]string{"ctrl"}, "1", "Ctrl+1"},
		{[]string{"ctrl"}, ",", "Ctrl+,"},
		{[]string{"ctrl"}, "???", ""},
		{[]string{"ctrl"}, "", ""},
	}
	for _, test := range tests {
		if got := Accelerator(test.modifiers, test.key); got != test.want {
			t.Errorf("Accelerator(%v, %q) = %q, want %q", test.modifiers, test.key, got, test.want)
		}
	}
}

func TestSignatureIgnoresOrder(t *testing.T) {
	keyID := 461
	a := Config{Modifiers: []string{"Shift", "Ctrl"}, Key: "J", KeyID: &keyID}
	b := Config{Modifiers: []string{"ctrl", "shift"}, Key: "X", KeyID: &keyID}
	if Signature(a) != Signature(b) {
		t.Fatalf("signatures differ: %q vs %q", Signature(a), Signature(b))
	}
}

func TestParseConfigs(t *testing.T) {
	data := []byte(`[
		{"actionId":"open_main_window","enabled":true,"modifiers":["ctrl"],"key":"1"},
		{"bad":true},
		{"actionId":"open_scheduler","enabled":true,"modifiers":["alt"],"key":"S"}
	]`)
	configs := parseConfigs(data)
	if len(configs) != 2 {
		t.Fatalf("configs = %d, want 2", len(configs))
	}
	if configs[0].ActionID != "open_main_window" || configs[1].ActionID != "open_scheduler" {
		t.Fatalf("configs = %+v", configs)
	}
}

func TestParseConfigsCorrupted(t *testing.T) {
	if configs := parseConfigs([]byte(`{not json`)); configs != nil {
		t.Fatalf("configs = %+v, want nil", configs)
	}
}

func TestFromInput(t *testing.T) {
	config, ok := FromInput(ui.InputEvent{
		Kind: ui.InputKeyDown,
		Key:  ui.KeyJ,
		Mods: ui.Ctrl | ui.Shift,
	})
	if !ok {
		t.Fatal("FromInput rejected a valid combination")
	}
	if config.Key != "J" || config.Accelerator != "Ctrl+Shift+J" {
		t.Fatalf("config = %+v", config)
	}
	if _, ok := FromInput(ui.InputEvent{Kind: ui.InputKeyDown, Key: ui.KeyJ}); ok {
		t.Fatal("FromInput accepted a key without modifiers")
	}
	if _, ok := FromInput(ui.InputEvent{Kind: ui.InputKeyUp, Key: ui.KeyJ, Mods: ui.Ctrl}); ok {
		t.Fatal("FromInput accepted a key up event")
	}
}

func TestDisplay(t *testing.T) {
	config := Config{Modifiers: []string{"ctrl", "shift"}, Key: "J"}
	if got := Display(config); got != "Ctrl + Shift + J" {
		t.Fatalf("Display = %q", got)
	}
	if got := Display(Config{}); got != "未设置" {
		t.Fatalf("Display empty = %q", got)
	}
}
