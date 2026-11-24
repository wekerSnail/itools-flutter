// Package tools describes the tools the home window lists.
package tools

// Spec is one tool: its identity, its text, its icon and its window size.
type Spec struct {
	ID          string
	Title       string
	Description string
	Icon        string
	Width       int
	Height      int
	MinWidth    int
	MinHeight   int
}

// All lists the tools in the order the home window shows them.
var All = []Spec{
	{
		ID:          "scheduler",
		Title:       "定时任务",
		Description: "按时间与周期执行命令",
		Icon:        "clock",
		Width:       950,
		Height:      700,
		MinWidth:    800,
		MinHeight:   550,
	},
	{
		ID:          "folder_mapping",
		Title:       "文件夹映射",
		Description: "快捷管理并双击打开目录",
		Icon:        "folder-open",
		Width:       900,
		Height:      650,
		MinWidth:    700,
		MinHeight:   500,
	},
	{
		ID:          "json_formatter",
		Title:       "JSON 格式化",
		Description: "格式化、压缩、转义与修复",
		Icon:        "braces",
		Width:       1000,
		Height:      700,
		MinWidth:    800,
		MinHeight:   550,
	},
}

// ByID finds a tool by its id.
func ByID(id string) (Spec, bool) {
	for _, spec := range All {
		if spec.ID == id {
			return spec, true
		}
	}
	return Spec{}, false
}
