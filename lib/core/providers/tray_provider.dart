import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../system/app_tray_service.dart';

final trayServiceProvider = Provider<AppTrayService>((ref) {
  return AppTrayService.instance;
});
