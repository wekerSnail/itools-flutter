import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/hotkey_provider.dart';

class AppHotkeyBootstrap extends ConsumerWidget {
  const AppHotkeyBootstrap({
    required this.child,
    super.key,
    this.providerOverrideForTest,
  });

  final Widget child;
  final ProviderListenable<Object?>? providerOverrideForTest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(providerOverrideForTest ?? hotkeyProvider);
    return child;
  }
}
