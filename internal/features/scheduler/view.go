package scheduler

import (
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/egoist/mygo/ui"
	"github.com/egoist/mygo/ui/editor"

	"itools/internal/core/id"
	"itools/internal/core/jsontime"
	"itools/internal/ui/theme"
	"itools/internal/ui/widgets"
)

// Deps are what the view calls back into.
type Deps struct {
	Engine  *Engine
	Palette func() theme.Palette
}

type page int

const (
	pageList page = iota
	pageEditor
	pageLogs
)

type variableDraft struct {
	name  string
	typ   string
	value string
}

type draft struct {
	id        string
	name      string
	taskType  int
	command   string
	script    *editor.State
	startAt   time.Time
	interval  float64
	unit      string
	variables []variableDraft
	timeout   float64
	enabled   bool
	editing   bool
}

// Controller is one scheduler window's state.
type Controller struct {
	deps Deps

	page     page
	editing  *draft
	logState ui.ListState

	confirm     bool
	confirmID   string
	confirmName string
	toast       string
}

// NewController returns a scheduler controller.
func NewController(deps Deps) *Controller {
	return &Controller{deps: deps}
}

// Close releases the controller.
func (c *Controller) Close() {}

// View draws the scheduler window.
func (c *Controller) View(x *ui.Context) {
	p := c.deps.Palette()
	if c.toast != "" {
		x.Toast(c.toast)
		c.toast = ""
	}
	switch c.page {
	case pageEditor:
		if c.editing == nil {
			c.page = pageList
			c.viewList(x, p)
			return
		}
		c.viewEditor(x, p)
	case pageLogs:
		c.viewLogs(x, p)
	default:
		c.viewList(x, p)
	}
}

func (c *Controller) viewList(x *ui.Context, p theme.Palette) {
	tasks := c.deps.Engine.Tasks()
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "定时任务", "按时间与周期执行命令", nil, func() {
			ui.Button(x, "运行日志").OnClick(func() {
				c.page = pageLogs
			})
			ui.PrimaryButton(x, "添加任务").OnClick(func() {
				c.editing = newDraft()
				c.page = pageEditor
			})
		})
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(12).Children(func() {
				widgets.SectionHeader(x, p, "任务总览", "", "clock")
				if len(tasks) == 0 {
					c.viewEmpty(x, p)
				}
				for _, task := range tasks {
					task := task
					c.viewTaskCard(x, p, task)
				}
			})
		})
	})

	if c.confirm {
		switch ui.AlertDialog(x, &c.confirm, "删除任务", fmt.Sprintf("确定要删除「%s」吗？此操作不可撤销。", c.confirmName), "取消", "确定删除") {
		case 1:
			if err := c.deps.Engine.Remove(c.confirmID); err != nil {
				c.toast = "删除失败: " + err.Error()
			}
		}
	}
}

func (c *Controller) viewEmpty(x *ui.Context, p theme.Palette) {
	widgets.SurfaceCard(x, p, func() {
		ui.Column(x).FillWidth().Padding(10).Gap(8).AlignItems(ui.Center).Children(func() {
			widgets.IconContainer(x, p, "calendar-clock")
			ui.Text(x, "暂无定时任务").FontSize(theme.FontSizeHeading).FontWeight(600).TextColor(p.Foreground)
			ui.Text(x, "点击右上角「添加任务」开始创建").FontSize(theme.FontSizeBody).TextColor(p.MutedForeground)
			ui.PrimaryButton(x, "添加任务").OnClick(func() {
				c.editing = newDraft()
				c.page = pageEditor
			})
		})
	})
}

func (c *Controller) viewTaskCard(x *ui.Context, p theme.Palette, task Task) {
	statusColor := p.Success
	if !task.Enabled {
		statusColor = p.MutedForeground
	}
	card := ui.Box(x).
		FillWidth().
		Padding(14).
		Radius(p.Radius).
		Background(p.Card).
		Border(1, p.Border).
		Gap(10)
	card.Children(func() {
		ui.Row(x).FillWidth().AlignItems(ui.Center).Gap(10).Children(func() {
			ui.Row(x).Size(6, 6).Radius(3).Background(statusColor)
			ui.Column(x).Grow(1).Gap(2).Children(func() {
				ui.Text(x, task.Name).FontSize(theme.FontSizeBody).FontWeight(600).TextColor(p.Foreground)
				ui.Text(x, taskTypeLabel(task.Type)+" · "+scheduleText(task)).
					FontSize(theme.FontSizeTiny).
					TextColor(p.SubtleForeground)
			})
			if !task.Enabled {
				widgets.StatusBadge(x, p, "已停用", p.MutedForeground)
			}
			enabled := task.Enabled
			toggle := ui.Switch(x, &enabled)
			if toggle.Changed() {
				if err := c.deps.Engine.SetEnabled(task.ID, enabled); err != nil {
					c.toast = "更新失败: " + err.Error()
				}
			}
		})
		ui.Row(x).FillWidth().Gap(8).Children(func() {
			ui.Button(x, "立即运行").OnClick(func() {
				if err := c.deps.Engine.RunNow(task.ID); err != nil {
					c.toast = "任务执行失败: " + err.Error()
					return
				}
				c.toast = "已提交执行：" + task.Name
			})
			ui.Button(x, "编辑").OnClick(func() {
				c.editing = draftFromTask(task)
				c.page = pageEditor
			})
			ui.Button(x, "删除").OnClick(func() {
				c.confirm = true
				c.confirmID = task.ID
				c.confirmName = task.Name
			})
		})
	})
}

func (c *Controller) viewEditor(x *ui.Context, p theme.Palette) {
	d := c.editing
	title := "新建任务"
	if d.editing {
		title = "编辑任务"
	}
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, title, "配置执行内容、时间与变量", func() {
			c.page = pageList
			c.editing = nil
		}, func() {
			ui.Button(x, "取消").OnClick(func() {
				c.page = pageList
				c.editing = nil
			})
			ui.PrimaryButton(x, "保存").OnClick(func() {
				if c.saveDraft() {
					c.page = pageList
					c.editing = nil
				}
			})
		})
		ui.Scroll(x).Grow(1).Children(func() {
			ui.Column(x).Padding(20, 20).Gap(16).Children(func() {
				labeled(x, p, "任务名称", func() {
					ui.TextInput(x, &d.name).Placeholder("例如：每日备份")
				})
				labeled(x, p, "任务类型", func() {
					ui.Segmented(x, &d.taskType, "终端命令", "JS 脚本").Width(260)
				})
				labeled(x, p, "开始时间", func() {
					ui.Row(x).Gap(8).Children(func() {
						ui.DateInput(x, &d.startAt).Width(180)
						ui.TimeInput(x, &d.startAt).Width(120)
					})
				})
				labeled(x, p, "执行间隔", func() {
					ui.Row(x).Gap(8).AlignItems(ui.Center).Children(func() {
						ui.NumberInput(x, &d.interval, 1, 9999, 1).Width(140)
						ui.Select(x, &d.unit, unitLabels()).Width(120)
					})
				})
				if d.taskType == 1 {
					labeled(x, p, "JS 脚本", func() {
						ui.Box(x).
							FillWidth().
							Height(240).
							Border(1, p.Border).
							Radius(p.Radius).
							Clip().
							Children(func() {
								editor.View(x, d.script).Fill()
							})
					})
				} else {
					labeled(x, p, "终端命令", func() {
						ui.TextArea(x, &d.command).
							Placeholder("例如：echo hello").
							Height(160)
					})
				}
				c.viewVariables(x, p)
				labeled(x, p, "超时（秒，0 表示默认 600 秒）", func() {
					ui.NumberInput(x, &d.timeout, 0, 86400, 10).Width(160)
				})
			})
		})
	})
}

func (c *Controller) viewVariables(x *ui.Context, p theme.Palette) {
	d := c.editing
	labeled(x, p, "变量", func() {
		ui.Column(x).Gap(8).Children(func() {
			for index := range d.variables {
				index := index
				variable := &d.variables[index]
				ui.Row(x).FillWidth().Gap(8).AlignItems(ui.Center).Children(func() {
					ui.TextInput(x, &variable.name).Placeholder("变量名").Width(160)
					ui.Select(x, &variable.typ, variableTypeLabels()).Width(110)
					ui.TextInput(x, &variable.value).Placeholder("值").Grow(1)
					widgets.IconButton(x, p, "trash-2", func() {
						d.variables = append(d.variables[:index], d.variables[index+1:]...)
					})
				})
			}
			ui.Button(x, "添加变量").Width(110).OnClick(func() {
				d.variables = append(d.variables, variableDraft{typ: "字符串"})
			})
		})
	})
}

func (c *Controller) viewLogs(x *ui.Context, p theme.Palette) {
	logs := c.deps.Engine.Logs()
	ui.Column(x).Fill().Background(p.Background).Children(func() {
		widgets.PageHeader(x, p, "运行日志", "最近 5 天、最多 2000 条", func() {
			c.page = pageList
		}, nil)
		ui.Box(x).Grow(1).Padding(16, 20).Children(func() {
			ui.Box(x).
				Fill().
				Border(1, p.Border).
				Radius(p.Radius).
				Clip().
				Children(func() {
					if len(logs) == 0 {
						ui.Column(x).Fill().Center().Children(func() {
							ui.Text(x, "暂无日志").FontSize(theme.FontSizeTiny).TextColor(p.SubtleForeground)
						})
						return
					}
					c.logState.FollowEnd = true
					ui.List(x, &c.logState, len(logs), func(index int) {
						ui.Text(x, logs[index]).
							Font("Consolas").
							FontSize(theme.FontSizeTiny).
							TextColor(p.Foreground).
							Padding(3, 10)
					}).Fill()
				})
		})
	})
}

func (c *Controller) saveDraft() bool {
	d := c.editing
	if d == nil {
		return false
	}
	name := strings.TrimSpace(d.name)
	if name == "" {
		c.toast = "任务名称不能为空"
		return false
	}
	if d.interval < 1 {
		c.toast = "执行间隔必须大于 0"
		return false
	}
	variables := make([]Variable, 0, len(d.variables))
	for _, variable := range d.variables {
		variableName := strings.TrimSpace(variable.name)
		if variableName == "" {
			continue
		}
		value, err := parseVariableValue(variable.typ, variable.value)
		if err != nil {
			c.toast = "变量 " + variableName + " 的值无效: " + err.Error()
			return false
		}
		variables = append(variables, Variable{
			Name:  variableName,
			Type:  variableType(variable.typ),
			Value: value,
		})
	}

	script := d.script.Buffer.String()
	task := Task{
		ID:            d.id,
		Name:          name,
		Type:          TypeTerminal,
		Command:       d.command,
		StartAt:       jsontime.From(d.startAt),
		IntervalValue: int(d.interval),
		IntervalUnit:  unitFromLabel(d.unit),
		Variables:     variables,
		Enabled:       d.enabled,
		Script:        &script,
	}
	if d.taskType == 1 {
		task.Type = TypeJS
	}
	if d.timeout > 0 {
		timeout := int(d.timeout)
		task.TimeoutSeconds = &timeout
	}
	if d.editing {
		if err := c.deps.Engine.Update(task); err != nil {
			c.toast = "保存失败: " + err.Error()
			return false
		}
		return true
	}
	task.ID = id.New()
	if err := c.deps.Engine.Add(task); err != nil {
		c.toast = "保存失败: " + err.Error()
		return false
	}
	return true
}

func newDraft() *draft {
	buffer := editor.NewBuffer("")
	buffer.SetLanguage(editor.LanguageFor("task.js"))
	return &draft{
		taskType: 0,
		startAt:  time.Now().Add(time.Minute).Truncate(time.Minute),
		interval: 5,
		unit:     "分钟",
		enabled:  true,
		script:   &editor.State{Buffer: buffer},
	}
}

func draftFromTask(task Task) *draft {
	script := ""
	if task.Script != nil {
		script = *task.Script
	}
	buffer := editor.NewBuffer(script)
	buffer.SetLanguage(editor.LanguageFor("task.js"))
	result := &draft{
		id:       task.ID,
		name:     task.Name,
		command:  task.Command,
		startAt:  task.StartAt.Time,
		interval: float64(task.IntervalValue),
		unit:     unitLabel(task.IntervalUnit),
		enabled:  task.Enabled,
		script:   &editor.State{Buffer: buffer},
		editing:  true,
	}
	if task.Type == TypeJS {
		result.taskType = 1
	}
	if task.TimeoutSeconds != nil {
		result.timeout = float64(*task.TimeoutSeconds)
	}
	for _, variable := range task.Variables {
		result.variables = append(result.variables, variableDraft{
			name:  variable.Name,
			typ:   variableTypeLabel(variable.Type),
			value: formatVariableValue(variable.Value),
		})
	}
	return result
}

func labeled(x *ui.Context, p theme.Palette, label string, content func()) {
	ui.Column(x).FillWidth().Gap(6).Children(func() {
		widgets.FieldLabel(x, p, label)
		content()
	})
}

func taskTypeLabel(taskType TaskType) string {
	if taskType == TypeJS {
		return "JS 脚本"
	}
	return "终端命令"
}

func scheduleText(task Task) string {
	return fmt.Sprintf("每 %d %s，从 %s 开始",
		task.IntervalValue,
		unitLabel(task.IntervalUnit),
		task.StartAt.Format("2006-01-02 15:04"),
	)
}

func unitLabels() []string {
	return []string{"秒", "分钟", "小时", "天", "周", "月"}
}

func unitLabel(unit Unit) string {
	switch unit {
	case UnitSecond:
		return "秒"
	case UnitHour:
		return "小时"
	case UnitDay:
		return "天"
	case UnitWeek:
		return "周"
	case UnitMonth:
		return "月"
	default:
		return "分钟"
	}
}

func unitFromLabel(label string) Unit {
	switch label {
	case "秒":
		return UnitSecond
	case "小时":
		return UnitHour
	case "天":
		return UnitDay
	case "周":
		return UnitWeek
	case "月":
		return UnitMonth
	default:
		return UnitMinute
	}
}

func variableTypeLabels() []string {
	return []string{"字符串", "数字", "布尔", "对象"}
}

func variableTypeLabel(value string) string {
	switch value {
	case "number":
		return "数字"
	case "boolean":
		return "布尔"
	case "object":
		return "对象"
	default:
		return "字符串"
	}
}

func variableType(label string) string {
	switch label {
	case "数字":
		return "number"
	case "布尔":
		return "boolean"
	case "对象":
		return "object"
	default:
		return "string"
	}
}

func formatVariableValue(value any) string {
	if value == nil {
		return ""
	}
	if text, ok := value.(string); ok {
		return text
	}
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Sprint(value)
	}
	return string(data)
}

func parseVariableValue(label, raw string) (any, error) {
	switch label {
	case "数字":
		return strconv.ParseFloat(strings.TrimSpace(raw), 64)
	case "布尔":
		return strings.EqualFold(strings.TrimSpace(raw), "true"), nil
	case "对象":
		var value any
		if err := json.Unmarshal([]byte(raw), &value); err != nil {
			return nil, err
		}
		return value, nil
	default:
		return raw, nil
	}
}
