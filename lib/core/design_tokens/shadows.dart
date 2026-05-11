import 'package:flutter/material.dart';

/// Shadow design tokens for elevation system
class Shadows {
  // No shadow (elevation 0)
  static const List<BoxShadow> none = <BoxShadow>[];

  // Subtle shadow - for slightly elevated elements
  static const List<BoxShadow> sm = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  // Small shadow - for cards and hover states
  static const List<BoxShadow> md = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2)),
  ];

  // Medium shadow - for floating elements
  static const List<BoxShadow> lg = <BoxShadow>[
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  // Large shadow - for modals and top-level elements
  static const List<BoxShadow> xl = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 16, offset: Offset(0, 8)),
  ];

  // Extra large shadow
  static const List<BoxShadow> xxl = <BoxShadow>[
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 12)),
  ];
}
