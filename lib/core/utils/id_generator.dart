/// Shared id generation for domain entities.
library;

import 'dart:math';

final _random = Random();

/// Generates a time-sortable unique id: `<millis>_<4-digit random>`.
String nextEntityId() {
  return '${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(9999)}';
}
