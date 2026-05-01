import 'dart:convert';

class JsonFormatterService {
  /// Formats a JSON string with the given [indent] level.
  String format(String input, {int indent = 2}) {
    final dynamic decoded = _decodeJson(input);
    final encoder = JsonEncoder.withIndent(' ' * indent);
    return encoder.convert(decoded);
  }

  /// Minifies a JSON string by removing whitespace.
  String minify(String input) {
    final dynamic decoded = _decodeJson(input);
    return json.encode(decoded);
  }

  /// Escapes special characters in a string for JSON embedding.
  String escape(String input) {
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      switch (char) {
        case '"':
          buffer.write('\\"');
        case '\\':
          buffer.write('\\\\');
        case '\n':
          buffer.write('\\n');
        case '\r':
          buffer.write('\\r');
        case '\t':
          buffer.write('\\t');
        case '\b':
          buffer.write('\\b');
        case '\f':
          buffer.write('\\f');
        default:
          final codeUnit = char.codeUnitAt(0);
          if (codeUnit < 0x20) {
            buffer.write('\\u${codeUnit.toRadixString(16).padLeft(4, '0')}');
          } else {
            buffer.write(char);
          }
      }
    }
    return buffer.toString();
  }

  /// Unescapes JSON-escaped special characters in a string.
  String unescape(String input) {
    final buffer = StringBuffer();
    int i = 0;
    while (i < input.length) {
      if (input[i] == '\\' && i + 1 < input.length) {
        final next = input[i + 1];
        switch (next) {
          case '"':
            buffer.write('"');
            i += 2;
          case '\\':
            buffer.write('\\');
            i += 2;
          case 'n':
            buffer.write('\n');
            i += 2;
          case 'r':
            buffer.write('\r');
            i += 2;
          case 't':
            buffer.write('\t');
            i += 2;
          case 'b':
            buffer.write('\b');
            i += 2;
          case 'f':
            buffer.write('\f');
            i += 2;
          case 'u':
            if (i + 5 < input.length) {
              final hex = input.substring(i + 2, i + 6);
              final codeUnit = int.tryParse(hex, radix: 16);
              if (codeUnit != null) {
                buffer.write(String.fromCharCode(codeUnit));
                i += 6;
              } else {
                buffer.write(input[i]);
                i++;
              }
            } else {
              buffer.write(input[i]);
              i++;
            }
          default:
            buffer.write(input[i]);
            i++;
        }
      } else {
        buffer.write(input[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  /// Returns `true` if [input] is valid JSON.
  bool isValid(String input) {
    try {
      json.decode(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the error message if [input] is invalid JSON, or `null` if valid.
  String? getErrorMessage(String input) {
    try {
      _decodeJson(input);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  dynamic _decodeJson(String input) {
    try {
      return json.decode(input);
    } on FormatException catch (e) {
      throw FormatException('无效的JSON格式: ${e.message}');
    }
  }
}
