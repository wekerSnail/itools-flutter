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
  late CodeScrollController _scrollController;
  String _lastExternalText = '';

  /// 触底后是否保持贴底。re_editor 用「未显示行数 × 行高」估算总高度，
  /// 与真实 paragraph 高度有误差，滚到底会被 correctBy 拉回一点。
  bool _stickToEnd = false;

  /// 横向是否贴在行尾。粘贴/格式化后 re_editor 的高亮 isolate 会异步重建
  /// 段落，期间 maxScrollExtent 可能变化；若不跟随，行尾会被裁出视口。
  bool _hStickToEnd = false;
  double _lastHMax = 0;

  @override
  void initState() {
    super.initState();
    _controller = CodeLineEditingController.fromText(widget.jsonString);
    _lastExternalText = widget.jsonString;
    _controller
      ..addListener(_onTextChanged)
      ..addListener(_onSelectionChanged);
    _findController = widget.findController ?? CodeFindController(_controller);
    _scrollController = CodeScrollController();
    _scrollController.verticalScroller.addListener(_onVerticalScroll);
    _scrollController.horizontalScroller.addListener(_onHorizontalScroll);
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
    _scrollController.verticalScroller.removeListener(_onVerticalScroll);
    _scrollController.horizontalScroller.removeListener(_onHorizontalScroll);
    _scrollController.dispose();
    _scrollController.verticalScroller.dispose();
    _scrollController.horizontalScroller.dispose();
    _controller
      ..removeListener(_onTextChanged)
      ..removeListener(_onSelectionChanged)
      ..dispose();
    if (widget.findController == null) {
      _findController.dispose();
    }
    super.dispose();
  }

  void _onVerticalScroll() {
    final scroller = _scrollController.verticalScroller;
    if (!scroller.hasClients) return;
    final position = scroller.position;
    final max = position.maxScrollExtent;
    if (max <= 0) {
      _stickToEnd = false;
      return;
    }
    // re_editor 的 makePositionVisible（End 键/方向键移到行尾时调用）纵向
    // jumpTo 不 clamp 到 maxScrollExtent，越界后 goBallistic 会以弹簧
    // 动画拉回，表现为“滚到底再回弹一段”。越界当帧直接拉回 max。
    if (position.pixels > max) {
      scroller.jumpTo(max);
      _stickToEnd = true;
      return;
    }
    // 用户主动滚离底部后取消贴底，避免和手动滚动打架。
    if (position.pixels < max - 48) {
      _stickToEnd = false;
      return;
    }
    if (position.pixels >= max - 2) {
      _stickToEnd = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_stickToEnd) return;
        if (!scroller.hasClients) return;
        final p = scroller.position;
        if (p.pixels < p.maxScrollExtent && p.maxScrollExtent > 0) {
          scroller.jumpTo(p.maxScrollExtent);
        }
      });
    }
  }

  void _onHorizontalScroll() {
    final scroller = _scrollController.horizontalScroller;
    if (!scroller.hasClients) return;
    final position = scroller.position;
    final max = position.maxScrollExtent;
    if (max <= 0) {
      _hStickToEnd = false;
      _lastHMax = 0;
      return;
    }
    // re_editor 的 makePositionVisible 横向 jumpTo 不 clamp，光标到行尾时
    // 目标值会超出 maxScrollExtent 约 lineHeight - padding，越界后
    // goBallistic 的弹簧动画把位置拉回，表现为“滚到末尾再回弹”。
    // 越界发生在同一帧内（jumpTo 同步通知），这里立即拉回 max 掐掉回弹。
    if (position.pixels > max) {
      scroller.jumpTo(max);
      _hStickToEnd = true;
      _lastHMax = max;
      return;
    }
    // 贴底期间 maxScrollExtent 增长（高亮 isolate 异步重建段落、外部
    // 内容更新等）时跟随到新末端，避免行尾被裁出视口、光标不可见。
    if (_hStickToEnd && max > _lastHMax + 0.5) {
      scroller.jumpTo(max);
      _lastHMax = max;
      return;
    }
    // 用户主动滚离末端后取消贴底，避免和手动滚动打架。
    if (position.pixels < max - 48) {
      _hStickToEnd = false;
      _lastHMax = max;
      return;
    }
    if (position.pixels >= max - 2) {
      _hStickToEnd = true;
      _lastHMax = max;
      // 到行尾后被 width 估算纠正时贴回末端，避免小幅回弹。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_hStickToEnd || !scroller.hasClients) return;
        final p = scroller.position;
        if (p.maxScrollExtent > 0 && p.pixels < p.maxScrollExtent) {
          scroller.jumpTo(p.maxScrollExtent);
        }
      });
    }
  }

  void _onTextChanged() {
    // 光标/选区变化不重建全文；大 JSON 上 .text 是 O(n) 拼接。
    final pre = _controller.preValue;
    if (pre != null && identical(pre.codeLines, _controller.codeLines)) {
      return;
    }
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
      scrollController: _scrollController,
      toolbarController: widget.toolbarController,
      findBuilder: (context, controller, readonly) {
        return _CodeFindBar(controller: controller, readonly: readonly);
      },
      hint: widget.hintText ?? '结果将显示在此处...',
      style: CodeEditorStyle(
        fontSize: 13,
        fontFamily: 'Consolas',
        // 1.5 会得到 19.5 这类碎行高，放大 re_editor 总高度估算误差；
        // 2.0 → 26px 整数行高，滚到底更稳。
        fontHeight: 2.0,
        backgroundColor: const Color(0x00000000),
        textColor: shad.colorScheme.foreground,
        cursorColor: shad.colorScheme.primary,
        selectionColor: shad.colorScheme.primary.withValues(alpha: 0.2),
        highlightColor: const Color(0x3FFFAB00),
        cursorLineColor: shad.colorScheme.primary.withValues(alpha: 0.06),
        codeTheme: CodeHighlightTheme(
          languages: {
            'json': CodeHighlightThemeMode(
              mode: langJson,
              // 总长 / 单行超限时库会跳过高亮，避免大 JSON、超长单行卡顿。
              maxSize: 512 * 1024,
              maxLineLength: 8 * 1024,
            ),
          },
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
