import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itools/core/themes/modern_theme.dart';
import 'package:itools/features/settings/presentation/theme_settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'theme settings page exposes overview and live preview sections',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ShadApp(theme: ModernTheme.light(), home: const ThemeSettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前配置'), findsOneWidget);
      expect(find.text('主题风格库'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('实时预览'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('实时预览'), findsOneWidget);
    },
  );
}
