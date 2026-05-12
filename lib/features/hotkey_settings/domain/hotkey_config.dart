class HotkeyConfig {
  const HotkeyConfig({
    required this.actionId,
    required this.enabled,
    required this.modifiers,
    required this.key,
  });

  final String actionId;
  final bool enabled;
  final List<String> modifiers;
  final String key;

  String get displayText {
    final parts = <String>[];
    for (final modifier in modifiers) {
      parts.add(_formatModifier(modifier));
    }
    parts.add(key.toUpperCase());
    return parts.join(' + ');
  }

  String _formatModifier(String modifier) {
    switch (modifier.toLowerCase()) {
      case 'ctrl':
        return 'Ctrl';
      case 'shift':
        return 'Shift';
      case 'alt':
        return 'Alt';
      case 'meta':
        return 'Win';
      default:
        return modifier;
    }
  }

  HotkeyConfig copyWith({
    String? actionId,
    bool? enabled,
    List<String>? modifiers,
    String? key,
  }) {
    return HotkeyConfig(
      actionId: actionId ?? this.actionId,
      enabled: enabled ?? this.enabled,
      modifiers: modifiers ?? this.modifiers,
      key: key ?? this.key,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionId': actionId,
      'enabled': enabled,
      'modifiers': modifiers,
      'key': key,
    };
  }

  factory HotkeyConfig.fromJson(Map<String, dynamic> json) {
    return HotkeyConfig(
      actionId: json['actionId'] as String,
      enabled: json['enabled'] as bool? ?? true,
      modifiers: (json['modifiers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          [],
      key: json['key'] as String,
    );
  }
}
