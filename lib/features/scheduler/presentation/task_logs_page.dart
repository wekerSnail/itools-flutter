import 'package:flutter/material.dart';

import '../application/task_runner.dart';

class TaskLogsPage extends StatelessWidget {
  const TaskLogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('运行日志')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Text('日志默认保留 5 天，超过时间会自动清理。'),
          ),
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: TaskRunner.instance.logs,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return const Center(child: Text('暂无运行日志'));
                }

                return ListView.separated(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: SelectableText(logs[index]),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
