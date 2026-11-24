package json_formatter

import (
	"time"

	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/editor"

	"itools/internal/ui/icons"
	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

// Deps are what the view calls back into.
type Deps struct {
	Palette       func() theme.Palette
	OpenNewWindow func()
}

// Controller is one JSON formatter window's state.
type Controller struct {
	deps Deps

	split      float32
	input      *editor.Buffer
	output     *editor.Buffer
	inputView  *editor.State
	outputView *editor.State

	valid        bool
	errorMessage string
	status       string
	message      string

	lastVersion uint64
	pending     bool
	lastEdit    time.Time
}

// New returns a JSON formatter controller.
func New(deps Deps) *Controller {
	input := editor.NewBuffer("")
	input.SetLanguage(editor.LanguageFor("input.json"))
	output := editor.NewBuffer("")
	output.SetLanguage(editor.LanguageFor("output.json"))
	return &Controller{
		deps:       deps,
		split:      50,
		input:      input,
		output:     output,
		inputView:  &editor.State{Buffer: input},
		outputView: &editor.State{Buffer: output, ReadOnly: true},
	}
}

// Close releases the controller.
func (c *Controller) Close() {}

// View draws the JSON formatter.
func (c *Controller) View(x *ui.Context) {
	p := c.deps.Palette()
	c.refreshValidation(x)
	if c.message != "" {
		x.Toast(c.message)
		c.message = ""
	}
	tokenTheme := jsonTokenTheme(p.Dark)
	c.inputView.Theme = tokenTheme
	c.outputView.Theme = tokenTheme
	c.inputView.ContextMenu = c.jsonMenu(x, c.inputView)
	c.outputView.ContextMenu = c.jsonMenu(x, c.outputView)

	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "JSON 格式化", "格式化、压缩、转义及智能修复", nil, nil)
		c.viewToolbar(x, p)
		c.viewStatus(x, p)
		ui.SplitPercent(x, &c.split, func() {
			c.viewInput(x, p)
		}, func() {
			c.viewOutput(x, p)
		}).Grow(1).Padding(0, 20, 16)
	})
}

func (c *Controller) viewToolbar(x *ui.Context, p theme.Palette) {
	ui.Row(x).FillWidth().Wrap().Gap(6).Padding(12, 20).Children(func() {
		ui.PrimaryButton(x, "格式化").OnClick(func() {
			c.runFormat(x)
		})
		ui.Button(x, "压缩").OnClick(func() {
			c.runMinify(x)
		})
		ui.Button(x, "转义").OnClick(func() {
			c.runEscape(x)
		})
		ui.Button(x, "反转义").OnClick(func() {
			c.runUnescape(x)
		})
		ui.Button(x, "智能修复").OnClick(func() {
			c.runRepair(x)
		})
		ui.Button(x, "交换").OnClick(func() {
			c.swap()
		})
		ui.Button(x, "复制").OnClick(func() {
			c.copyOutput(x)
		})
		ui.Button(x, "清空").OnClick(func() {
			c.clear()
		})
		ui.Button(x, "新窗口").OnClick(func() {
			if c.deps.OpenNewWindow != nil {
				c.deps.OpenNewWindow()
			}
		})
	})
}

func (c *Controller) viewStatus(x *ui.Context, p theme.Palette) {
	hasInput := c.input.Len() > 0
	bar := ui.Row(x).
		FillWidth().
		Margin(8, 20).
		Padding(6, 10).
		Radius(8).
		Background(p.Muted).
		Border(1, p.Border).
		AlignItems(ui.Center).
		Gap(6)
	bar.Children(func() {
		if hasInput {
			icon := "x"
			color := p.Danger
			label := "JSON 无效"
			if c.valid {
				icon = "check"
				color = p.Success
				label = "JSON 有效"
			}
			ui.Icon(x, icons.Must(icon)).Width(14).Height(14).TextColor(color)
			ui.Text(x, label).FontSize(12).TextColor(color)
		} else {
			ui.Text(x, "等待输入").FontSize(12).TextColor(p.MutedForeground)
		}
		if c.status != "" {
			ui.Text(x, "· "+c.status).FontSize(12).TextColor(p.MutedForeground)
		}
		if c.errorMessage != "" {
			ui.Text(x, c.errorMessage).FontSize(12).TextColor(p.Danger).MaxLines(1)
		}
	})
}

func (c *Controller) viewInput(x *ui.Context, p theme.Palette) {
	ui.Column(x).Fill().Gap(6).Children(func() {
		ui.Text(x, "输入").FontSize(12).FontWeight(600).TextColor(p.MutedForeground)
		ui.Box(x).
			Fill().
			Border(1, p.Border).
			Radius(8).
			Clip().
			Children(func() {
				editor.View(x, c.inputView).Fill()
			})
	})
}

func (c *Controller) viewOutput(x *ui.Context, p theme.Palette) {
	ui.Column(x).Fill().Gap(6).Children(func() {
		ui.Text(x, "输出").FontSize(12).FontWeight(600).TextColor(p.MutedForeground)
		ui.Box(x).
			Fill().
			Border(1, p.Border).
			Radius(8).
			Clip().
			Children(func() {
				editor.View(x, c.outputView).Fill()
			})
	})
}

func (c *Controller) refreshValidation(x *ui.Context) {
	version := c.input.Version()
	if version != c.lastVersion {
		c.lastVersion = version
		c.pending = true
		c.lastEdit = x.Now()
		x.After(300 * time.Millisecond)
	}
	if !c.pending {
		return
	}
	if x.Now().Sub(c.lastEdit) < 300*time.Millisecond {
		x.After(50 * time.Millisecond)
		return
	}
	c.pending = false
	input := c.input.String()
	if input == "" {
		c.valid = false
		c.errorMessage = ""
		return
	}
	c.valid = IsValid(input)
	c.errorMessage = ""
	if !c.valid {
		c.errorMessage = ErrorMessage(input)
	}
}

func (c *Controller) requireInput(x *ui.Context) (string, bool) {
	input := c.input.String()
	if input == "" {
		x.Toast("请输入 JSON 内容")
		return "", false
	}
	return input, true
}

func (c *Controller) runFormat(x *ui.Context) {
	input, ok := c.requireInput(x)
	if !ok {
		return
	}
	result, err := Format(input, 2)
	if err != nil {
		c.errorMessage = err.Error()
		c.status = ""
		c.valid = false
		return
	}
	c.input.Set(result)
	c.output.Set(result)
	c.valid = true
	c.errorMessage = ""
	c.status = "格式化完成"
}

func (c *Controller) runMinify(x *ui.Context) {
	input, ok := c.requireInput(x)
	if !ok {
		return
	}
	result, err := Minify(input)
	if err != nil {
		c.errorMessage = err.Error()
		c.status = ""
		c.valid = false
		return
	}
	c.output.Set(result)
	c.valid = true
	c.errorMessage = ""
	c.status = "压缩完成"
}

func (c *Controller) runEscape(x *ui.Context) {
	input, ok := c.requireInput(x)
	if !ok {
		return
	}
	c.input.Set(Escape(input))
	c.status = "转义完成"
	c.validateNow()
}

func (c *Controller) runUnescape(x *ui.Context) {
	input, ok := c.requireInput(x)
	if !ok {
		return
	}
	c.input.Set(Unescape(input))
	c.status = "反转义完成"
	c.validateNow()
}

func (c *Controller) runRepair(x *ui.Context) {
	input, ok := c.requireInput(x)
	if !ok {
		return
	}
	repaired, ok := SmartRepair(input)
	if !ok {
		c.errorMessage = "无法自动修复该 JSON"
		c.status = ""
		c.valid = false
		return
	}
	c.input.Set(repaired)
	c.valid = true
	c.errorMessage = ""
	c.status = "JSON 修复成功"
}

func (c *Controller) swap() {
	input := c.input.String()
	output := c.output.String()
	c.input.Set(output)
	c.output.Set(input)
	c.status = "已交换"
	c.validateNow()
}

func (c *Controller) copyOutput(x *ui.Context) {
	if c.output.Len() == 0 {
		x.Toast("输出为空")
		return
	}
	x.WriteClipboard(c.output.String())
	x.Toast("已复制到剪贴板")
}

// jsonMenu builds the copy items the Flutter version's context menu had,
// for the caret's line. The editor's own items stay above them: MyGo only
// lets apps add to an editor's menu.
func (c *Controller) jsonMenu(x *ui.Context, view *editor.State) func(m *ui.Menu) {
	return func(m *ui.Menu) {
		prop := ParseLineProperty(view.Buffer.Line(view.CursorPos().Line))
		if prop.HasName {
			if m.Item("复制属性名").Chosen() {
				c.copyText(x, prop.Name)
			}
		}
		if prop.HasValue {
			if m.Item("复制属性值").Chosen() {
				c.copyText(x, prop.Value)
			}
		}
		if prop.HasName && prop.HasValue {
			if m.Item("复制键值对").Chosen() {
				c.copyText(x, `"`+prop.Name+`": `+prop.Value)
			}
		}
		if prop.HasName || prop.HasValue {
			m.Separator()
		}
		if m.Item("复制全部").Chosen() {
			c.copyText(x, view.Buffer.String())
		}
	}
}

func (c *Controller) copyText(x *ui.Context, text string) {
	x.WriteClipboard(text)
	x.Toast("已复制到剪贴板")
}

func (c *Controller) clear() {
	c.input.Reset("")
	c.output.Reset("")
	c.valid = false
	c.errorMessage = ""
	c.status = ""
	c.pending = false
	c.lastVersion = c.input.Version()
}

func (c *Controller) validateNow() {
	input := c.input.String()
	if input == "" {
		c.valid = false
		c.errorMessage = ""
		return
	}
	c.valid = IsValid(input)
	c.errorMessage = ""
	if !c.valid {
		c.errorMessage = ErrorMessage(input)
	}
}

// jsonTokenTheme colors JSON tokens so keys, strings, numbers and
// constants read apart at a glance. Only token colors are set; the rest
// follows the window's default editor theme.
func jsonTokenTheme(dark bool) *editor.Theme {
	ct := &editor.Theme{}
	tok := func(k editor.TokenKind, hex string) { ct.Tokens[k].Color = ui.Hex(hex) }
	if dark {
		tok(editor.TokenProperty, "#9CDCFE") // keys: light blue
		tok(editor.TokenString, "#CE9178")   // string values: orange
		tok(editor.TokenEscape, "#CE9178")
		tok(editor.TokenNumber, "#B5CEA8")   // numbers: light green
		tok(editor.TokenConstant, "#C586C0") // true/false/null: pink-purple
		tok(editor.TokenOperator, "#8B949E") // colons: muted gray
	} else {
		tok(editor.TokenProperty, "#0451A5") // keys: deep blue
		tok(editor.TokenString, "#A31515")   // string values: dark red
		tok(editor.TokenEscape, "#A31515")
		tok(editor.TokenNumber, "#098658")   // numbers: green
		tok(editor.TokenConstant, "#7C3AED") // true/false/null: purple
		tok(editor.TokenOperator, "#6E7781") // colons: muted gray
	}
	ct.Tokens[editor.TokenProperty].Bold = true
	return ct
}
