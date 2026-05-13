import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itools/core/providers/theme_provider.dart';
import 'package:itools/core/themes/modern_theme.dart';
import 'package:itools/features/settings/presentation/theme_settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  testWidgets(
    'theme settings page exposes style and mode sections',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            themeProvider.overrideWith(() => _TestThemeNotifier()),
          ],
          child: ShadApp(
            theme: ModernTheme.light(),
            home: const ThemeSettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('主题风格库'), findsOneWidget);
      expect(find.text('色调模式'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('主题设置会随备份一起保存'),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('主题设置会随备份一起保存'), findsOneWidget);
    },
  );
}

class _TestThemeNotifier extends ThemeNotifier {
  @override
  Future<ThemeState> build() async {
    return const ThemeState();
  }
}
