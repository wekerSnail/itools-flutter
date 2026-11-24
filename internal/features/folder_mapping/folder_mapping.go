// Package folder_mapping stores collections of folders and opens them.
package folder_mapping

import (
	"encoding/json"
	"fmt"
	"sync"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"

	"itools/internal/core/id"
	"itools/internal/core/jsontime"
	"itools/internal/core/store"
	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

const path = "folder_mapping/collections.json"

// Shortcut is one folder shortcut.
type Shortcut struct {
	ID         string        `json:"id"`
	Name       string        `json:"name"`
	TargetPath string        `json:"targetPath"`
	CreatedAt  jsontime.Time `json:"createdAt"`
}

// Collection groups shortcuts.
type Collection struct {
	ID        string        `json:"id"`
	Name      string        `json:"name"`
	Items     []Shortcut    `json:"items"`
	CreatedAt jsontime.Time `json:"createdAt"`
}

// Deps are what the view calls back into.
type Deps struct {
	Store      *store.Store
	Palette    func() theme.Palette
	Invalidate func()
}

type modalKind int

const (
	modalNone modalKind = iota
	modalCollection
	modalShortcut
)

type form struct {
	id      string
	name    string
	path    string
	editing bool
}

// Controller is one folder-mapping window's state.
type Controller struct {
	deps Deps

	mu          sync.Mutex
	collections []Collection
	selectedID  string

	modalKind    modalKind
	modalOpen    bool
	form         form
	confirm      bool
	confirmTitle string
	confirmMsg   string
	pendingDel   func()

	pendingPath   string
	pendingNotice string
	notice        string

	split float32
}

// New loads the collections and returns a controller.
func New(deps Deps) *Controller {
	controller := &Controller{deps: deps, split: 30}
	controller.load()
	return controller
}

// Close releases the controller.
func (c *Controller) Close() {}

// View draws the folder-mapping window.
func (c *Controller) View(x *ui.Context) {
	c.takePending()
	p := c.deps.Palette()

	if c.notice != "" {
		x.Toast(c.notice)
		c.notice = ""
	}

	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "文件夹映射", "快捷管理并双击打开目录", nil, func() {
			ui.Button(x, "新建集合").OnClick(func() {
				c.openCollectionForm(nil)
			})
		})
		ui.SplitPercent(x, &c.split, func() {
			c.viewCollections(x, p)
		}, func() {
			c.viewShortcuts(x, p)
		}).Grow(1)
	})

	c.viewDialogs(x, p)
}

func (c *Controller) viewCollections(x *ui.Context, p theme.Palette) {
	ui.Box(x).Fill().Padding(12).Children(func() {
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Gap(6).Children(func() {
				if len(c.collections) == 0 {
					ui.Text(x, "还没有集合").
						FontSize(12).
						TextColor(p.MutedForeground).
						Padding(10)
					return
				}
				for _, collection := range c.collections {
					collection := collection
					selected := collection.ID == c.selectedID
					row := ui.Row(x).
						FillWidth().
						Padding(10).
						Radius(8).
						AlignItems(ui.Center).
						Gap(4).
						OnClick(func() {
							c.selectedID = collection.ID
						})
					switch {
					case selected:
						row.Background(p.Secondary)
					case row.Hovered():
						row.Background(p.Muted)
					}
					row.Children(func() {
						ui.Column(x).Grow(1).Gap(1).Children(func() {
							ui.Text(x, collection.Name).
								FontSize(14).
								FontWeight(600).
								TextColor(p.Foreground).
								MaxLines(1)
							ui.Text(x, fmt.Sprintf("%d 个快捷方式", len(collection.Items))).
								FontSize(12).
								TextColor(p.MutedForeground)
						})
						widgets.IconButton(x, p, "pencil", func() {
							c.openCollectionForm(&collection)
						})
						widgets.IconButton(x, p, "trash-2", func() {
							c.confirmDelete(
								"确认删除集合",
								fmt.Sprintf("确定要删除集合「%s」吗？此操作不可撤销。", collection.Name),
								func() { c.deleteCollection(collection.ID) },
							)
						})
					})
				}
			})
		})
	})
}

func (c *Controller) viewShortcuts(x *ui.Context, p theme.Palette) {
	collection, ok := c.selected()
	ui.Box(x).Fill().Padding(12).Children(func() {
		ui.Row(x).FillWidth().AlignItems(ui.Center).Gap(10).Children(func() {
			ui.Column(x).Grow(1).Gap(1).Children(func() {
				name := "快捷方式"
				if ok {
					name = collection.Name
				}
				ui.Text(x, name).FontSize(15).FontWeight(600).TextColor(p.Foreground)
				if ok {
					ui.Text(x, fmt.Sprintf("%d 个快捷方式", len(collection.Items))).
						FontSize(12).
						TextColor(p.MutedForeground)
				}
			})
			ui.Button(x, "新建快捷方式").OnClick(func() {
				if !ok {
					x.Toast("请先创建并选择一个集合")
					return
				}
				c.openShortcutForm(nil)
			})
		})
		ui.Scroll(x).Grow(1).Children(func() {
			if !ok {
				ui.Column(x).Grow(1).Padding(8).Children(func() {
					widgets.EmptyState(x, p, "folder-open", "暂无集合", "先创建一个集合，再把常用目录加进来。")
				})
				return
			}
			if len(collection.Items) == 0 {
				ui.Column(x).Grow(1).Padding(8).Children(func() {
					widgets.EmptyState(x, p, "folder-open", "暂无快捷方式", "点击右上角「新建快捷方式」添加目录。")
				})
				return
			}
			ui.Grid(x).Columns(2).Gap(10).Children(func() {
				for _, shortcut := range collection.Items {
					shortcut := shortcut
					card := ui.Box(x).
						FillWidth().
						Padding(12).
						Radius(p.Radius).
						Background(p.Card).
						Border(1, p.Border).
						OnClick(func() {})
					if card.Hovered() {
						card.Background(p.CardHover)
						card.Border(1, p.Ring)
						card.Shadow(0, 2, 8, 0, p.Foreground.Alpha(0.08))
					}
					if card.DoubleClicked() {
						c.openShortcut(shortcut.TargetPath)
					}
					card.Children(func() {
						ui.Row(x).FillWidth().AlignItems(ui.Center).Gap(10).Children(func() {
							widgets.IconContainer(x, p, "folder-open")
							ui.Column(x).Grow(1).Gap(1).Children(func() {
								ui.Text(x, shortcut.Name).
									FontSize(14).
									FontWeight(600).
									TextColor(p.Foreground).
									MaxLines(1)
								ui.Text(x, shortcut.TargetPath).
									FontSize(12).
									TextColor(p.MutedForeground).
									MaxLines(1)
							})
							widgets.IconButton(x, p, "pencil", func() {
								c.openShortcutForm(&shortcut)
							})
							widgets.IconButton(x, p, "trash-2", func() {
								c.confirmDelete(
									"确认删除快捷方式",
									fmt.Sprintf("确定要删除「%s」吗？此操作不可撤销。", shortcut.Name),
									func() { c.deleteShortcut(collection.ID, shortcut.ID) },
								)
							})
						})
					})
				}
			})
		})
	})
}

func (c *Controller) viewDialogs(x *ui.Context, p theme.Palette) {
	if c.modalOpen {
		ui.Modal(x, &c.modalOpen, func() {
			panel := ui.Box(x).
				Width(460).
				Background(p.Card).
				Border(1, p.Border).
				Radius(p.Radius).
				Padding(18).
				Gap(12)
			panel.Children(func() {
				title := "新建集合"
				if c.modalKind == modalShortcut {
					title = "新建快捷方式"
				}
				if c.form.editing {
					if c.modalKind == modalShortcut {
						title = "编辑快捷方式"
					} else {
						title = "编辑集合"
					}
				}
				ui.Text(x, title).FontSize(16).FontWeight(600).TextColor(p.Foreground)
				ui.TextInput(x, &c.form.name).Placeholder("名称").Label("名称")
				if c.modalKind == modalShortcut {
					ui.Row(x).FillWidth().Gap(8).AlignItems(ui.Center).Children(func() {
						ui.TextInput(x, &c.form.path).Placeholder("目录路径").Label("目录路径").Grow(1)
						ui.Button(x, "浏览...").OnClick(func() {
							c.pickFolder()
						})
					})
				}
				ui.Row(x).FillWidth().Gap(8).Justify(ui.End).Children(func() {
					ui.Button(x, "取消").OnClick(func() {
						c.modalOpen = false
					})
					ui.PrimaryButton(x, "保存").OnClick(func() {
						if c.saveForm() {
							c.modalOpen = false
						}
					})
				})
			})
		})
	}
	if c.modalOpen == false && c.modalKind != modalNone {
		c.modalKind = modalNone
	}

	if c.confirm {
		switch ui.AlertDialog(x, &c.confirm, c.confirmTitle, c.confirmMsg, "取消", "确定删除") {
		case 1:
			if c.pendingDel != nil {
				c.pendingDel()
			}
			c.pendingDel = nil
		case 0, ui.AlertDismissed:
			c.pendingDel = nil
		}
	}
}

func (c *Controller) load() {
	data, err := c.deps.Store.Read(path)
	if err != nil {
		c.notice = "读取文件夹映射失败: " + err.Error()
		return
	}
	if len(data) == 0 {
		return
	}
	var entries []json.RawMessage
	if err := json.Unmarshal(data, &entries); err != nil {
		return
	}
	collections := make([]Collection, 0, len(entries))
	for _, entry := range entries {
		var collection Collection
		if err := json.Unmarshal(entry, &collection); err != nil || collection.ID == "" {
			continue
		}
		collections = append(collections, collection)
	}
	c.collections = collections
	if len(collections) > 0 {
		c.selectedID = collections[0].ID
	}
}

func (c *Controller) save() bool {
	collections := c.collections
	if collections == nil {
		collections = []Collection{}
	}
	data, err := json.MarshalIndent(collections, "", "  ")
	if err != nil {
		c.notice = "保存文件夹映射失败: " + err.Error()
		return false
	}
	if err := c.deps.Store.Write(path, data); err != nil {
		c.notice = "保存文件夹映射失败: " + err.Error()
		return false
	}
	return true
}

func (c *Controller) selected() (Collection, bool) {
	for _, collection := range c.collections {
		if collection.ID == c.selectedID {
			return collection, true
		}
	}
	return Collection{}, false
}

func (c *Controller) openCollectionForm(original *Collection) {
	c.modalKind = modalCollection
	c.modalOpen = true
	if original == nil {
		c.form = form{}
		return
	}
	c.form = form{id: original.ID, name: original.Name, editing: true}
}

func (c *Controller) openShortcutForm(original *Shortcut) {
	c.modalKind = modalShortcut
	c.modalOpen = true
	if original == nil {
		c.form = form{}
		return
	}
	c.form = form{
		id:      original.ID,
		name:    original.Name,
		path:    original.TargetPath,
		editing: true,
	}
}

func (c *Controller) saveForm() bool {
	name := c.form.name
	if name == "" {
		c.notice = "名称不能为空"
		return false
	}
	switch c.modalKind {
	case modalCollection:
		if c.form.editing {
			for index := range c.collections {
				if c.collections[index].ID == c.form.id {
					c.collections[index].Name = name
					break
				}
			}
		} else {
			collection := Collection{
				ID:        id.New(),
				Name:      name,
				Items:     []Shortcut{},
				CreatedAt: jsontime.Now(),
			}
			c.collections = append(c.collections, collection)
			c.selectedID = collection.ID
		}
	case modalShortcut:
		if c.form.path == "" {
			c.notice = "目录路径不能为空"
			return false
		}
		for index := range c.collections {
			if c.collections[index].ID != c.selectedID {
				continue
			}
			if c.form.editing {
				for item := range c.collections[index].Items {
					if c.collections[index].Items[item].ID == c.form.id {
						c.collections[index].Items[item].Name = name
						c.collections[index].Items[item].TargetPath = c.form.path
						break
					}
				}
			} else {
				c.collections[index].Items = append(c.collections[index].Items, Shortcut{
					ID:         id.New(),
					Name:       name,
					TargetPath: c.form.path,
					CreatedAt:  jsontime.Now(),
				})
			}
			break
		}
	default:
		return false
	}
	return c.save()
}

func (c *Controller) deleteCollection(collectionID string) {
	filtered := c.collections[:0]
	for _, collection := range c.collections {
		if collection.ID != collectionID {
			filtered = append(filtered, collection)
		}
	}
	c.collections = filtered
	if c.selectedID == collectionID {
		c.selectedID = ""
		if len(c.collections) > 0 {
			c.selectedID = c.collections[0].ID
		}
	}
	c.save()
}

func (c *Controller) deleteShortcut(collectionID, shortcutID string) {
	for index := range c.collections {
		if c.collections[index].ID != collectionID {
			continue
		}
		items := c.collections[index].Items[:0]
		for _, item := range c.collections[index].Items {
			if item.ID != shortcutID {
				items = append(items, item)
			}
		}
		c.collections[index].Items = items
		break
	}
	c.save()
}

func (c *Controller) confirmDelete(title, message string, action func()) {
	c.confirm = true
	c.confirmTitle = title
	c.confirmMsg = message
	c.pendingDel = action
}

func (c *Controller) openShortcut(target string) {
	go func() {
		if err := mygo.Shell.OpenPath(target); err != nil {
			c.setPendingNotice("打开文件夹失败: " + err.Error())
		}
	}()
}

func (c *Controller) pickFolder() {
	go func() {
		paths, err := mygo.Dialog.Open(mygo.OpenDialogOptions{
			Title:     "选择文件夹",
			Directory: true,
		})
		if err != nil {
			c.setPendingNotice("选择文件夹失败: " + err.Error())
			return
		}
		if len(paths) > 0 {
			c.setPendingPath(paths[0])
		}
	}()
}

func (c *Controller) setPendingPath(value string) {
	c.mu.Lock()
	c.pendingPath = value
	c.mu.Unlock()
	c.deps.Invalidate()
}

func (c *Controller) setPendingNotice(value string) {
	c.mu.Lock()
	c.pendingNotice = value
	c.mu.Unlock()
	c.deps.Invalidate()
}

func (c *Controller) takePending() {
	c.mu.Lock()
	if c.pendingPath != "" {
		c.form.path = c.pendingPath
		c.pendingPath = ""
	}
	if c.pendingNotice != "" {
		c.notice = c.pendingNotice
		c.pendingNotice = ""
	}
	c.mu.Unlock()
}
