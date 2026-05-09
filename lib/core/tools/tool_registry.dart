import 'dart:ui';

import 'package:flutter/material.dart';

import '../router/app_routes.dart';
import '../../features/folder_mapping/presentation/folder_mapping_page.dart';
import '../../features/json_formatter/presentation/json_formatter_page.dart';
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
      windowSize: const Size(950, 700),
      minWindowSize: const Size(800, 550),
    ),
    ToolDescriptor(
      id: 'folder_mapping',
      title: '文件夹映射',
      description: '快捷管理并双击打开目录',
      icon: Icons.folder_copy_outlined,
      route: AppRoutes.folderMapping,
      builder: (_) => const FolderMappingPage(),
      windowSize: const Size(900, 650),
      minWindowSize: const Size(700, 500),
    ),
    ToolDescriptor(
      id: 'json_formatter',
      title: 'JSON 格式化',
      description: '格式化、压缩、转义及智能修复JSON数据',
      icon: Icons.data_object,
      route: AppRoutes.jsonFormatter,
      builder: (_) => const JsonFormatterPage(),
      windowSize: const Size(1000, 700),
      minWindowSize: const Size(800, 550),
    ),
  ];

  static ToolDescriptor? findById(String id) {
    return tools.where((t) => t.id == id).firstOrNull;
  }
}
