// Package theme holds the app's palettes and turns them into MyGo themes.
package theme

import (
	"encoding/json"
	"sync"

	"github.com/egoist/mygo/ui"

	"itools/internal/core/store"
)

// Accent names a color the interface is drawn with.
type Accent string

const (
	// AccentSystem follows the desktop's accent color, falling back to blue.
	AccentSystem Accent = "system"
	AccentBlue   Accent = "blue"
	AccentTeal   Accent = "teal"
	AccentGreen  Accent = "green"
	AccentIndigo Accent = "indigo"
	AccentPurple Accent = "purple"
	AccentPink   Accent = "pink"
	AccentOrange Accent = "orange"
	AccentRed    Accent = "red"
	AccentGray   Accent = "gray"
)

// AccentSpec is one choice of the accent picker.
type AccentSpec struct {
	ID   Accent
	Name string
	Base Color
}

// Accents are the accent choices, the system color first as the default.
var Accents = []AccentSpec{
	{AccentSystem, "跟随系统", ui.Hex("#0078D4")},
	{AccentBlue, "蓝色", ui.Hex("#0078D4")},
	{AccentTeal, "青色", ui.Hex("#00B7C3")},
	{AccentGreen, "绿色", ui.Hex("#10B981")},
	{AccentIndigo, "靛蓝", ui.Hex("#6366F1")},
	{AccentPurple, "紫色", ui.Hex("#8764B8")},
	{AccentPink, "粉色", ui.Hex("#E3008C")},
	{AccentOrange, "橙色", ui.Hex("#F97316")},
	{AccentRed, "红色", ui.Hex("#EF4444")},
	{AccentGray, "灰色", ui.Hex("#69797E")},
}

// DefaultAccent is the accent a window draws with until one is picked.
var DefaultAccent = Accents[0]

// LookupAccent returns the spec of an accent, the default for an unknown one.
func LookupAccent(a Accent) AccentSpec {
	for _, spec := range Accents {
		if spec.ID == a {
			return spec
		}
	}
	return DefaultAccent
}

// AccentName is the label the settings show for an accent.
func AccentName(a Accent) string { return LookupAccent(a).Name }

// Mode names how the appearance is chosen.
type Mode string

const (
	ModeLight  Mode = "light"
	ModeDark   Mode = "dark"
	ModeBlack  Mode = "black"
	ModeSystem Mode = "system"
)

// ModeName is the label the settings show for a mode.
func ModeName(m Mode) string {
	switch m {
	case ModeLight:
		return "亮色"
	case ModeDark:
		return "深色"
	case ModeBlack:
		return "纯黑"
	default:
		return "跟随系统"
	}
}

// Type sizes, in DIPs.
const (
	FontSizeTiny    float32 = 11
	FontSizeBody    float32 = 13
	FontSizeTitle   float32 = 15
	FontSizeHeading float32 = 18
	FontSizeDisplay float32 = 22
)

// Metrics, in DIPs, as ApiGo's interface measures.
const (
	HeaderHeight    float32 = 48
	ToolbarHeight   float32 = 40
	StatusBarHeight float32 = 32
	ControlHeight   float32 = 32
	ControlPaddingX float32 = 14
	IconButtonSize  float32 = 28
	ListRowHeight   float32 = 52
	PagePadding     float32 = 20
)

// Radii, in DIPs.
const (
	RadiusCard    float32 = 6
	RadiusSmall   float32 = 4
	RadiusControl float32 = 4
	RadiusDialog  float32 = 8
	RadiusIconBox float32 = 6
)

// FontName is the family of the embedded interface font.
const FontName = "Inter Variable"

// FontFamily is the family the app draws with: the embedded Inter Variable,
// with the system's sans-serif fonts for the glyphs it does not cover.
const FontFamily = FontName + ", sans-serif"

// Palette is the app's color set for one appearance.
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
	// SubtleForeground colors captions and hints at 11 DIPs.
	SubtleForeground Color

	Border  Color
	Divider Color
	Ring    Color

	Selection Color
	Danger    Color
	Success   Color
	Warning   Color

	Radius float32
}

// Color is an alias for ui.Color, so views need one import less.
type Color = ui.Color

const themePath = "settings/theme.json"

// BuildPalette returns the palette of an accent and appearance, the system
// accent resolving to blue where no desktop accent is available.
func BuildPalette(accent Accent, dark bool) Palette {
	return buildPalette(LookupAccent(accent).Base, dark, false)
}

// BuildPaletteFor returns the palette of an accent in a mode, taking the
// desktop's accent color when the accent is AccentSystem.
func BuildPaletteFor(accent Accent, system Color, mode Mode) Palette {
	base := LookupAccent(accent).Base
	if accent == AccentSystem && system.A > 0 {
		base = system
	}
	switch mode {
	case ModeBlack:
		return buildPalette(base, true, true)
	case ModeDark:
		return buildPalette(base, true, false)
	case ModeLight:
		return buildPalette(base, false, false)
	default:
		return buildPalette(base, false, false)
	}
}

func buildPalette(accent Color, dark, black bool) Palette {
	p := Palette{Dark: dark, Radius: RadiusCard}
	switch {
	case black:
		p.Background = ui.Hex("#0F0F0F")
		p.Foreground = ui.Hex("#FAFAFA")
		p.Card = ui.Hex("#171717")
		p.CardHover = ui.Hex("#1F1F1F")
		p.CardPress = ui.Hex("#27272A")
		p.Muted = ui.Hex("#1F1F1F")
		p.MutedForeground = ui.Hex("#A1A1AA")
		p.SubtleForeground = ui.Hex("#71717A")
		p.Border = ui.Hex("#2A2A2E")
		p.Divider = ui.Hex("#1F1F1F")
	case dark:
		p.Background = ui.Hex("#181818")
		p.Foreground = ui.Hex("#FAFAFA")
		p.Card = ui.Hex("#1C1C1E")
		p.CardHover = ui.Hex("#262626")
		p.CardPress = ui.Hex("#2F2F33")
		p.Muted = ui.Hex("#262626")
		p.MutedForeground = ui.Hex("#A3A3A3")
		p.SubtleForeground = ui.Hex("#737373")
		p.Border = ui.Hex("#2F2F33")
		p.Divider = ui.Hex("#1F1F1F")
	default:
		p.Background = ui.Hex("#FFFFFF")
		p.Foreground = ui.Hex("#111827")
		p.Card = ui.Hex("#FAFAFA")
		p.CardHover = ui.Hex("#F3F4F6")
		p.CardPress = ui.Hex("#E5E7EB")
		p.Muted = ui.Hex("#F3F4F6")
		p.MutedForeground = ui.Hex("#6B7280")
		p.SubtleForeground = ui.Hex("#9CA3AF")
		p.Border = ui.Hex("#E5E7EB")
		p.Divider = ui.Hex("#F3F4F6")
	}
	p.Danger = ui.Hex("#EF4444")
	p.Success = ui.Hex("#22C55E")
	p.Warning = ui.Hex("#F59E0B")
	applyAccent(&p, accent, dark)
	return p
}

// applyAccent derives the accent, its shades and the tints of selections from
// the base color, as ApiGo's design system does.
func applyAccent(p *Palette, base Color, dark bool) {
	white := ui.RGB(255, 255, 255)
	black := ui.RGB(0, 0, 0)
	p.Primary = base
	p.PrimaryHover = base.Mix(white, 0.18)
	p.PrimaryPressed = base.Mix(black, 0.18)
	p.PrimaryForeground = white
	if luminance(base) > 150 {
		p.PrimaryForeground = ui.Hex("#111827")
	}
	p.Secondary = base.Alpha(0.12)
	p.SecondaryForeground = base
	if dark {
		p.Selection = base.Alpha(0.32)
		p.Ring = base.Alpha(0.65)
	} else {
		p.Selection = base.Alpha(0.22)
		p.Ring = base.Alpha(0.55)
	}
}

// luminance is the color's perceived brightness, from 0 (black) to 255
// (white), as a threshold for the text that reads on it.
func luminance(c Color) float32 {
	return 0.2126*float32(c.R) + 0.7152*float32(c.G) + 0.0722*float32(c.B)
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
	t.InactiveAccent = p.Primary
	t.Danger = p.Danger
	t.Success = p.Success
	t.Warning = p.Warning
	t.Selection = p.Selection
	t.Focus = p.Ring
	// Controls (buttons, inputs, selects, segments) take the tighter radius
	// ApiGo draws them with; cards keep the palette's own.
	t.Radius = RadiusControl
	t.Spacing = 4
	t.Font = FontFamily
	t.FontSize = FontSizeBody
	if p.Dark {
		t.Scrollbar = ui.RGBA(255, 255, 255, 0.30)
	} else {
		t.Scrollbar = ui.RGBA(0, 0, 0, 0.28)
	}
	return &t
}

type themeFile struct {
	Accent string `json:"themeAccent"`
	Mode   string `json:"themeMode"`
	// Style is the pre-ApiGo style key, kept so old files load without error.
	Style string `json:"themeStyle,omitempty"`
}

// Manager loads, saves and applies the current theme.
type Manager struct {
	mu           sync.RWMutex
	store        *store.Store
	accent       Accent
	mode         Mode
	systemAccent Color
	systemDark   func() bool
	listeners    []func()
}

// NewManager returns a manager that reads the system appearance through
// systemDark.
func NewManager(st *store.Store, systemDark func() bool) *Manager {
	if systemDark == nil {
		systemDark = func() bool { return false }
	}
	return &Manager{
		store:      st,
		accent:     DefaultAccent.ID,
		mode:       ModeSystem,
		systemDark: systemDark,
	}
}

// Load reads settings/theme.json, tolerating a missing or corrupted file and
// files written by versions with the old style keys.
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
	if a := Accent(f.Accent); validAccent(a) {
		m.accent = a
	}
	switch Mode(f.Mode) {
	case ModeLight, ModeDark, ModeBlack, ModeSystem:
		m.mode = Mode(f.Mode)
	}
	return nil
}

func validAccent(a Accent) bool {
	for _, spec := range Accents {
		if spec.ID == a {
			return true
		}
	}
	return false
}

// Save writes settings/theme.json.
func (m *Manager) Save() error {
	if m.store == nil {
		return nil
	}
	m.mu.RLock()
	f := themeFile{Accent: string(m.accent), Mode: string(m.mode)}
	m.mu.RUnlock()
	data, err := json.Marshal(f)
	if err != nil {
		return err
	}
	return m.store.Write(themePath, data)
}

// Accent returns the current accent choice.
func (m *Manager) Accent() Accent {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.accent
}

// Mode returns the current appearance mode.
func (m *Manager) Mode() Mode {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.mode
}

// SetAccent changes the accent and persists it.
func (m *Manager) SetAccent(accent Accent) error {
	if !validAccent(accent) {
		accent = DefaultAccent.ID
	}
	m.mu.Lock()
	previous := m.accent
	m.accent = accent
	m.mu.Unlock()
	if err := m.Save(); err != nil {
		m.mu.Lock()
		m.accent = previous
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

// SetSystemAccent remembers the desktop's accent color, as Apply reads it.
func (m *Manager) SetSystemAccent(c Color) {
	if c.A == 0 {
		return
	}
	m.mu.Lock()
	m.systemAccent = c
	m.mu.Unlock()
}

// IsDark reports whether the resolved appearance is dark.
func (m *Manager) IsDark() bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	return m.darkLocked()
}

func (m *Manager) darkLocked() bool {
	switch m.mode {
	case ModeDark, ModeBlack:
		return true
	case ModeLight:
		return false
	default:
		return m.systemDark()
	}
}

// Palette returns the palette for the current accent and appearance.
func (m *Manager) Palette() Palette {
	m.mu.RLock()
	accent, mode, system := m.accent, m.mode, m.systemAccent
	dark := m.darkLocked()
	m.mu.RUnlock()
	if mode == ModeSystem {
		mode = ModeLight
		if dark {
			mode = ModeDark
		}
	}
	return BuildPaletteFor(accent, system, mode)
}

// Theme returns the MyGo theme for the current palette.
func (m *Manager) Theme() *ui.Theme {
	return BuildTheme(m.Palette())
}

// Apply sets the window's theme, reading the desktop's accent color first
// when the accent follows the system.
func (m *Manager) Apply(c *ui.Context) {
	if m.Accent() == AccentSystem {
		m.SetSystemAccent(c.Preferences().Accent)
	}
	c.SetTheme(m.Theme())
}

// OnChange registers a listener called after a successful accent or mode
// change.
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
