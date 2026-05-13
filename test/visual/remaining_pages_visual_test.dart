import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itools/core/providers/scheduler_provider.dart';
import 'package:itools/core/themes/modern_theme.dart';
import 'package:itools/features/folder_mapping/presentation/folder_mapping_page.dart';
import 'package:itools/features/json_formatter/presentation/json_formatter_page.dart';
import 'package:itools/features/scheduler/domain/scheduled_task.dart';
import 'package:itools/features/scheduler/presentation/scheduler_page.dart';
import 'package:itools/features/settings/presentation/autostart_settings_page.dart';
import 'package:itools/features/settings/presentation/backup_settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'backup settings page exposes overview and action center sections',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ShadApp(theme: ModernTheme.light(), home: const BackupSettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('数据概览'), findsOneWidget);
      expect(find.text('操作中心'), findsOneWidget);
    },
  );

  testWidgets(
    'autostart settings page exposes switch and troubleshooting sections',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ShadApp(
          theme: ModernTheme.light(),
          home: const AutostartSettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('启动开关'), findsOneWidget);
      expect(find.text('故障排查'), findsOneWidget);
    },
  );

  testWidgets('scheduler page exposes an overview section in empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          schedulerProvider.overrideWith(() => _FakeSchedulerNotifier()),
        ],
        child: ShadApp(theme: ModernTheme.light(), home: const SchedulerPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('任务总览'), findsOneWidget);
  });

  testWidgets('folder mapping page exposes collection management section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(theme: ModernTheme.light(), home: const FolderMappingPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('集合管理'), findsOneWidget);
  });

  testWidgets('json formatter page exposes an editing workspace section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(theme: ModernTheme.light(), home: const JsonFormatterPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑工作台'), findsOneWidget);
  });
}

class _FakeSchedulerNotifier extends SchedulerNotifier {
  @override
  Future<List<ScheduledTask>> build() async => <ScheduledTask>[];
}
