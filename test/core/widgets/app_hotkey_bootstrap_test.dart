import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:itools/core/widgets/app_hotkey_bootstrap.dart';

class _BuildCounter extends AsyncNotifier<int> {
  static var buildCount = 0;

  @override
  Future<int> build() async {
    buildCount += 1;
    return 1;
  }
}

final _testProvider = AsyncNotifierProvider<_BuildCounter, int>(
  _BuildCounter.new,
);

void main() {
  testWidgets('bootstrap eagerly watches provider', (tester) async {
    _BuildCounter.buildCount = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppHotkeyBootstrap(
            providerOverrideForTest: _testProvider,
            child: const SizedBox(),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(_BuildCounter.buildCount, 1);
  });
}
