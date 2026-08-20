import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Typography;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/data/file_store.dart';
import '../../../core/design_tokens/index.dart';
import '../../../core/providers/task_runner_provider.dart';
import '../../../core/system/app_runtime.dart';
import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/loading_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';

class TaskLogsPage extends ConsumerStatefulWidget {
  const TaskLogsPage({super.key});

  @override
  ConsumerState<TaskLogsPage> createState() => _TaskLogsPageState();
}

class _TaskLogsPageState extends ConsumerState<TaskLogsPage> {
  StreamSubscription<FileSystemEvent>? _logsWatchSub;
  Timer? _reloadDebounce;

  @override
  void initState() {
    super.initState();
    // 子窗口中日志由主引擎写入，内存副本不会自动更新，需要监听文件变化。
    if (AppRuntime.isChildWindow) {
      _setupChildWindowLogs();
    }
  }

  void _setupChildWindowLogs() {
    unawaited(() async {
      try {
        await ref.read(taskRunnerProvider).reloadLogs();
        final basePath = await FileStore.basePath;
        _logsWatchSub = Directory('$basePath/scheduler').watch().listen((
          event,
        ) {
          final path = event.path.replaceAll('\\', '/');
          if (!path.endsWith('scheduler/logs.json')) {
            return;
          }
          _reloadDebounce?.cancel();
          _reloadDebounce = Timer(const Duration(milliseconds: 300), () {
            unawaited(ref.read(taskRunnerProvider).reloadLogs());
          });
        });
      } catch (e) {
        debugPrint('[TaskLogsPage] Watch logs.json failed: $e');
      }
    }());
  }

  @override
  void dispose() {
    _logsWatchSub?.cancel();
    _reloadDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final logs = ref.watch(logsProvider);
    return CustomScaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(
        title: '运行日志',
        subtitle: '查看任务执行轨迹和最近输出',
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          const PageSectionHeader(
            title: '日志总览',
            subtitle: '执行记录、保留周期和空状态统一在一个日志工作区里。',
            icon: LucideIcons.fileText,
          ),
          const SizedBox(height: Spacing.md),
          SurfaceCard(
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 14,
                  color: shad.colorScheme.mutedForeground,
                ),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    '日志默认保留 5 天，超过时间会自动清理。',
                    style: Typography.bodySmall.copyWith(
                      color: shad.colorScheme.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            height: 520,
            child: ValueListenableBuilder<List<String>>(
              valueListenable: logs,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return const SurfaceCard(
                    child: SizedBox(
                      height: 320,
                      child: EmptyStateWidget(
                        icon: LucideIcons.fileX,
                        title: '暂无运行日志',
                        description: '任务开始运行后，最新日志会按时间倒序显示在这里。',
                      ),
                    ),
                  );
                }
                return SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.all(Spacing.md),
                    itemCount: logs.length,
                    separatorBuilder: (_, index) =>
                        const SizedBox(height: Spacing.sm),
                    itemBuilder: (_, i) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.md,
                        vertical: Spacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: shad.colorScheme.secondary.withValues(
                          alpha: 0.2,
                        ),
                        border: Border.all(color: shad.colorScheme.border),
                        borderRadius: BorderRadius.circular(
                          BorderRadiusTokens.sm,
                        ),
                      ),
                      child: SelectableText(
                        logs[i],
                        style: Typography.bodySmall.copyWith(
                          color: shad.colorScheme.foreground,
                          fontFamily: 'Consolas',
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
