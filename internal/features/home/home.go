// Package home draws the main window's tool grid.
package home

import (
	"github.com/egoist/mygo/ui"

	"itools/internal/core/tools"
	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

// Deps are what the home view calls back into.
type Deps struct {
	Palette      func() theme.Palette
	OpenTool     func(id string)
	OpenSettings func()
}

// View draws the home page.
func View(c *ui.Context, deps Deps) {
	p := deps.Palette()
	ui.Column(c).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(c, p, "Windows 工具集", "选择下方工具开始使用", nil, func() {
			ui.Button(c, "设置").OnClick(deps.OpenSettings)
		})
		ui.Scroll(c).Grow(1).Children(func() {
			ui.Row(c).FillWidth().Justify(ui.Center).Padding(16, 20).Children(func() {
				columns := len(tools.All)
				if columns > 4 {
					columns = 4
				}
				ui.Grid(c).FillWidth().MaxWidth(1040).Columns(columns).Gap(16).Children(func() {
					for _, spec := range tools.All {
						spec := spec
						widgets.InteractiveCard(c, p, func() {
							deps.OpenTool(spec.ID)
						}, func() {
							ui.Column(c).Fill().Gap(8).AlignItems(ui.Center).Justify(ui.Center).Children(func() {
								widgets.IconContainer(c, p, spec.Icon)
								ui.Text(c, spec.Title).
									FontSize(14).
									FontWeight(600).
									TextColor(p.Foreground).
									TextAlign(ui.Center)
								ui.Text(c, spec.Description).
									FontSize(12).
									TextColor(p.MutedForeground).
									TextAlign(ui.Center).
									MaxLines(2)
							})
						}).Height(150)
					}
				})
			})
		})
	})
}
