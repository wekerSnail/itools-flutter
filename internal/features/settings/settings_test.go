package settings

import (
	"testing"

	"github.com/egoist/mygo/ui"

	"itools/internal/core/store"
	"itools/internal/services/hotkeys"
)

type fakeRegistrar struct {
	accelerators []string
}

func (f *fakeRegistrar) Register(accelerator string, fn func()) error {
	f.accelerators = append(f.accelerators, accelerator)
	return nil
}

func (f *fakeRegistrar) UnregisterAll() {
	f.accelerators = nil
}

func TestCaptureHotkey(t *testing.T) {
	st := store.New(t.TempDir())
	registrar := &fakeRegistrar{}
	manager := hotkeys.NewWithRegistrar(st, []hotkeys.Action{
		{ID: "open_main_window", Title: "打开主窗口", Trigger: func() {}},
	}, registrar)
	controller := New(Deps{
		Hotkeys:    manager,
		Invalidate: func() {},
	})
	controller.recordingID = "open_main_window"
	ok := controller.captureHotkey(ui.InputEvent{
		Kind: ui.InputKeyDown,
		Key:  ui.KeyJ,
		Mods: ui.Ctrl | ui.Shift,
	})
	if !ok {
		t.Fatal("captureHotkey rejected the combination")
	}
	config, found := manager.ConfigFor("open_main_window")
	if !found {
		t.Fatal("config was not saved")
	}
	if config.Key != "J" || config.Accelerator != "Ctrl+Shift+J" {
		t.Fatalf("config = %+v", config)
	}
	if len(registrar.accelerators) != 1 || registrar.accelerators[0] != "Ctrl+Shift+J" {
		t.Fatalf("registered = %v", registrar.accelerators)
	}
}

func TestCaptureHotkeyConflict(t *testing.T) {
	st := store.New(t.TempDir())
	registrar := &fakeRegistrar{}
	manager := hotkeys.NewWithRegistrar(st, []hotkeys.Action{
		{ID: "open_main_window", Title: "打开主窗口", Trigger: func() {}},
		{ID: "open_scheduler", Title: "打开定时任务", Trigger: func() {}},
	}, registrar)
	if err := manager.SetConfig(hotkeys.Config{
		ActionID:  "open_scheduler",
		Enabled:   true,
		Modifiers: []string{"ctrl", "shift"},
		Key:       "J",
	}); err != nil {
		t.Fatal(err)
	}

	controller := New(Deps{
		Hotkeys:    manager,
		Invalidate: func() {},
	})
	controller.recordingID = "open_main_window"
	controller.captureHotkey(ui.InputEvent{
		Kind: ui.InputKeyDown,
		Key:  ui.KeyJ,
		Mods: ui.Ctrl | ui.Shift,
	})
	if !controller.conflict {
		t.Fatal("conflict was not detected")
	}
	if controller.conflictID != "open_scheduler" {
		t.Fatalf("conflictID = %q", controller.conflictID)
	}
	if controller.pending.ActionID != "open_main_window" {
		t.Fatalf("pending = %+v", controller.pending)
	}
}
