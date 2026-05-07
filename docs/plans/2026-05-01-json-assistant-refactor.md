# JSON助手功能重构计划 - 类似utools

> **状态：已调整方向并完成实现（2026-05-07）**
>
> 原计划的树形视图方案已调整为**左右分栏代码编辑器**方案，更贴近实际使用场景。
> 以下为最终实现记录。

**Goal:** 重构JSON格式化工具，提供更好的编辑和处理体验

**Architecture:**

- 左右分栏布局（输入/输出），支持可拖拽分割面板
- 使用 `re_editor` 代码编辑器提供 JSON 语法高亮和行号
- 实时 JSON 验证（300ms 防抖）
- 智能修复功能（多策略组合）
- 移除不需要的转Dart/TypeScript功能

**Tech Stack:** Flutter, shadcn_ui, dart:convert, re_editor, re_highlight

---

## 实际完成的功能

### ✅ 已完成

1. ✅ JSON格式化/压缩
2. ✅ 转义/反转义
3. ✅ 智能修复（单引号替换、未引用键名补全、尾部逗号移除、括号补全、截断修复）
4. ✅ 左右分栏代码编辑器（re_editor + re_highlight 语法高亮）
5. ✅ 行号显示
6. ✅ 可拖拽分割面板（20%~80% 比例调节）
7. ✅ 实时 JSON 验证（300ms 防抖）
8. ✅ 错误提示和状态栏
9. ✅ 交换输入输出
10. ✅ 复制输出到剪贴板

### ❌ 已移除（不再需要）

- ~~转Dart Map~~
- ~~转TypeScript接口~~

### ⏸️ 未实现（原计划但最终未采用）

- ~~树形视图展开收起~~（改为代码编辑器方案）
- ~~JSON路径显示/复制~~
- ~~语法高亮组件（自定义实现）~~（改用 re_highlight 库）

---

## 最终文件结构

```
lib/features/json_formatter/
├── domain/
│   └── json_formatter_service.dart      # JSON处理服务（格式化、压缩、转义、智能修复）
└── presentation/
    ├── json_formatter_page.dart          # 主页面（分栏布局、状态管理）
    └── widgets/
        ├── json_code_editor.dart         # 代码编辑器组件（re_editor 封装）
        └── json_toolbar.dart             # 工具栏组件
```

---

## 原始计划（仅供参考，已调整方向）

<details>
<summary>点击展开原始树形视图计划</summary>

### 原始功能需求分析

#### utools JSON助手核心功能

1. ✅ JSON格式化/压缩
2. ~~树形视图 - 可展开/收起~~ → 改为代码编辑器
3. ~~JSON路径显示 - 点击节点显示路径~~ → 未实现
4. ✅ 复制功能 - 复制整个JSON
5. ✅ JSON验证
6. ✅ 错误提示
7. ✅ 智能修复（新增）

#### 不需要的功能

- ❌ 转Dart Map
- ❌ 转TypeScript接口

</details>

---

## Task 1: 创建JSON节点数据模型

**Files:**

- Create: `lib/features/json_formatter/presentation/models/json_node_model.dart`

- [ ] **Step 1: 创建JSON节点模型**

```dart
import 'dart:convert';

enum JsonNodeType {
  object,
  array,
  string,
  number,
  boolean,
  nullValue,
}

class JsonNodeModel {
  JsonNodeModel({
    required this.key,
    required this.value,
    required this.type,
    required this.path,
    this.isExpanded = false,
    this.children = const [],
  });

  final String key;
  final dynamic value;
  final JsonNodeType type;
  final String path;
  bool isExpanded;
  final List<JsonNodeModel> children;

  bool get isExpandable => type == JsonNodeType.object || type == JsonNodeType.array;

  String get displayValue {
    switch (type) {
      case JsonNodeType.string:
        return '"$value"';
      case JsonNodeType.nullValue:
        return 'null';
      case JsonNodeType.boolean:
        return value.toString();
      case JsonNodeType.number:
        return value.toString();
      case JsonNodeType.object:
        return '{${children.length}}';
      case JsonNodeType.array:
        return '[${children.length}]';
    }
  }

  String get pathDisplay => path;

  static List<JsonNodeModel> fromJson(String jsonString) {
    final dynamic parsed = json.decode(jsonString);
    return _buildNodes(parsed, '');
  }

  static List<JsonNodeModel> _buildNodes(dynamic value, String parentPath) {
    if (value is Map) {
      return value.entries.map((entry) {
        final path = parentPath.isEmpty ? entry.key : '$parentPath.${entry.key}';
        final children = _buildNodes(entry.value, path);
        return JsonNodeModel(
          key: entry.key,
          value: entry.value,
          type: _getType(entry.value),
          path: path,
          children: children,
        );
      }).toList();
    } else if (value is List) {
      return value.asMap().entries.map((entry) {
        final path = parentPath.isEmpty ? '${entry.key}' : '$parentPath.${entry.key}';
        final children = _buildNodes(entry.value, path);
        return JsonNodeModel(
          key: '${entry.key}',
          value: entry.value,
          type: _getType(entry.value),
          path: path,
          children: children,
        );
      }).toList();
    }
    return [];
  }

  static JsonNodeType _getType(dynamic value) {
    if (value == null) return JsonNodeType.nullValue;
    if (value is String) return JsonNodeType.string;
    if (value is num) return JsonNodeType.number;
    if (value is bool) return JsonNodeType.boolean;
    if (value is Map) return JsonNodeType.object;
    if (value is List) return JsonNodeType.array;
    return JsonNodeType.string;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/presentation/models/
git commit -m "feat: add json node model for tree view"
```

---

## Task 2: 重构JsonFormatterService

**Files:**

- Modify: `lib/features/json_formatter/domain/json_formatter_service.dart`

- [ ] **Step 1: 简化服务，移除不需要的方法**

重构 `lib/features/json_formatter/domain/json_formatter_service.dart`：

```dart
import 'dart:convert';

class JsonFormatterService {
  /// 格式化JSON字符串
  String format(String input, {int indent = 2}) {
    try {
      final dynamic parsed = _decodeJson(input);
      return const JsonEncoder.withIndent('  ').convert(parsed);
    } catch (e) {
      rethrow;
    }
  }

  /// 压缩JSON字符串
  String minify(String input) {
    try {
      final dynamic parsed = _decodeJson(input);
      return json.encode(parsed);
    } catch (e) {
      rethrow;
    }
  }

  /// 验证JSON是否有效
  bool isValid(String input) {
    try {
      _decodeJson(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 获取JSON错误信息
  String? getErrorMessage(String input) {
    try {
      _decodeJson(input);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// 转义JSON字符串
  String escape(String input) {
    return json.encode(input);
  }

  /// 反转义JSON字符串
  String unescape(String input) {
    try {
      final String unescaped = _decodeJson(input);
      return unescaped;
    } catch (e) {
      rethrow;
    }
  }

  /// 内部JSON解码方法，统一错误处理
  dynamic _decodeJson(String input) {
    try {
      return json.decode(input);
    } catch (e) {
      throw FormatException('无效的JSON格式: $e');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/domain/json_formatter_service.dart
git commit -m "refactor: simplify json formatter service, remove dart/ts conversion"
```

---

## Task 3: 实现语法高亮组件

**Files:**

- Create: `lib/features/json_formatter/presentation/widgets/json_syntax_highlighter.dart`

- [ ] **Step 1: 创建语法高亮组件**

```dart
import 'package:flutter/material.dart';

class JsonSyntaxHighlighter extends StatelessWidget {
  const JsonSyntaxHighlighter({
    super.key,
    required this.text,
    this.style,
  });

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: _buildTextSpan(context),
    );
  }

  TextSpan _buildTextSpan(BuildContext context) {
    final defaultStyle = style ?? const TextStyle(fontSize: 13);

    return TextSpan(
      children: _parseJson(text, defaultStyle),
    );
  }

  List<TextSpan> _parseJson(String json, TextStyle defaultStyle) {
    final List<TextSpan> spans = [];
    final buffer = StringBuffer();
    bool inString = false;
    bool escapeNext = false;

    for (int i = 0; i < json.length; i++) {
      final char = json[i];

      if (escapeNext) {
        buffer.write(char);
        escapeNext = false;
        continue;
      }

      if (char == '\\' && inString) {
        buffer.write(char);
        escapeNext = true;
        continue;
      }

      if (char == '"') {
        if (inString) {
          buffer.write(char);
          spans.add(TextSpan(
            text: buffer.toString(),
            style: defaultStyle.copyWith(color: const Color(0xFF22C55E)), // 绿色
          ));
          buffer.clear();
          inString = false;
        } else {
          if (buffer.isNotEmpty) {
            spans.add(TextSpan(
              text: buffer.toString(),
              style: defaultStyle,
            ));
            buffer.clear();
          }
          buffer.write(char);
          inString = true;
        }
        continue;
      }

      if (inString) {
        buffer.write(char);
        continue;
      }

      // 处理非字符串内容
      if (char == '{' || char == '}' || char == '[' || char == ']') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: defaultStyle,
          ));
          buffer.clear();
        }
        spans.add(TextSpan(
          text: char,
          style: defaultStyle.copyWith(color: defaultStyle.color),
        ));
      } else if (char == ':') {
        if (buffer.isNotEmpty) {
          spans.add(TextSpan(
            text: buffer.toString(),
            style: defaultStyle,
          ));
          buffer.clear();
        }
        spans.add(TextSpan(
          text: char,
          style: defaultStyle,
        ));
      } else if (char == ',') {
        if (buffer.isNotEmpty) {
          final word = buffer.toString();
          spans.add(TextSpan(
            text: word,
            style: _getValueStyle(word, defaultStyle),
          ));
          buffer.clear();
        }
        spans.add(TextSpan(
          text: char,
          style: defaultStyle,
        ));
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      final word = buffer.toString();
      spans.add(TextSpan(
        text: word,
        style: inString
            ? defaultStyle.copyWith(color: const Color(0xFF22C55E))
            : _getValueStyle(word, defaultStyle),
      ));
    }

    return spans;
  }

  TextStyle _getValueStyle(String value, TextStyle defaultStyle) {
    if (value == 'true' || value == 'false') {
      return defaultStyle.copyWith(color: const Color(0xFFA855F7)); // 紫色
    }
    if (value == 'null') {
      return defaultStyle.copyWith(color: const Color(0xFF6B7280)); // 灰色
    }
    if (num.tryParse(value) != null) {
      return defaultStyle.copyWith(color: const Color(0xFF3B82F6)); // 蓝色
    }
    return defaultStyle;
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/presentation/widgets/json_syntax_highlighter.dart
git commit -m "feat: add json syntax highlighter component"
```

---

## Task 4: 实现树节点组件

**Files:**

- Create: `lib/features/json_formatter/presentation/widgets/json_tree_node.dart`

- [ ] **Step 1: 创建树节点组件**

```dart
import 'package:flutter/material.dart';
import '../models/json_node_model.dart';
import 'json_syntax_highlighter.dart';

class JsonTreeNode extends StatefulWidget {
  const JsonTreeNode({
    super.key,
    required this.node,
    required this.depth,
    required this.onNodeTap,
    required this.onCopy,
  });

  final JsonNodeModel node;
  final int depth;
  final void Function(JsonNodeModel node) onNodeTap;
  final void Function(JsonNodeModel node) onCopy;

  @override
  State<JsonTreeNode> createState() => _JsonTreeNodeState();
}

class _JsonTreeNodeState extends State<JsonTreeNode> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNodeHeader(),
        if (widget.node.isExpanded && widget.node.isExpandable)
          _buildChildren(),
      ],
    );
  }

  Widget _buildNodeHeader() {
    final indent = widget.depth * 20.0;

    return InkWell(
      onTap: () {
        if (widget.node.isExpandable) {
          setState(() {
            widget.node.isExpanded = !widget.node.isExpanded;
          });
        }
        widget.onNodeTap(widget.node);
      },
      onSecondaryTap: () => widget.onCopy(widget.node),
      child: Container(
        padding: EdgeInsets.only(left: indent, top: 2, bottom: 2, right: 8),
        child: Row(
          children: [
            if (widget.node.isExpandable)
              Icon(
                widget.node.isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 16,
                color: Colors.grey[600],
              )
            else
              const SizedBox(width: 16),
            const SizedBox(width: 4),
            if (widget.node.key.isNotEmpty) ...[
              Text(
                '"${widget.node.key}"',
                style: TextStyle(
                  color: const Color(0xFFE06C75),
                  fontSize: 13,
                  fontFamily: 'Consolas',
                ),
              ),
              Text(
                ': ',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontFamily: 'Consolas',
                ),
              ),
            ],
            _buildValue(),
          ],
        ),
      ),
    );
  }

  Widget _buildValue() {
    if (widget.node.isExpandable) {
      final bracket = widget.node.type == JsonNodeType.object ? '{' : '[';
      final count = widget.node.children.length;
      return Text(
        '$bracket $count ${widget.node.type == JsonNodeType.object ? 'keys' : 'items'}',
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 13,
          fontFamily: 'Consolas',
        ),
      );
    }

    return JsonSyntaxHighlighter(
      text: widget.node.displayValue,
      style: const TextStyle(
        fontSize: 13,
        fontFamily: 'Consolas',
      ),
    );
  }

  Widget _buildChildren() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...widget.node.children.map((child) => JsonTreeNode(
              node: child,
              depth: widget.depth + 1,
              onNodeTap: widget.onNodeTap,
              onCopy: widget.onCopy,
            )),
        _buildClosingBracket(),
      ],
    );
  }

  Widget _buildClosingBracket() {
    final indent = widget.depth * 20.0;
    final bracket = widget.node.type == JsonNodeType.object ? '}' : ']';

    return Container(
      padding: EdgeInsets.only(left: indent, top: 2, bottom: 2),
      child: Text(
        bracket,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
          fontFamily: 'Consolas',
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/presentation/widgets/json_tree_node.dart
git commit -m "feat: add json tree node component"
```

---

## Task 5: 实现树形视图组件

**Files:**

- Create: `lib/features/json_formatter/presentation/widgets/json_tree_view.dart`

- [ ] **Step 1: 创建树形视图组件**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/json_node_model.dart';
import 'json_tree_node.dart';

class JsonTreeView extends StatefulWidget {
  const JsonTreeView({
    super.key,
    required this.jsonString,
    required this.onPathChanged,
  });

  final String jsonString;
  final void Function(String path) onPathChanged;

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  List<JsonNodeModel>? _nodes;
  String? _error;
  String _currentPath = '';

  @override
  void initState() {
    super.initState();
    _parseJson();
  }

  @override
  void didUpdateWidget(JsonTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jsonString != widget.jsonString) {
      _parseJson();
    }
  }

  void _parseJson() {
    if (widget.jsonString.isEmpty) {
      setState(() {
        _nodes = null;
        _error = null;
      });
      return;
    }

    try {
      final nodes = JsonNodeModel.fromJson(widget.jsonString);
      setState(() {
        _nodes = nodes;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _nodes = null;
        _error = e.toString();
      });
    }
  }

  void _handleNodeTap(JsonNodeModel node) {
    setState(() {
      _currentPath = node.path;
    });
    widget.onPathChanged(node.path);
  }

  void _handleCopy(JsonNodeModel node) {
    final text = node.isExpandable
        ? node.displayValue
        : node.value.toString();
    Clipboard.setData(ClipboardData(text: text));
    _showToast('已复制: $text');
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'JSON解析错误: $_error',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_nodes == null || _nodes!.isEmpty) {
      return const Center(
        child: Text(
          '请输入JSON内容',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        if (_currentPath.isNotEmpty)
          _buildPathBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _nodes!.map((node) => JsonTreeNode(
                node: node,
                depth: 0,
                onNodeTap: _handleNodeTap,
                onCopy: _handleCopy,
              )).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPathBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.route, size: 14, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            '路径: $_currentPath',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontFamily: 'Consolas',
            ),
          ),
          const Spacer(),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _currentPath));
              _showToast('已复制路径');
            },
            child: const Icon(Icons.copy, size: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/presentation/widgets/json_tree_view.dart
git commit -m "feat: add json tree view component"
```

---

## Task 6: 实现工具栏组件

**Files:**

- Create: `lib/features/json_formatter/presentation/widgets/json_toolbar.dart`

- [ ] **Step 1: 创建工具栏组件**

```dart
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum JsonOperation {
  format,
  minify,
  escape,
  unescape,
}

class JsonToolbar extends StatelessWidget {
  const JsonToolbar({
    super.key,
    required this.selectedOperation,
    required this.onOperationChanged,
    required this.onExecute,
    required this.onSwap,
    required this.onCopy,
    required this.onClear,
    required this.onFormat,
    required this.onMinify,
  });

  final JsonOperation selectedOperation;
  final void Function(JsonOperation) onOperationChanged;
  final VoidCallback onExecute;
  final VoidCallback onSwap;
  final VoidCallback onCopy;
  final VoidCallback onClear;
  final VoidCallback onFormat;
  final VoidCallback onMinify;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          _buildOperationButton('格式化', JsonOperation.format, Icons.format_align_left),
          const SizedBox(width: 6),
          _buildOperationButton('压缩', JsonOperation.minify, Icons.compress),
          const SizedBox(width: 6),
          _buildOperationButton('转义', JsonOperation.escape, Icons.code),
          const SizedBox(width: 6),
          _buildOperationButton('反转义', JsonOperation.unescape, Icons.chevron_right),
          const Spacer(),
          _buildActionButton('格式化', Icons.play_arrow, onFormat),
          const SizedBox(width: 6),
          _buildActionButton('压缩', Icons.compress, onMinify),
          const SizedBox(width: 6),
          _buildActionButton('交换', Icons.swap_horiz, onSwap),
          const SizedBox(width: 6),
          _buildActionButton('复制', Icons.copy, onCopy),
          const SizedBox(width: 6),
          _buildActionButton('清空', Icons.clear_all, onClear),
        ],
      ),
    );
  }

  Widget _buildOperationButton(String label, JsonOperation operation, IconData icon) {
    final isSelected = selectedOperation == operation;

    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: () => onOperationChanged(operation),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isSelected ? Colors.blue : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onPressed) {
    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/presentation/widgets/json_toolbar.dart
git commit -m "feat: add json toolbar component"
```

---

## Task 7: 重构主页面

**Files:**

- Modify: `lib/features/json_formatter/presentation/json_formatter_page.dart`

- [ ] **Step 1: 重构主页面**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../domain/json_formatter_service.dart';
import 'models/json_node_model.dart';
import 'widgets/json_tree_view.dart';
import 'widgets/json_toolbar.dart';

class JsonFormatterPage extends StatefulWidget {
  const JsonFormatterPage({super.key});

  @override
  State<JsonFormatterPage> createState() => _JsonFormatterPageState();
}

class _JsonFormatterPageState extends State<JsonFormatterPage> {
  final JsonFormatterService _service = JsonFormatterService();
  final TextEditingController _inputController = TextEditingController();

  String _outputText = '';
  String _currentPath = '';
  JsonOperation _selectedOperation = JsonOperation.format;
  bool _isValidJson = true;
  String? _errorMessage;
  bool _showTreeView = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final input = _inputController.text;
    setState(() {
      _isValidJson = _service.isValid(input);
      _errorMessage = _isValidJson ? null : _service.getErrorMessage(input);
    });
  }

  void _formatJson() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _showToast('请输入JSON内容');
      return;
    }

    try {
      final result = _service.format(input);
      setState(() {
        _outputText = result;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showToast('格式化失败: $e');
    }
  }

  void _minifyJson() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _showToast('请输入JSON内容');
      return;
    }

    try {
      final result = _service.minify(input);
      setState(() {
        _outputText = result;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showToast('压缩失败: $e');
    }
  }

  void _executeOperation() {
    final input = _inputController.text.trim();
    if (input.isEmpty) {
      _showToast('请输入JSON内容');
      return;
    }

    try {
      String result;
      switch (_selectedOperation) {
        case JsonOperation.format:
          result = _service.format(input);
          break;
        case JsonOperation.minify:
          result = _service.minify(input);
          break;
        case JsonOperation.escape:
          result = _service.escape(input);
          break;
        case JsonOperation.unescape:
          result = _service.unescape(input);
          break;
      }

      setState(() {
        _outputText = result;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showToast('操作失败: $e');
    }
  }

  void _swapInputOutput() {
    if (_outputText.isEmpty) {
      _showToast('没有输出内容可交换');
      return;
    }

    final temp = _inputController.text;
    _inputController.text = _outputText;
    setState(() {
      _outputText = temp;
    });
  }

  void _copyOutput() {
    if (_outputText.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _outputText));
      _showToast('已复制到剪贴板');
    }
  }

  void _clearAll() {
    _inputController.clear();
    setState(() {
      _outputText = '';
      _errorMessage = null;
      _currentPath = '';
    });
  }

  void _handlePathChanged(String path) {
    setState(() {
      _currentPath = path;
    });
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: 'JSON 助手',
        subtitle: '格式化、压缩、验证JSON数据',
        showBack: true,
        actions: [
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: () => setState(() => _showTreeView = !_showTreeView),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _showTreeView ? Icons.code : Icons.account_tree,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(_showTreeView ? '代码视图' : '树形视图'),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          JsonToolbar(
            selectedOperation: _selectedOperation,
            onOperationChanged: (op) => setState(() => _selectedOperation = op),
            onExecute: _executeOperation,
            onSwap: _swapInputOutput,
            onCopy: _copyOutput,
            onClear: _clearAll,
            onFormat: _formatJson,
            onMinify: _minifyJson,
          ),
          Expanded(
            child: _showTreeView ? _buildTreeView() : _buildCodeView(shad),
          ),
          _buildStatusBar(shad),
        ],
      ),
    );
  }

  Widget _buildTreeView() {
    return Row(
      children: [
        Expanded(
          child: _buildInputPanel(),
        ),
        Container(
          width: 1,
          color: Colors.grey[300],
        ),
        Expanded(
          child: JsonTreeView(
            jsonString: _outputText.isNotEmpty ? _outputText : _inputController.text,
            onPathChanged: _handlePathChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCodeView(ShadThemeData shad) {
    return Row(
      children: [
        Expanded(
          child: _buildInputPanel(),
        ),
        Container(
          width: 1,
          color: shad.colorScheme.border,
        ),
        Expanded(
          child: _buildOutputPanel(shad),
        ),
      ],
    );
  }

  Widget _buildInputPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Text(
                '输入',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              if (!_isValidJson && _inputController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '格式错误',
                    style: TextStyle(fontSize: 11, color: Colors.red),
                  ),
                )
              else if (_inputController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '格式正确',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: TextField(
            controller: _inputController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: const TextStyle(
              fontFamily: 'Consolas',
              fontSize: 13,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: '请输入JSON内容...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              contentPadding: const EdgeInsets.all(12),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutputPanel(ShadThemeData shad) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: [
              const Text(
                '输出',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const Spacer(),
              if (_outputText.isNotEmpty) ...[
                Text(
                  '${_outputText.split('\n').length} 行',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _copyOutput,
                  child: const Icon(Icons.copy, size: 14, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.red[50],
            child: Text(
              _errorMessage!,
              style: TextStyle(fontSize: 12, color: Colors.red[700]),
            ),
          ),
        Expanded(
          child: Container(
            color: Colors.white,
            child: _outputText.isEmpty
                ? Center(
                    child: Text(
                      '输出结果将显示在这里',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _outputText,
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBar(ShadThemeData shad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Icon(
            _isValidJson ? Icons.check_circle : Icons.error,
            size: 14,
            color: _isValidJson ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            _isValidJson ? 'JSON格式有效' : 'JSON格式无效',
            style: TextStyle(
              fontSize: 12,
              color: _isValidJson ? Colors.green : Colors.red,
            ),
          ),
          if (_currentPath.isNotEmpty) ...[
            const SizedBox(width: 16),
            const Icon(Icons.route, size: 14, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              '路径: $_currentPath',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          const Spacer(),
          Text(
            '操作: ${_getOperationName(_selectedOperation)}',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _getOperationName(JsonOperation operation) {
    switch (operation) {
      case JsonOperation.format:
        return '格式化';
      case JsonOperation.minify:
        return '压缩';
      case JsonOperation.escape:
        return '转义';
      case JsonOperation.unescape:
        return '反转义';
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/json_formatter/presentation/json_formatter_page.dart
git commit -m "feat: refactor json formatter page with tree view support"
```

---

## Task 8: 验证和测试

- [ ] **Step 1: 运行代码分析**

```bash
flutter analyze
```

Expected: 无错误

- [ ] **Step 2: 构建应用**

```bash
flutter build windows --release
```

Expected: 构建成功

- [ ] **Step 3: Final Commit**

```bash
git add .
git commit -m "feat: complete json assistant with tree view and syntax highlighting"
```

---

## 总结

本计划实现了类似utools的JSON助手功能：

1. ✅ **树形视图** - 可展开/收起的树形结构
2. ✅ **语法高亮** - 字符串(绿色)、数字(蓝色)、布尔(紫色)、null(灰色)
3. ✅ **JSON路径显示** - 点击节点显示路径
4. ✅ **复制功能** - 复制整个JSON或单个节点
5. ✅ **格式化/压缩** - 基础功能
6. ✅ **转义/反转义** - 辅助功能
7. ❌ **移除转Dart** - 按用户要求移除
8. ❌ **移除转TypeScript** - 按用户要求移除
