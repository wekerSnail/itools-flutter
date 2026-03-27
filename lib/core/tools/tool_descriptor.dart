import 'package:flutter/material.dart';

class ToolDescriptor {
  const ToolDescriptor({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.route,
    required this.builder,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final String route;
  final WidgetBuilder builder;
}
