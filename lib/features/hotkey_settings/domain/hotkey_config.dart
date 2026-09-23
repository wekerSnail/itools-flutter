class HotkeyConfig {
  const HotkeyConfig({
    required this.actionId,
    required this.enabled,
    required this.modifiers,
    required this.key,
    this.keyId,
  });

  final String actionId;
  final bool enabled;
  final List<String> modifiers;

  /// 展示用按键标签（如 `A`、`Space`）。注册优先用 [keyId]。
  final String key;

  /// 稳定按键 id（USB HID usage）。布局/区域设置无关，重启后可还原。
  final int? keyId;

  String get displayText {
    final parts = <String>[];
    for (final modifier in modifiers) {
      parts.add(_formatModifier(modifier));
    }
    parts.add(key.toUpperCase());
    return parts.join(' + ');
  }

  /// 冲突比较用的签名：modifier 集合 + 稳定 key id（或退化为 key 标签）。
  String get signature {
    final mods = modifiers.map((m) => m.toLowerCase()).toList()..sort();
    final idPart = keyId?.toString() ?? key.toUpperCase();
    return '${mods.join('+')}|$idPart';
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
    int? keyId,
  }) {
    return HotkeyConfig(
      actionId: actionId ?? this.actionId,
      enabled: enabled ?? this.enabled,
      modifiers: modifiers ?? this.modifiers,
      key: key ?? this.key,
      keyId: keyId ?? this.keyId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actionId': actionId,
      'enabled': enabled,
      'modifiers': modifiers,
      'key': key,
      'keyId': keyId,
    };
  }

  factory HotkeyConfig.fromJson(Map<String, dynamic> json) {
    final key = json['key'] as String? ?? '';
    final rawKeyId = json['keyId'];
    int? keyId;
    if (rawKeyId is int) {
      keyId = rawKeyId;
    } else if (rawKeyId is num) {
      keyId = rawKeyId.toInt();
    }
    return HotkeyConfig(
      actionId: json['actionId'] as String,
      enabled: json['enabled'] as bool? ?? true,
      modifiers: (json['modifiers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          [],
      key: key,
      // 旧数据无 keyId：由 HotkeyService 在注册时从 key 标签迁移。
      keyId: keyId,
    );
  }
}
