package folder_mapping

import (
	"testing"

	"itools/internal/core/jsontime"
	"itools/internal/core/store"
	"itools/internal/ui/theme"
)

func TestSaveAndLoad(t *testing.T) {
	st := store.New(t.TempDir())
	controller := New(Deps{
		Store: st,
		Palette: func() theme.Palette {
			return theme.BuildPalette(theme.StyleModern, false)
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
			return theme.BuildPalette(theme.StyleModern, false)
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
			return theme.BuildPalette(theme.StyleModern, false)
		},
		Invalidate: func() {},
	})
	if len(controller.collections) != 1 {
		t.Fatalf("collections = %d", len(controller.collections))
	}
}
