// Package hotkeys registers the app's global shortcuts and stores their bindings.
package hotkeys

import (
	"encoding/json"
	"log/slog"
	"sort"
	"strconv"
	"strings"
	"sync"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"

	"itools/internal/core/store"
)

const path = "settings/hotkeys.json"

// Config is one action's binding, compatible with the Flutter app's
// settings/hotkeys.json.
type Config struct {
	ActionID    string   `json:"actionId"`
	Enabled     bool     `json:"enabled"`
	Modifiers   []string `json:"modifiers"`
	Key         string   `json:"key"`
	KeyID       *int     `json:"keyId,omitempty"`
	Accelerator string   `json:"accelerator,omitempty"`
}

// Action is something a shortcut can trigger.
type Action struct {
	ID          string
	Title       string
	Description string
	Trigger     func()
}

// Registrar registers shortcuts with the system.
type Registrar interface {
	Register(accelerator string, fn func()) error
	UnregisterAll()
}

type systemRegistrar struct{}

func (systemRegistrar) Register(accelerator string, fn func()) error {
	return mygo.GlobalShortcut.Register(accelerator, fn)
}

func (systemRegistrar) UnregisterAll() {
	mygo.GlobalShortcut.UnregisterAll()
}

// Manager registers the configured shortcuts.
type Manager struct {
	store     *store.Store
	registrar Registrar

	mu      sync.RWMutex
	actions []Action
	configs []Config
}

// New returns a manager for the given actions.
func New(st *store.Store, actions []Action) *Manager {
	return NewWithRegistrar(st, actions, systemRegistrar{})
}

// NewWithRegistrar returns a manager that registers through registrar.
func NewWithRegistrar(st *store.Store, actions []Action, registrar Registrar) *Manager {
	if registrar == nil {
		registrar = systemRegistrar{}
	}
	return &Manager{
		store:     st,
		registrar: registrar,
		actions:   append([]Action(nil), actions...),
	}
}

// Actions returns the actions in registration order.
func (m *Manager) Actions() []Action {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return append([]Action(nil), m.actions...)
}

// LoadAndRegister reads settings/hotkeys.json and registers the bindings.
func (m *Manager) LoadAndRegister() error {
	configs, err := m.load()
	if err != nil {
		return err
	}
	m.mu.Lock()
	m.configs = configs
	m.mu.Unlock()
	m.registerAll()
	return nil
}

// Reload reads the file again, for example after a backup import.
func (m *Manager) Reload() error {
	return m.LoadAndRegister()
}

// Configs returns a copy of the saved bindings.
func (m *Manager) Configs() []Config {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return append([]Config(nil), m.configs...)
}

// ConfigFor returns one action's binding.
func (m *Manager) ConfigFor(actionID string) (Config, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	for _, config := range m.configs {
		if config.ActionID == actionID {
			return config, true
		}
	}
	return Config{}, false
}

// FindConflict returns an enabled binding with the same key combination.
func (m *Manager) FindConflict(candidate Config) (Config, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	signature := Signature(candidate)
	for _, config := range m.configs {
		if !config.Enabled || config.ActionID == candidate.ActionID {
			continue
		}
		if Signature(config) == signature {
			return config, true
		}
	}
	return Config{}, false
}

// SetConfig saves one binding and registers the whole set again.
func (m *Manager) SetConfig(config Config) error {
	config.Accelerator = Accelerator(config.Modifiers, config.Key)
	m.mu.Lock()
	previous := append([]Config(nil), m.configs...)
	replaced := false
	for i := range m.configs {
		if m.configs[i].ActionID == config.ActionID {
			m.configs[i] = config
			replaced = true
			break
		}
	}
	if !replaced {
		m.configs = append(m.configs, config)
	}
	m.mu.Unlock()

	if err := m.save(); err != nil {
		m.mu.Lock()
		m.configs = previous
		m.mu.Unlock()
		return err
	}
	m.registerAll()
	return nil
}

// RemoveConfig deletes one binding and registers the rest again.
func (m *Manager) RemoveConfig(actionID string) error {
	m.mu.Lock()
	previous := append([]Config(nil), m.configs...)
	filtered := m.configs[:0]
	for _, config := range m.configs {
		if config.ActionID != actionID {
			filtered = append(filtered, config)
		}
	}
	m.configs = filtered
	m.mu.Unlock()

	if err := m.save(); err != nil {
		m.mu.Lock()
		m.configs = previous
		m.mu.Unlock()
		return err
	}
	m.registerAll()
	return nil
}

// Display returns a binding as "Ctrl + Shift + J".
func Display(config Config) string {
	parts := make([]string, 0, len(config.Modifiers)+1)
	for _, modifier := range config.Modifiers {
		parts = append(parts, displayModifier(modifier))
	}
	if config.Key != "" {
		parts = append(parts, displayKey(config.Key))
	}
	if len(parts) == 0 {
		return "未设置"
	}
	return strings.Join(parts, " + ")
}

// Accelerator turns a binding into the accelerator MyGo registers.
func Accelerator(modifiers []string, key string) string {
	parts := make([]string, 0, len(modifiers)+1)
	for _, modifier := range modifiers {
		switch strings.ToLower(strings.TrimSpace(modifier)) {
		case "ctrl", "control":
			parts = append(parts, "Ctrl")
		case "shift":
			parts = append(parts, "Shift")
		case "alt":
			parts = append(parts, "Alt")
		case "meta", "super", "win", "cmd", "command":
			parts = append(parts, "Super")
		}
	}
	normalized := normalizeKey(key)
	if normalized == "" {
		return ""
	}
	parts = append(parts, normalized)
	return strings.Join(parts, "+")
}

// FromInput builds a binding from a key event.
func FromInput(event ui.InputEvent) (Config, bool) {
	if event.Kind != ui.InputKeyDown {
		return Config{}, false
	}
	key := event.Key
	if key == ui.KeyUnknown {
		key = event.PhysicalKey
	}
	name, ok := KeyName(key)
	if !ok {
		return Config{}, false
	}
	modifiers := make([]string, 0, 4)
	if event.Mods&ui.Ctrl != 0 {
		modifiers = append(modifiers, "ctrl")
	}
	if event.Mods&ui.Shift != 0 {
		modifiers = append(modifiers, "shift")
	}
	if event.Mods&ui.Alt != 0 {
		modifiers = append(modifiers, "alt")
	}
	if event.Mods&ui.Super != 0 {
		modifiers = append(modifiers, "meta")
	}
	if len(modifiers) == 0 {
		return Config{}, false
	}
	config := Config{Enabled: true, Modifiers: modifiers, Key: name}
	config.Accelerator = Accelerator(modifiers, name)
	if config.Accelerator == "" {
		return Config{}, false
	}
	return config, true
}

// KeyName returns the accelerator name of a key.
func KeyName(key ui.Key) (string, bool) {
	switch key {
	case ui.KeyEnter:
		return "Enter", true
	case ui.KeyEscape:
		return "Escape", true
	case ui.KeyBackspace:
		return "Backspace", true
	case ui.KeyTab:
		return "Tab", true
	case ui.KeySpace:
		return "Space", true
	case ui.KeyDelete:
		return "Delete", true
	case ui.KeyInsert:
		return "Insert", true
	case ui.KeyHome:
		return "Home", true
	case ui.KeyEnd:
		return "End", true
	case ui.KeyPageUp:
		return "PageUp", true
	case ui.KeyPageDown:
		return "PageDown", true
	case ui.KeyLeft:
		return "Left", true
	case ui.KeyRight:
		return "Right", true
	case ui.KeyUp:
		return "Up", true
	case ui.KeyDown:
		return "Down", true
	case ui.KeyMinus:
		return "-", true
	case ui.KeyEqual:
		return "=", true
	case ui.KeyComma:
		return ",", true
	case ui.KeyPeriod:
		return ".", true
	case ui.KeySlash:
		return "/", true
	case ui.KeySemicolon:
		return ";", true
	case ui.KeyQuote:
		return "'", true
	case ui.KeyBracketLeft:
		return "[", true
	case ui.KeyBracketRight:
		return "]", true
	case ui.KeyBackslash:
		return "\\", true
	case ui.KeyBackquote:
		return "`", true
	case ui.Key0:
		return "0", true
	case ui.Key1:
		return "1", true
	case ui.Key2:
		return "2", true
	case ui.Key3:
		return "3", true
	case ui.Key4:
		return "4", true
	case ui.Key5:
		return "5", true
	case ui.Key6:
		return "6", true
	case ui.Key7:
		return "7", true
	case ui.Key8:
		return "8", true
	case ui.Key9:
		return "9", true
	case ui.KeyA:
		return "A", true
	case ui.KeyB:
		return "B", true
	case ui.KeyC:
		return "C", true
	case ui.KeyD:
		return "D", true
	case ui.KeyE:
		return "E", true
	case ui.KeyF:
		return "F", true
	case ui.KeyG:
		return "G", true
	case ui.KeyH:
		return "H", true
	case ui.KeyI:
		return "I", true
	case ui.KeyJ:
		return "J", true
	case ui.KeyK:
		return "K", true
	case ui.KeyL:
		return "L", true
	case ui.KeyM:
		return "M", true
	case ui.KeyN:
		return "N", true
	case ui.KeyO:
		return "O", true
	case ui.KeyP:
		return "P", true
	case ui.KeyQ:
		return "Q", true
	case ui.KeyR:
		return "R", true
	case ui.KeyS:
		return "S", true
	case ui.KeyT:
		return "T", true
	case ui.KeyU:
		return "U", true
	case ui.KeyV:
		return "V", true
	case ui.KeyW:
		return "W", true
	case ui.KeyX:
		return "X", true
	case ui.KeyY:
		return "Y", true
	case ui.KeyZ:
		return "Z", true
	case ui.KeyF1:
		return "F1", true
	case ui.KeyF2:
		return "F2", true
	case ui.KeyF3:
		return "F3", true
	case ui.KeyF4:
		return "F4", true
	case ui.KeyF5:
		return "F5", true
	case ui.KeyF6:
		return "F6", true
	case ui.KeyF7:
		return "F7", true
	case ui.KeyF8:
		return "F8", true
	case ui.KeyF9:
		return "F9", true
	case ui.KeyF10:
		return "F10", true
	case ui.KeyF11:
		return "F11", true
	case ui.KeyF12:
		return "F12", true
	}
	return "", false
}

// Signature identifies a key combination for conflict detection.
func Signature(config Config) string {
	modifiers := make([]string, 0, len(config.Modifiers))
	for _, modifier := range config.Modifiers {
		modifiers = append(modifiers, strings.ToLower(strings.TrimSpace(modifier)))
	}
	sort.Strings(modifiers)
	key := strings.ToUpper(strings.TrimSpace(config.Key))
	if config.KeyID != nil {
		key = strconv.Itoa(*config.KeyID)
	}
	return strings.Join(modifiers, "+") + "|" + key
}

func (m *Manager) load() ([]Config, error) {
	if m.store == nil {
		return nil, nil
	}
	data, err := m.store.Read(path)
	if err != nil {
		return nil, err
	}
	return parseConfigs(data), nil
}

func (m *Manager) save() error {
	if m.store == nil {
		return nil
	}
	m.mu.RLock()
	configs := m.configs
	if configs == nil {
		configs = []Config{}
	}
	data, err := json.MarshalIndent(configs, "", "  ")
	m.mu.RUnlock()
	if err != nil {
		return err
	}
	return m.store.Write(path, data)
}

func (m *Manager) registerAll() {
	m.mu.RLock()
	configs := append([]Config(nil), m.configs...)
	actions := make(map[string]Action, len(m.actions))
	for _, action := range m.actions {
		actions[action.ID] = action
	}
	m.mu.RUnlock()

	m.registrar.UnregisterAll()
	for _, config := range configs {
		if !config.Enabled {
			continue
		}
		action, ok := actions[config.ActionID]
		if !ok {
			continue
		}
		accelerator := config.Accelerator
		if accelerator == "" {
			accelerator = Accelerator(config.Modifiers, config.Key)
		}
		if accelerator == "" {
			slog.Warn("unsupported hotkey", "action", config.ActionID, "key", config.Key)
			continue
		}
		if err := m.registrar.Register(accelerator, action.Trigger); err != nil {
			slog.Warn("register hotkey", "accelerator", accelerator, "err", err)
		}
	}
}

func parseConfigs(data []byte) []Config {
	if len(data) == 0 {
		return nil
	}
	var entries []json.RawMessage
	if err := json.Unmarshal(data, &entries); err != nil {
		return nil
	}
	configs := make([]Config, 0, len(entries))
	for _, entry := range entries {
		var config Config
		if err := json.Unmarshal(entry, &config); err != nil || config.ActionID == "" {
			continue
		}
		configs = append(configs, config)
	}
	return configs
}

func normalizeKey(key string) string {
	trimmed := strings.TrimSpace(key)
	if trimmed == "" {
		return ""
	}
	upper := strings.ToUpper(trimmed)
	if len(upper) == 1 {
		ch := upper[0]
		if (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') {
			return upper
		}
		switch ch {
		case '-', '=', ',', '.', '/', ';', '\'', '[', ']', '\\', '`':
			return upper
		}
	}
	if strings.HasPrefix(upper, "F") {
		if number, err := strconv.Atoi(upper[1:]); err == nil && number >= 1 && number <= 24 {
			return upper
		}
	}
	switch upper {
	case "SPACE":
		return "Space"
	case "ENTER", "RETURN":
		return "Enter"
	case "TAB":
		return "Tab"
	case "ESCAPE", "ESC":
		return "Escape"
	case "BACKSPACE":
		return "Backspace"
	case "DELETE":
		return "Delete"
	case "INSERT":
		return "Insert"
	case "HOME":
		return "Home"
	case "END":
		return "End"
	case "PAGEUP":
		return "PageUp"
	case "PAGEDOWN":
		return "PageDown"
	case "ARROWUP", "UP":
		return "Up"
	case "ARROWDOWN", "DOWN":
		return "Down"
	case "ARROWLEFT", "LEFT":
		return "Left"
	case "ARROWRIGHT", "RIGHT":
		return "Right"
	}
	return ""
}

func displayModifier(modifier string) string {
	switch strings.ToLower(strings.TrimSpace(modifier)) {
	case "ctrl", "control":
		return "Ctrl"
	case "shift":
		return "Shift"
	case "alt":
		return "Alt"
	case "meta", "super", "win", "cmd", "command":
		return "Win"
	default:
		return modifier
	}
}

func displayKey(key string) string {
	normalized := normalizeKey(key)
	if normalized == "" {
		return key
	}
	if len(normalized) == 1 {
		return normalized
	}
	return normalized
}
