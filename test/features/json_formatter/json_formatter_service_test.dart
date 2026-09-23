import 'package:flutter_test/flutter_test.dart';
import 'package:itools/features/json_formatter/domain/json_formatter_service.dart';

void main() {
  final service = JsonFormatterService();

  group('smartRepair trailing commas', () {
    test('removes trailing commas outside strings', () {
      final out = service.smartRepair('{"a": 1,}');
      expect(out, '{"a": 1}');
    });

    test('does not touch commas inside strings', () {
      // Invalid only due to trailing comma; the `",}"` inside the string
      // must not be rewritten by the old regex.
      const input = '{"a": "hello,}", "b": 1,}';
      final out = service.smartRepair(input);
      expect(out, '{"a": "hello,}", "b": 1}');
    });

    test('removes trailing comma in arrays', () {
      final out = service.smartRepair('[1, 2, 3,]');
      expect(out, '[1, 2, 3]');
    });
  });
}
