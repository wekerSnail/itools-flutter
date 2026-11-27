// Package app wires the services and draws the app's windows.
package app

import (
	"log/slog"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"

	"itools/assets"
	"itools/internal/core/logging"
	"itools/internal/core/store"
	"itools/internal/core/tools"
	"itools/internal/features/backup"
	"itools/internal/features/folder_mapping"
	"itools/internal/features/home"
	"itools/internal/features/json_formatter"
	"itools/internal/features/scheduler"
	"itools/internal/features/settings"
	"itools/internal/services/hotkeys"
	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

type mainPage int

const (
	pageHome mainPage = iota
	pageSettings
)

// App holds the services the windows share.
type App struct {
	store     *store.Store
	theme     *theme.Manager
	hotkeys   *hotkeys.Manager
	scheduler *scheduler.Engine
	backup    *backup.Service
	settings  *settings.Controller
	windows   *Windows
	tray      *mygo.Tray
	page      mainPage
	// pageDirection is which way the main window's next page slides: 1 into
	// the settings, -1 back home.
	pageDirection int

	shutdownOnce sync.Once
}

// New returns an app before it starts.
func New() *App {
	return &App{page: pageHome, pageDirection: 1}
}

// Start initializes the services and creates the main window and the tray.
func (a *App) Start() {
	base, err := mygo.App.Path(mygo.PathUserData)
	if err != nil {
		slog.Error("resolve user data directory", "err", err)
		return
	}
	logging.Setup(filepath.Join(base, "logs", "app.log"))

	a.store = store.New(base)
	a.theme = theme.NewManager(a.store, mygo.Theme.IsDark)
	if err := a.theme.Load(); err != nil {
		slog.Warn("load theme", "err", err)
	}

	a.windows = NewWindows(a)
	a.theme.OnChange(func() {
		a.windows.InvalidateAll()
	})

	a.hotkeys = hotkeys.New(a.store, a.hotkeyActions())
	a.scheduler = scheduler.NewEngine(a.store, func() {
		a.windows.InvalidateAll()
	})
	a.scheduler.Start()
	a.backup = backup.New(a.store)
	a.settings = settings.New(settings.Deps{
		Theme:          a.theme,
		Hotkeys:        a.hotkeys,
		Backup:         a.backup,
		Palette:        a.theme.Palette,
		Invalidate:     a.windows.InvalidateAll,
		ReloadAll:      a.ReloadAll,
		OpenAtLogin:    mygo.App.OpenAtLogin,
		SetOpenAtLogin: mygo.App.SetOpenAtLogin,
	})

	a.windows.CreateMain(startHidden())
	if err := a.hotkeys.LoadAndRegister(); err != nil {
		slog.Warn("load hotkeys", "err", err)
	}
	if err := a.createTray(); err != nil {
		slog.Error("create tray", "err", err)
	}

	mygo.Theme.OnUpdated(func() {
		a.windows.InvalidateAll()
	})
	mygo.App.OnBeforeQuit(func(e *mygo.QuitEvent) {
		a.shutdown()
	})

	slog.Info("app started", "data", base)
}

// ShowMain shows the main window, as the tray and a second instance do.
func (a *App) ShowMain() {
	if a.windows != nil {
		a.windows.ShowMain()
	}
}

// Quit closes every window and quits the app.
func (a *App) Quit() {
	if a.windows != nil {
		a.windows.CloseAll()
	}
	mygo.App.Quit()
}

// ReloadAll reloads the data a backup import may have replaced.
func (a *App) ReloadAll() {
	if a.theme != nil {
		_ = a.theme.Load()
	}
	if a.hotkeys != nil {
		_ = a.hotkeys.Reload()
	}
	if a.scheduler != nil {
		a.scheduler.Reload()
	}
	if a.windows != nil {
		a.windows.InvalidateAll()
	}
}

func (a *App) shutdown() {
	a.shutdownOnce.Do(func() {
		if a.scheduler != nil {
			a.scheduler.Stop()
		}
		mygo.GlobalShortcut.UnregisterAll()
		if a.tray != nil {
			a.tray.Destroy()
		}
	})
}

func (a *App) hotkeyActions() []hotkeys.Action {
	actions := []hotkeys.Action{
		{
			ID:          "open_main_window",
			Title:       "打开主窗口",
			Description: "显示/隐藏应用主窗口",
			Trigger:     a.ShowMain,
		},
	}
	for _, spec := range tools.All {
		spec := spec
		actions = append(actions, hotkeys.Action{
			ID:          "open_" + spec.ID,
			Title:       "打开" + spec.Title,
			Description: "打开" + spec.Title + "页面",
			Trigger: func() {
				if a.windows != nil {
					a.windows.OpenTool(spec.ID, false)
				}
			},
		})
	}
	return actions
}

func (a *App) viewMain(c *ui.Context) {
	a.theme.Apply(c)
	widgets.PageHost(c, a.page, a.pageDirection, func() {
		switch a.page {
		case pageSettings:
			a.settings.View(c, func() {
				a.page = pageHome
				a.pageDirection = -1
				a.windows.InvalidateMain()
			})
		default:
			home.View(c, home.Deps{
				Palette: a.theme.Palette,
				OpenTool: func(id string) {
					a.windows.OpenTool(id, false)
				},
				OpenSettings: func() {
					a.settings.Reset()
					a.page = pageSettings
					a.pageDirection = 1
					a.windows.InvalidateMain()
				},
			})
		}
	})
}

func (a *App) themed(view func(*ui.Context)) func(*ui.Context) {
	return func(c *ui.Context) {
		a.theme.Apply(c)
		view(c)
	}
}

func (a *App) newToolView(spec tools.Spec) (func(*ui.Context), func()) {
	switch spec.ID {
	case "folder_mapping":
		controller := folder_mapping.New(folder_mapping.Deps{
			Store:      a.store,
			Palette:    a.theme.Palette,
			Invalidate: a.windows.InvalidateAll,
		})
		return controller.View, controller.Close
	case "json_formatter":
		controller := json_formatter.New(json_formatter.Deps{
			Palette: a.theme.Palette,
			OpenNewWindow: func() {
				a.windows.OpenTool("json_formatter", true)
			},
			Invalidate: a.windows.InvalidateAll,
		})
		return controller.View, controller.Close
	case "scheduler":
		controller := scheduler.NewController(scheduler.Deps{
			Engine:  a.scheduler,
			Palette: a.theme.Palette,
		})
		return controller.View, controller.Close
	default:
		return func(c *ui.Context) {
			a.viewPlaceholder(c, spec)
		}, nil
	}
}

func (a *App) viewPlaceholder(c *ui.Context, spec tools.Spec) {
	p := a.theme.Palette()
	ui.Column(c).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(c, p, spec.Title, spec.Description, nil, nil)
		ui.Scroll(c).Grow(1).Children(func() {
			ui.Column(c).Padding(theme.PagePadding, theme.PagePadding).Children(func() {
				widgets.EmptyState(c, p, spec.Icon, spec.Title+" 正在实现", "该模块将在后续版本接入。")
			})
		})
	})
}

func (a *App) createTray() error {
	tray, err := mygo.NewTray(mygo.TrayOptions{
		ID:      "main",
		Icon:    assets.TrayPNG,
		ToolTip: "Windows 工具集 - 点击打开主界面",
	})
	if err != nil {
		return err
	}
	a.tray = tray
	tray.OnClick(func() {
		a.ShowMain()
	})
	// Refresh the menu before the tray shows it: it pops the menu itself
	// once this notice returns. Popping it here too opens it twice, and a
	// quit chosen in the first is left mid-show as the second dies with the
	// process.
	tray.OnRightClick(func() {
		a.refreshTrayMenu()
	})
	a.refreshTrayMenu()
	return nil
}

func (a *App) refreshTrayMenu() {
	if a.tray == nil {
		return
	}
	startup := mygo.App.OpenAtLogin()
	startupLabel := "开机自启"
	if startup {
		startupLabel = "取消开机自启"
	}
	a.tray.SetMenu(mygo.NewMenu([]*mygo.MenuItem{
		{
			ID:    "show",
			Label: "打开主界面",
			Click: func(*mygo.MenuItem, *mygo.Window) {
				a.ShowMain()
			},
		},
		mygo.Separator(),
		{
			ID:    "startup",
			Label: startupLabel,
			Click: func(*mygo.MenuItem, *mygo.Window) {
				if err := mygo.App.SetOpenAtLogin(!startup); err != nil {
					slog.Error("set open at login", "err", err)
					return
				}
				a.refreshTrayMenu()
			},
		},
		mygo.Separator(),
		{
			ID:    "quit",
			Label: "退出",
			Click: func(*mygo.MenuItem, *mygo.Window) {
				a.Quit()
			},
		},
	}))
}

func startHidden() bool {
	if mygo.App.WasOpenedAtLogin() {
		return true
	}
	for _, arg := range os.Args[1:] {
		if strings.EqualFold(arg, "--minimized") {
			return true
		}
	}
	return false
}
