import 'package:flutter/widgets.dart';

class HotkeyActionDescriptor {
  const HotkeyActionDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTrigger,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTrigger;
}
