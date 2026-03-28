import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/page_header.dart';
import '../application/task_runner.dart';

class TaskLogsPage extends StatelessWidget {
  const TaskLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return Scaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: PageHeader(
        title: '运行日志',
        showBack: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: shad.colorScheme.secondary,
              border: Border(
                bottom: BorderSide(color: shad.colorScheme.border),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.info,
                  size: 14,
                  color: shad.colorScheme.mutedForeground,
                ),
                const SizedBox(width: 6),
                Text(
                  '日志默认保留 5 天，超过时间会自动清理。',
                  style: shad.textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: TaskRunner.instance.logs,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.fileX,
                          size: 32,
                          color: shad.colorScheme.mutedForeground,
                        ),
                        const SizedBox(height: 12),
                        Text('暂无运行日志', style: shad.textTheme.muted),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: shad.colorScheme.card,
                      border: Border.all(color: shad.colorScheme.border),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      logs[i],
                      style: shad.textTheme.small.copyWith(
                        fontFamily: 'Consolas',
                        fontSize: 12,
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
