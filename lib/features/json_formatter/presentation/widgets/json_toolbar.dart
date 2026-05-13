import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

enum JsonOperation {
  format('格式化'),
  minify('压缩'),
  escape('转义'),
  unescape('反转义');

  const JsonOperation(this.label);
  final String label;
}

class JsonToolbar extends StatelessWidget {
  const JsonToolbar({
    super.key,
    required this.onOperation,
    required this.onSmartRepair,
    required this.onSwap,
    required this.onCopy,
    required this.onClear,
  });

  final ValueChanged<JsonOperation> onOperation;
  final VoidCallback onSmartRepair;
  final VoidCallback onSwap;
  final VoidCallback onCopy;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: shad.colorScheme.background,
        border: Border(bottom: BorderSide(color: shad.colorScheme.border)),
      ),
      child: Row(
        children: [
          ...JsonOperation.values.map((op) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ShadButton.ghost(
                size: ShadButtonSize.sm,
                onPressed: () => onOperation(op),
                child: Text(op.label),
              ),
            );
          }),
          const SizedBox(width: 8),
          Container(width: 1, height: 20, color: shad.colorScheme.border),
          const SizedBox(width: 8),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: onSmartRepair,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.zap, size: 14),
                SizedBox(width: 4),
                Text('智能修复'),
              ],
            ),
          ),
          const Spacer(),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: onSwap,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.arrowLeftRight, size: 14),
                SizedBox(width: 4),
                Text('交换'),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: onCopy,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.copy, size: 14),
                SizedBox(width: 4),
                Text('复制'),
              ],
            ),
          ),
          const SizedBox(width: 6),
          ShadButton.ghost(
            size: ShadButtonSize.sm,
            onPressed: onClear,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.trash2, size: 14),
                SizedBox(width: 4),
                Text('清空'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
