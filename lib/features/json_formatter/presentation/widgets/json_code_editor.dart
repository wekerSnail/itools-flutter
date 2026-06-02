import 'package:flutter/material.dart' hide Typography;
import 'package:flutter/services.dart';
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
    this.findController,
    this.onFindControllerReady,
    this.toolbarController,
    this.lineIndexNotifier,
  });

  final String jsonString;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final CodeFindController? findController;
  final ValueChanged<CodeFindController>? onFindControllerReady;
  final SelectionToolbarController? toolbarController;
  final ValueNotifier<int>? lineIndexNotifier;

  @override
  State<JsonCodeEditor> createState() => _JsonCodeEditorState();
}

class _JsonCodeEditorState extends State<JsonCodeEditor> {
  late CodeLineEditingController _controller;
  late CodeFindController _findController;
  String _lastExternalText = '';

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.jsonString);
    _lastExternalText = widget.jsonString;
    _controller
      ..addListener(_onTextChanged)
      ..addListener(_onSelectionChanged);
    _findController = widget.findController ?? CodeFindController(_controller);
    _notifyFindControllerReady();
  }

  @override
  void didUpdateWidget(JsonCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jsonString != _lastExternalText) {
      _lastExternalText = widget.jsonString;
      _controller.text = widget.jsonString;
    }
    if (widget.findController != oldWidget.findController) {
      if (oldWidget.findController == null) {
        _findController.dispose();
      }
      _findController =
          widget.findController ?? CodeFindController(_controller);
    }
    _notifyFindControllerReady();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..removeListener(_onSelectionChanged)
      ..dispose();
    if (widget.findController == null) {
      _findController.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text != _lastExternalText) {
      _lastExternalText = text;
      widget.onChanged?.call(text);
    }
  }

  void _onSelectionChanged() {
    final lineIndex = _controller.selection.baseIndex;
    if (lineIndex >= 0) {
      widget.lineIndexNotifier?.value = lineIndex;
    }
  }

  void _notifyFindControllerReady() {
    widget.onFindControllerReady?.call(_findController);
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return CodeEditor(
      controller: _controller,
      findController: _findController,
      toolbarController: widget.toolbarController,
      findBuilder: (context, controller, readonly) {
        return _CodeFindBar(controller: controller, readonly: readonly);
      },
      hint: widget.hintText ?? '结果将显示在此处...',
      style: CodeEditorStyle(
        fontSize: 13,
        fontFamily: 'Consolas',
        fontHeight: 1.5,
        backgroundColor: const Color(0x00000000),
        textColor: shad.colorScheme.foreground,
        cursorColor: shad.colorScheme.primary,
        selectionColor: shad.colorScheme.primary.withValues(alpha: 0.2),
        highlightColor: const Color(0x3FFFAB00),
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

class _CodeFindBar extends StatelessWidget implements PreferredSizeWidget {
  const _CodeFindBar({required this.controller, required this.readonly});

  final CodeFindController controller;
  final bool readonly;

  @override
  Size get preferredSize =>
      controller.value == null ? Size.zero : const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return ValueListenableBuilder<CodeFindValue?>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (value == null) {
          return const SizedBox.shrink();
        }

        final result = value.result;
        final matchCount = result?.matches.length ?? 0;
        final currentIndex = result?.index ?? -1;

        return Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: shad.colorScheme.popover,
            border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 200,
                height: 30,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        controller.close,
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: TextField(
                      controller: controller.findInputController,
                      focusNode: controller.findInputFocusNode,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'Consolas',
                      ),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        hintText: '搜索...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: shad.colorScheme.mutedForeground,
                        ),
                        filled: true,
                        fillColor: shad.colorScheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: shad.colorScheme.border,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: shad.colorScheme.primary,
                          ),
                        ),
                      ),
                      onChanged: (_) {},
                      onSubmitted: (_) => controller.nextMatch(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                matchCount > 0 ? '${currentIndex + 1}/$matchCount' : '无匹配',
                style: TextStyle(
                  fontSize: 12,
                  color: shad.colorScheme.mutedForeground,
                ),
              ),
              const SizedBox(width: 4),
              _iconBtn(
                icon: LucideIcons.chevronUp,
                onTap: controller.previousMatch,
                shad: shad,
              ),
              _iconBtn(
                icon: LucideIcons.chevronDown,
                onTap: controller.nextMatch,
                shad: shad,
              ),
              _iconBtn(
                icon: LucideIcons.caseSensitive,
                onTap: controller.toggleCaseSensitive,
                shad: shad,
                highlighted: value.option.caseSensitive,
              ),
              _iconBtn(
                icon: LucideIcons.regex,
                onTap: controller.toggleRegex,
                shad: shad,
                highlighted: value.option.regex,
              ),
              const Spacer(),
              _iconBtn(
                icon: LucideIcons.x,
                onTap: controller.close,
                shad: shad,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    required ShadThemeData shad,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: highlighted
              ? shad.colorScheme.primary.withValues(alpha: 0.15)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: highlighted
              ? shad.colorScheme.primary
              : shad.colorScheme.mutedForeground,
        ),
      ),
    );
  }
}
