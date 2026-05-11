import 'package:flutter_test/flutter_test.dart';

import 'package:itools/core/themes/modern_theme.dart';
import 'package:itools/features/home/presentation/home_page.dart';
import 'package:itools/features/settings/presentation/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets('home page keeps a clear title and subtitle hierarchy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(
        theme: ModernTheme.light(),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Windows 工具集'), findsOneWidget);
    expect(find.text('选择下方工具开始使用'), findsOneWidget);
  });

  testWidgets('settings page exposes a preference entry section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ShadApp(
        theme: ModernTheme.light(),
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('偏好入口'), findsOneWidget);
    expect(find.text('主题设置'), findsOneWidget);
  });
}
