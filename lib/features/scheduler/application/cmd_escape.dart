/// Windows cmd.exe literal escaping for scheduler variable substitution.
///
/// Values substituted into terminal commands must never be re-parsed as
/// cmd metacharacters (`&`, `|`, `>`, `%`, …). Helpers here produce a
/// double-quoted cmd-safe literal suitable for writing into a temp `.cmd`
/// file (where `%%` is a real `%` escape).
library;

import 'dart:convert';

/// Converts a runtime variable to text (string / number / bool / object).
String stringifyCmdVar(Object? value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value;
  }
  if (value is num || value is bool) {
    return value.toString();
  }
  return jsonEncode(value);
}

/// Escapes [raw] as a double-quoted cmd literal for a `.cmd` script body.
///
/// - Newlines / NUL are replaced with spaces (cmd cannot carry them safely).
/// - `%` → `%%` (batch percent escape)
/// - `"` → `""` (batch quote escape inside quotes)
/// - `!` → `^!` (avoid delayed-expansion surprises)
///
/// Returns a value that already includes the surrounding quotes.
String escapeCmdLiteral(String raw) {
  final cleaned = raw.replaceAll(RegExp('[\r\n\x00]'), ' ');
  final escaped = cleaned
      .replaceAll('%', '%%')
      .replaceAll('"', '""')
      .replaceAll('!', '^!');
  return '"$escaped"';
}

/// Substitutes `{{key}}` placeholders with [escapeCmdLiteral] output.
///
/// Handles both bare `{{key}}` and user-quoted `"{{key}}"` so callers do
/// not need to (and should not) add their own quotes around placeholders.
String applyCmdVariables(
  String command,
  Map<String, dynamic> variables,
) {
  var result = command;
  for (final entry in variables.entries) {
    final safe = escapeCmdLiteral(stringifyCmdVar(entry.value));
    final key = entry.key;
    result = result
        .replaceAll('"{{$key}}"', safe)
        .replaceAll('{{$key}}', safe);
  }
  return result;
}
