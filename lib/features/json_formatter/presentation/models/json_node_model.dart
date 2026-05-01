import 'package:flutter/foundation.dart';

enum JsonNodeType { object, array, string, number, boolean, nullValue }

class JsonNodeModel {
  JsonNodeModel({
    required this.key,
    required this.value,
    required this.type,
    required this.path,
    this.isExpanded = false,
    this.children = const [],
  });

  final String key;
  final dynamic value;
  final JsonNodeType type;
  final String path;
  bool isExpanded;
  final List<JsonNodeModel> children;

  bool get hasChildren => children.isNotEmpty;

  JsonNodeModel copyWith({
    String? key,
    dynamic value,
    JsonNodeType? type,
    String? path,
    bool? isExpanded,
    List<JsonNodeModel>? children,
  }) {
    return JsonNodeModel(
      key: key ?? this.key,
      value: value ?? this.value,
      type: type ?? this.type,
      path: path ?? this.path,
      isExpanded: isExpanded ?? this.isExpanded,
      children: children ?? this.children,
    );
  }

  static List<JsonNodeModel> fromJson(dynamic json) {
    return _buildNodes(json, '', '');
  }

  static List<JsonNodeModel> _buildNodes(
    dynamic value,
    String parentPath,
    String key,
  ) {
    final path = parentPath.isEmpty ? key : '$parentPath.$key';
    final type = _getType(value);

    if (type == JsonNodeType.object) {
      final map = value as Map<String, dynamic>;
      final children = <JsonNodeModel>[];
      for (final entry in map.entries) {
        children.addAll(_buildNodes(entry.value, path, entry.key));
      }
      return [
        JsonNodeModel(
          key: key,
          value: value,
          type: type,
          path: path,
          children: children,
        ),
      ];
    } else if (type == JsonNodeType.array) {
      final list = value as List<dynamic>;
      final children = <JsonNodeModel>[];
      for (int i = 0; i < list.length; i++) {
        children.addAll(_buildNodes(list[i], path, '[$i]'));
      }
      return [
        JsonNodeModel(
          key: key,
          value: value,
          type: type,
          path: path,
          children: children,
        ),
      ];
    } else {
      return [
        JsonNodeModel(key: key, value: value, type: type, path: path),
      ];
    }
  }

  static JsonNodeType _getType(dynamic value) {
    if (value == null) return JsonNodeType.nullValue;
    if (value is Map) return JsonNodeType.object;
    if (value is List) return JsonNodeType.array;
    if (value is String) return JsonNodeType.string;
    if (value is num) return JsonNodeType.number;
    if (value is bool) return JsonNodeType.boolean;
    return JsonNodeType.string;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JsonNodeModel &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          type == other.type &&
          path == other.path &&
          isExpanded == other.isExpanded &&
          listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(key, value, type, path, isExpanded, children);
}
