import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/json_node_model.dart';

class JsonTreeNode extends StatefulWidget {
  const JsonTreeNode({
    super.key,
    required this.node,
    required this.depth,
    this.onToggle,
    this.indentSize = 20.0,
  });

  final JsonNodeModel node;
  final int depth;
  final VoidCallback? onToggle;
  final double indentSize;

  static const Color keyColor = Color(0xFFE06C75);
  static const Color stringColor = Color(0xFF22C55E);
  static const Color numberColor = Color(0xFF3B82F6);
  static const Color booleanColor = Color(0xFFA855F7);
  static const Color nullColor = Color(0xFF6B7280);
  static const Color bracketColor = Color(0xFFABB2BF);

  @override
  State<JsonTreeNode> createState() => _JsonTreeNodeState();
}

class _JsonTreeNodeState extends State<JsonTreeNode> {
  void _copyValue() {
    final text = _getValueText();
    Clipboard.setData(ClipboardData(text: text));
  }

  String _getValueText() {
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
        return '${node.value}';
      case JsonNodeType.array:
        return '${node.value}';
    }
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

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final hasChildren = node.hasChildren;
    final isExpandable =
        node.type == JsonNodeType.object || node.type == JsonNodeType.array;

    return GestureDetector(
      onSecondaryTap: _copyValue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: isExpandable ? widget.onToggle : null,
            hoverColor: Colors.white.withValues(alpha: 0.05),
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.depth * widget.indentSize,
                right: 8,
                top: 2,
                bottom: 2,
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
                ],
              ),
            ),
          ),
          if (node.isExpanded && hasChildren)
            ...node.children.map(
              (child) => JsonTreeNode(
                node: child,
                depth: widget.depth + 1,
                indentSize: widget.indentSize,
                onToggle: () {
                  setState(() {
                    child.isExpanded = !child.isExpanded;
                  });
                },
              ),
            ),
          if (node.isExpanded && isExpandable)
            Padding(
              padding: EdgeInsets.only(
                left: widget.depth * widget.indentSize,
                right: 8,
                top: 2,
                bottom: 2,
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
      ),
    );
  }
}
