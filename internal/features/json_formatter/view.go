package json_formatter

import (
	"errors"
	"fmt"
	"sync"
	"time"
	"unicode/utf8"

	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/editor"

	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

const (
	// liveValidateLimit is the input size above which edits no longer
	// trigger a validation pass: scanning tens of megabytes after every
	// keystroke only burns CPU, so the status bar says so instead.
	liveValidateLimit = 8 << 20
	// heavyRepairLimit is the input size from which a repair gives its
	// truncation fallback the longer budget; the loading dialog itself
	// follows the operation's actual duration, not its size.
	heavyRepairLimit = 4 << 20
	// loadingDelay keeps the dialog from flashing when an operation
	// still finishes quickly.
	loadingDelay = 150 * time.Millisecond
	// validateDelay is how long the input must sit still before it is
	// checked, as typing produces a new text every keystroke.
	validateDelay = 300 * time.Millisecond
)

var errRepairFailed = errors.New("无法自动修复该 JSON")

// Deps are what the view calls back into.
type Deps struct {
	Palette       func() theme.Palette
	OpenNewWindow func()
	Invalidate    func()
}

// Controller is one JSON formatter window's state.
type Controller struct {
	deps Deps

	split      float32
	input      *editor.Buffer
	output     *editor.Buffer
	inputView  *editor.State
	outputView *editor.State

	// mu guards the fields below, which an operation goroutine writes
	// before it asks for a redraw.
	mu           sync.Mutex
	valid        bool
	errorMessage string
	status       string
	message      string
	busy         bool
	opStart      time.Time
	skipped      bool
	lastVersion  uint64
	pending      bool
	lastEdit     time.Time

	// loadingOpen is the modal dialog's state; View alone reads and
	// writes it, on the main thread.
	loadingOpen bool

	// marks are the issues the last check found, at markVersion. An edit
	// makes them stale, so View drops them instead of drawing ranges
	// that no longer point at what they marked.
	markVersion uint64
	marks       []Issue
	// reveal asks the next frame to scroll to marks[0]: the check ran off
	// the UI thread, which cannot move the view itself.
	reveal bool
	// painted is the version whose marks the input view shows, so View
	// sets them when they change rather than on every frame.
	painted uint64
}

// statusSnapshot is the part of the state that View draws.
type statusSnapshot struct {
	valid        bool
	errorMessage string
	status       string
	busy         bool
	opStart      time.Time
	skipped      bool
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
	if message := c.takeMessage(); message != "" {
		x.Toast(message)
	}
	tokenTheme := jsonTokenTheme(p.Dark)
	c.inputView.Theme = tokenTheme
	c.outputView.Theme = tokenTheme
	c.inputView.ContextMenu = c.jsonMenu(x, c.inputView)
	c.outputView.ContextMenu = c.jsonMenu(x, c.outputView)
	c.applyMarks(p)

	state := c.snapshot()
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "JSON 格式化", "格式化、压缩、转义及智能修复", nil, nil)
		c.viewToolbar(x, p, state.busy)
		c.viewStatus(x, p, state)
		ui.SplitPercent(x, &c.split, func() {
			c.viewInput(x, p)
		}, func() {
			c.viewOutput(x, p)
		}).Grow(1).Padding(0, theme.PagePadding, 16)
	})
	c.viewLoading(x, p, state)
}

func (c *Controller) viewToolbar(x *ui.Context, p theme.Palette, busy bool) {
	ui.Column(x).FillWidth().Children(func() {
		ui.Row(x).FillWidth().Wrap().Gap(8).Padding(4, theme.PagePadding).Background(p.Background).Children(func() {
			widgets.PrimaryButton(x, "格式化").Disabled(busy).OnClick(func() {
				c.runFormat(x)
			})
			widgets.Button(x, "压缩").Disabled(busy).OnClick(func() {
				c.runMinify(x)
			})
			widgets.Button(x, "转义").Disabled(busy).OnClick(func() {
				c.runEscape(x)
			})
			widgets.Button(x, "反转义").Disabled(busy).OnClick(func() {
				c.runUnescape(x)
			})
			widgets.Button(x, "智能修复").Disabled(busy).OnClick(func() {
				c.runRepair(x)
			})
			widgets.Button(x, "JSON 校验").Disabled(busy).OnClick(func() {
				c.runCheck(x)
			})
			widgets.Button(x, "交换").Disabled(busy).OnClick(func() {
				c.swap()
			})
			widgets.Button(x, "复制").OnClick(func() {
				c.copyOutput(x)
			})
			widgets.Button(x, "清空").Disabled(busy).OnClick(func() {
				c.clear()
			})
			widgets.Button(x, "新窗口").OnClick(func() {
				if c.deps.OpenNewWindow != nil {
					c.deps.OpenNewWindow()
				}
			})
		})
		widgets.Divider(x, p)
	})
}

func (c *Controller) viewStatus(x *ui.Context, p theme.Palette, st statusSnapshot) {
	hasInput := c.input.Len() > 0
	bar := ui.Row(x).
		FillWidth().
		Height(theme.StatusBarHeight).
		Padding(0, theme.PagePadding).
		AlignItems(ui.Center).
		Gap(8)
	bar.Children(func() {
		switch {
		case st.busy:
			ui.Text(x, st.status).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
		case !hasInput:
			ui.Text(x, "等待输入").FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
		case st.skipped && !st.valid:
			ui.Text(x, "大文件：编辑后不自动校验").FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
		default:
			color := p.Danger
			label := "JSON 无效"
			if st.valid {
				color = p.Success
				label = "JSON 有效"
			}
			widgets.StatusBadge(x, p, label, color)
		}
		if !st.busy && st.status != "" {
			ui.Text(x, "· "+st.status).FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
		}
		if st.errorMessage != "" {
			ui.Text(x, st.errorMessage).FontSize(theme.FontSizeTiny).TextColor(p.Danger).MaxLines(1)
		}
	})
}

// viewLoading shows the loading dialog of an operation that outlasts
// loadingDelay: the wait keeps it from flashing for quick work, and the
// dialog stays while the operation runs in the background, so the window
// remains responsive.
func (c *Controller) viewLoading(x *ui.Context, p theme.Palette, st statusSnapshot) {
	if !st.busy {
		c.loadingOpen = false
		return
	}
	if elapsed := x.Now().Sub(st.opStart); elapsed < loadingDelay {
		x.After(loadingDelay - elapsed)
		return
	}
	c.loadingOpen = true
	ui.Modal(x, &c.loadingOpen, func() {
		panel := ui.Box(x).
			Width(320).
			Gap(12)
		panel.Children(func() {
			ui.Row(x).Gap(10).AlignItems(ui.Center).Children(func() {
				ui.Spinner(x)
				ui.Text(x, st.status).FontSize(theme.FontSizeTitle).FontWeight(600).TextColor(p.Foreground)
			})
			ui.Text(x, "正在后台处理，窗口不会卡住。").
				FontSize(theme.FontSizeTiny).
				TextColor(p.SubtleForeground)
		})
	})
}

func (c *Controller) viewInput(x *ui.Context, p theme.Palette) {
	ui.Column(x).Fill().Gap(6).Children(func() {
		widgets.FieldLabel(x, p, "输入")
		ui.Box(x).
			Fill().
			Border(1, p.Border).
			Radius(p.Radius).
			Clip().
			Children(func() {
				editor.View(x, c.inputView).Fill()
			})
	})
}

func (c *Controller) viewOutput(x *ui.Context, p theme.Palette) {
	ui.Column(x).Fill().Gap(6).Children(func() {
		widgets.FieldLabel(x, p, "输出")
		ui.Box(x).
			Fill().
			Border(1, p.Border).
			Radius(p.Radius).
			Clip().
			Children(func() {
				editor.View(x, c.outputView).Fill()
			})
	})
}

// refreshValidation starts a validation pass once the input has sat
// still. The scan runs off the UI thread, so a large document never
// stalls a frame.
func (c *Controller) refreshValidation(x *ui.Context) {
	version := c.input.Version()
	c.mu.Lock()
	if version != c.lastVersion {
		c.lastVersion = version
		c.pending = true
		c.lastEdit = x.Now()
	}
	pending := c.pending
	lastEdit := c.lastEdit
	busy := c.busy
	c.mu.Unlock()

	if busy || !pending {
		return
	}
	if x.Now().Sub(lastEdit) < validateDelay {
		x.After(50 * time.Millisecond)
		return
	}

	snap := c.input.Snapshot()
	if snap.Len() > liveValidateLimit {
		c.mu.Lock()
		c.pending = false
		c.valid = false
		c.errorMessage = ""
		c.skipped = true
		c.mu.Unlock()
		return
	}
	c.mu.Lock()
	c.pending = false
	c.skipped = false
	c.mu.Unlock()
	if snap.Len() == 0 {
		c.mu.Lock()
		c.valid = false
		c.errorMessage = ""
		c.mu.Unlock()
		return
	}
	input := snap.String()
	go func() {
		valid, message := Check(input)
		c.applyValidation(snap.Version(), valid, message)
	}()
}

func (c *Controller) applyValidation(version uint64, valid bool, message string) {
	c.mu.Lock()
	if c.input.Version() != version {
		c.mu.Unlock()
		return
	}
	c.valid = valid
	c.errorMessage = message
	c.mu.Unlock()
	c.invalidate()
}

// runAsync runs work off the UI thread and applies its result only when
// the input was not edited while it ran; a stale result is dropped so a
// slow repair never overwrites a newer text.
func (c *Controller) runAsync(x *ui.Context, status string, work func(input string) (string, error), apply func(result string)) {
	if c.input.Len() == 0 {
		x.Toast("请输入 JSON 内容")
		return
	}
	if !c.beginOp(status, x.Now()) {
		return
	}
	snap := c.input.Snapshot()
	if snap.Len() == 0 {
		c.cancelOp()
		return
	}
	input := snap.String()
	version := snap.Version()
	c.invalidate()
	go func() {
		result, err := work(input)
		if c.input.Version() != version {
			c.cancelOp()
			return
		}
		if err != nil {
			c.failOp(err.Error())
			return
		}
		apply(result)
	}()
}

func (c *Controller) runFormat(x *ui.Context) {
	c.runAsync(x, "格式化中…", func(input string) (string, error) {
		return Format(input, 2)
	}, func(result string) {
		c.input.Set(result)
		c.output.Set(result)
		c.succeedOp("格式化完成")
	})
}

func (c *Controller) runMinify(x *ui.Context) {
	c.runAsync(x, "压缩中…", func(input string) (string, error) {
		return Minify(input)
	}, func(result string) {
		c.output.Set(result)
		c.succeedOp("压缩完成")
	})
}

func (c *Controller) runEscape(x *ui.Context) {
	c.runAsync(x, "转义中…", func(input string) (string, error) {
		return Escape(input), nil
	}, func(result string) {
		c.input.Set(result)
		c.finishOp("转义完成")
	})
}

func (c *Controller) runUnescape(x *ui.Context) {
	c.runAsync(x, "反转义中…", func(input string) (string, error) {
		return Unescape(input), nil
	}, func(result string) {
		c.input.Set(result)
		c.finishOp("反转义完成")
	})
}

func (c *Controller) runRepair(x *ui.Context) {
	c.runAsync(x, "正在修复…", func(input string) (string, error) {
		budget := truncateBudget
		if len(input) > heavyRepairLimit {
			budget = heavyTruncateBudget
		}
		repaired, ok := smartRepair(input, budget)
		if !ok {
			return "", errRepairFailed
		}
		return repaired, nil
	}, func(result string) {
		c.input.Set(result)
		c.succeedOp("JSON 修复成功")
	})
}

// runCheck marks the errors of the input and scrolls to the first of
// them. It never repairs: the marked text stays as it is, for the user
// to fix.
func (c *Controller) runCheck(x *ui.Context) {
	snap := c.input.Snapshot()
	if snap.Len() == 0 {
		x.Toast("请输入 JSON 内容")
		return
	}
	if snap.Len() > liveValidateLimit {
		x.Toast("内容过大，无法自动校验")
		return
	}
	input, version := snap.String(), snap.Version()
	go func() {
		issue, found := Locate(input)
		c.applyCheck(version, issue, found)
	}()
}

// applyCheck keeps the issues a check found, for View to mark and reveal.
// A result of an older text is dropped, as it marks bytes that changed.
func (c *Controller) applyCheck(version uint64, issue Issue, found bool) {
	message := ""
	if found {
		message = fmt.Sprintf("第 %d 行第 %d 列：%s", issue.Line, c.displayCol(issue), issue.Message)
	}
	c.mu.Lock()
	if c.input.Version() != version {
		c.mu.Unlock()
		return
	}
	c.markVersion = version
	if found {
		c.marks = []Issue{issue}
		c.reveal = true
		c.valid = false
		c.errorMessage = issue.Message
		c.status = ""
		c.skipped = false
		c.message = message
	} else {
		c.marks, c.reveal = nil, false
		c.valid = true
		c.errorMessage = ""
		c.status = "校验通过"
		c.skipped = false
		c.message = "JSON 有效"
	}
	c.mu.Unlock()
	c.invalidate()
}

// displayCol turns the byte column of an issue into the column a reader
// counts, in runes: the editor's Pos and Locate both count bytes.
func (c *Controller) displayCol(issue Issue) int {
	if issue.Col < 1 || issue.Line < 1 || issue.Line > c.input.LineCount() {
		return issue.Col
	}
	line := c.input.Line(issue.Line - 1)
	if issue.Col-1 > len(line) {
		return issue.Col
	}
	return utf8.RuneCountInString(line[:issue.Col-1]) + 1
}

// applyMarks marks the issues of the last check in the input view and,
// when the check asked for it, scrolls to the first one.
func (c *Controller) applyMarks(p theme.Palette) {
	version := c.input.Version()
	c.mu.Lock()
	marks, reveal := c.marks, c.reveal
	if c.markVersion != version {
		marks, reveal = nil, false
		c.marks, c.markVersion, c.reveal = nil, 0, false
	}
	c.reveal = false
	c.mu.Unlock()

	if len(marks) == 0 {
		if c.painted != 0 {
			c.inputView.SetDiagnostics(version, nil)
			c.inputView.GutterMarks = nil
			c.inputView.LineBackgrounds = nil
			c.painted = 0
		}
		return
	}
	if c.painted != version {
		c.painted = version
		diags := make([]editor.Diagnostic, 0, len(marks))
		gutter := make([]editor.GutterMark, 0, len(marks))
		backgrounds := make([]editor.LineBackground, 0, len(marks))
		for _, issue := range marks {
			diags = append(diags, editor.Diagnostic{
				Start:    issue.Start,
				End:      issue.End,
				Severity: editor.SeverityError,
				Message:  issue.Message,
				Source:   "JSON",
			})
			line := issue.Line - 1
			gutter = append(gutter, editor.GutterMark{Line: line, Color: p.Danger})
			backgrounds = append(backgrounds, editor.LineBackground{
				First: line,
				Last:  line,
				Color: p.Danger.Alpha(0.12),
			})
		}
		c.inputView.SetDiagnostics(version, diags)
		c.inputView.GutterMarks = gutter
		c.inputView.LineBackgrounds = backgrounds
	}
	if reveal {
		c.inputView.GoTo(editor.Pos{Line: marks[0].Line - 1, Col: marks[0].Col - 1})
	}
}

func (c *Controller) swap() {
	input := c.input.String()
	output := c.output.String()
	c.input.Set(output)
	c.output.Set(input)
	c.finishOp("已交换")
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
	c.mu.Lock()
	c.valid = false
	c.errorMessage = ""
	c.status = ""
	c.message = ""
	c.skipped = false
	c.pending = false
	c.lastVersion = c.input.Version()
	c.markVersion = 0
	c.marks = nil
	c.reveal = false
	c.mu.Unlock()
}

func (c *Controller) snapshot() statusSnapshot {
	c.mu.Lock()
	defer c.mu.Unlock()
	return statusSnapshot{
		valid:        c.valid,
		errorMessage: c.errorMessage,
		status:       c.status,
		busy:         c.busy,
		opStart:      c.opStart,
		skipped:      c.skipped,
	}
}

func (c *Controller) takeMessage() string {
	c.mu.Lock()
	defer c.mu.Unlock()
	message := c.message
	c.message = ""
	return message
}

func (c *Controller) beginOp(status string, now time.Time) bool {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.busy {
		return false
	}
	c.busy = true
	c.opStart = now
	c.status = status
	c.errorMessage = ""
	return true
}

// succeedOp ends an operation whose result is valid JSON.
func (c *Controller) succeedOp(status string) {
	c.mu.Lock()
	c.busy = false
	c.valid = true
	c.errorMessage = ""
	c.status = status
	c.skipped = false
	c.pending = false
	c.lastVersion = c.input.Version()
	c.mu.Unlock()
	c.invalidate()
}

// finishOp ends an operation whose result still has to be checked, as
// escaping and swapping any text, so the next frame validates it.
func (c *Controller) finishOp(status string) {
	c.mu.Lock()
	c.busy = false
	c.status = status
	c.errorMessage = ""
	c.mu.Unlock()
	c.invalidate()
}

func (c *Controller) failOp(message string) {
	c.mu.Lock()
	c.busy = false
	c.valid = false
	c.errorMessage = message
	c.status = ""
	c.skipped = false
	c.mu.Unlock()
	c.invalidate()
}

func (c *Controller) cancelOp() {
	c.mu.Lock()
	c.busy = false
	c.status = "已取消：输入已修改"
	c.mu.Unlock()
	c.invalidate()
}

func (c *Controller) invalidate() {
	if c.deps.Invalidate != nil {
		c.deps.Invalidate()
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
