import 'package:flutter_test/flutter_test.dart';
import 'package:itools/core/system/window_reveal_controller.dart';

void main() {
  test('playReveal increments sequence and notifies listeners', () {
    final controller = WindowRevealController();
    var notifications = 0;

    controller.addListener(() {
      notifications += 1;
    });

    expect(controller.sequence, 0);

    controller.playReveal();
    controller.playReveal();

    expect(controller.sequence, 2);
    expect(notifications, 2);
  });
}
