import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/hotkey_settings/application/hotkey_service.dart';
import '../../features/hotkey_settings/data/hotkey_action_registry.dart';
import '../../features/hotkey_settings/data/hotkey_store.dart';
import '../../features/hotkey_settings/domain/hotkey_config.dart';

class HotkeyNotifier extends AsyncNotifier<List<HotkeyConfig>> {
  final HotkeyStore _store = HotkeyStore();

  @override
  Future<List<HotkeyConfig>> build() async {
    final configs = await _store.loadConfigs();
    await HotkeyService.registerAllHotkeys(
      configs,
      HotkeyActionRegistry.instance,
    );
    return configs;
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final configs = await _store.loadConfigs();
      await HotkeyService.registerAllHotkeys(
        configs,
        HotkeyActionRegistry.instance,
      );
      return configs;
    });
  }

  Future<void> updateConfig(HotkeyConfig config) async {
    final previous = state;
    final current = state.value ?? <HotkeyConfig>[];
    final index = current.indexWhere((c) => c.actionId == config.actionId);
    final List<HotkeyConfig> updated;
    if (index >= 0) {
      updated = [...current];
      updated[index] = config;
    } else {
      updated = [...current, config];
    }
    state = AsyncData(updated);
    try {
      await _store.saveConfigs(updated);
      await HotkeyService.registerAllHotkeys(
        updated,
        HotkeyActionRegistry.instance,
      );
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  Future<void> removeConfig(String actionId) async {
    final previous = state;
    final current = state.value ?? <HotkeyConfig>[];
    final updated = current.where((c) => c.actionId != actionId).toList();
    state = AsyncData(updated);
    try {
      await _store.saveConfigs(updated);
      await HotkeyService.registerAllHotkeys(
        updated,
        HotkeyActionRegistry.instance,
      );
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  HotkeyConfig? getConfig(String actionId) {
    final current = state.value ?? <HotkeyConfig>[];
    return current.where((c) => c.actionId == actionId).firstOrNull;
  }
}

final hotkeyProvider =
    AsyncNotifierProvider<HotkeyNotifier, List<HotkeyConfig>>(
  HotkeyNotifier.new,
);

final hotkeyRegistryProvider = Provider<HotkeyActionRegistry>(
  (ref) => HotkeyActionRegistry.instance,
);
