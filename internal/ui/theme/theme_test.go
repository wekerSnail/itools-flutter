package theme

import (
	"testing"

	"itools/internal/core/store"
)

func TestManagerRoundTrip(t *testing.T) {
	st := store.New(t.TempDir())
	m := NewManager(st, func() bool { return false })
	if err := m.Load(); err != nil {
		t.Fatal(err)
	}
	if m.Style() != StyleModern {
		t.Fatalf("style = %q, want modern", m.Style())
	}
	if m.Mode() != ModeSystem {
		t.Fatalf("mode = %q, want system", m.Mode())
	}
	if m.IsDark() {
		t.Fatal("system mode with a light system reported dark")
	}

	if err := m.SetStyle(StyleLuxury); err != nil {
		t.Fatal(err)
	}
	if err := m.SetMode(ModeDark); err != nil {
		t.Fatal(err)
	}

	reloaded := NewManager(st, func() bool { return false })
	if err := reloaded.Load(); err != nil {
		t.Fatal(err)
	}
	if reloaded.Style() != StyleLuxury {
		t.Fatalf("style = %q, want luxury", reloaded.Style())
	}
	if reloaded.Mode() != ModeDark {
		t.Fatalf("mode = %q, want dark", reloaded.Mode())
	}
	if !reloaded.IsDark() {
		t.Fatal("dark mode reported light")
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

func TestPalette(t *testing.T) {
	light := BuildPalette(StyleModern, false)
	if light.Background.R != 0xF8 || light.Background.G != 0xF9 || light.Background.B != 0xFE {
		t.Fatalf("modern light background = %+v", light.Background)
	}
	if light.Radius != 12 {
		t.Fatalf("modern radius = %v, want 12", light.Radius)
	}
	luxury := BuildPalette(StyleLuxury, true)
	if luxury.Radius != 16 {
		t.Fatalf("luxury radius = %v, want 16", luxury.Radius)
	}
	if !luxury.Dark {
		t.Fatal("luxury dark palette is not dark")
	}

	uiTheme := BuildTheme(light)
	if uiTheme == nil {
		t.Fatal("BuildTheme returned nil")
	}
	if uiTheme.Background.R != 0xF8 {
		t.Fatalf("theme background = %+v", uiTheme.Background)
	}
}
