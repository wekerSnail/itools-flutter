import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../design_tokens/index.dart';

Future<T?> showCustomDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x80000000),
    transitionDuration: const Duration(milliseconds: 200),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return builder(context);
    },
  );
}

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String content,
  String confirmText = '确认',
  String cancelText = '取消',
  bool isDestructive = false,
}) {
  final shad = ShadTheme.of(context);

  return showCustomDialog<bool>(
    context: context,
    builder: (context) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(Spacing.lg),
              decoration: BoxDecoration(
                color: shad.colorScheme.card,
                borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                border: Border.all(color: shad.colorScheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Typography.h4.copyWith(
                      color: shad.colorScheme.foreground,
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    content,
                    style: Typography.body.copyWith(
                      color: shad.colorScheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ShadButton.outline(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(cancelText),
                      ),
                      const SizedBox(width: Spacing.sm),
                      isDestructive
                          ? ShadButton.destructive(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(confirmText),
                            )
                          : ShadButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: Text(confirmText),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  String? placeholder,
  String? initialValue,
  String confirmText = '确认',
  String cancelText = '取消',
  String? Function(String value)? validator,
  bool isDestructive = false,
}) {
  final shad = ShadTheme.of(context);

  return showCustomDialog<String>(
    context: context,
    builder: (dialogContext) {
      final controller = TextEditingController(text: initialValue);
      String? errorMsg;

      return StatefulBuilder(
        builder: (context, setState) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Container(
                  padding: const EdgeInsets.all(Spacing.lg),
                  decoration: BoxDecoration(
                    color: shad.colorScheme.card,
                    borderRadius: BorderRadius.circular(BorderRadiusTokens.lg),
                    border: Border.all(color: shad.colorScheme.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Typography.h4.copyWith(
                          color: shad.colorScheme.foreground,
                        ),
                      ),
                      const SizedBox(height: Spacing.md),
                      ShadInput(
                        controller: controller,
                        placeholder:
                            placeholder != null ? Text(placeholder) : null,
                        autofocus: true,
                      ),
                      if (errorMsg != null) ...[
                        const SizedBox(height: Spacing.xs),
                        Text(
                          errorMsg!,
                          style: Typography.caption.copyWith(
                            color: shad.colorScheme.destructive,
                          ),
                        ),
                      ],
                      const SizedBox(height: Spacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ShadButton.outline(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(cancelText),
                          ),
                          const SizedBox(width: Spacing.sm),
                          isDestructive
                              ? ShadButton.destructive(
                                  onPressed: () {
                                    final value = controller.text.trim();
                                    if (validator != null) {
                                      final error = validator(value);
                                      if (error != null) {
                                        setState(() => errorMsg = error);
                                        return;
                                      }
                                    }
                                    Navigator.of(context).pop(value);
                                  },
                                  child: Text(confirmText),
                                )
                              : ShadButton(
                                  onPressed: () {
                                    final value = controller.text.trim();
                                    if (validator != null) {
                                      final error = validator(value);
                                      if (error != null) {
                                        setState(() => errorMsg = error);
                                        return;
                                      }
                                    }
                                    Navigator.of(context).pop(value);
                                  },
                                  child: Text(confirmText),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
