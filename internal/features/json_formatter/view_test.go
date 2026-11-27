package json_formatter

import (
	"slices"
	"testing"
	"time"

	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/editor"

	"itools/internal/ui/theme"
)

// The context menu keeps the copy items of the Flutter version, on the
// caret's line.
func TestContextMenuHasJsonCopyItems(t *testing.T) {
	controller := New(Deps{
		Palette: func() theme.Palette { return theme.BuildPalette(theme.AccentBlue, false) },
	})
	controller.input.Set("  \"code\": \"200\",\n")
	tt := ui.NewTester(func(c *ui.Context) {
		controller.inputView.ContextMenu = controller.jsonMenu(c, controller.inputView)
		editor.View(c, controller.inputView).Fill().AutoFocus()
	}, 600, 400)
	tt.Frame()
	// On the property's line: the right click moves the caret there, and
	// the menu reads it.
	tt.RightClickAt(300, 10)
	menu := tt.Menu()
	for _, label := range []string{"复制属性名", "复制属性值", "复制键值对", "复制全部"} {
		if !slices.Contains(menu, label) {
			t.Fatalf("Menu() %q misses %q", menu, label)
		}
	}
}

// The check marks the first error, scrolls to it, and the marks go once
// the text changes, as their bytes no longer point at what they marked.
func TestCheckMarksAndRevealsFirstError(t *testing.T) {
	controller := New(Deps{
		Palette: func() theme.Palette { return theme.BuildPalette(theme.AccentBlue, false) },
	})
	controller.input.Set("{\n  \"a\": 1\n  \"b\": 2\n}")
	tt := ui.NewTester(controller.View, 900, 600)
	tt.Frame()

	issue, found := Locate(controller.input.String())
	if !found {
		t.Fatal("Locate found no error in the test input")
	}
	controller.applyCheck(controller.input.Version(), issue, true)
	tt.Frame()

	diags := controller.inputView.Diagnostics()
	if len(diags) != 1 || diags[0].Start != issue.Start || diags[0].End != issue.End {
		t.Fatalf("Diagnostics() = %+v, want one over %d:%d", diags, issue.Start, issue.End)
	}
	if got := controller.inputView.CursorPos().Line; got != issue.Line-1 {
		t.Fatalf("caret at line %d, want %d", got, issue.Line-1)
	}
	if got := len(controller.inputView.GutterMarks); got != 1 {
		t.Fatalf("GutterMarks = %d, want 1", got)
	}

	controller.input.Set("{\n  \"a\": 1,\n  \"b\": 2\n}")
	tt.Frame()
	if got := controller.inputView.Diagnostics(); len(got) != 0 {
		t.Fatalf("marks stayed after an edit: %+v", got)
	}
	if got := len(controller.inputView.GutterMarks); got != 0 {
		t.Fatalf("GutterMarks stayed after an edit: %d", got)
	}
}

// A long operation shows the loading dialog only after the delay, and
// hides it once the operation ends.
func TestLoadingDialogFollowsLongOperation(t *testing.T) {
	controller := New(Deps{
		Palette: func() theme.Palette { return theme.BuildPalette(theme.AccentBlue, false) },
	})
	controller.input.Set(`{"a":1}`)
	tt := ui.NewTester(controller.View, 900, 600)
	tt.Frame()

	controller.mu.Lock()
	controller.busy = true
	controller.opStart = tt.Now()
	controller.status = "正在修复…"
	controller.mu.Unlock()
	tt.Frame()
	if tt.HasText("正在后台处理，窗口不会卡住。") {
		t.Fatal("loading dialog shown before the delay")
	}

	tt.Advance(200 * time.Millisecond)
	tt.Frame()
	if !tt.HasText("正在后台处理，窗口不会卡住。") {
		t.Fatal("loading dialog missing for a long operation")
	}

	controller.mu.Lock()
	controller.busy = false
	controller.mu.Unlock()
	tt.Frame()
	if tt.HasText("正在后台处理，窗口不会卡住。") {
		t.Fatal("loading dialog still shown after the operation")
	}
}
