// Package settings draws the settings pages and their sub-pages.
package settings

import (
	"fmt"
	"sync"
	"time"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"

	"itools/internal/features/backup"
	"itools/internal/services/hotkeys"
	"itools/internal/ui/icons"
	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

type page int

const (
	pageMenu page = iota
	pageTheme
	pageHotkeys
	pageBackup
	pageAutostart
)

// Deps are the services the settings pages use.
type Deps struct {
	Theme          *theme.Manager
	Hotkeys        *hotkeys.Manager
	Backup         *backup.Service
	Palette        func() theme.Palette
	Invalidate     func()
	ReloadAll      func()
	OpenAtLogin    func() bool
	SetOpenAtLogin func(bool) error
}

// Controller is the main window's settings state.
type Controller struct {
	deps Deps
	page page
	// direction is which way the next page slides: 1 into a sub-page, -1
	// back to the menu.
	direction int

	recordOpen   bool
	recordingID  string
	pending      hotkeys.Config
	conflict     bool
	conflictName string
	conflictID   string

	mu            sync.Mutex
	busy          bool
	pendingNotice string
	notice        string
}

// New returns a settings controller.
func New(deps Deps) *Controller {
	return &Controller{deps: deps, direction: 1}
}

// Reset returns to the settings menu.
func (c *Controller) Reset() {
	c.page = pageMenu
	c.direction = 1
	c.recordOpen = false
	c.conflict = false
}

// View draws the current settings page, sliding it in over the one it
// replaces.
func (c *Controller) View(x *ui.Context, onHome func()) {
	c.takePending()
	p := c.deps.Palette()
	if c.notice != "" {
		x.Toast(c.notice)
		c.notice = ""
	}
	content := ui.Box(x).
		Fill().
		Key(c.page).
		Transition(ui.ElementTransition{
			Duration: 200 * time.Millisecond,
			Enter:    &ui.Motion{X: 24 * float32(c.direction), Opacity: 1},
			Exit:     &ui.Motion{Opacity: 0},
		})
	content.Children(func() {
		switch c.page {
		case pageTheme:
			c.viewTheme(x, p)
		case pageHotkeys:
			c.viewHotkeys(x, p)
		case pageBackup:
			c.viewBackup(x, p)
		case pageAutostart:
			c.viewAutostart(x, p)
		default:
			c.viewMenu(x, p, onHome)
		}
	})
}

// navigate moves to a page, remembering which way the slide goes: into a
// sub-page from the right, back to the menu from the left.
func (c *Controller) navigate(next page) {
	if next == c.page {
		return
	}
	if next == pageMenu {
		c.direction = -1
	} else if c.page == pageMenu {
		c.direction = 1
	}
	c.page = next
}

func (c *Controller) viewMenu(x *ui.Context, p theme.Palette, onHome func()) {
	entries := []struct {
		icon        string
		title       string
		description string
		page        page
	}{
		{"sun-moon", "主题设置", "选择外观与主题色", pageTheme},
		{"keyboard", "热键设置", "配置全局快捷键，快速触发常用操作", pageHotkeys},
		{"database", "备份还原", "导出当前数据或导入历史备份", pageBackup},
		{"power", "开机自启", "设置开机时自动启动应用", pageAutostart},
	}
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "设置", "管理应用配置和偏好", onHome, nil)
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(12).Children(func() {
				widgets.SectionHeader(x, p, "偏好入口", "", "info")
				for _, entry := range entries {
					entry := entry
					widgets.MenuCard(x, p, entry.icon, entry.title, entry.description, func() {
						c.navigate(entry.page)
					})
				}
			})
		})
	})
}

func (c *Controller) viewTheme(x *ui.Context, p theme.Palette) {
	manager := c.deps.Theme
	mode := modeIndex(manager.Mode())
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "主题设置", "外观与强调色", func() {
			c.navigate(pageMenu)
		}, nil)
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(20).Children(func() {
				c.section(x, p, "外观", "亮色、深色、纯黑或跟随系统", func() {
					seg := ui.Segmented(x, &mode, "亮色", "深色", "纯黑", "跟随系统").Width(320)
					if seg.Changed() {
						if err := manager.SetMode(modeValue(mode)); err != nil {
							c.notice = "保存主题失败: " + err.Error()
						}
						c.deps.Invalidate()
					}
					ui.Text(x, theme.ModeName(manager.Mode())).
						FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
				})
				widgets.Divider(x, p)
				c.section(x, p, "主题色", "按钮、选中态与焦点环的颜色", func() {
					ui.Row(x).Wrap().Gap(6).AlignItems(ui.Center).Children(func() {
						for _, spec := range theme.Accents {
							spec := spec
							selected := manager.Accent() == spec.ID
							btn := ui.ButtonBase(x).
								Width(30).
								Height(30).
								Label("主题色 " + spec.Name).
								Cursor(ui.CursorPointer)
							btn.Children(func() {
								swatch := ui.Row(x).
									Size(18, 18).
									Radius(9).
									Background(spec.Base).
									AlignItems(ui.Center).
									Justify(ui.Center)
								if selected {
									swatch.Border(2, p.Foreground)
									ui.Icon(x, icons.Must("check")).
										Width(10).
										Height(10).
										TextColor(swatchInk(spec.Base))
								}
							})
							if btn.Clicked() {
								if err := manager.SetAccent(spec.ID); err != nil {
									c.notice = "保存主题失败: " + err.Error()
									return
								}
								c.deps.Invalidate()
							}
						}
					})
					ui.Text(x, theme.AccentName(manager.Accent())).
						FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
				})
			})
		})
	})
}

// section draws one settings row: its label and note at the left, its controls
// at the right, as ApiGo's settings panel does.
func (c *Controller) section(x *ui.Context, p theme.Palette, title, note string, controls func()) {
	ui.Row(x).FillWidth().Gap(24).AlignItems(ui.Start).Children(func() {
		ui.Column(x).Width(160).Gap(4).Children(func() {
			ui.Text(x, title).FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Foreground)
			ui.Text(x, note).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
		})
		ui.Column(x).Grow(1).Gap(8).Children(controls)
	})
}

func (c *Controller) viewHotkeys(x *ui.Context, p theme.Palette) {
	manager := c.deps.Hotkeys
	actions := manager.Actions()
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "热键设置", "配置全局快捷键，快速触发常用操作", func() {
			c.navigate(pageMenu)
		}, nil)
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(12).Children(func() {
				widgets.SectionHeader(x, p, "全局热键", "应用在后台或最小化时仍然有效", "keyboard")
				for _, action := range actions {
					action := action
					config, has := manager.ConfigFor(action.ID)
					binding := "未设置"
					if has {
						binding = hotkeys.Display(config)
					}
					widgets.SurfaceCard(x, p, func() {
						ui.Row(x).FillWidth().AlignItems(ui.Center).Gap(12).Children(func() {
							widgets.IconContainer(x, p, "keyboard")
							ui.Column(x).Grow(1).Gap(2).Children(func() {
								ui.Text(x, action.Title).FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Foreground)
								ui.Text(x, action.Description).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
								ui.Text(x, binding).FontSize(theme.FontSizeTiny).FontWeight(600).TextColor(p.Primary)
							})
							ui.Button(x, "设置").OnClick(func() {
								c.recordingID = action.ID
								c.recordOpen = true
								c.pending = hotkeys.Config{}
							})
							if has {
								ui.Button(x, "清除").OnClick(func() {
									if err := manager.RemoveConfig(action.ID); err != nil {
										c.notice = "清除失败: " + err.Error()
										return
									}
									c.notice = "已清除「" + action.Title + "」的热键"
									c.deps.Invalidate()
								})
							}
						})
					})
				}
			})
		})
	})

	if c.recordOpen {
		ui.Modal(x, &c.recordOpen, func() {
			panel := ui.Box(x).
				Width(400).
				Gap(12).
				Focusable().
				AutoFocus().
				HandleInput(func(event ui.InputEvent) bool {
					return c.captureHotkey(event)
				})
			panel.Children(func() {
				ui.Text(x, "录制热键").FontSize(theme.FontSizeTitle).FontWeight(600).TextColor(p.Foreground)
				ui.Text(x, "请按下要绑定的组合键，支持 Ctrl / Shift / Alt / Win，Esc 取消。").
					FontSize(theme.FontSizeTiny).
					TextColor(p.SubtleForeground)
				if c.pending.Accelerator != "" {
					ui.Text(x, hotkeys.Display(c.pending)).FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Primary)
				}
				ui.Row(x).FillWidth().Justify(ui.End).Children(func() {
					ui.Button(x, "取消").OnClick(func() {
						c.recordOpen = false
					})
				})
			})
		})
	}

	if c.conflict {
		message := fmt.Sprintf("%s 已被「%s」占用，是否覆盖？", hotkeys.Display(c.pending), c.conflictName)
		switch ui.AlertDialog(x, &c.conflict, "热键冲突", message, "取消", "覆盖") {
		case 1:
			if c.conflictID != "" {
				_ = c.deps.Hotkeys.RemoveConfig(c.conflictID)
			}
			if err := c.deps.Hotkeys.SetConfig(c.pending); err != nil {
				c.notice = "保存热键失败: " + err.Error()
			} else {
				c.notice = "已保存热键：" + hotkeys.Display(c.pending)
			}
			c.deps.Invalidate()
		}
	}
}

func (c *Controller) captureHotkey(event ui.InputEvent) bool {
	if event.Kind != ui.InputKeyDown {
		return false
	}
	if event.Key == ui.KeyEscape {
		c.recordOpen = false
		return true
	}
	config, ok := hotkeys.FromInput(event)
	if !ok {
		return false
	}
	config.ActionID = c.recordingID
	if conflict, found := c.deps.Hotkeys.FindConflict(config); found {
		c.pending = config
		c.conflict = true
		c.conflictID = conflict.ActionID
		c.conflictName = actionTitle(c.deps.Hotkeys.Actions(), conflict.ActionID)
		c.recordOpen = false
		return true
	}
	if err := c.deps.Hotkeys.SetConfig(config); err != nil {
		c.notice = "保存热键失败: " + err.Error()
	} else {
		c.notice = "已保存热键：" + hotkeys.Display(config)
	}
	c.recordOpen = false
	c.deps.Invalidate()
	return true
}

func (c *Controller) viewBackup(x *ui.Context, p theme.Palette) {
	files, _ := c.deps.Backup.Current()
	busy := c.isBusy()
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "备份还原", "导出当前数据或导入历史备份", func() {
			c.navigate(pageMenu)
		}, nil)
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(16).Children(func() {
				widgets.SectionHeader(x, p, "当前数据", "包含定时任务、日志、文件夹映射、主题与热键", "database")
				widgets.SurfaceCard(x, p, func() {
					ui.Column(x).Gap(4).Children(func() {
						ui.Text(x, fmt.Sprintf("将备份 %d 个文件", len(files))).
							FontSize(theme.FontSizeBody).
							FontWeight(600).
							TextColor(p.Foreground)
						if len(files) == 0 {
							ui.Text(x, "暂无数据").FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
						}
						for _, name := range files {
							ui.Text(x, name).Font("Consolas").FontSize(theme.FontSizeTiny).TextColor(p.MutedForeground)
						}
					})
				})
				ui.Row(x).Gap(8).Children(func() {
					exportButton := ui.PrimaryButton(x, "导出备份")
					if busy {
						exportButton.Disabled(true)
					}
					exportButton.OnClick(func() {
						c.exportBackup()
					})
					importButton := ui.Button(x, "导入备份")
					if busy {
						importButton.Disabled(true)
					}
					importButton.OnClick(func() {
						c.importBackup()
					})
				})
				if busy {
					ui.Text(x, "正在处理...").FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
				}
			})
		})
	})
}

func (c *Controller) viewAutostart(x *ui.Context, p theme.Palette) {
	enabled := c.deps.OpenAtLogin()
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "开机自启", "设置开机时自动启动应用", func() {
			c.navigate(pageMenu)
		}, nil)
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(16).Children(func() {
				widgets.SectionHeader(x, p, "启动选项", "开机自动启动，仅在托盘驻留", "power")
				widgets.SurfaceCard(x, p, func() {
					ui.Row(x).FillWidth().AlignItems(ui.Center).Gap(12).Children(func() {
						widgets.IconContainer(x, p, "power")
						ui.Column(x).Grow(1).Gap(2).Children(func() {
							ui.Text(x, "开机自启").FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Foreground)
							status := "当前未开启"
							if enabled {
								status = "当前已开启"
							}
							ui.Text(x, status).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
						})
						toggle := ui.Switch(x, &enabled)
						if toggle.Changed() {
							c.setAutostart(enabled)
						}
					})
				})
				ui.Text(x, "说明：开机自启由 Windows 当前用户的启动项管理，可在系统设置中关闭。").
					FontSize(theme.FontSizeTiny).
					TextColor(p.SubtleForeground)
			})
		})
	})
}

func (c *Controller) exportBackup() {
	if !c.beginBusy() {
		return
	}
	go func() {
		path, err := mygo.Dialog.Save(mygo.SaveDialogOptions{
			Title:       "导出备份",
			DefaultPath: c.deps.Backup.SuggestedName(),
			Filters: []mygo.FileFilter{
				{Name: "JSON 文件", Extensions: []string{"json"}},
			},
		})
		if err != nil {
			c.endBusy("导出失败: " + err.Error())
			return
		}
		if path == "" {
			c.endBusy("")
			return
		}
		summary, err := c.deps.Backup.Export(path)
		if err != nil {
			c.endBusy("导出失败: " + err.Error())
			return
		}
		c.endBusy(fmt.Sprintf("已导出 %d 个文件", len(summary.Files)))
	}()
}

func (c *Controller) importBackup() {
	if !c.beginBusy() {
		return
	}
	go func() {
		paths, err := mygo.Dialog.Open(mygo.OpenDialogOptions{
			Title: "导入备份",
			Filters: []mygo.FileFilter{
				{Name: "JSON 文件", Extensions: []string{"json"}},
			},
		})
		if err != nil {
			c.endBusy("导入失败: " + err.Error())
			return
		}
		if len(paths) == 0 {
			c.endBusy("")
			return
		}
		summary, err := c.deps.Backup.Import(paths[0])
		if err != nil {
			c.endBusy("导入失败: " + err.Error())
			return
		}
		if c.deps.ReloadAll != nil {
			c.deps.ReloadAll()
		}
		c.endBusy(fmt.Sprintf("已导入 %d 个文件", len(summary.Files)))
	}()
}

func (c *Controller) setAutostart(enabled bool) {
	if !c.beginBusy() {
		return
	}
	go func() {
		if err := c.deps.SetOpenAtLogin(enabled); err != nil {
			c.endBusy("设置开机自启失败: " + err.Error())
			return
		}
		if enabled {
			c.endBusy("已开启开机自启")
		} else {
			c.endBusy("已关闭开机自启")
		}
	}()
}

func (c *Controller) beginBusy() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.busy {
		return false
	}
	c.busy = true
	return true
}

func (c *Controller) endBusy(notice string) {
	c.mu.Lock()
	c.busy = false
	c.pendingNotice = notice
	c.mu.Unlock()
	c.deps.Invalidate()
}

func (c *Controller) isBusy() bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.busy
}

func (c *Controller) takePending() {
	c.mu.Lock()
	if c.pendingNotice != "" {
		c.notice = c.pendingNotice
		c.pendingNotice = ""
	}
	c.mu.Unlock()
}

// swatchInk is the color of the check on an accent swatch: dark on a light
// color, white on a dark one.
func swatchInk(c ui.Color) ui.Color {
	if 0.2126*float32(c.R)+0.7152*float32(c.G)+0.0722*float32(c.B) > 160 {
		return ui.Hex("#111827")
	}
	return ui.Hex("#FFFFFF")
}

func modeIndex(mode theme.Mode) int {
	switch mode {
	case theme.ModeLight:
		return 0
	case theme.ModeDark:
		return 1
	case theme.ModeBlack:
		return 2
	default:
		return 3
	}
}

func modeValue(index int) theme.Mode {
	switch index {
	case 0:
		return theme.ModeLight
	case 1:
		return theme.ModeDark
	case 2:
		return theme.ModeBlack
	default:
		return theme.ModeSystem
	}
}

func actionTitle(actions []hotkeys.Action, id string) string {
	for _, action := range actions {
		if action.ID == id {
			return action.Title
		}
	}
	return id
}
