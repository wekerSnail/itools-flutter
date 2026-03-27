import 'package:flutter/material.dart';

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
      route: '/tools/scheduler',
      builder: (_) => const SchedulerPage(),
    ),
    ToolDescriptor(
      id: 'folder_mapping',
      title: '文件夹映射',
      description: '快捷管理并双击打开目录',
      icon: Icons.folder_copy_outlined,
      route: '/tools/folder-mapping',
      builder: (_) => const FolderMappingPage(),
    ),
  ];
}
