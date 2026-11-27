package folder_mapping

import (
	"slices"
	"testing"

	"github.com/egoist/mygo/ui"

	"itools/internal/core/jsontime"
	"itools/internal/core/store"
	"itools/internal/ui/theme"
)

func TestSaveAndLoad(t *testing.T) {
	st := store.New(t.TempDir())
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	controller.collections = []Collection{
		{
			ID:        "c1",
			Name:      "项目",
			CreatedAt: jsontime.Now(),
			Items: []Shortcut{
				{ID: "s1", Name: "仓库", TargetPath: `D:\repo`, CreatedAt: jsontime.Now()},
			},
		},
	}
	if !controller.save() {
		t.Fatalf("save failed: %s", controller.notice)
	}

	reloaded := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	if len(reloaded.collections) != 1 {
		t.Fatalf("collections = %d", len(reloaded.collections))
	}
	if reloaded.collections[0].Name != "项目" || len(reloaded.collections[0].Items) != 1 {
		t.Fatalf("collection = %+v", reloaded.collections[0])
	}
	if reloaded.selectedID != "c1" {
		t.Fatalf("selected = %q", reloaded.selectedID)
	}
}

func TestLoadSkipsCorruptEntries(t *testing.T) {
	st := store.New(t.TempDir())
	if err := st.Write(path, []byte(`[
		{"id":"c1","name":"ok","createdAt":"2026-01-01T09:00:00.000","items":[]},
		{"bad":true}
	]`)); err != nil {
		t.Fatal(err)
	}
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	if len(controller.collections) != 1 {
		t.Fatalf("collections = %d", len(controller.collections))
	}
}

func TestMoveBefore(t *testing.T) {
	items := []string{"a", "b", "c", "d"}
	tests := []struct {
		rows []int
		to   int
		want []string
	}{
		{[]int{1}, 3, []string{"a", "c", "b", "d"}},
		{[]int{3}, 1, []string{"a", "d", "b", "c"}},
		{[]int{3}, 4, []string{"a", "b", "c", "d"}},
		{[]int{0}, 0, []string{"a", "b", "c", "d"}},
	}
	for _, test := range tests {
		if got := moveBefore(items, test.rows, test.to); !slices.Equal(got, test.want) {
			t.Errorf("moveBefore(%v, %d) = %v, want %v", test.rows, test.to, got, test.want)
		}
	}
}

func TestReorderShortcutPersists(t *testing.T) {
	st := store.New(t.TempDir())
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	controller.collections = []Collection{{
		ID:        "c1",
		Name:      "项目",
		CreatedAt: jsontime.Now(),
		Items: []Shortcut{
			{ID: "s1", Name: "一", TargetPath: `D:\one`, CreatedAt: jsontime.Now()},
			{ID: "s2", Name: "二", TargetPath: `D:\two`, CreatedAt: jsontime.Now()},
			{ID: "s3", Name: "三", TargetPath: `D:\three`, CreatedAt: jsontime.Now()},
		},
	}}
	controller.reorderShortcut(shortcutDrag{CollectionID: "c1", ShortcutID: "s1"}, "c1", "s3")
	ids := make([]string, 0, 3)
	for _, item := range controller.collections[0].Items {
		ids = append(ids, item.ID)
	}
	if !slices.Equal(ids, []string{"s2", "s1", "s3"}) {
		t.Fatalf("items = %v", ids)
	}
	// A drag from another collection, or onto itself, moves nothing.
	controller.reorderShortcut(shortcutDrag{CollectionID: "c2", ShortcutID: "s2"}, "c1", "s3")
	controller.reorderShortcut(shortcutDrag{CollectionID: "c1", ShortcutID: "s2"}, "c1", "s2")
	if got := controller.collections[0].Items[0].ID; got != "s2" {
		t.Fatalf("first item = %q", got)
	}

	reloaded := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	if len(reloaded.collections) != 1 || len(reloaded.collections[0].Items) != 3 {
		t.Fatalf("reloaded = %+v", reloaded.collections)
	}
	order := []string{
		reloaded.collections[0].Items[0].ID,
		reloaded.collections[0].Items[1].ID,
		reloaded.collections[0].Items[2].ID,
	}
	if !slices.Equal(order, []string{"s2", "s1", "s3"}) {
		t.Fatalf("reloaded order = %v", order)
	}
}

// Dragging a shortcut card onto another moves it before that one, and the
// new order is saved.
func TestDragReordersShortcuts(t *testing.T) {
	st := store.New(t.TempDir())
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	controller.collections = []Collection{{
		ID:        "c1",
		Name:      "项目",
		CreatedAt: jsontime.Now(),
		Items: []Shortcut{
			{ID: "s1", Name: "一号目录", TargetPath: `D:\one`, CreatedAt: jsontime.Now()},
			{ID: "s2", Name: "二号目录", TargetPath: `D:\two`, CreatedAt: jsontime.Now()},
			{ID: "s3", Name: "三号目录", TargetPath: `D:\three`, CreatedAt: jsontime.Now()},
		},
	}}
	controller.selectedID = "c1"
	tt := ui.NewTester(controller.View, 1000, 700)
	tt.Frame()
	from, ok := tt.Find("一号目录")
	if !ok {
		t.Fatal("the first shortcut is not shown")
	}
	to, ok := tt.Find("三号目录")
	if !ok {
		t.Fatal("the third shortcut is not shown")
	}
	tt.Press(from.X+4, from.Y+4)
	tt.Move(from.X+40, from.Y+20)
	tt.Move(to.X+4, to.Y+4)
	tt.Release(to.X+4, to.Y+4)
	tt.Frame()

	ids := make([]string, 0, 3)
	for _, item := range controller.collections[0].Items {
		ids = append(ids, item.ID)
	}
	if !slices.Equal(ids, []string{"s2", "s1", "s3"}) {
		t.Fatalf("items after the drag = %v", ids)
	}
}

// Dragging a collection row above another moves it there, and the new
// order is saved.
func TestDragReordersCollections(t *testing.T) {
	st := store.New(t.TempDir())
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	controller.collections = []Collection{
		{ID: "c1", Name: "集合一", CreatedAt: jsontime.Now(), Items: []Shortcut{}},
		{ID: "c2", Name: "集合二", CreatedAt: jsontime.Now(), Items: []Shortcut{}},
		{ID: "c3", Name: "集合三", CreatedAt: jsontime.Now(), Items: []Shortcut{}},
	}
	controller.selectedID = "c1"
	tt := ui.NewTester(controller.View, 1000, 700)
	tt.Frame()
	from, ok := tt.Find("集合一")
	if !ok {
		t.Fatal("the first collection is not shown")
	}
	to, ok := tt.Find("集合三")
	if !ok {
		t.Fatal("the third collection is not shown")
	}
	tt.Press(from.X+4, from.Y+4)
	tt.Move(from.X+40, from.Y+20)
	tt.Move(to.X+4, to.Y)
	tt.Release(to.X+4, to.Y)
	tt.Frame()

	ids := make([]string, 0, 3)
	for _, collection := range controller.collections {
		ids = append(ids, collection.ID)
	}
	if !slices.Equal(ids, []string{"c2", "c1", "c3"}) {
		t.Fatalf("collections after the drag = %v", ids)
	}
}

// A click on a collection row still chooses it, and a drag of a row still
// reorders instead of choosing.
func TestClickChoosesCollection(t *testing.T) {
	st := store.New(t.TempDir())
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.AccentBlue, false)
		},
		Invalidate: func() {},
	})
	controller.collections = []Collection{
		{ID: "c1", Name: "集合一", CreatedAt: jsontime.Now(), Items: []Shortcut{}},
		{ID: "c2", Name: "集合二", CreatedAt: jsontime.Now(), Items: []Shortcut{}},
	}
	controller.selectedID = "c1"
	tt := ui.NewTester(controller.View, 1000, 700)
	tt.Frame()
	if err := tt.Click("集合二"); err != nil {
		t.Fatal(err)
	}
	tt.Frame()
	if controller.selectedID != "c2" {
		t.Fatalf("selected = %q", controller.selectedID)
	}
}
