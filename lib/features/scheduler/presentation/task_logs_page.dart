import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/widgets/loading_widgets.dart';
import '../../../core/widgets/page_header.dart';
import '../../../core/widgets/surface_cards.dart';
import '../application/task_runner.dart';

class TaskLogsPage extends StatelessWidget {
  const TaskLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Scaffold(
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
            icon: Icons.receipt_long_outlined,
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
              valueListenable: TaskRunner.instance.logs,
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
