import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/design_tokens/index.dart';
import '../../../core/utils/id_generator.dart';
import '../domain/folder_mapping.dart';

/// Shows the create/edit dialog for a [FolderCollection].
///
/// Returns the saved collection, or null when cancelled.
Future<FolderCollection?> showCollectionEditorDialog({
  required BuildContext context,
  FolderCollection? original,
}) async {
  final nameCtrl = TextEditingController(text: original?.name ?? '');
  String? errorMsg;

  final result = await showDialog<FolderCollection>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialog) {
        final shad = ShadTheme.of(context);
        return ShadDialog(
          constraints: const BoxConstraints(maxWidth: 480),
          title: Row(
            children: [
              Icon(
                LucideIcons.folderOpen,
                size: 18,
                color: shad.colorScheme.foreground,
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                original == null ? '新增集合' : '编辑集合',
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
                if (name.isEmpty) {
                  setDialog(() => errorMsg = '集合名称不能为空');
                  return;
                }
                Navigator.of(context).pop(
                  FolderCollection(
                    id: original?.id ?? nextEntityId(),
                    name: name,
                    items: original?.items ?? <FolderShortcut>[],
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
                placeholder: const Text('集合名称'),
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
            ],
          ),
        );
      },
    ),
  );

  nameCtrl.dispose();
  return result;
}
