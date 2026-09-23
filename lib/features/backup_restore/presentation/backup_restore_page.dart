import 'package:flutter/material.dart' hide Typography;
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/widgets/custom_scaffold.dart';
import '../../../core/widgets/page_header.dart';
import '../../backup_restore/presentation/backup_restore_view.dart';

class BackupRestorePage extends StatelessWidget {
  const BackupRestorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    return CustomScaffold(
      backgroundColor: shad.colorScheme.background,
      appBar: const PageHeader(title: '备份还原', subtitle: '导出当前数据，或导入历史备份进行迁移恢复'),
      body: const BackupRestoreView(),
    );
  }
}
