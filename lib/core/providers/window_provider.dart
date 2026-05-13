import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../system/window_manager_service.dart';

final windowServiceProvider = Provider<WindowManagerService>((ref) {
  return WindowManagerService.instance;
});
