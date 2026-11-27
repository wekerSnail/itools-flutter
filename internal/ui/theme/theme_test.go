package theme

import (
	"testing"

	"github.com/egoist/mygo/ui"

	"itools/internal/core/store"
)

func TestManagerRoundTrip(t *testing.T) {
	st := store.New(t.TempDir())
	m := NewManager(st, func() bool { return false })
	if err := m.Load(); err != nil {
		t.Fatal(err)
	}
	if m.Accent() != AccentSystem {
		t.Fatalf("accent = %q, want system", m.Accent())
	}
	if m.Mode() != ModeSystem {
		t.Fatalf("mode = %q, want system", m.Mode())
	}
	if m.IsDark() {
		t.Fatal("system mode with a light system reported dark")
	}

	if err := m.SetAccent(AccentPurple); err != nil {
		t.Fatal(err)
	}
	if err := m.SetMode(ModeBlack); err != nil {
		t.Fatal(err)
	}

	reloaded := NewManager(st, func() bool { return false })
	if err := reloaded.Load(); err != nil {
		t.Fatal(err)
	}
	if reloaded.Accent() != AccentPurple {
		t.Fatalf("accent = %q, want purple", reloaded.Accent())
	}
	if reloaded.Mode() != ModeBlack {
		t.Fatalf("mode = %q, want black", reloaded.Mode())
	}
	if !reloaded.IsDark() {
		t.Fatal("black mode reported light")
	}
}

func TestLegacyThemeFileLoads(t *testing.T) {
	st := store.New(t.TempDir())
	if err := st.Write(themePath, []byte(`{"themeStyle":"luxury","themeMode":"dark"}`)); err != nil {
		t.Fatal(err)
	}
	m := NewManager(st, func() bool { return false })
	if err := m.Load(); err != nil {
		t.Fatal(err)
	}
	if m.Accent() != AccentSystem {
		t.Fatalf("accent = %q, want the default", m.Accent())
	}
	if m.Mode() != ModeDark {
		t.Fatalf("mode = %q, want dark", m.Mode())
	}
}

func TestSystemModeFollowsSystem(t *testing.T) {
	m := NewManager(nil, func() bool { return true })
	if !m.IsDark() {
		t.Fatal("system mode did not follow a dark system")
	}
	if err := m.SetMode(ModeLight); err != nil {
		t.Fatal(err)
	}
	if m.IsDark() {
		t.Fatal("light mode reported dark")
	}
}

func TestSystemAccentReachesPalette(t *testing.T) {
	m := NewManager(nil, func() bool { return false })
	m.SetSystemAccent(ui.Hex("#FF00AA"))
	if got := m.Palette().Primary; got != ui.Hex("#FF00AA") {
		t.Fatalf("primary = %+v, want the desktop accent", got)
	}
	if err := m.SetAccent(AccentGreen); err != nil {
		t.Fatal(err)
	}
	if got := m.Palette().Primary; got != ui.Hex("#10B981") {
		t.Fatalf("primary = %+v, want green", got)
	}
}

func TestPalette(t *testing.T) {
	light := BuildPalette(AccentBlue, false)
	if light.Background != ui.Hex("#FFFFFF") {
		t.Fatalf("light background = %+v", light.Background)
	}
	if light.Radius != RadiusCard {
		t.Fatalf("radius = %v, want %v", light.Radius, RadiusCard)
	}
	if light.Primary != ui.Hex("#0078D4") {
		t.Fatalf("primary = %+v, want blue", light.Primary)
	}
	if light.Divider.A == 0 {
		t.Fatal("divider is transparent")
	}

	black := BuildPaletteFor(AccentGreen, ui.Color{}, ModeBlack)
	if !black.Dark {
		t.Fatal("black palette is not dark")
	}
	if black.Background != ui.Hex("#0F0F0F") {
		t.Fatalf("black background = %+v", black.Background)
	}
	if black.Primary != ui.Hex("#10B981") {
		t.Fatalf("black primary = %+v, want green", black.Primary)
	}

	uiTheme := BuildTheme(light)
	if uiTheme == nil {
		t.Fatal("BuildTheme returned nil")
	}
	if uiTheme.Background != ui.Hex("#FFFFFF") {
		t.Fatalf("theme background = %+v", uiTheme.Background)
	}
	if uiTheme.Font != FontFamily || uiTheme.FontSize != FontSizeBody {
		t.Fatalf("theme font = %q %v", uiTheme.Font, uiTheme.FontSize)
	}
}
