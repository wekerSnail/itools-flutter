import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../data/app_backup_service.dart';

class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key});

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
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
        final shad = ShadTheme.of(context);
        return AlertDialog(
          backgroundColor: shad.colorScheme.background,
          title: const Text('确认导入备份'),
          content: const Text('导入后会覆盖当前已有的备份数据，是否继续？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            TextButton(
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

      await _refreshSummary();
      if (!mounted) {
        return;
      }

      setState(() => _lastImportedSummary = summary);
      _showToast('备份导入成功，重新进入功能页后将看到最新数据');
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
    final shad = ShadTheme.of(context);
    final currentSummary = _currentSummary;

    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '备份还原',
        subtitle: '导出当前数据，或导入历史备份进行迁移恢复',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _InfoCard(
            title: '当前数据概览',
            icon: LucideIcons.database,
            child: currentSummary == null
                ? const Text('正在读取当前数据...')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('当前可备份数据项：${currentSummary.itemCount}'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
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
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ActionCard(
                  title: '导出备份',
                  description: '把当前软件数据保存为 JSON 文件，用于迁移、归档或人工留底。',
                  buttonText: _busy ? '处理中...' : '导出当前数据',
                  icon: LucideIcons.download,
                  enabled: !_busy,
                  onPressed: _handleExport,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ActionCard(
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
          const SizedBox(height: 16),
          if (_lastExportPath != null)
            _InfoCard(
              title: '最近一次导出',
              icon: LucideIcons.fileArchive,
              child: SelectableText(_lastExportPath!),
            ),
          if (_lastExportPath != null) const SizedBox(height: 16),
          if (_lastImportedSummary != null)
            _InfoCard(
              title: '最近一次导入',
              icon: LucideIcons.history,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '备份时间：${_formatDateTime(_lastImportedSummary!.exportedAt)}',
                  ),
                  const SizedBox(height: 8),
                  Text('恢复数据项：${_lastImportedSummary!.itemCount}'),
                ],
              ),
            ),
          if (_lastImportedSummary != null) const SizedBox(height: 16),
          _InfoCard(
            title: '说明',
            icon: LucideIcons.shieldCheck,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• 当前会备份应用受管的数据项，包括文件夹映射、定时任务和运行日志。'),
                SizedBox(height: 6),
                Text('• 导入会覆盖这些数据项，因此建议先导出一次当前数据再执行导入。'),
                SizedBox(height: 6),
                Text('• 导入完成后，重新打开对应功能页即可加载最新数据。'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: shad.colorScheme.foreground),
              const SizedBox(width: 8),
              Text(title, style: shad.textTheme.large),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
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
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: shad.colorScheme.secondaryForeground,
            ),
          ),
          const SizedBox(height: 14),
          Text(title, style: shad.textTheme.large),
          const SizedBox(height: 6),
          Text(description, style: shad.textTheme.muted),
          const SizedBox(height: 16),
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
