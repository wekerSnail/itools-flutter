import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/providers/hotkey_provider.dart';
import '../../../core/providers/scheduler_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/icon_container.dart';
import '../../../core/widgets/surface_cards.dart';
import '../data/app_backup_service.dart';

/// 备份/还原主体。设置页与工具页共用此实现，入口只保留壳。
class BackupRestoreView extends ConsumerStatefulWidget {
  const BackupRestoreView({super.key});

  @override
  ConsumerState<BackupRestoreView> createState() => _BackupRestoreViewState();
}

class _BackupRestoreViewState extends ConsumerState<BackupRestoreView> {
  final AppBackupService _backupService = AppBackupService();

  BackupSummary? _currentSummary;
  BackupSummary? _lastImportedSummary;
  String? _lastExportPath;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshSummary();
  }

  Future<void> _refreshSummary() async {
    final summary = await _backupService.getCurrentSummary();
    if (!mounted) {
      return;
    }
    setState(() => _currentSummary = summary);
  }

  void _showToast(String message) {
    ShadToaster.of(context).show(ShadToast(description: Text(message)));
  }

  String _formatDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} ${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  Future<void> _handleExport() async {
    setState(() => _busy = true);
    try {
      final filePath = await _backupService.exportBackup();
      if (filePath == null) {
        _showToast('已取消导出');
        return;
      }
      await _refreshSummary();
      if (!mounted) {
        return;
      }
      setState(() => _lastExportPath = filePath);
      _showToast('备份已导出到：$filePath');
    } on Exception catch (e) {
      _showToast('导出失败：$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _handleImport() async {
    final shouldImport = await showDialog<bool>(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('确认导入备份'),
          description: const Text('导入后会覆盖当前已有的备份数据，是否继续？'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ShadButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('继续导入'),
            ),
          ],
        );
      },
    );

    if (shouldImport != true) {
      return;
    }

    setState(() => _busy = true);
    try {
      final summary = await _backupService.importBackup();
      if (summary == null) {
        _showToast('已取消导入');
        return;
      }

      // 刷新受管数据的内存态，避免必须重开页面才能看到导入结果。
      ref
        ..invalidate(schedulerProvider)
        ..invalidate(hotkeyProvider)
        ..invalidate(themeProvider);

      await _refreshSummary();
      if (!mounted) {
        return;
      }

      setState(() => _lastImportedSummary = summary);
      _showToast('备份导入成功');
    } on Exception catch (e) {
      _showToast('导入失败：$e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSummary = _currentSummary;

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const PageSectionHeader(
          title: '数据概览',
          subtitle: '先确认当前有哪些数据会被纳入备份，再决定导出或导入。',
          icon: LucideIcons.package,
        ),
        const SizedBox(height: Spacing.md),
        BackupInfoCard(
          title: '当前数据概览',
          icon: LucideIcons.database,
          child: currentSummary == null
              ? const Text('正在读取当前数据...')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前可备份数据项：${currentSummary.itemCount}'),
                    const SizedBox(height: Spacing.sm),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: currentSummary.keys.isEmpty
                          ? const <Widget>[Text('暂无可备份数据')]
                          : currentSummary.keys
                                .map(
                                  (key) =>
                                      ShadBadge.secondary(child: Text(key)),
                                )
                                .toList(growable: false),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: Spacing.xl),
        const PageSectionHeader(
          title: '操作中心',
          subtitle: '把最常用的导出、导入操作集中放在一起，动作更明确，风险提示也更清楚。',
          icon: LucideIcons.arrowLeftRight,
        ),
        const SizedBox(height: Spacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: BackupActionCard(
                title: '导出备份',
                description: '把当前软件数据保存为 JSON 文件，用于迁移、归档或人工留底。',
                buttonText: _busy ? '处理中...' : '导出当前数据',
                icon: LucideIcons.download,
                enabled: !_busy,
                onPressed: _handleExport,
              ),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: BackupActionCard(
                title: '导入备份',
                description: '从之前导出的备份文件恢复数据，适合换机迁移或误操作后回滚。',
                buttonText: _busy ? '处理中...' : '导入历史备份',
                icon: LucideIcons.upload,
                enabled: !_busy,
                onPressed: _handleImport,
              ),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xl),
        if (_lastExportPath != null) ...[
          BackupInfoCard(
            title: '最近一次导出',
            icon: LucideIcons.fileArchive,
            child: SelectableText(_lastExportPath!),
          ),
          const SizedBox(height: Spacing.md),
        ],
        if (_lastImportedSummary != null) ...[
          BackupInfoCard(
            title: '最近一次导入',
            icon: LucideIcons.history,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '备份时间：${_formatDateTime(_lastImportedSummary!.exportedAt)}',
                ),
                const SizedBox(height: Spacing.sm),
                Text('恢复数据项：${_lastImportedSummary!.itemCount}'),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
        ],
        const PageSectionHeader(
          title: '使用说明',
          subtitle: '把关键风险和恢复预期提前说清楚，避免备份操作像开盲盒。',
          icon: LucideIcons.info,
        ),
        const SizedBox(height: Spacing.md),
        const BackupInfoCard(
          title: '说明',
          icon: LucideIcons.shieldCheck,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• 当前会备份应用受管的数据项，包括文件夹映射、定时任务和运行日志。'),
              SizedBox(height: Spacing.xs),
              Text('• 导入会覆盖这些数据项，因此建议先导出一次当前数据再执行导入。'),
              SizedBox(height: Spacing.xs),
              Text('• 导入完成后，功能页数据会自动刷新。'),
            ],
          ),
        ),
      ],
    );
  }
}

class BackupInfoCard extends StatelessWidget {
  const BackupInfoCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: shad.colorScheme.foreground),
              const SizedBox(width: Spacing.sm),
              Text(
                title,
                style: Typography.label.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          child,
        ],
      ),
    );
  }
}

class BackupActionCard extends StatelessWidget {
  const BackupActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonText;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return InteractiveSurfaceCard(
      onTap: enabled ? onPressed : null,
      expand: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconContainer(icon: icon),
          const SizedBox(height: Spacing.sm),
          Text(
            title,
            style: Typography.label.copyWith(
              color: shad.colorScheme.foreground,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            description,
            style: Typography.bodySmall.copyWith(
              color: shad.colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: ShadButton(
              onPressed: enabled ? onPressed : null,
              child: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}
