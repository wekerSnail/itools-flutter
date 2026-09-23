import 'package:flutter_test/flutter_test.dart';
import 'package:itools/features/scheduler/application/cmd_escape.dart';

void main() {
  group('stringifyCmdVar', () {
    test('passes strings through', () {
      expect(stringifyCmdVar('hello'), 'hello');
    });

    test('stringifies number and bool', () {
      expect(stringifyCmdVar(42), '42');
      expect(stringifyCmdVar(true), 'true');
    });

    test('json-encodes objects', () {
      expect(stringifyCmdVar({'a': 1}), '{"a":1}');
    });

    test('null becomes empty', () {
      expect(stringifyCmdVar(null), '');
    });
  });

  group('escapeCmdLiteral', () {
    test('wraps in quotes', () {
      expect(escapeCmdLiteral('hello'), '"hello"');
    });

    test('escapes percent for batch files', () {
      expect(escapeCmdLiteral('%PATH%'), '"%%PATH%%"');
    });

    test('escapes embedded quotes', () {
      expect(escapeCmdLiteral('x"y'), '"x""y"');
    });

    test('keeps shell metacharacters literal inside quotes', () {
      expect(escapeCmdLiteral('a&b|c'), '"a&b|c"');
    });

    test('escapes bang for delayed expansion', () {
      expect(escapeCmdLiteral('hi!'), '"hi^!"');
    });

    test('strips newlines and NUL', () {
      expect(escapeCmdLiteral('a\nb\r\x00c'), '"a b  c"');
    });
  });

  group('applyCmdVariables', () {
    test('substitutes bare placeholder as safe literal', () {
      expect(
        applyCmdVariables('echo {{name}}', {'name': 'a&b'}),
        'echo "a&b"',
      );
    });

    test('folds user-quoted placeholder without double quotes', () {
      expect(
        applyCmdVariables('echo "{{name}}"', {'name': 'hi'}),
        'echo "hi"',
      );
    });

    test('does not let values break out via percent', () {
      final out = applyCmdVariables('echo {{v}}', {'v': '%PATH%'});
      expect(out, 'echo "%%PATH%%"');
    });
  });
}
