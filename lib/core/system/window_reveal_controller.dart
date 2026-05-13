import 'package:flutter/foundation.dart';

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
