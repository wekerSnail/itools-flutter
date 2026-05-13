import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:itools/app.dart';
import 'package:itools/core/providers/theme_provider.dart';

void main() {
  testWidgets('Home page is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          themeProvider.overrideWith(
            () => _TestThemeNotifier(),
          ),
        ],
        child: const ToolboxApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Windows 工具集'), findsOneWidget);
    expect(find.text('选择下方工具开始使用'), findsOneWidget);
    expect(find.text('定时任务'), findsOneWidget);
    expect(find.text('文件夹映射'), findsOneWidget);
    expect(find.text('JSON 格式化'), findsOneWidget);
  });
}

class _TestThemeNotifier extends ThemeNotifier {
  @override
  Future<ThemeState> build() async {
    return const ThemeState();
  }
}
