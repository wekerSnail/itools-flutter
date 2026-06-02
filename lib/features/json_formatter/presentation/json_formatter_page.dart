import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart' hide Typography;
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/system/window_manager_service.dart';
import '../../../core/tools/tool_registry.dart';
import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/page_header.dart';

import '../domain/json_formatter_service.dart';
import 'widgets/json_code_editor.dart';
import 'widgets/json_context_menu.dart';
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
  final JsonContextMenuController _outputMenuController =
      JsonContextMenuController();

  bool _isValid = true;
  String? _errorMessage;
  String? _statusMessage;
  Timer? _debounceTimer;
  double _splitRatio = 0.5;
  bool _isDragging = false;

  CodeFindController? _inputFindController;

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController
      ..removeListener(_onInputChanged)
      ..dispose();
    _outputController.dispose();
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
  }

  void _openFindBar() {
    _inputFindController?.findMode();
  }

  void _closeFindBar() {
    _inputFindController?.close();
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
        } else if (operation == JsonOperation.format) {
          _inputController.text = result;
          _outputController.text = result;
          _isValid = true;
          _errorMessage = null;
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

  void _openNewWindow() {
    final tool = ToolRegistry.findById('json_formatter');
    if (tool != null) {
      WindowManagerService.instance.openNewToolWindow(tool);
    }
  }

  void _smartRepair() {
    final input = _inputController.text;
    if (input.isEmpty) {
      _showToast('请输入 JSON 内容');
      return;
    }
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'JSON 修复中...';
    });

    try {
      final repaired = _service.smartRepair(input);
      if (!mounted) return;
      if (repaired != null) {
        setState(() {
          _inputController.text = repaired;
          _isValid = true;
          _errorMessage = null;
          _statusMessage = 'JSON 修复成功';
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
      appBar: const PageHeader(title: 'JSON 格式化', subtitle: '格式化、压缩、转义及智能修复'),
      body: Column(
        children: [
          const SizedBox(height: Spacing.xs),
          JsonToolbar(
            onOperation: _execute,
            onSmartRepair: _smartRepair,
            onCopy: _copyOutput,
            onClear: _clear,
            onNewWindow: _openNewWindow,
          ),
          const SizedBox(height: Spacing.xs),
          _buildStatusBar(shad),
          const SizedBox(height: Spacing.xs),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Spacing.cardPadding,
                0,
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
                      SizedBox(width: leftWidth, child: _buildInputPanel(shad)),
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
      height: 28,
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
        final totalWidth = renderBox.size.width - (Spacing.cardPadding * 2);
        const dividerWidth = 6.0;
        final availableWidth = totalWidth - dividerWidth;
        setState(() {
          _splitRatio = (_splitRatio + details.delta.dx / availableWidth).clamp(
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
              ],
            ),
          ),
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                    _openFindBar,
                const SingleActivator(LogicalKeyboardKey.escape): _closeFindBar,
              },
              child: JsonCodeEditor(
                jsonString: _inputController.text,
                hintText: '在此粘贴 JSON 内容...',
                onChanged: (text) {
                  if (text != _inputController.text) {
                    _inputController.text = text;
                  }
                },
                onFindControllerReady: (controller) {
                  _inputFindController = controller;
                },
              ),
            ),
          ),
        ],
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
              toolbarController: _outputMenuController,
              lineIndexNotifier: _outputMenuController.lineIndexNotifier,
            ),
          ),
        ],
      ),
    );
  }
}
