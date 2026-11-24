package json_formatter

import (
	"slices"
	"testing"

	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/editor"

	"itools/internal/ui/theme"
)

// The context menu keeps the copy items of the Flutter version, on the
// caret's line.
func TestContextMenuHasJsonCopyItems(t *testing.T) {
	controller := New(Deps{
		Palette: func() theme.Palette { return theme.BuildPalette(theme.StyleModern, false) },
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
