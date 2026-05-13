import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
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
    final shad = ShadTheme.of(context);

    return CodeEditor(
      controller: _controller,
      hint: widget.hintText ?? '结果将显示在此处...',
      style: CodeEditorStyle(
        fontSize: 13,
        fontFamily: 'Consolas',
        fontHeight: 1.5,
        backgroundColor: const Color(0x00000000),
        textColor: shad.colorScheme.foreground,
        cursorColor: shad.colorScheme.primary,
        selectionColor: shad.colorScheme.primary.withValues(alpha: 0.2),
        cursorLineColor: shad.colorScheme.primary.withValues(alpha: 0.06),
        codeTheme: CodeHighlightTheme(
          languages: {'json': langJson.themeMode},
          theme: atomOneDarkTheme,
        ),
      ),
      wordWrap: false,
      indicatorBuilder:
          (context, editingController, chunkController, notifier) {
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
                    color: shad.colorScheme.mutedForeground.withValues(
                      alpha: 0.55,
                    ),
                  ),
                  focusedTextStyle: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Consolas',
                    color: shad.colorScheme.mutedForeground.withValues(
                      alpha: 0.85,
                    ),
                  ),
                ),
              ],
            );
          },
      scrollbarBuilder: (context, child, details) {
        return RawScrollbar(
          controller: details.controller,
          notificationPredicate: (notification) => true,
          child: child,
        );
      },
    );
  }
}
