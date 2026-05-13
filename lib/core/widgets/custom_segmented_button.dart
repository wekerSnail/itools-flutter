import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

class CustomSegmentedButton<T> extends StatelessWidget {
  const CustomSegmentedButton({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.multiSelect = false,
  });

  final List<CustomButtonSegment<T>> segments;
  final Set<T> selected;
  final void Function(Set<T>) onSelectionChanged;
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: shad.colorScheme.secondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        border: Border.all(color: shad.colorScheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = selected.contains(segment.value);
          return _buildSegment(context, shad, segment, isSelected);
        }).toList(growable: false),
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    ShadThemeData shad,
    CustomButtonSegment<T> segment,
    bool isSelected,
  ) {
    return GestureDetector(
      onTap: () {
        if (multiSelect) {
          final updated = Set<T>.from(selected);
          if (isSelected) {
            updated.remove(segment.value);
          } else {
            updated.add(segment.value);
          }
          onSelectionChanged(updated);
        } else {
          onSelectionChanged({segment.value});
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? shad.colorScheme.primary : null,
          borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.icon != null) ...[
              Icon(
                segment.icon,
                size: 16,
                color: isSelected
                    ? shad.colorScheme.primaryForeground
                    : shad.colorScheme.foreground,
              ),
              const SizedBox(width: Spacing.xs),
            ],
            Text(
              segment.label,
              style: Typography.label.copyWith(
                color: isSelected
                    ? shad.colorScheme.primaryForeground
                    : shad.colorScheme.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomButtonSegment<T> {
  const CustomButtonSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}
