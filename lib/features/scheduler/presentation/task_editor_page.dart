import 'dart:convert';
import 'dart:math';

import 'package:code_text_field/code_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
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
    if (value is String) return value;
    return jsonEncode(value);
  }

  String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  dynamic _parseObjectCompatible(String raw) {
    final input = raw.trim();
    if (input.isEmpty) throw const FormatException('object 类型不能为空');
    try {
      return jsonDecode(input);
    } catch (_) {}
    final normalized = _normalizeJsLikeObjectToJson(input);
    try {
      return jsonDecode(normalized);
    } catch (_) {
      throw const FormatException(
          'object 类型格式无效。\n示例：{"a":1,"name":"demo"} 或 {a:1, name:"demo"}');
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
          quoted.write(ch == '"' ? r'\"' : ch);
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
        quoted.write(ch == '"' ? r'\"' : ch);
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
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _openVariableEditor({int? index}) async {
    final original = index == null ? null : _variables[index];
    final nameCtrl = TextEditingController(text: original?.name ?? '');
    final valueCtrl = TextEditingController(
      text: original == null ? '' : _variableDisplayValue(original),
    );

    var type = original?.type ?? TaskVariableType.string;
    var boolValue =
        (original?.value is bool) ? original!.value as bool : false;
    String? validationMessage;

    final variable = await showDialog<TaskVariable>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          dynamic parsedValue() {
            switch (type) {
              case TaskVariableType.string:
                return valueCtrl.text;
              case TaskVariableType.number:
                final n = num.tryParse(valueCtrl.text.trim());
                if (n == null) {
                  throw const FormatException('number 类型请输入合法数字');
                }
                return n;
              case TaskVariableType.boolean:
                return boolValue;
              case TaskVariableType.object:
                return _parseObjectCompatible(valueCtrl.text);
            }
          }

          final shad = ShadTheme.of(context);
          return Dialog(
            backgroundColor: shad.colorScheme.background,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: SizedBox(
              width: 520,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(index == null ? '新增变量' : '编辑变量',
                        style: shad.textTheme.h4),
                    const SizedBox(height: 20),
                    ShadInput(
                      controller: nameCtrl,
                      placeholder: const Text('变量名'),
                    ),
                    const SizedBox(height: 12),
                    ShadSelect<TaskVariableType>(
                      key: ValueKey(type),
                      initialValue: type,
                      placeholder: const Text('变量类型'),
                      selectedOptionBuilder: (_, v) =>
                          Text(_variableTypeLabel(v)),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            type = v;
                            validationMessage = null;
                          });
                        }
                      },
                      options: TaskVariableType.values
                          .map((v) => ShadOption(
                              value: v,
                              child: Text(_variableTypeLabel(v))))
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    if (type == TaskVariableType.boolean)
                      Row(
                        children: [
                          ShadSwitch(
                            value: boolValue,
                            onChanged: (v) =>
                                setDialogState(() => boolValue = v),
                          ),
                          const SizedBox(width: 8),
                          Text(boolValue ? 'true' : 'false',
                              style: shad.textTheme.small),
                        ],
                      )
                    else
                      (type == TaskVariableType.object
                          ? ShadTextarea(
                              controller: valueCtrl,
                              placeholder: const Text('变量值（JSON / JS对象）'),
                              minHeight: 80,
                              maxHeight: 200,
                            )
                          : ShadTextarea(
                              controller: valueCtrl,
                              placeholder: const Text('变量值'),
                            )),
                    if (type == TaskVariableType.object) ...[
                      const SizedBox(height: 6),
                      Text(
                        '兼容模式：支持 {a:1}、单引号、尾逗号，保存时会按标准 JSON 解析。',
                        style: shad.textTheme.muted.copyWith(fontSize: 11),
                      ),
                    ],
                    if (validationMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationMessage!,
                        style: TextStyle(
                            color: shad.colorScheme.destructive,
                            fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShadButton.outline(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        ShadButton(
                          onPressed: () {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setDialogState(
                                  () => validationMessage = '变量名不能为空');
                              return;
                            }
                            try {
                              final value = parsedValue();
                              Navigator.of(context).pop(
                                  TaskVariable(
                                      name: name,
                                      type: type,
                                      value: value));
                            } catch (e) {
                              setDialogState(
                                  () => validationMessage = e.toString());
                            }
                          },
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nameCtrl.dispose();
    valueCtrl.dispose();

    if (variable == null || !mounted) return;
    setState(() {
      if (index == null) {
        _variables.add(variable);
      } else {
        _variables[index] = variable;
      }
    });
  }

  Widget _buildVariablesSection() {
    final shad = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('变量配置', style: shad.textTheme.p.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              ShadButton.outline(
                size: ShadButtonSize.sm,
                onPressed: () => _openVariableEditor(),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14),
                    SizedBox(width: 4),
                    Text('新增变量'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '支持 string / number / boolean / object。\n'
            '• 命令任务：使用 {{变量名}} 进行替换\n'
            '• JS脚本：通过 vars.变量名 访问',
            style: shad.textTheme.muted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (_variables.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('暂无变量，点击"新增变量"创建。',
                  style: shad.textTheme.muted),
            )
          else
            ...List.generate(_variables.length, (index) {
              final v = _variables[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: shad.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    ShadBadge.outline(
                        child: Text(_variableTypeLabel(v.type))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name,
                              style: shad.textTheme.small
                                  .copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            _variableDisplayValue(v),
                            style: shad.textTheme.muted
                                .copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () => _openVariableEditor(index: index),
                      child: const Icon(LucideIcons.pencil, size: 14),
                    ),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () =>
                          setState(() => _variables.removeAt(index)),
                      child: Icon(LucideIcons.trash2,
                          size: 14,
                          color: shad.colorScheme.destructive),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildCodeEditor() {
    final shad = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('JS 脚本编辑器',
                  style: shad.textTheme.p
                      .copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Icon(LucideIcons.gripHorizontal,
                  size: 16, color: shad.colorScheme.mutedForeground),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '支持语法高亮。通过 vars 对象访问变量。\n'
            '示例：console.log(vars.myName); vars.count++;',
            style: shad.textTheme.muted.copyWith(fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: _codeEditorHeight,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF3C3C3C)),
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
              onVerticalDragUpdate: (d) {
                setState(() {
                  _codeEditorHeight =
                      (_codeEditorHeight + d.delta.dy).clamp(100.0, 800.0);
                });
              },
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: shad.colorScheme.border,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 3,
                    decoration: BoxDecoration(
                      color: shad.colorScheme.mutedForeground,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(
      ShadToast(
        description: Text(message),
      ),
    );
  }

  void _saveTask() {
    if (_nameCtrl.text.trim().isEmpty) {
      _showToast('任务名不能为空');
      return;
    }
    if (_taskType == ScheduledTaskType.terminalCommand &&
        _commandCtrl.text.trim().isEmpty) {
      _showToast('终端命令不能为空');
      return;
    }
    if (_taskType == ScheduledTaskType.jsScript &&
        _scriptCodeCtrl.text.trim().isEmpty) {
      _showToast('JS脚本不能为空');
      return;
    }

    final savedTask = ScheduledTask(
      id: widget.initialTask?.id ??
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
    final shad = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: _isEditing ? '编辑任务' : '新增任务',
        showBack: true,
        actions: [
          ShadButton(
            size: ShadButtonSize.sm,
            onPressed: _saveTask,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.save, size: 15),
                SizedBox(width: 6),
                Text('保存'),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ShadInput(
            controller: _nameCtrl,
            placeholder: const Text('任务名称'),
          ),
          const SizedBox(height: 12),
          ShadSelect<ScheduledTaskType>(
            key: ValueKey(_taskType),
            initialValue: _taskType,
            placeholder: const Text('任务类型'),
            selectedOptionBuilder: (_, v) => Text(
              v == ScheduledTaskType.terminalCommand ? '终端命令任务' : 'JS脚本任务（Node.js）',
            ),
            onChanged: (v) {
              if (v != null) setState(() => _taskType = v);
            },
            options: const [
              ShadOption(
                value: ScheduledTaskType.terminalCommand,
                child: Text('终端命令任务'),
              ),
              ShadOption(
                value: ScheduledTaskType.jsScript,
                child: Text('JS脚本任务（Node.js）'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_taskType == ScheduledTaskType.terminalCommand)
            ShadTextarea(
              controller: _commandCtrl,
              placeholder: const Text('终端命令（支持 {{变量名}}）'),
              minHeight: 80,
            )
          else
            _buildCodeEditor(),
          const SizedBox(height: 12),
          _buildVariablesSection(),
          const SizedBox(height: 12),
          ShadButton.outline(
            onPressed: _pickStartAt,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.calendar, size: 15),
                const SizedBox(width: 6),
                Text('开始时间：${_formatDateTime(_startAt)}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ShadSelect<int>(
                  key: ValueKey(_intervalValue),
                  initialValue: _intervalValue,
                  placeholder: const Text('间隔'),
                  selectedOptionBuilder: (_, v) => Text('$v'),
                  onChanged: (v) {
                    if (v != null) setState(() => _intervalValue = v);
                  },
                  options: List.generate(60, (i) => i + 1)
                      .map((v) => ShadOption(
                            value: v,
                            child: Text('$v'),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ShadSelect<ScheduleUnit>(
                  key: ValueKey(_intervalUnit),
                  initialValue: _intervalUnit,
                  placeholder: const Text('单位'),
                  selectedOptionBuilder: (_, v) =>
                      Text(_scheduleUnitLabel(v)),
                  onChanged: (v) {
                    if (v != null) setState(() => _intervalUnit = v);
                  },
                  options: ScheduleUnit.values
                      .map((v) => ShadOption(
                            value: v,
                            child: Text(_scheduleUnitLabel(v)),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => setState(() {
                  _intervalValue = 1;
                  _intervalUnit = ScheduleUnit.second;
                }),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.zap, size: 13),
                    SizedBox(width: 4),
                    Text('秒级示例'),
                  ],
                ),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => setState(() {
                  _intervalValue = 5;
                  _intervalUnit = ScheduleUnit.minute;
                }),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.clock, size: 13),
                    SizedBox(width: 4),
                    Text('5分钟'),
                  ],
                ),
              ),
              ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => setState(() {
                  _intervalValue = 1;
                  _intervalUnit = ScheduleUnit.day;
                }),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.calendarDays, size: 13),
                    SizedBox(width: 4),
                    Text('按天示例'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
