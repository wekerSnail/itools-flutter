import 'package:flutter/material.dart';

import '../router/app_routes.dart';
import '../../features/backup_restore/presentation/backup_restore_page.dart';
import '../../features/folder_mapping/presentation/folder_mapping_page.dart';
import '../../features/scheduler/presentation/scheduler_page.dart';
import 'tool_descriptor.dart';

class ToolRegistry {
  ToolRegistry._();

  static final List<ToolDescriptor> tools = [
    ToolDescriptor(
      id: 'scheduler',
      title: '定时任务',
      description: '按时间与周期执行命令',
      icon: Icons.schedule,
      route: AppRoutes.scheduler,
      builder: (_) => const SchedulerPage(),
    ),
    ToolDescriptor(
      id: 'folder_mapping',
      title: '文件夹映射',
      description: '快捷管理并双击打开目录',
      icon: Icons.folder_copy_outlined,
      route: AppRoutes.folderMapping,
      builder: (_) => const FolderMappingPage(),
    ),
    ToolDescriptor(
      id: 'backup_restore',
      title: '备份还原',
      description: '导出当前数据或导入历史备份',
      icon: Icons.restore_page_outlined,
      route: AppRoutes.backupRestore,
      builder: (_) => const BackupRestorePage(),
    ),
  ];
}
