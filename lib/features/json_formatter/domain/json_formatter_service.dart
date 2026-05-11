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

  /// Attempts to repair an incomplete or malformed JSON string.
  /// Returns the repaired string if successful, or null if repair fails.
  String? smartRepair(String input) {
    if (input.trim().isEmpty) return null;

    // Already valid
    if (isValid(input)) return input;

    var repaired = input.trim();

    // Strategy 1: Replace single quotes with double quotes
    repaired = _replaceSingleQuotes(repaired);
    if (isValid(repaired)) return repaired;

    // Strategy 2: Quote unquoted keys
    repaired = _quoteUnquotedKeys(repaired);
    if (isValid(repaired)) return repaired;

    // Strategy 3: Remove trailing commas
    repaired = _removeTrailingCommas(repaired);
    if (isValid(repaired)) return repaired;

    // Strategy 4: Balance brackets
    repaired = _balanceBrackets(repaired);
    if (isValid(repaired)) return repaired;

    // Strategy 5: Combine all repairs
    repaired = input.trim();
    repaired = _replaceSingleQuotes(repaired);
    repaired = _quoteUnquotedKeys(repaired);
    repaired = _removeTrailingCommas(repaired);
    repaired = _balanceBrackets(repaired);
    if (isValid(repaired)) return repaired;

    // Strategy 6: Truncate at last valid position
    final truncated = _truncateAtLastValid(repaired);
    if (truncated != null && isValid(truncated)) return truncated;

    return null;
  }

  String _replaceSingleQuotes(String input) {
    final buffer = StringBuffer();
    bool inDoubleQuote = false;
    bool escaped = false;

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escaped) {
        buffer.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        buffer.write(ch);
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(ch);
        continue;
      }
      if (ch == "'" && !inDoubleQuote) {
        // Find matching single quote
        int j = i + 1;
        while (j < input.length && input[j] != "'") {
          if (input[j] == '\\') j++;
          j++;
        }
        buffer
          ..write('"')
          ..write(input.substring(i + 1, j))
          ..write('"');
        i = j;
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  String _quoteUnquotedKeys(String input) {
    // Match unquoted keys before colon: word characters not inside quotes
    final buffer = StringBuffer();
    bool inDoubleQuote = false;
    bool escaped = false;

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escaped) {
        buffer.write(ch);
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        buffer.write(ch);
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inDoubleQuote = !inDoubleQuote;
        buffer.write(ch);
        continue;
      }
      if (!inDoubleQuote && _isIdentStart(ch)) {
        // Read identifier
        int j = i;
        while (j < input.length && _isIdentChar(input[j])) {
          j++;
        }
        // Check if followed by optional whitespace then colon
        int k = j;
        while (k < input.length && (input[k] == ' ' || input[k] == '\t')) {
          k++;
        }
        if (k < input.length && input[k] == ':') {
          // It's a key, quote it
          buffer
            ..write('"')
            ..write(input.substring(i, j))
            ..write('"');
          i = j - 1;
        } else {
          buffer.write(input.substring(i, j));
          i = j - 1;
        }
        continue;
      }
      buffer.write(ch);
    }
    return buffer.toString();
  }

  bool _isIdentStart(String ch) =>
      ch == '_' ||
      (ch.codeUnitAt(0) >= 65 && ch.codeUnitAt(0) <= 90) || // A-Z
      (ch.codeUnitAt(0) >= 97 && ch.codeUnitAt(0) <= 122); // a-z

  bool _isIdentChar(String ch) =>
      _isIdentStart(ch) ||
      (ch.codeUnitAt(0) >= 48 && ch.codeUnitAt(0) <= 57); // 0-9

  String _removeTrailingCommas(String input) {
    // Remove commas before } or ]
    return input.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
  }

  String _balanceBrackets(String input) {
    final stack = <String>[];
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < input.length; i++) {
      final ch = input[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (ch == '\\') {
        escaped = true;
        continue;
      }
      if (ch == '"') {
        inString = !inString;
        continue;
      }
      if (inString) continue;

      if (ch == '{' || ch == '[') {
        stack.add(ch);
      } else if (ch == '}') {
        if (stack.isNotEmpty && stack.last == '{') {
          stack.removeLast();
        }
      } else if (ch == ']') {
        if (stack.isNotEmpty && stack.last == '[') {
          stack.removeLast();
        }
      }
    }

    // Append missing closing brackets
    final closing = StringBuffer();
    for (int i = stack.length - 1; i >= 0; i--) {
      closing.write(stack[i] == '{' ? '}' : ']');
    }

    // Also handle incomplete trailing value
    var result = input.trimRight();
    if (result.endsWith(',')) {
      result = result.substring(0, result.length - 1);
    }

    return result + closing.toString();
  }

  String? _truncateAtLastValid(String input) {
    // Try progressively truncating at comma or value boundaries
    for (int i = input.length - 1; i >= 0; i--) {
      final ch = input[i];
      if (ch == ',' || ch == ':' || ch == '"' || ch == '}' || ch == ']') {
        final candidate = input.substring(0, i + 1);
        final balanced = _balanceBrackets(candidate);
        if (isValid(balanced)) return balanced;
      }
    }
    return null;
  }

  dynamic _decodeJson(String input) {
    try {
      return json.decode(input);
    } on FormatException catch (e) {
      throw FormatException('无效的JSON格式: ${e.message}');
    }
  }
}
