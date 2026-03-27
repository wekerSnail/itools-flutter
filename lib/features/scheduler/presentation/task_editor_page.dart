import 'dart:convert';
import 'dart:math';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/javascript.dart';

import '../domain/scheduled_task.dart';

class TaskEditorPage extends StatefulWidget {
  const TaskEditorPage({super.key, this.initialTask});

  final ScheduledTask? initialTask;

  @override
  State<TaskEditorPage> createState() => _TaskEditorPageState();
}

class _TaskEditorPageState extends State<TaskEditorPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _commandCtrl = TextEditingController();
  late final CodeController _scriptCodeCtrl;

  final List<TaskVariable> _variables = <TaskVariable>[];

  late DateTime _startAt;
  late int _intervalValue;
  late ScheduleUnit _intervalUnit;
  late ScheduledTaskType _taskType;
  double _codeEditorHeight = 300;

  bool get _isEditing => widget.initialTask != null;

  @override
  void initState() {
    super.initState();
    _scriptCodeCtrl = CodeController(language: javascript, text: '');

    final task = widget.initialTask;
    if (task == null) {
      _startAt = DateTime.now().add(const Duration(minutes: 1));
      _intervalValue = 5;
      _intervalUnit = ScheduleUnit.minute;
      _taskType = ScheduledTaskType.terminalCommand;
      return;
    }

    _nameCtrl.text = task.name;
    _commandCtrl.text = task.command;
    _scriptCodeCtrl.text = task.script ?? '';
    _variables.addAll(task.variables.map((e) => e.copyWith()));
    _startAt = task.startAt;
    _intervalValue = task.intervalValue;
    _intervalUnit = task.intervalUnit;
    _taskType = task.type;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _commandCtrl.dispose();
    _scriptCodeCtrl.dispose();
    super.dispose();
  }

  String _scheduleUnitLabel(ScheduleUnit unit) {
    switch (unit) {
      case ScheduleUnit.second:
        return '秒';
      case ScheduleUnit.minute:
        return '分钟';
      case ScheduleUnit.hour:
        return '小时';
      case ScheduleUnit.day:
        return '天';
      case ScheduleUnit.week:
        return '周';
      case ScheduleUnit.month:
        return '月';
    }
  }

  String _variableTypeLabel(TaskVariableType type) {
    switch (type) {
      case TaskVariableType.string:
        return 'string';
      case TaskVariableType.number:
        return 'number';
      case TaskVariableType.boolean:
        return 'boolean';
      case TaskVariableType.object:
        return 'object';
    }
  }

  String _variableDisplayValue(TaskVariable variable) {
    final value = variable.value;
    if (value is String) {
      return value;
    }
    return jsonEncode(value);
  }

  String _formatDateTime(DateTime dt) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  dynamic _parseObjectCompatible(String raw) {
    final input = raw.trim();
    if (input.isEmpty) {
      throw const FormatException('object 类型不能为空');
    }

    // 1) Strict JSON first.
    try {
      return jsonDecode(input);
    } catch (_) {
      // continue with compatibility mode
    }

    // 2) Compatibility mode for JS-like object literal:
    // - unquoted keys: {a:1} -> {"a":1}
    // - single quoted strings: {'a':'b'} -> {"a":"b"}
    // - trailing commas: {"a":1,} -> {"a":1}
    final normalized = _normalizeJsLikeObjectToJson(input);

    try {
      return jsonDecode(normalized);
    } catch (_) {
      throw const FormatException(
        'object 类型格式无效。\n示例：{"a":1,"name":"demo"} 或 {a:1, name:"demo"}',
      );
    }
  }

  String _normalizeJsLikeObjectToJson(String input) {
    final quoted = StringBuffer();
    var inDouble = false;
    var inSingle = false;
    var escaping = false;

    for (var i = 0; i < input.length; i++) {
      final ch = input[i];

      if (inSingle) {
        if (escaping) {
          if (ch == '"') {
            quoted.write(r'\"');
          } else {
            quoted.write(ch);
          }
          escaping = false;
          continue;
        }

        if (ch == r'\') {
          quoted.write(ch);
          escaping = true;
          continue;
        }

        if (ch == "'") {
          quoted.write('"');
          inSingle = false;
          continue;
        }

        if (ch == '"') {
          quoted.write(r'\"');
        } else {
          quoted.write(ch);
        }
        continue;
      }

      if (inDouble) {
        quoted.write(ch);
        if (escaping) {
          escaping = false;
          continue;
        }
        if (ch == r'\') {
          escaping = true;
        } else if (ch == '"') {
          inDouble = false;
        }
        continue;
      }

      if (ch == '"') {
        inDouble = true;
        quoted.write(ch);
        continue;
      }

      if (ch == "'") {
        inSingle = true;
        quoted.write('"');
        continue;
      }

      quoted.write(ch);
    }

    var normalized = quoted.toString();

    normalized = normalized.replaceAllMapped(
      RegExp(r'([\{,]\s*)([A-Za-z_\$][A-Za-z0-9_\$-]*)(\s*):'),
      (m) => '${m[1]}"${m[2]}"${m[3]}:',
    );

    normalized = normalized.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
    return normalized;
  }

  Future<void> _pickStartAt() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2100),
      initialDate: _startAt,
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null || !mounted) {
      return;
    }

    setState(() {
      _startAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _openVariableEditor({int? index}) async {
    final original = index == null ? null : _variables[index];
    final nameCtrl = TextEditingController(text: original?.name ?? '');
    final valueCtrl = TextEditingController(
      text: original == null ? '' : _variableDisplayValue(original),
    );

    var type = original?.type ?? TaskVariableType.string;
    var boolValue = (original?.value is bool) ? original!.value as bool : false;
    String? validationMessage;

    final variable = await showDialog<TaskVariable>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dynamic parsedValue() {
              switch (type) {
                case TaskVariableType.string:
                  return valueCtrl.text;
                case TaskVariableType.number:
                  final numValue = num.tryParse(valueCtrl.text.trim());
                  if (numValue == null) {
                    throw const FormatException('number 类型请输入合法数字');
                  }
                  return numValue;
                case TaskVariableType.boolean:
                  return boolValue;
                case TaskVariableType.object:
                  return _parseObjectCompatible(valueCtrl.text);
              }
            }

            return AlertDialog(
              title: Text(index == null ? '新增变量' : '编辑变量'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '变量名',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<TaskVariableType>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: '变量类型',
                        border: OutlineInputBorder(),
                      ),
                      items: TaskVariableType.values
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text(_variableTypeLabel(v)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            type = value;
                            validationMessage = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (type == TaskVariableType.boolean)
                      SwitchListTile(
                        value: boolValue,
                        title: const Text('布尔值'),
                        subtitle: Text(boolValue ? 'true' : 'false'),
                        onChanged: (v) => setDialogState(() => boolValue = v),
                      )
                    else
                      TextField(
                        controller: valueCtrl,
                        minLines: type == TaskVariableType.object ? 4 : 1,
                        maxLines: type == TaskVariableType.object ? 8 : 1,
                        decoration: InputDecoration(
                          labelText: type == TaskVariableType.object
                              ? '变量值（JSON / JS对象）'
                              : '变量值',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    if (type == TaskVariableType.object)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '兼容模式：支持 {a:1}、单引号、尾逗号，保存时会按标准 JSON 解析。',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ),
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setDialogState(() => validationMessage = '变量名不能为空');
                      return;
                    }

                    try {
                      final value = parsedValue();
                      Navigator.of(
                        context,
                      ).pop(TaskVariable(name: name, type: type, value: value));
                    } catch (e) {
                      setDialogState(() => validationMessage = e.toString());
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    valueCtrl.dispose();

    if (variable == null || !mounted) {
      return;
    }

    setState(() {
      if (index == null) {
        _variables.add(variable);
      } else {
        _variables[index] = variable;
      }
    });
  }

  Widget _buildVariablesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('变量配置', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () => _openVariableEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('新增变量'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '支持 string / number / boolean / object。\n'
              '• 命令任务：使用 {{变量名}} 进行替换\n'
              '• JS脚本：通过 vars.变量名 访问（如 vars.myVar、vars.config.key）',
            ),
            const SizedBox(height: 8),
            if (_variables.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无变量，点击“新增变量”创建。'),
              )
            else
              ...List.generate(_variables.length, (index) {
                final variable = _variables[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(variable.name),
                  subtitle: Text(
                    _variableDisplayValue(variable),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  leading: Chip(label: Text(_variableTypeLabel(variable.type))),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '编辑变量',
                        onPressed: () => _openVariableEditor(index: index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: '删除变量',
                        onPressed: () =>
                            setState(() => _variables.removeAt(index)),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCodeEditor() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'JS 脚本编辑器',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Tooltip(
                  message: '向下拖动分割线调整编辑框大小',
                  child: Icon(
                    Icons.drag_indicator,
                    color: Colors.grey[600],
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '支持语法高亮。通过 vars 对象访问变量。\n'
              '示例：console.log(vars.myName); vars.count++; var data = vars.config;',
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: _codeEditorHeight,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: SingleChildScrollView(
                  child: CodeTheme(
                    data: CodeThemeData(styles: atomOneDarkTheme),
                    child: CodeField(
                      controller: _scriptCodeCtrl,
                      textStyle: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _codeEditorHeight = (_codeEditorHeight + details.delta.dy)
                        .clamp(100.0, 800.0);
                  });
                },
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTask() {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('任务名不能为空')));
      return;
    }

    if (_taskType == ScheduledTaskType.terminalCommand &&
        _commandCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('终端命令不能为空')));
      return;
    }

    if (_taskType == ScheduledTaskType.jsScript &&
        _scriptCodeCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('JS脚本不能为空')));
      return;
    }

    final savedTask = ScheduledTask(
      id:
          widget.initialTask?.id ??
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
      name: _nameCtrl.text.trim(),
      type: _taskType,
      command: _commandCtrl.text.trim(),
      startAt: _startAt,
      intervalValue: _intervalValue,
      intervalUnit: _intervalUnit,
      variables: List<TaskVariable>.from(_variables),
      enabled: widget.initialTask?.enabled ?? true,
      script: _scriptCodeCtrl.text.trim().isEmpty
          ? null
          : _scriptCodeCtrl.text.trim(),
    );

    Navigator.of(context).pop(savedTask);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑任务' : '新增任务'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saveTask,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '任务名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ScheduledTaskType>(
            initialValue: _taskType,
            decoration: const InputDecoration(
              labelText: '任务类型',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: ScheduledTaskType.terminalCommand,
                child: Text('终端命令任务'),
              ),
              DropdownMenuItem(
                value: ScheduledTaskType.jsScript,
                child: Text('JS脚本任务（Node.js）'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _taskType = value);
              }
            },
          ),
          const SizedBox(height: 12),
          if (_taskType == ScheduledTaskType.terminalCommand)
            TextField(
              controller: _commandCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '终端命令（支持 {{变量名}}）',
                border: OutlineInputBorder(),
              ),
            )
          else
            _buildCodeEditor(),
          const SizedBox(height: 12),
          _buildVariablesSection(),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickStartAt,
            icon: const Icon(Icons.event),
            label: Text('开始时间：${_formatDateTime(_startAt)}'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _intervalValue,
                  decoration: const InputDecoration(
                    labelText: '间隔',
                    border: OutlineInputBorder(),
                  ),
                  items: List<int>.generate(60, (index) => index + 1)
                      .map(
                        (e) =>
                            DropdownMenuItem<int>(value: e, child: Text('$e')),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _intervalValue = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ScheduleUnit>(
                  initialValue: _intervalUnit,
                  decoration: const InputDecoration(
                    labelText: '单位',
                    border: OutlineInputBorder(),
                  ),
                  items: ScheduleUnit.values
                      .map(
                        (e) => DropdownMenuItem<ScheduleUnit>(
                          value: e,
                          child: Text(_scheduleUnitLabel(e)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _intervalUnit = value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _intervalValue = 1;
                    _intervalUnit = ScheduleUnit.second;
                  });
                },
                icon: const Icon(Icons.bolt),
                label: const Text('秒级示例'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _intervalValue = 5;
                    _intervalUnit = ScheduleUnit.minute;
                  });
                },
                icon: const Icon(Icons.schedule),
                label: const Text('5分钟'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _intervalValue = 1;
                    _intervalUnit = ScheduleUnit.day;
                  });
                },
                icon: const Icon(Icons.today),
                label: const Text('按天示例'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
