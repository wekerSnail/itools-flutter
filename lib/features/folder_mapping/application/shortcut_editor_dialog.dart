import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/folder_mapping.dart';

/// Shows the create/edit dialog for a [FolderShortcut].
///
/// Returns the saved shortcut, or null when cancelled.
Future<FolderShortcut?> showShortcutEditorDialog({
  required BuildContext context,
  FolderShortcut? original,
}) async {
  final nameCtrl = TextEditingController(text: original?.name ?? '');
  final targetCtrl = TextEditingController(text: original?.targetPath ?? '');
  String? errorMsg;

  final result = await showDialog<FolderShortcut>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) {
        final shad = ShadTheme.of(context);

        Future<void> pickTarget() async {
          final path = await getDirectoryPath(confirmButtonText: '选择目标目录');
          if (path != null) {
            setDialog(() => targetCtrl.text = path);
          }
        }

        return ShadDialog(
          constraints: const BoxConstraints(maxWidth: 520),
          title: Row(
            children: [
              Icon(
                LucideIcons.link,
                size: 18,
                color: shad.colorScheme.foreground,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                original == null ? '新增快捷方式' : '编辑快捷方式',
                style: Typography.h4.copyWith(
                  color: shad.colorScheme.foreground,
                ),
              ),
            ],
          ),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            ShadButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final target = targetCtrl.text.trim();
                if (name.isEmpty || target.isEmpty) {
                  setDialog(() => errorMsg = '名称和目录不能为空');
                  return;
                }
                Navigator.of(context).pop(
                  FolderShortcut(
                    id: original?.id ?? nextEntityId(),
                    name: name,
                    targetPath: target,
                    createdAt: original?.createdAt ?? DateTime.now(),
                  ),
                );
              },
              child: const Text('保存'),
            ),
          ],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShadInput(
                controller: nameCtrl,
                placeholder: const Text('快捷方式名称'),
                autofocus: true,
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ShadInput(
                      controller: targetCtrl,
                      placeholder: const Text('目标目录路径'),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: pickTarget,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.folderOpen, size: 14),
                        SizedBox(width: Spacing.xs),
                        Text('浏览'),
                      ],
                    ),
                  ),
                ],
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
            ],
          ),
        );
      },
    ),
  );

  nameCtrl.dispose();
  targetCtrl.dispose();
  return result;
}
