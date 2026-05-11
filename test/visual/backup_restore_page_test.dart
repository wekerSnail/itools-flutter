import 'package:flutter_test/flutter_test.dart';

import 'package:itools/core/themes/modern_theme.dart';
import 'package:itools/features/backup_restore/presentation/backup_restore_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('backup restore page exposes overview and action center sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(
        theme: ModernTheme.light(),
        home: const BackupRestorePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据概览'), findsOneWidget);
    expect(find.text('操作中心'), findsOneWidget);
  });
}
