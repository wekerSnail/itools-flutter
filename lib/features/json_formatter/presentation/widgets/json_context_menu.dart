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

    final items = <PopupMenuEntry<String>>[];

    if (jsonContext.propertyName != null) {
      items.add(_buildMenuItem(
        value: 'key',
        label: '复制属性名',
        icon: LucideIcons.tag,
        shad: shad,
      ));
    }

    if (jsonContext.propertyValue != null) {
      items.add(_buildMenuItem(
        value: 'value',
        label: '复制属性值',
        icon: LucideIcons.braces,
        shad: shad,
      ));
    }

    if (jsonContext.propertyName != null && jsonContext.propertyValue != null) {
      items.add(_buildMenuItem(
        value: 'pair',
        label: '复制键值对',
        icon: LucideIcons.code,
        shad: shad,
      ));
    }

    if (items.isNotEmpty) {
      items.add(PopupMenuDivider(
        height: 1,
        color: shad.colorScheme.border,
      ));
    }

    items.add(_buildMenuItem(
      value: 'all',
      label: '复制全部',
      icon: LucideIcons.copy,
      shad: shad,
    ));

    showMenu<String>(
      context: context,
      position: RelativeRect.fromSize(
        anchors.primaryAnchor & const Size(200, double.infinity),
        MediaQuery.of(context).size,
      ),
      items: items,
      color: shad.colorScheme.popover,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        side: BorderSide(color: shad.colorScheme.border),
      ),
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

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required String label,
    required IconData icon,
    required ShadThemeData shad,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(icon, size: 14, color: shad.colorScheme.mutedForeground),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: shad.colorScheme.foreground,
            ),
          ),
        ],
      ),
    );
  }

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
