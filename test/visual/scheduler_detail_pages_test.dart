import 'package:flutter_test/flutter_test.dart';

import 'package:itools/core/themes/modern_theme.dart';
import 'package:itools/features/scheduler/presentation/task_editor_page.dart';
import 'package:itools/features/scheduler/presentation/task_logs_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('task editor page exposes a task configuration section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(theme: ModernTheme.light(), home: const TaskEditorPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('任务配置'), findsOneWidget);
  });

  testWidgets('task logs page exposes a logs overview section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(theme: ModernTheme.light(), home: const TaskLogsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('日志总览'), findsOneWidget);
  });
}
