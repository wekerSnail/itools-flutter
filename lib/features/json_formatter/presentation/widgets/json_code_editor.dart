import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

class JsonCodeEditor extends StatefulWidget {
  const JsonCodeEditor({
    super.key,
    required this.jsonString,
    this.hintText,
    this.onChanged,
  });

  final String jsonString;
  final String? hintText;
  final ValueChanged<String>? onChanged;

  @override
  State<JsonCodeEditor> createState() => _JsonCodeEditorState();
}

class _JsonCodeEditorState extends State<JsonCodeEditor> {
  late CodeLineEditingController _controller;
  String _lastExternalText = '';

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.jsonString);
    _lastExternalText = widget.jsonString;
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(JsonCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jsonString != _lastExternalText) {
      _lastExternalText = widget.jsonString;
      _controller.text = widget.jsonString;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text != _lastExternalText) {
      _lastExternalText = text;
      widget.onChanged?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return CodeEditor(
      controller: _controller,
      hint: widget.hintText ?? '结果将显示在此处...',
      style: CodeEditorStyle(
        fontSize: 13,
        fontFamily: 'Consolas',
        fontHeight: 1.5,
        backgroundColor: Colors.transparent,
        textColor: isDark ? const Color(0xFFABB2BF) : const Color(0xFF383A42),
        cursorColor: theme.colorScheme.primary,
        selectionColor: theme.colorScheme.primary.withValues(alpha: 0.2),
        cursorLineColor: theme.colorScheme.primary.withValues(alpha: 0.06),
        codeTheme: CodeHighlightTheme(
          languages: {
            'json': langJson.themeMode,
          },
          theme: atomOneDarkTheme,
        ),
      ),
      wordWrap: false,
      indicatorBuilder: (context, editingController, chunkController, notifier) {
        return Row(
          children: [
            DefaultCodeChunkIndicator(
              width: 20,
              controller: chunkController,
              notifier: notifier,
            ),
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: TextStyle(
                fontSize: 12,
                fontFamily: 'Consolas',
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              focusedTextStyle: TextStyle(
                fontSize: 12,
                fontFamily: 'Consolas',
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        );
      },
      scrollbarBuilder: (context, child, details) {
        return Scrollbar(
          controller: details.controller,
          notificationPredicate: (notification) => true,
          child: child,
        );
      },
    );
  }
}
