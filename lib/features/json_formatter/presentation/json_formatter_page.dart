import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../domain/json_formatter_service.dart';
import 'widgets/json_editable_text_field.dart';
import 'widgets/json_toolbar.dart';
import 'widgets/json_tree_view.dart';

enum JsonViewMode {
  code('代码'),
  tree('树形');

  const JsonViewMode(this.label);
  final String label;
}

class JsonFormatterPage extends StatefulWidget {
  const JsonFormatterPage({super.key});

  @override
  State<JsonFormatterPage> createState() => _JsonFormatterPageState();
}

class _JsonFormatterPageState extends State<JsonFormatterPage> {
  final JsonFormatterService _service = JsonFormatterService();
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _outputController = TextEditingController();

  JsonViewMode _viewMode = JsonViewMode.code;
  bool _isValid = true;
  String? _errorMessage;
  String? _statusMessage;
  Timer? _debounceTimer;

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
        _outputController.text = result;
        _statusMessage = '${operation.label}完成';
        _errorMessage = null;
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
            onSwap: _swap,
            onCopy: _copyOutput,
            onClear: _clear,
          ),
          _buildStatusBar(shad),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildInputPanel(shad)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildOutputPanel(shad)),
                ],
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
                const Spacer(),
                _buildViewModeToggle(shad),
              ],
            ),
          ),
          Expanded(
            child: _viewMode == JsonViewMode.code
                ? _buildCodeView(shad)
                : JsonTreeView(jsonString: _outputController.text),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeToggle(ShadThemeData shad) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: shad.colorScheme.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModeButton(
            shad,
            mode: JsonViewMode.code,
            icon: LucideIcons.code,
          ),
          Container(
            width: 1,
            color: shad.colorScheme.border,
          ),
          _buildViewModeButton(
            shad,
            mode: JsonViewMode.tree,
            icon: LucideIcons.network,
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeButton(
    ShadThemeData shad, {
    required JsonViewMode mode,
    required IconData icon,
  }) {
    final selected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? shad.colorScheme.muted.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(
          icon,
          size: 14,
          color: selected
              ? shad.colorScheme.foreground
              : shad.colorScheme.mutedForeground,
        ),
      ),
    );
  }

  Widget _buildCodeView(ShadThemeData shad) {
    return JsonEditableTextField(
      controller: _outputController,
      hintText: '结果将显示在此处...',
    );
  }
}
