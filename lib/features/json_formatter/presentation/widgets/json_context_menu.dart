import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../../core/design_tokens/index.dart';

class JsonContextMenuController implements SelectionToolbarController {
  JsonContextMenuController();

  final ValueNotifier<int> lineIndexNotifier = ValueNotifier(-1);

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    final lineIndex = lineIndexNotifier.value;
    final jsonContext = _parseJsonContext(controller, lineIndex);
    final shad = ShadTheme.of(context);

    final items = <_MenuItemData>[];

    if (jsonContext.propertyName != null) {
      items.add(const _MenuItemData(
        value: 'key',
        label: '复制属性名',
        icon: LucideIcons.tag,
      ));
    }

    if (jsonContext.propertyValue != null) {
      items.add(const _MenuItemData(
        value: 'value',
        label: '复制属性值',
        icon: LucideIcons.braces,
      ));
    }

    if (jsonContext.propertyName != null && jsonContext.propertyValue != null) {
      items.add(const _MenuItemData(
        value: 'pair',
        label: '复制键值对',
        icon: LucideIcons.code,
      ));
    }

    items.add(const _MenuItemData(
      value: 'all',
      label: '复制全部',
      icon: LucideIcons.copy,
    ));

    final position = anchors.primaryAnchor;

    showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'context_menu',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return Stack(
          children: [
            Positioned(
              left: position.dx,
              top: position.dy,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0)
                    .animate(curvedAnimation),
                alignment: Alignment.topLeft,
                child: FadeTransition(
                  opacity: curvedAnimation,
                  child: _ContextMenuContent(
                    items: items,
                    shad: shad,
                    hasDivider: jsonContext.propertyName != null ||
                        jsonContext.propertyValue != null,
                    onSelected: (String value) {
                      Navigator.of(context).pop(value);
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ).then((value) {
      if (value == null || !context.mounted) return;

      String textToCopy;
      switch (value) {
        case 'key':
          textToCopy = jsonContext.propertyName!;
        case 'value':
          textToCopy = jsonContext.propertyValue!;
        case 'pair':
          textToCopy =
              '"${jsonContext.propertyName}": ${jsonContext.propertyValue}';
        case 'all':
          textToCopy = controller.text;
        default:
          return;
      }

      Clipboard.setData(ClipboardData(text: textToCopy));
      ShadToaster.of(context).show(
        const ShadToast(
          duration: Duration(seconds: 2),
          description: Text('已复制到剪贴板'),
        ),
      );
    });
  }

  @override
  void hide(BuildContext context) {}

  JsonContext _parseJsonContext(CodeLineEditingController controller, int lineIndex) {
    if (lineIndex < 0) return const JsonContext();

    final lines = controller.text.split('\n');
    if (lineIndex >= lines.length) return const JsonContext();

    return _extractJsonProperty(lines[lineIndex]);
  }

  JsonContext _extractJsonProperty(String line) {
    final trimmed = line.trimRight();
    if (trimmed.isEmpty) return const JsonContext();

    final colonIndex = trimmed.indexOf(':');
    if (colonIndex < 0) return const JsonContext();

    final keyPart = trimmed.substring(0, colonIndex).trim();
    final valuePart = trimmed.substring(colonIndex + 1).trim();

    String? propertyName;
    if (keyPart.startsWith('"') &&
        keyPart.endsWith('"') &&
        keyPart.length >= 2) {
      propertyName = keyPart.substring(1, keyPart.length - 1);
    } else {
      return const JsonContext();
    }

    String? propertyValue;
    if (valuePart.isNotEmpty) {
      propertyValue = _extractValue(valuePart);
    }

    return JsonContext(propertyName: propertyName, propertyValue: propertyValue);
  }

  String? _extractValue(String valueStr) {
    if (valueStr.isEmpty) return null;

    final trimmed = valueStr.trimRight();
    if (trimmed.isEmpty) return null;

    if (trimmed.endsWith(',')) {
      final withoutComma =
          trimmed.substring(0, trimmed.length - 1).trimRight();
      if (withoutComma.isEmpty) return null;
      return _parseSingleValue(withoutComma);
    }

    return _parseSingleValue(trimmed);
  }

  String? _parseSingleValue(String value) {
    if (value.isEmpty) return null;

    if (value.startsWith('"')) {
      final endQuote = _findMatchingQuote(value, 0);
      if (endQuote > 0) {
        return value.substring(0, endQuote + 1);
      }
      return value;
    }

    if (value == 'true' || value == 'false' || value == 'null') {
      return value;
    }

    final numPattern = RegExp(r'^-?\d+(\.\d+)?([eE][+-]?\d+)?');
    final match = numPattern.firstMatch(value);
    if (match != null) {
      return match.group(0);
    }

    if (value.startsWith('{')) {
      final endBrace = _findMatchingBrace(value, 0);
      if (endBrace > 0) {
        return value.substring(0, endBrace + 1);
      }
      return value;
    }

    if (value.startsWith('[')) {
      final endBracket = _findMatchingBracket(value, 0);
      if (endBracket > 0) {
        return value.substring(0, endBracket + 1);
      }
      return value;
    }

    return value;
  }

  int _findMatchingQuote(String text, int start) {
    for (int i = start + 1; i < text.length; i++) {
      if (text[i] == '\\') {
        i++;
        continue;
      }
      if (text[i] == '"') {
        return i;
      }
    }
    return -1;
  }

  int _findMatchingBrace(String text, int start) {
    int depth = 0;
    bool inString = false;
    for (int i = start; i < text.length; i++) {
      if (text[i] == '\\') {
        i++;
        continue;
      }
      if (text[i] == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (text[i] == '{') depth++;
        if (text[i] == '}') {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }

  int _findMatchingBracket(String text, int start) {
    int depth = 0;
    bool inString = false;
    for (int i = start; i < text.length; i++) {
      if (text[i] == '\\') {
        i++;
        continue;
      }
      if (text[i] == '"') {
        inString = !inString;
        continue;
      }
      if (!inString) {
        if (text[i] == '[') depth++;
        if (text[i] == ']') {
          depth--;
          if (depth == 0) return i;
        }
      }
    }
    return -1;
  }
}

class JsonContext {
  const JsonContext({this.propertyName, this.propertyValue});

  final String? propertyName;
  final String? propertyValue;
}

class _MenuItemData {
  const _MenuItemData({
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;
}

class _ContextMenuContent extends StatefulWidget {
  const _ContextMenuContent({
    required this.items,
    required this.shad,
    required this.hasDivider,
    required this.onSelected,
  });

  final List<_MenuItemData> items;
  final ShadThemeData shad;
  final bool hasDivider;
  final ValueChanged<String> onSelected;

  @override
  State<_ContextMenuContent> createState() => _ContextMenuContentState();
}

class _ContextMenuContentState extends State<_ContextMenuContent> {
  int _hoveredIndex = -1;

  @override
  Widget build(BuildContext context) {
    final shad = widget.shad;
    final children = <Widget>[];

    for (int i = 0; i < widget.items.length; i++) {
      if (widget.hasDivider && i == widget.items.length - 1) {
        children.add(
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: shad.colorScheme.border,
          ),
        );
      }

      final item = widget.items[i];
      final isHovered = _hoveredIndex == i;

      children.add(
        MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = i),
          onExit: (_) => setState(() => _hoveredIndex = -1),
          child: GestureDetector(
            onTap: () => widget.onSelected(item.value),
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: isHovered
                    ? shad.colorScheme.accent
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 13,
                    color: isHovered
                        ? shad.colorScheme.accentForeground
                        : shad.colorScheme.mutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isHovered
                          ? shad.colorScheme.accentForeground
                          : shad.colorScheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: 160,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: shad.colorScheme.popover,
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: shad.colorScheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}
