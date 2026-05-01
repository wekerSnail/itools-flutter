import 'package:flutter/material.dart';

class JsonEditableTextField extends StatefulWidget {
  const JsonEditableTextField({
    super.key,
    required this.controller,
    this.hintText,
  });

  final TextEditingController controller;
  final String? hintText;

  @override
  State<JsonEditableTextField> createState() => _JsonEditableTextFieldState();
}

class _JsonEditableTextFieldState extends State<JsonEditableTextField> {
  late final _HighlightEditingController _highlightController;

  @override
  void initState() {
    super.initState();
    _highlightController = _HighlightEditingController(
      baseStyle: const TextStyle(
        fontFamily: 'Consolas',
        fontSize: 13,
        height: 1.5,
      ),
    );
    widget.controller.addListener(_syncText);
    _highlightController.addListener(_syncBack);
    _syncText();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncText);
    _highlightController.removeListener(_syncBack);
    _highlightController.dispose();
    super.dispose();
  }

  void _syncText() {
    if (_highlightController.text != widget.controller.text) {
      final selection = widget.controller.selection;
      _highlightController.value = TextEditingValue(
        text: widget.controller.text,
        selection: selection,
      );
    }
  }

  void _syncBack() {
    if (widget.controller.text != _highlightController.text) {
      final selection = _highlightController.selection;
      widget.controller.value = TextEditingValue(
        text: _highlightController.text,
        selection: selection,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: _highlightController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style: const TextStyle(
        fontFamily: 'Consolas',
        fontSize: 13,
        height: 1.5,
      ),
      decoration: InputDecoration(
        hintText: widget.hintText ?? '在此输入...',
        hintStyle: TextStyle(
          color: theme.hintColor.withValues(alpha: 0.5),
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.all(14),
        isDense: true,
      ),
    );
  }
}

class _HighlightEditingController extends TextEditingController {
  _HighlightEditingController({required this.baseStyle});

  final TextStyle baseStyle;

  static const Color stringColor = Color(0xFF22C55E);
  static const Color numberColor = Color(0xFF3B82F6);
  static const Color booleanColor = Color(0xFFA855F7);
  static const Color nullColor = Color(0xFF6B7280);
  static const Color keyColor = Color(0xFFE06C75);
  static const Color punctuationColor = Color(0xFFABB2BF);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return TextSpan(
      style: baseStyle,
      children: _highlight(text, baseStyle),
    );
  }

  List<TextSpan> _highlight(String source, TextStyle defaultStyle) {
    if (source.isEmpty) return [const TextSpan(text: '')];

    final spans = <TextSpan>[];
    int i = 0;

    while (i < source.length) {
      final char = source[i];

      if (char == '"') {
        final end = _findStringEnd(source, i);
        final raw = source.substring(i, end + 1);

        final isKey = _isKeyPosition(source, i);
        final color = isKey ? keyColor : stringColor;

        spans.add(TextSpan(
          text: raw,
          style: TextStyle(color: color),
        ));
        i = end + 1;
      } else if (char == '-' ||
          (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57)) {
        final end = _findNumberEnd(source, i);
        spans.add(TextSpan(
          text: source.substring(i, end),
          style: const TextStyle(color: numberColor),
        ));
        i = end;
      } else if (source.startsWith('true', i)) {
        spans.add(const TextSpan(
          text: 'true',
          style: TextStyle(color: booleanColor),
        ));
        i += 4;
      } else if (source.startsWith('false', i)) {
        spans.add(const TextSpan(
          text: 'false',
          style: TextStyle(color: booleanColor),
        ));
        i += 5;
      } else if (source.startsWith('null', i)) {
        spans.add(const TextSpan(
          text: 'null',
          style: TextStyle(color: nullColor),
        ));
        i += 4;
      } else if (char == '{' ||
          char == '}' ||
          char == '[' ||
          char == ']' ||
          char == ':' ||
          char == ',') {
        spans.add(TextSpan(
          text: char,
          style: const TextStyle(color: punctuationColor),
        ));
        i++;
      } else {
        final end = _findNextToken(source, i);
        spans.add(TextSpan(text: source.substring(i, end)));
        i = end;
      }
    }

    return spans;
  }

  int _findStringEnd(String source, int start) {
    int i = start + 1;
    while (i < source.length) {
      if (source[i] == '\\') {
        i += 2;
        continue;
      }
      if (source[i] == '"') return i;
      i++;
    }
    return source.length - 1;
  }

  int _findNumberEnd(String source, int start) {
    int i = start;
    if (source[i] == '-') i++;
    while (i < source.length &&
        (source[i].codeUnitAt(0) >= 48 && source[i].codeUnitAt(0) <= 57 ||
            source[i] == '.' ||
            source[i] == 'e' ||
            source[i] == 'E' ||
            source[i] == '+' ||
            source[i] == '-')) {
      i++;
    }
    return i;
  }

  int _findNextToken(String source, int start) {
    int i = start;
    while (i < source.length &&
        source[i] != '"' &&
        source[i] != '{' &&
        source[i] != '}' &&
        source[i] != '[' &&
        source[i] != ']' &&
        source[i] != ':' &&
        source[i] != ',' &&
        !(source[i].codeUnitAt(0) >= 48 && source[i].codeUnitAt(0) <= 57) &&
        source[i] != '-') {
      i++;
    }
    return i;
  }

  bool _isKeyPosition(String source, int stringStart) {
    int i = stringStart - 1;
    while (i >= 0 &&
        (source[i] == ' ' ||
            source[i] == '\n' ||
            source[i] == '\r' ||
            source[i] == '\t')) {
      i--;
    }
    if (i < 0) return false;
    return source[i] == ',' || source[i] == '{' || source[i] == '[';
  }
}
