import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart' hide Typography;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/page_header.dart';
import '../domain/json_formatter_service.dart';
import 'widgets/json_code_editor.dart';
import 'widgets/json_toolbar.dart';

class JsonFormatterPage extends StatefulWidget {
  const JsonFormatterPage({super.key});

  @override
  State<JsonFormatterPage> createState() => _JsonFormatterPageState();
}

class _JsonFormatterPageState extends State<JsonFormatterPage> {
  final JsonFormatterService _service = JsonFormatterService();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final ScrollController _inputScrollController = ScrollController();
  double _charHeight = 18.0;

  bool _isValid = true;
  String? _errorMessage;
  String? _statusMessage;
  Timer? _debounceTimer;
  double _splitRatio = 0.5;
  bool _isDragging = false;

  bool _showFindBar = false;
  final TextEditingController _findTextController = TextEditingController();
  List<int> _matchOffsets = [];
  int _currentMatch = -1;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
    _findTextController.addListener(_onFindPatternChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController
      ..removeListener(_onInputChanged)
      ..dispose();
    _outputController.dispose();
    _findTextController
      ..removeListener(_onFindPatternChanged)
      ..dispose();
    _inputFocusNode.dispose();
    _inputScrollController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final input = _inputController.text;
    if (input.isEmpty) {
      _debounceTimer?.cancel();
      setState(() {
        _isValid = true;
        _errorMessage = null;
      });
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final valid = await _isValidAsync(input);
      if (mounted) {
        setState(() {
          _isValid = valid;
          _errorMessage = valid ? null : 'JSON 格式无效';
        });
      }
    });

    if (_showFindBar && _findTextController.text.isNotEmpty) {
      _runSearch();
    }
  }

  void _onFindPatternChanged() {
    _runSearch();
  }

  void _openFindBar() {
    setState(() {
      _showFindBar = true;
    });
    _findTextController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _findTextController.text.length,
    );
    _runSearch();
  }

  void _closeFindBar() {
    setState(() {
      _showFindBar = false;
      _matchOffsets = [];
      _currentMatch = -1;
    });
    _inputController.selection = const TextSelection.collapsed(offset: -1);
    _inputFocusNode.requestFocus();
  }

  void _runSearch() {
    final pattern = _findTextController.text;
    final text = _inputController.text;

    if (pattern.isEmpty || text.isEmpty) {
      if (mounted) {
        setState(() {
          _matchOffsets = [];
          _currentMatch = -1;
        });
      }
      return;
    }

    final lowerText = text.toLowerCase();
    final lowerPattern = pattern.toLowerCase();
    final offsets = <int>[];
    var startIndex = 0;
    while (true) {
      final index = lowerText.indexOf(lowerPattern, startIndex);
      if (index == -1) break;
      offsets.add(index);
      startIndex = index + 1;
    }

    if (mounted) {
      setState(() {
        _matchOffsets = offsets;
        if (offsets.isEmpty) {
          _currentMatch = -1;
        } else if (_currentMatch >= offsets.length) {
          _currentMatch = 0;
          _selectMatch(0);
        } else if (_currentMatch == -1) {
          _currentMatch = 0;
          _selectMatch(0);
        } else {
          _selectMatch(_currentMatch);
        }
      });
    }
  }

  void _nextMatch() {
    if (_matchOffsets.isEmpty) return;
    final next = (_currentMatch + 1) % _matchOffsets.length;
    setState(() => _currentMatch = next);
    _selectMatch(next);
  }

  void _previousMatch() {
    if (_matchOffsets.isEmpty) return;
    final prev =
        (_currentMatch - 1 + _matchOffsets.length) % _matchOffsets.length;
    setState(() => _currentMatch = prev);
    _selectMatch(prev);
  }

  void _selectMatch(int index) {
    if (index < 0 || index >= _matchOffsets.length) return;
    final offset = _matchOffsets[index];
    final length = _findTextController.text.length;
    _inputController.selection = TextSelection(
      baseOffset: offset,
      extentOffset: offset + length,
    );
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _autoScrollToMatch(offset);
    });
  }

  void _autoScrollToMatch(int charOffset) {
    if (!_inputScrollController.hasClients) return;
    final text = _inputController.text;
    if (charOffset > text.length) return;

    final line = '\n'.allMatches(text.substring(0, charOffset)).length;
    final matchTop = line * _charHeight;
    final viewportHeight = _inputScrollController.position.viewportDimension;
    final currentOffset = _inputScrollController.offset;

    if (matchTop < currentOffset ||
        matchTop + _charHeight > currentOffset + viewportHeight) {
      final target =
          (matchTop - viewportHeight / 2 + _charHeight / 2).clamp(
        0.0,
        _inputScrollController.position.maxScrollExtent,
      );
      _inputScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Future<bool> _isValidAsync(String input) async {
    try {
      await Isolate.run(() => json.decode(input));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _execute(JsonOperation operation) async {
    final input = _inputController.text;
    if (input.isEmpty) {
      _showToast('请输入 JSON 内容');
      return;
    }
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '${operation.label}中...';
    });

    try {
      final result = await _runInIsolate(operation, input);
      if (!mounted) return;
      setState(() {
        if (operation == JsonOperation.escape ||
            operation == JsonOperation.unescape) {
          _inputController.text = result;
          _isValid = _service.isValid(result);
          _errorMessage = _isValid ? null : 'JSON 格式无效';
        } else {
          _outputController.text = result;
        }
        _statusMessage = '${operation.label}完成';
      });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _statusMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '操作失败: $e';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  static Future<String> _runInIsolate(
    JsonOperation operation,
    String input,
  ) async {
    return Isolate.run(() {
      final service = JsonFormatterService();
      switch (operation) {
        case JsonOperation.format:
          return service.format(input);
        case JsonOperation.minify:
          return service.minify(input);
        case JsonOperation.escape:
          return service.escape(input);
        case JsonOperation.unescape:
          return service.unescape(input);
      }
    });
  }

  void _swap() {
    final output = _outputController.text;
    if (output.isEmpty) {
      _showToast('输出内容为空');
      return;
    }
    final valid = _service.isValid(output);
    setState(() {
      _inputController.text = output;
      _outputController.clear();
      _isValid = valid;
      _errorMessage = valid ? null : 'JSON 格式无效';
      _statusMessage = '已交换输入输出';
    });
  }

  void _copyOutput() {
    final output = _outputController.text;
    if (output.isEmpty) {
      _showToast('输出内容为空');
      return;
    }
    Clipboard.setData(ClipboardData(text: output));
    _showToast('已复制到剪贴板');
  }

  void _clear() {
    setState(() {
      _inputController.clear();
      _outputController.clear();
      _errorMessage = null;
      _statusMessage = null;
      _isValid = true;
    });
  }

  Future<void> _smartRepair() async {
    final input = _inputController.text;
    if (input.isEmpty) {
      _showToast('请输入 JSON 内容');
      return;
    }
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = '智能修复中...';
    });

    try {
      final repaired = await Isolate.run(() {
        final service = JsonFormatterService();
        return service.smartRepair(input);
      });
      if (!mounted) return;
      if (repaired != null) {
        setState(() {
          _inputController.text = repaired;
          _isValid = true;
          _errorMessage = null;
          _statusMessage = '智能修复成功';
        });
      } else {
        setState(() {
          _errorMessage = '无法自动修复该 JSON';
          _statusMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '修复失败: $e';
        _statusMessage = null;
      });
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return CustomScaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: 'JSON 格式化',
        subtitle: '格式化、压缩、转义及智能修复',
      ),
      body: Column(
        children: [
          JsonToolbar(
            onOperation: _execute,
            onSmartRepair: _smartRepair,
            onSwap: _swap,
            onCopy: _copyOutput,
            onClear: _clear,
          ),
          const SizedBox(height: Spacing.sm),
          _buildStatusBar(shad),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.cardPadding,
                Spacing.sm,
                Spacing.cardPadding,
                Spacing.cardPadding,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  const dividerWidth = 6.0;
                  const minPanelWidth = 300.0;
                  final availableWidth = totalWidth - dividerWidth;
                  final leftWidth = (availableWidth * _splitRatio).clamp(
                    minPanelWidth,
                    availableWidth - minPanelWidth,
                  );
                  final rightWidth = availableWidth - leftWidth;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: leftWidth,
                        child: _buildInputPanel(shad),
                      ),
                      _buildDivider(shad),
                      SizedBox(
                        width: rightWidth,
                        child: _buildOutputPanel(shad),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ShadThemeData shad) {
    final input = _inputController.text;
    final hasInput = input.isNotEmpty;

    return Container(
      height: 36,
      margin: const EdgeInsets.fromLTRB(
        Spacing.cardPadding,
        0,
        Spacing.cardPadding,
        0,
      ),
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      decoration: BoxDecoration(
        color: shad.colorScheme.secondary.withValues(alpha: 0.18),
        border: Border.all(color: shad.colorScheme.border),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
      ),
      child: Row(
        children: [
          if (hasInput) ...[
            Icon(
              _isValid ? LucideIcons.check : LucideIcons.x,
              size: 14,
              color: _isValid
                  ? const Color(0xFF22C55E)
                  : shad.colorScheme.destructive,
            ),
            const SizedBox(width: Spacing.xs),
            Text(
              _isValid ? 'JSON 有效' : 'JSON 无效',
              style: Typography.caption.copyWith(
                color: _isValid
                    ? const Color(0xFF22C55E)
                    : shad.colorScheme.destructive,
              ),
            ),
          ] else
            Text(
              '等待输入',
              style: Typography.caption.copyWith(
                color: shad.colorScheme.mutedForeground,
              ),
            ),
          const Spacer(),
          if (_isProcessing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: shad.colorScheme.mutedForeground,
              ),
            )
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: Typography.caption.copyWith(
                color: shad.colorScheme.destructive,
              ),
            )
          else if (_statusMessage != null)
            Text(
              _statusMessage!,
              style: Typography.caption.copyWith(
                color: shad.colorScheme.mutedForeground,
              ),
            )
          else
            Text(
              '点击上方按钮执行操作',
              style: Typography.caption.copyWith(
                color: shad.colorScheme.mutedForeground,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider(ShadThemeData shad) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => setState(() => _isDragging = true),
      onHorizontalDragUpdate: (details) {
        final renderBox = context.findRenderObject() as RenderBox;
        final totalWidth =
            renderBox.size.width - (Spacing.cardPadding * 2);
        const dividerWidth = 6.0;
        final availableWidth = totalWidth - dividerWidth;
        setState(() {
          _splitRatio =
              (_splitRatio + details.delta.dx / availableWidth).clamp(
            0.2,
            0.8,
          );
        });
      },
      onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: const Color(0x00000000),
          child: Center(
            child: Container(
              width: _isDragging ? 3 : 2,
              decoration: BoxDecoration(
                color: _isDragging
                    ? shad.colorScheme.primary
                    : shad.colorScheme.border,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputPanel(ShadThemeData shad) {
    return ShadCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: shad.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.braces,
                  size: 16,
                  color: shad.colorScheme.mutedForeground,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  '输入',
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openFindBar,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        BorderRadiusTokens.sm,
                      ),
                    ),
                    child: Icon(
                      LucideIcons.search,
                      size: 14,
                      color: shad.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showFindBar) _buildFindBar(shad),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(
                  LogicalKeyboardKey.keyF,
                  control: true,
                ): _openFindBar,
                const SingleActivator(LogicalKeyboardKey.escape):
                    _closeFindBar,
              },
              child: _buildTextField(shad),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(ShadThemeData shad) {
    final textStyle = Typography.bodySmall.copyWith(
      fontFamily: 'Consolas',
      fontSize: 13,
      height: 1.4,
      color: shad.colorScheme.foreground,
    );
    _charHeight = (textStyle.fontSize ?? 13) * (textStyle.height ?? 1.4);

    return TextField(
      controller: _inputController,
      focusNode: _inputFocusNode,
      scrollController: _inputScrollController,
      maxLines: null,
      expands: true,
      keyboardType: TextInputType.multiline,
      style: textStyle,
      cursorColor: shad.colorScheme.primary,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(12),
        border: InputBorder.none,
        hintText: '在此粘贴 JSON 内容...',
        hintStyle: textStyle.copyWith(
          color: shad.colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildFindBar(ShadThemeData shad) {
    final matchCount = _matchOffsets.length;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: shad.colorScheme.popover,
        border: Border(
          bottom: BorderSide(color: shad.colorScheme.border),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            height: 30,
            child: KeyboardListener(
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.enter) {
                    _nextMatch();
                  } else if (event.logicalKey ==
                      LogicalKeyboardKey.escape) {
                    _closeFindBar();
                  }
                }
              },
              child: TextField(
                controller: _findTextController,
                autofocus: true,
                style: Typography.bodySmall.copyWith(
                  fontFamily: 'Consolas',
                  color: shad.colorScheme.foreground,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  hintText: '搜索...',
                  hintStyle: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                  filled: true,
                  fillColor: shad.colorScheme.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      BorderRadiusTokens.sm,
                    ),
                    borderSide: BorderSide(
                      color: shad.colorScheme.border,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      BorderRadiusTokens.sm,
                    ),
                    borderSide: BorderSide(
                      color: shad.colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            matchCount > 0 ? '${_currentMatch + 1}/$matchCount' : '无匹配',
            style: Typography.caption.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 4),
          _findBarIconBtn(
            icon: LucideIcons.chevronUp,
            onTap: _previousMatch,
            shad: shad,
          ),
          _findBarIconBtn(
            icon: LucideIcons.chevronDown,
            onTap: _nextMatch,
            shad: shad,
          ),
          const Spacer(),
          _findBarIconBtn(
            icon: LucideIcons.x,
            onTap: _closeFindBar,
            shad: shad,
          ),
        ],
      ),
    );
  }

  Widget _findBarIconBtn({
    required IconData icon,
    required VoidCallback onTap,
    required ShadThemeData shad,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BorderRadiusTokens.sm),
        ),
        child: Icon(
          icon,
          size: 14,
          color: shad.colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildOutputPanel(ShadThemeData shad) {
    return ShadCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: shad.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText,
                  size: 16,
                  color: shad.colorScheme.mutedForeground,
                ),
                const SizedBox(width: Spacing.xs),
                Text(
                  '输出',
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: JsonCodeEditor(
              jsonString: _outputController.text,
              hintText: '结果将显示在此处...',
              onChanged: (text) {
                _outputController.text = text;
              },
            ),
          ),
        ],
      ),
    );
  }
}
