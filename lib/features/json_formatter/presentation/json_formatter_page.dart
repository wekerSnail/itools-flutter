import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

  bool _isValid = true;
  String? _errorMessage;
  String? _statusMessage;
  Timer? _debounceTimer;
  double _splitRatio = 0.5;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
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
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      final valid = _service.isValid(input);
      if (mounted) {
        setState(() {
          _isValid = valid;
          _errorMessage = valid ? null : 'JSON 格式无效';
        });
      }
    });
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  void _execute(JsonOperation operation) {
    final input = _inputController.text;
    if (input.isEmpty) {
      _showToast('请输入 JSON 内容');
      return;
    }

    try {
      String result;
      switch (operation) {
        case JsonOperation.format:
          result = _service.format(input);
        case JsonOperation.minify:
          result = _service.minify(input);
        case JsonOperation.escape:
          result = _service.escape(input);
        case JsonOperation.unescape:
          result = _service.unescape(input);
      }
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
      setState(() {
        _errorMessage = e.message;
        _statusMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '操作失败: $e';
        _statusMessage = null;
      });
    }
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

  void _smartRepair() {
    final input = _inputController.text;
    if (input.isEmpty) {
      _showToast('请输入 JSON 内容');
      return;
    }
    if (_service.isValid(input)) {
      _showToast('JSON 已经是有效格式');
      return;
    }

    final repaired = _service.smartRepair(input);
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
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: 'JSON 格式化',
        subtitle: '格式化、压缩、转义及代码转换',
        showBack: true,
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
          _buildStatusBar(shad),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  const dividerWidth = 6.0;
                  const minPanelWidth = 300.0;
                  final availableWidth = totalWidth - dividerWidth;
                  final leftWidth =
                      (availableWidth * _splitRatio).clamp(minPanelWidth, availableWidth - minPanelWidth);
                  final rightWidth = availableWidth - leftWidth;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: leftWidth, child: _buildInputPanel(shad)),
                      _buildDivider(shad),
                      SizedBox(width: rightWidth, child: _buildOutputPanel(shad)),
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
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: shad.colorScheme.muted.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
      ),
      child: Row(
        children: [
          if (hasInput) ...[
            Icon(
              _isValid ? LucideIcons.check : LucideIcons.x,
              size: 13,
              color: _isValid ? Colors.green : shad.colorScheme.destructive,
            ),
            const SizedBox(width: 6),
            Text(
              _isValid ? 'JSON 有效' : 'JSON 无效',
              style: shad.textTheme.muted.copyWith(
                fontSize: 12,
                color: _isValid ? Colors.green : shad.colorScheme.destructive,
              ),
            ),
          ] else
            Text(
              '等待输入',
              style: shad.textTheme.muted.copyWith(fontSize: 12),
            ),
          const Spacer(),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: shad.textTheme.muted.copyWith(
                fontSize: 12,
                color: shad.colorScheme.destructive,
              ),
            )
          else if (_statusMessage != null)
            Text(
              _statusMessage!,
              style: shad.textTheme.muted.copyWith(fontSize: 12),
            )
          else
            Text(
              '点击上方按钮执行操作',
              style: shad.textTheme.muted.copyWith(fontSize: 12),
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
        final totalWidth = renderBox.size.width - 40; // minus padding
        const dividerWidth = 6.0;
        final availableWidth = totalWidth - dividerWidth;
        setState(() {
          _splitRatio =
              (_splitRatio + details.delta.dx / availableWidth).clamp(0.2, 0.8);
        });
      },
      onHorizontalDragEnd: (_) => setState(() => _isDragging = false),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 6,
          color: Colors.transparent,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: shad.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.braces,
                  size: 14,
                  color: shad.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text('输入', style: shad.textTheme.p),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontFamily: 'Consolas', fontSize: 13),
              decoration: const InputDecoration(
                hintText: '在此粘贴 JSON 内容...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
                isDense: true,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: shad.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText,
                  size: 14,
                  color: shad.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text('输出', style: shad.textTheme.p),
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
