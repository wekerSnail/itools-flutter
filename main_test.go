package main

import (
	"testing"

	"github.com/egoist/mygo/ui"

	"itools/internal/core/store"
	"itools/internal/features/backup"
	"itools/internal/features/home"
	"itools/internal/features/settings"
	"itools/internal/services/hotkeys"
	"itools/internal/ui/theme"
)

func TestHomeView(t *testing.T) {
	opened := ""
	view := func(c *ui.Context) {
		home.View(c, home.Deps{
			Palette: func() theme.Palette {
				return theme.BuildPalette(theme.StyleModern, false)
			},
			OpenTool: func(id string) {
				opened = id
			},
			OpenSettings: func() {},
		})
	}

	tester := ui.NewTester(view, 680, 520)
	if !tester.HasText("Windows 工具集") {
		t.Fatalf("home title missing, texts: %v", tester.Texts())
	}
	if err := tester.Click("定时任务"); err != nil {
		t.Fatal(err)
	}
	if opened != "scheduler" {
		t.Fatalf("opened = %q, want scheduler", opened)
	}
}

func TestSettingsView(t *testing.T) {
	palette := theme.BuildPalette(theme.StyleLuxury, true)
	dataStore := store.New(t.TempDir())
	controller := settings.New(settings.Deps{
		Theme:   theme.NewManager(dataStore, func() bool { return false }),
		Hotkeys: hotkeys.New(dataStore, nil),
		Backup:  backup.New(dataStore),
		Palette: func() theme.Palette { return palette },
	})
	view := func(c *ui.Context) {
		controller.View(c, func() {})
	}

	tester := ui.NewTester(view, 680, 520)
	if !tester.HasText("设置") {
		t.Fatalf("settings title missing, texts: %v", tester.Texts())
	}
	if !tester.HasText("主题设置") {
		t.Fatalf("theme entry missing, texts: %v", tester.Texts())
	}
	if err := tester.Click("主题设置"); err != nil {
		t.Fatal(err)
	}
}
