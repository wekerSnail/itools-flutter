import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../features/settings/data/theme_service.dart';
import '../../features/settings/domain/app_theme_style.dart';
import '../../features/settings/domain/theme_mode.dart';

class ThemeState {
  const ThemeState({
    this.style = AppThemeStyle.modern,
    this.mode = AppThemeMode.system,
  });

  final AppThemeStyle style;
  final AppThemeMode mode;

  ThemeState copyWith({
    AppThemeStyle? style,
    AppThemeMode? mode,
  }) {
    return ThemeState(
      style: style ?? this.style,
      mode: mode ?? this.mode,
    );
  }
}

class ThemeNotifier extends AsyncNotifier<ThemeState> {
  final _service = ThemeService();

  @override
  Future<ThemeState> build() async {
    return _load();
  }

  Future<ThemeState> _load() async {
    final raw = await _service.load();
    if (raw == null) return const ThemeState();

    return ThemeState(
      style: raw.style,
      mode: raw.mode,
    );
  }

  Future<void> setStyle(AppThemeStyle style) async {
    state = AsyncData(state.value!.copyWith(style: style));
    await _service.save(
      style: style,
      mode: state.value!.mode,
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = AsyncData(state.value!.copyWith(mode: mode));
    await _service.save(
      style: state.value!.style,
      mode: mode,
    );
  }

  ShadThemeData getThemeData(AppThemeStyle style, Brightness brightness) {
    return _service.getThemeData(style, brightness);
  }
}

final themeProvider = AsyncNotifierProvider<ThemeNotifier, ThemeState>(
  ThemeNotifier.new,
);
