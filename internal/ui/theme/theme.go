// Package theme holds the app's palettes and turns them into MyGo themes.
package theme

import (
	"encoding/json"
	"sync"

	"github.com/egoist/mygo/ui"

	"itools/internal/core/store"
)

// Style names a visual style.
type Style string

const (
	StyleModern Style = "modern"
	StyleLuxury Style = "luxury"
)

// Mode names how the light or dark appearance is chosen.
type Mode string

const (
	ModeLight  Mode = "light"
	ModeDark   Mode = "dark"
	ModeSystem Mode = "system"
)

// Palette is the app's color set for one style and appearance.
type Palette struct {
	Dark bool

	Background Color
	Foreground Color
	Card       Color
	CardHover  Color
	CardPress  Color

	Primary           Color
	PrimaryHover      Color
	PrimaryPressed    Color
	PrimaryForeground Color

	Secondary           Color
	SecondaryForeground Color

	Muted           Color
	MutedForeground Color

	Border    Color
	Ring      Color
	Selection Color
	Danger    Color
	Success   Color
	Warning   Color

	Radius float32
}

// Color is an alias for ui.Color, so views need one import less.
type Color = ui.Color

const themePath = "settings/theme.json"

// BuildPalette returns the palette of a style and appearance.
func BuildPalette(style Style, dark bool) Palette {
	var p Palette
	switch style {
	case StyleLuxury:
		p = luxuryPalette(dark)
	default:
		p = modernPalette(dark)
	}
	p.Dark = dark
	if style == StyleLuxury {
		p.Radius = 16
	} else {
		p.Radius = 12
	}
	p.CardHover = p.Card.Mix(p.Foreground, 0.04)
	p.CardPress = p.Card.Mix(p.Foreground, 0.08)
	if dark {
		p.PrimaryHover = p.Primary.Mix(ui.RGB(255, 255, 255), 0.12)
		p.PrimaryPressed = p.Primary.Mix(ui.RGB(255, 255, 255), 0.20)
	} else {
		p.PrimaryHover = p.Primary.Mix(ui.RGB(0, 0, 0), 0.10)
		p.PrimaryPressed = p.Primary.Mix(ui.RGB(0, 0, 0), 0.18)
	}
	return p
}

func modernPalette(dark bool) Palette {
	if dark {
		return Palette{
			Background:          ui.Hex("#0F0F1A"),
			Foreground:          ui.Hex("#E2E8F0"),
			Card:                ui.Hex("#1A1A2E"),
			Primary:             ui.Hex("#818CF8"),
			PrimaryForeground:   ui.Hex("#0F0F1A"),
			Secondary:           ui.Hex("#1E1B4B"),
			SecondaryForeground: ui.Hex("#A5B4FC"),
			Muted:               ui.Hex("#1E293B"),
			MutedForeground:     ui.Hex("#94A3B8"),
			Border:              ui.Hex("#2D2B5E"),
			Ring:                ui.Hex("#818CF8"),
			Selection:           ui.Hex("#3730A3"),
			Danger:              ui.Hex("#F87171"),
			Success:             ui.Hex("#22C55E"),
			Warning:             ui.Hex("#F59E0B"),
		}
	}
	return Palette{
		Background:          ui.Hex("#F8F9FE"),
		Foreground:          ui.Hex("#1A1A2E"),
		Card:                ui.Hex("#FFFFFF"),
		Primary:             ui.Hex("#6366F1"),
		PrimaryForeground:   ui.Hex("#FFFFFF"),
		Secondary:           ui.Hex("#EEF2FF"),
		SecondaryForeground: ui.Hex("#4338CA"),
		Muted:               ui.Hex("#F1F5F9"),
		MutedForeground:     ui.Hex("#64748B"),
		Border:              ui.Hex("#E2E8F0"),
		Ring:                ui.Hex("#6366F1"),
		Selection:           ui.Hex("#C7D2FE"),
		Danger:              ui.Hex("#EF4444"),
		Success:             ui.Hex("#22C55E"),
		Warning:             ui.Hex("#F59E0B"),
	}
}

func luxuryPalette(dark bool) Palette {
	if dark {
		return Palette{
			Background:          ui.Hex("#1A1814"),
			Foreground:          ui.Hex("#E8E0D8"),
			Card:                ui.Hex("#242018"),
			Primary:             ui.Hex("#D4C5B2"),
			PrimaryForeground:   ui.Hex("#1A1814"),
			Secondary:           ui.Hex("#2A2520"),
			SecondaryForeground: ui.Hex("#C4B5A2"),
			Muted:               ui.Hex("#2A2520"),
			MutedForeground:     ui.Hex("#8C8070"),
			Border:              ui.Hex("#3A3530"),
			Ring:                ui.Hex("#D4C5B2"),
			Selection:           ui.Hex("#5C4A3A"),
			Danger:              ui.Hex("#F87171"),
			Success:             ui.Hex("#22C55E"),
			Warning:             ui.Hex("#F59E0B"),
		}
	}
	return Palette{
		Background:          ui.Hex("#FAF8F5"),
		Foreground:          ui.Hex("#2C2C2C"),
		Card:                ui.Hex("#FFFFFF"),
		Primary:             ui.Hex("#8B7355"),
		PrimaryForeground:   ui.Hex("#FFFFFF"),
		Secondary:           ui.Hex("#F5F0EB"),
		SecondaryForeground: ui.Hex("#5C4A3A"),
		Muted:               ui.Hex("#F0EBE3"),
		MutedForeground:     ui.Hex("#8C8C8C"),
		Border:              ui.Hex("#E5DDD5"),
		Ring:                ui.Hex("#8B7355"),
		Selection:           ui.Hex("#D4C5B2"),
		Danger:              ui.Hex("#B91C1C"),
		Success:             ui.Hex("#16A34A"),
		Warning:             ui.Hex("#D97706"),
	}
}

// Theme turns a palette into the theme MyGo widgets draw with.
func BuildTheme(p Palette) *ui.Theme {
	base := ui.LightTheme()
	if p.Dark {
		base = ui.DarkTheme()
	}
	t := *base
	t.Background = p.Background
	t.Surface = p.Card
	t.SurfaceHover = p.CardHover
	t.SurfacePressed = p.CardPress
	t.Border = p.Border
	t.Text = p.Foreground
	t.TextMuted = p.MutedForeground
	t.Accent = p.Primary
	t.AccentHover = p.PrimaryHover
	t.AccentPressed = p.PrimaryPressed
	t.AccentText = p.PrimaryForeground
	t.Danger = p.Danger
	t.Success = p.Success
	t.Warning = p.Warning
	t.Selection = p.Selection
	t.Focus = p.Ring
	t.Radius = p.Radius
	t.Spacing = 4
	return &t
}

type themeFile struct {
	Style string `json:"themeStyle"`
	Mode  string `json:"themeMode"`
}

// Manager loads, saves and applies the current theme.
type Manager struct {
	mu         sync.RWMutex
	store      *store.Store
	style      Style
	mode       Mode
	systemDark func() bool
	listeners  []func()
}

// NewManager returns a manager that reads the system appearance through
// systemDark.
func NewManager(st *store.Store, systemDark func() bool) *Manager {
	if systemDark == nil {
		systemDark = func() bool { return false }
	}
	return &Manager{
		store:      st,
		style:      StyleModern,
		mode:       ModeSystem,
		systemDark: systemDark,
	}
}

// Load reads settings/theme.json, tolerating a missing or corrupted file.
func (m *Manager) Load() error {
	if m.store == nil {
		return nil
	}
	data, err := m.store.Read(themePath)
	if err != nil {
		return err
	}
	if len(data) == 0 {
		return nil
	}
	var f themeFile
	if err := json.Unmarshal(data, &f); err != nil {
		return nil
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	switch Style(f.Style) {
	case StyleModern, StyleLuxury:
		m.style = Style(f.Style)
	}
	switch Mode(f.Mode) {
	case ModeLight, ModeDark, ModeSystem:
		m.mode = Mode(f.Mode)
	}
	return nil
}

// Save writes settings/theme.json.
func (m *Manager) Save() error {
	if m.store == nil {
		return nil
	}
	m.mu.RLock()
	f := themeFile{Style: string(m.style), Mode: string(m.mode)}
	m.mu.RUnlock()
	data, err := json.Marshal(f)
	if err != nil {
		return err
	}
	return m.store.Write(themePath, data)
}

// Style returns the current style.
func (m *Manager) Style() Style {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.style
}

// Mode returns the current appearance mode.
func (m *Manager) Mode() Mode {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.mode
}

// SetStyle changes the style and persists it.
func (m *Manager) SetStyle(style Style) error {
	m.mu.Lock()
	previous := m.style
	m.style = style
	m.mu.Unlock()
	if err := m.Save(); err != nil {
		m.mu.Lock()
		m.style = previous
		m.mu.Unlock()
		return err
	}
	m.notify()
	return nil
}

// SetMode changes the appearance mode and persists it.
func (m *Manager) SetMode(mode Mode) error {
	m.mu.Lock()
	previous := m.mode
	m.mode = mode
	m.mu.Unlock()
	if err := m.Save(); err != nil {
		m.mu.Lock()
		m.mode = previous
		m.mu.Unlock()
		return err
	}
	m.notify()
	return nil
}

// IsDark reports whether the resolved appearance is dark.
func (m *Manager) IsDark() bool {
	m.mu.RLock()
	mode := m.mode
	m.mu.RUnlock()
	switch mode {
	case ModeDark:
		return true
	case ModeLight:
		return false
	default:
		return m.systemDark()
	}
}

// Palette returns the palette for the current style and appearance.
func (m *Manager) Palette() Palette {
	return BuildPalette(m.Style(), m.IsDark())
}

// Theme returns the MyGo theme for the current palette.
func (m *Manager) Theme() *ui.Theme {
	return BuildTheme(m.Palette())
}

// Apply sets the window's theme.
func (m *Manager) Apply(c *ui.Context) {
	c.SetTheme(m.Theme())
}

// OnChange registers a listener called after a successful style or mode change.
func (m *Manager) OnChange(fn func()) {
	if fn == nil {
		return
	}
	m.mu.Lock()
	m.listeners = append(m.listeners, fn)
	m.mu.Unlock()
}

func (m *Manager) notify() {
	m.mu.RLock()
	listeners := append([]func(){}, m.listeners...)
	m.mu.RUnlock()
	for _, fn := range listeners {
		fn()
	}
}
