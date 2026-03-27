class FolderMapping {
  FolderMapping({
    required this.id,
    required this.name,
    required this.sourcePath,
    required this.targetPath,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String sourcePath;
  final String targetPath;
  final DateTime createdAt;

  FolderMapping copyWith({
    String? id,
    String? name,
    String? sourcePath,
    String? targetPath,
    DateTime? createdAt,
  }) {
    return FolderMapping(
      id: id ?? this.id,
      name: name ?? this.name,
      sourcePath: sourcePath ?? this.sourcePath,
      targetPath: targetPath ?? this.targetPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sourcePath': sourcePath,
      'targetPath': targetPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FolderMapping.fromJson(Map<String, dynamic> json) {
    return FolderMapping(
      id: json['id'] as String,
      name: json['name'] as String,
      sourcePath: json['sourcePath'] as String,
      targetPath: json['targetPath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
