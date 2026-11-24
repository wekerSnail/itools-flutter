package app

import (
	"fmt"
	"sync"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"

	"itools/internal/core/tools"
)

// Windows owns the main window and every tool window.
type Windows struct {
	app *App

	mu       sync.Mutex
	main     *mygo.Window
	byTool   map[string][]*toolWindow
	used     map[string]map[int]bool
	creating map[string]bool
}

type toolWindow struct {
	win      *mygo.Window
	spec     tools.Spec
	instance int
	temp     bool
	closeFn  func()
}

// NewWindows returns an empty window registry.
func NewWindows(app *App) *Windows {
	return &Windows{
		app:      app,
		byTool:   make(map[string][]*toolWindow),
		used:     make(map[string]map[int]bool),
		creating: make(map[string]bool),
	}
}

// CreateMain creates the main window.
func (w *Windows) CreateMain(hidden bool) {
	win := mygo.NewWindow(mygo.WindowOptions{
		Title:     "工具集",
		Width:     680,
		Height:    520,
		MinWidth:  580,
		MinHeight: 450,
		Hidden:    hidden,
		Content:   ui.View(w.app.viewMain),
	})
	win.OnClose(func(e *mygo.CloseEvent) {
		e.PreventDefault()
		win.Hide()
	})
	w.mu.Lock()
	w.main = win
	w.mu.Unlock()
}

// ShowMain shows and focuses the main window.
func (w *Windows) ShowMain() {
	w.mu.Lock()
	win := w.main
	w.mu.Unlock()
	if win != nil && !win.IsDestroyed() {
		win.Show()
		win.Focus()
	}
}

// InvalidateMain redraws the main window.
func (w *Windows) InvalidateMain() {
	w.mu.Lock()
	win := w.main
	w.mu.Unlock()
	if win != nil && !win.IsDestroyed() {
		win.Invalidate()
	}
}

// InvalidateAll redraws every window.
func (w *Windows) InvalidateAll() {
	w.mu.Lock()
	windows := make([]*mygo.Window, 0, len(w.byTool)+1)
	if w.main != nil {
		windows = append(windows, w.main)
	}
	for _, list := range w.byTool {
		for _, tool := range list {
			windows = append(windows, tool.win)
		}
	}
	w.mu.Unlock()
	for _, win := range windows {
		if !win.IsDestroyed() {
			win.Invalidate()
		}
	}
}

// OpenTool shows an existing tool window or creates one.
func (w *Windows) OpenTool(id string, temp bool) {
	spec, ok := tools.ByID(id)
	if !ok {
		return
	}

	w.mu.Lock()
	if !temp {
		for _, tool := range w.byTool[id] {
			if !tool.temp && !tool.win.IsDestroyed() {
				w.mu.Unlock()
				tool.win.Show()
				tool.win.Focus()
				return
			}
		}
		for _, tool := range w.byTool[id] {
			if !tool.win.IsDestroyed() {
				w.mu.Unlock()
				tool.win.Show()
				tool.win.Focus()
				return
			}
		}
	}
	if w.creating[id] {
		w.mu.Unlock()
		return
	}
	w.creating[id] = true
	instance := w.nextInstanceLocked(id)
	w.mu.Unlock()

	defer func() {
		w.mu.Lock()
		delete(w.creating, id)
		w.mu.Unlock()
	}()

	view, closeFn := w.app.newToolView(spec)
	title := fmt.Sprintf("%s %d", spec.Title, instance)
	win := mygo.NewWindow(mygo.WindowOptions{
		Title:     title,
		Width:     spec.Width,
		Height:    spec.Height,
		MinWidth:  spec.MinWidth,
		MinHeight: spec.MinHeight,
		Content:   ui.View(w.app.themed(view)),
	})

	tool := &toolWindow{
		win:      win,
		spec:     spec,
		instance: instance,
		temp:     temp,
		closeFn:  closeFn,
	}
	win.OnClose(func(e *mygo.CloseEvent) {
		if tool.temp {
			return
		}
		e.PreventDefault()
		win.Hide()
	})
	win.OnClosed(func() {
		if tool.closeFn != nil {
			tool.closeFn()
		}
		w.forget(tool)
	})

	w.mu.Lock()
	w.byTool[id] = append(w.byTool[id], tool)
	w.mu.Unlock()
}

// CloseAll destroys every window, for quitting the app.
func (w *Windows) CloseAll() {
	w.mu.Lock()
	windows := make([]*mygo.Window, 0, len(w.byTool)+1)
	if w.main != nil {
		windows = append(windows, w.main)
	}
	for _, list := range w.byTool {
		for _, tool := range list {
			windows = append(windows, tool.win)
		}
	}
	w.mu.Unlock()
	for _, win := range windows {
		if !win.IsDestroyed() {
			win.Destroy()
		}
	}
}

// Count reports the open windows of a tool, including hidden ones.
func (w *Windows) Count(id string) int {
	w.mu.Lock()
	defer w.mu.Unlock()
	return len(w.byTool[id])
}

func (w *Windows) nextInstanceLocked(id string) int {
	used := w.used[id]
	if used == nil {
		used = make(map[int]bool)
		w.used[id] = used
	}
	max := 0
	for instance := range used {
		if instance > max {
			max = instance
		}
	}
	next := max + 1
	used[next] = true
	return next
}

func (w *Windows) forget(tool *toolWindow) {
	w.mu.Lock()
	defer w.mu.Unlock()
	if used := w.used[tool.spec.ID]; used != nil {
		delete(used, tool.instance)
		if len(used) == 0 {
			delete(w.used, tool.spec.ID)
		}
	}
	list := w.byTool[tool.spec.ID]
	filtered := list[:0]
	for _, item := range list {
		if item != tool {
			filtered = append(filtered, item)
		}
	}
	if len(filtered) == 0 {
		delete(w.byTool, tool.spec.ID)
		return
	}
	w.byTool[tool.spec.ID] = filtered
}
