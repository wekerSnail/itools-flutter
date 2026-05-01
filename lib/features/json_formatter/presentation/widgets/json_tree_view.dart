import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/json_node_model.dart';
import 'json_tree_node.dart';

class JsonTreeView extends StatefulWidget {
  const JsonTreeView({
    super.key,
    required this.jsonString,
    this.indentSize = 20.0,
  });

  final String jsonString;
  final double indentSize;

  @override
  State<JsonTreeView> createState() => _JsonTreeViewState();
}

class _JsonTreeViewState extends State<JsonTreeView> {
  List<JsonNodeModel> _nodes = [];
  String? _errorMessage;
  String? _selectedPath;

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
    final input = widget.jsonString.trim();
    if (input.isEmpty) {
      setState(() {
        _nodes = [];
        _errorMessage = null;
        _selectedPath = null;
      });
      return;
    }

    try {
      final decoded = json.decode(input);
      setState(() {
        _nodes = JsonNodeModel.fromJson(decoded);
        _errorMessage = null;
        _selectedPath = null;
      });
    } on FormatException catch (e) {
      setState(() {
        _nodes = [];
        _errorMessage = 'JSON 解析失败: ${e.message}';
        _selectedPath = null;
      });
    } catch (e) {
      setState(() {
        _nodes = [];
        _errorMessage = '解析失败: $e';
        _selectedPath = null;
      });
    }
  }

  void _onNodeSelected(String path) {
    setState(() {
      _selectedPath = path.isEmpty ? null : path;
    });
  }

  void _copyPath() {
    if (_selectedPath == null) return;
    Clipboard.setData(ClipboardData(text: _selectedPath!));
    _showToast('路径已复制');
  }

  void _copyAllJson() {
    if (widget.jsonString.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.jsonString.trim()));
    _showToast('JSON 已复制');
  }

  void _expandAll() {
    setState(() {
      for (final node in _nodes) {
        _setExpandedRecursive(node, true);
      }
    });
  }

  void _collapseAll() {
    setState(() {
      for (final node in _nodes) {
        _setExpandedRecursive(node, false);
      }
    });
  }

  void _setExpandedRecursive(JsonNodeModel node, bool expanded) {
    node.isExpanded = expanded;
    for (final child in node.children) {
      _setExpandedRecursive(child, expanded);
    }
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 200,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(theme),
        _buildPathBar(theme),
        Expanded(child: _buildTreeContent(theme)),
      ],
    );
  }

  Widget _buildToolbar(ThemeData theme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            '树形视图',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          _buildToolbarButton(theme, '展开', Icons.unfold_more, _expandAll),
          const SizedBox(width: 4),
          _buildToolbarButton(
              theme, '收起', Icons.unfold_less, _collapseAll),
          const SizedBox(width: 4),
          _buildToolbarButton(theme, '复制JSON', Icons.copy, _copyAllJson),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(
    ThemeData theme,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildPathBar(ThemeData theme) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _selectedPath ?? '点击节点查看路径',
              style: TextStyle(
                fontFamily: 'Consolas',
                fontSize: 12,
                color: _selectedPath != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_selectedPath != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              onPressed: _copyPath,
              tooltip: '复制路径',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeContent(ThemeData theme) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (_nodes.isEmpty) {
      return Center(
        child: Text(
          '等待输入 JSON 内容',
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onNodeSelected(''),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _nodes
              .map((node) => _buildNodeWidget(node, 0))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildNodeWidget(JsonNodeModel node, int depth) {
    return _JsonTreeViewChild(
      node: node,
      depth: depth,
      indentSize: widget.indentSize,
      selectedPath: _selectedPath,
      onNodeSelected: _onNodeSelected,
    );
  }
}

class _JsonTreeViewChild extends StatefulWidget {
  const _JsonTreeViewChild({
    required this.node,
    required this.depth,
    required this.indentSize,
    required this.selectedPath,
    required this.onNodeSelected,
  });

  final JsonNodeModel node;
  final int depth;
  final double indentSize;
  final String? selectedPath;
  final ValueChanged<String> onNodeSelected;

  @override
  State<_JsonTreeViewChild> createState() => _JsonTreeViewChildState();
}

class _JsonTreeViewChildState extends State<_JsonTreeViewChild> {
  bool get _isSelected => widget.selectedPath == widget.node.path;

  void _copyValue() {
    final node = widget.node;
    String text;
    switch (node.type) {
      case JsonNodeType.string:
        text = '"${node.value}"';
      case JsonNodeType.number:
      case JsonNodeType.boolean:
        text = '${node.value}';
      case JsonNodeType.nullValue:
        text = 'null';
      case JsonNodeType.object:
      case JsonNodeType.array:
        text = json.encode(node.value);
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('值已复制'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 150,
      ),
    );
  }

  Color _getValueColor() {
    switch (widget.node.type) {
      case JsonNodeType.string:
        return JsonTreeNode.stringColor;
      case JsonNodeType.number:
        return JsonTreeNode.numberColor;
      case JsonNodeType.boolean:
        return JsonTreeNode.booleanColor;
      case JsonNodeType.nullValue:
        return JsonTreeNode.nullColor;
      case JsonNodeType.object:
      case JsonNodeType.array:
        return JsonTreeNode.bracketColor;
    }
  }

  String _getDisplayValue() {
    final node = widget.node;
    switch (node.type) {
      case JsonNodeType.string:
        return '"${node.value}"';
      case JsonNodeType.number:
      case JsonNodeType.boolean:
        return '${node.value}';
      case JsonNodeType.nullValue:
        return 'null';
      case JsonNodeType.object:
        return node.isExpanded ? '{' : '{...}';
      case JsonNodeType.array:
        return node.isExpanded ? '[' : '[...]';
    }
  }

  String _getClosingBracket() {
    switch (widget.node.type) {
      case JsonNodeType.object:
        return '}';
      case JsonNodeType.array:
        return ']';
      default:
        return '';
    }
  }

  String _getChildCountLabel() {
    final node = widget.node;
    if (node.type == JsonNodeType.object) {
      return '${node.children.length} 个属性';
    } else if (node.type == JsonNodeType.array) {
      return '${node.children.length} 项';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.hasChildren;
    final isExpandable =
        node.type == JsonNodeType.object || node.type == JsonNodeType.array;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            widget.onNodeSelected(node.path);
            if (isExpandable) {
              setState(() {
                node.isExpanded = !node.isExpanded;
              });
            }
          },
          onSecondaryTap: _copyValue,
          child: Container(
            color: _isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.3)
                : Colors.transparent,
            padding: EdgeInsets.only(
              left: widget.depth * widget.indentSize + 8,
              right: 8,
              top: 3,
              bottom: 3,
            ),
            child: Row(
              children: [
                if (isExpandable)
                  Icon(
                    node.isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 16,
                    color: Colors.grey,
                  )
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 4),
                if (node.key.isNotEmpty) ...[
                  Text(
                    '"${node.key}"',
                    style: const TextStyle(
                      color: JsonTreeNode.keyColor,
                      fontFamily: 'Consolas',
                      fontSize: 13,
                    ),
                  ),
                  const Text(
                    ': ',
                    style: TextStyle(
                      color: JsonTreeNode.bracketColor,
                      fontFamily: 'Consolas',
                      fontSize: 13,
                    ),
                  ),
                ],
                Text(
                  _getDisplayValue(),
                  style: TextStyle(
                    color: _getValueColor(),
                    fontFamily: 'Consolas',
                    fontSize: 13,
                  ),
                ),
                if (isExpandable && !node.isExpanded) ...[
                  const SizedBox(width: 8),
                  Text(
                    _getChildCountLabel(),
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.4),
                      fontFamily: 'Consolas',
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (node.isExpanded && hasChildren)
          ...node.children.map(
            (child) => _JsonTreeViewChild(
              node: child,
              depth: widget.depth + 1,
              indentSize: widget.indentSize,
              selectedPath: widget.selectedPath,
              onNodeSelected: widget.onNodeSelected,
            ),
          ),
        if (node.isExpanded && isExpandable)
          Padding(
            padding: EdgeInsets.only(
              left: widget.depth * widget.indentSize + 8,
              right: 8,
              top: 3,
              bottom: 3,
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                const SizedBox(width: 4),
                Text(
                  _getClosingBracket(),
                  style: const TextStyle(
                    color: JsonTreeNode.bracketColor,
                    fontFamily: 'Consolas',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
