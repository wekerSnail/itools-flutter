import 'package:flutter/material.dart' hide Typography;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../application/hotkey_service.dart';
import '../data/hotkey_action_registry.dart';
import '../domain/hotkey_action_descriptor.dart';
import '../domain/hotkey_config.dart';

class HotkeySettingsPage extends StatefulWidget {
  const HotkeySettingsPage({super.key});

  @override
  State<HotkeySettingsPage> createState() => _HotkeySettingsPageState();
}

class _HotkeySettingsPageState extends State<HotkeySettingsPage> {
  final _service = HotkeyService.instance;
  final _registry = HotkeyActionRegistry.instance;

  @override
  void initState() {
    super.initState();
    _service.reload().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  Future<void> _editHotkey(HotkeyActionDescriptor action) async {
    final existingConfig = _service.getConfig(action.id);

    final result = await showDialog<HotkeyConfig>(
      context: context,
      builder: (context) => _HotkeyEditDialog(
        action: action,
        existingConfig: existingConfig,
      ),
    );

    if (result == null) return;

    if (result.key.isEmpty) {
      await _service.removeConfig(action.id);
      _showToast('已清除 ${action.title} 的热键');
    } else {
      await _service.updateConfig(result);
      _showToast('已保存 ${action.title} 的热键：${result.displayText}');
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final actions = _registry.actions;

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '热键设置',
        subtitle: '配置全局快捷键，快速触发常用操作',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          const PageSectionHeader(
            title: '热键说明',
            subtitle: '全局热键可以在应用最小化或在后台时触发，方便快速操作。',
            icon: Icons.keyboard_outlined,
          ),
          const SizedBox(height: Spacing.md),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.info,
                      size: 16,
                      color: shad.colorScheme.foreground,
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '使用说明',
                      style: Typography.label.copyWith(
                        color: shad.colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                const Text('• 点击动作卡片可配置或修改热键'),
                const SizedBox(height: Spacing.xs),
                const Text('• 在弹出的对话框中按下想要的热键组合'),
                const SizedBox(height: Spacing.xs),
                const Text('• 热键设置会随备份一起保存和恢复'),
                const SizedBox(height: Spacing.xs),
                const Text('• 建议避免与系统或其他应用的热键冲突'),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          const PageSectionHeader(
            title: '可用动作',
            subtitle: '为以下动作配置全局热键，点击卡片进行设置。',
            icon: Icons.keyboard_command_key,
          ),
          const SizedBox(height: Spacing.md),
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: _buildActionCard(context, shad, action),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    ShadThemeData shad,
    HotkeyActionDescriptor action,
  ) {
    final config = _service.getConfig(action.id);

    return InteractiveSurfaceCard(
      onTap: () => _editHotkey(action),
      expand: true,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
            ),
            child: Icon(
              action.icon,
              size: 18,
              color: shad.colorScheme.secondaryForeground,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title,
                  style: Typography.label.copyWith(
                    color: shad.colorScheme.foreground,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  action.description,
                  style: Typography.bodySmall.copyWith(
                    color: shad.colorScheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (config != null && config.enabled) ...[
            ShadBadge.secondary(
              child: Text(config.displayText),
            ),
            const SizedBox(width: Spacing.sm),
          ],
          Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: shad.colorScheme.mutedForeground,
          ),
        ],
      ),
    );
  }
}

class _HotkeyEditDialog extends StatefulWidget {
  const _HotkeyEditDialog({
    required this.action,
    this.existingConfig,
  });

  final HotkeyActionDescriptor action;
  final HotkeyConfig? existingConfig;

  @override
  State<_HotkeyEditDialog> createState() => _HotkeyEditDialogState();
}

class _HotkeyEditDialogState extends State<_HotkeyEditDialog> {
  HotKey? _recordedHotKey;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _enabled = widget.existingConfig?.enabled ?? true;
  }

  void _onHotKeyRecorded(HotKey hotKey) {
    setState(() {
      _recordedHotKey = hotKey;
    });
  }

  void _onSave() {
    if (_recordedHotKey == null) {
      Navigator.of(context).pop(
        HotkeyConfig(
          actionId: widget.action.id,
          enabled: false,
          modifiers: [],
          key: '',
        ),
      );
      return;
    }

    final modifiers = _recordedHotKey!.modifiers
        ?.map((m) => m.name)
        .toList(growable: false) ?? [];

    Navigator.of(context).pop(
      HotkeyConfig(
        actionId: widget.action.id,
        enabled: _enabled,
        modifiers: modifiers,
        key: _recordedHotKey!.key.keyLabel,
      ),
    );
  }

  void _onClear() {
    Navigator.of(context).pop(
      HotkeyConfig(
        actionId: widget.action.id,
        enabled: false,
        modifiers: [],
        key: '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return AlertDialog(
      backgroundColor: shad.colorScheme.background,
      title: Text('设置热键 - ${widget.action.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.action.description,
            style: Typography.bodySmall.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            '按下热键组合：',
            style: Typography.label.copyWith(
              color: shad.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
              border: Border.all(color: shad.colorScheme.border),
            ),
            child: HotKeyRecorder(
              onHotKeyRecorded: _onHotKeyRecorded,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '启用热键',
                      style: Typography.label.copyWith(
                        color: shad.colorScheme.foreground,
                      ),
                    ),
                    const SizedBox(height: Spacing.xs),
                    Text(
                      '关闭后热键配置将保留但不生效',
                      style: Typography.bodySmall.copyWith(
                        color: shad.colorScheme.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              ShadSwitch(
                value: _enabled,
                onChanged: (value) {
                  setState(() {
                    _enabled = value;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _onClear,
          child: const Text('清除热键'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _onSave,
          child: const Text('保存'),
        ),
      ],
    );
  }
}
