import 'package:flutter/foundation.dart';

/// 主窗口显隐动画的全局触发器。
///
/// 进程级单例，生命周期与 App 相同，因此不应调用 `dispose()`：
/// 一旦释放，后续 `playReveal` 将不再通知监听者。
class WindowRevealController extends ChangeNotifier {
  WindowRevealController();

  static final WindowRevealController instance = WindowRevealController();

  int _sequence = 0;

  int get sequence => _sequence;

  void playReveal() {
    _sequence += 1;
    notifyListeners();
  }
}
