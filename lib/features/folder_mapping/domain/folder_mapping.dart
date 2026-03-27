class FolderShortcut {
  FolderShortcut({
    required this.id,
    required this.name,
    required this.targetPath,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String targetPath;
  final DateTime createdAt;

  FolderShortcut copyWith({
    String? id,
    String? name,
    String? targetPath,
    DateTime? createdAt,
  }) {
    return FolderShortcut(
      id: id ?? this.id,
      name: name ?? this.name,
      targetPath: targetPath ?? this.targetPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'targetPath': targetPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FolderShortcut.fromJson(Map<String, dynamic> json) {
    return FolderShortcut(
      id: json['id'] as String,
      name: json['name'] as String,
      targetPath: json['targetPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class FolderCollection {
  FolderCollection({
    required this.id,
    required this.name,
    required this.items,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<FolderShortcut> items;
  final DateTime createdAt;

  FolderCollection copyWith({
    String? id,
    String? name,
    List<FolderShortcut>? items,
    DateTime? createdAt,
  }) {
    return FolderCollection(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(growable: false),
    };
  }

  factory FolderCollection.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? <dynamic>[]);
    return FolderCollection(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: rawItems
          .map((e) => FolderShortcut.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
