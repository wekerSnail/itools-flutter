# 后续优化 TODO

> 承接 `docs/compose/spec/p0-correctness.md`。P0 七项已完成（`8bcc5de`）。
> **P1–P3 主体已于本批落地**（见下方「已完成」）；剩余为可选增强。
> 分支策略：`optimize/p0-correctness` 先保持，后续优化可续用本分支或再切 `optimize/p1-*` 等。

## 已完成（本批）

### P1 安全与语义

- [x] **终端/JS 执行边界**
  - 去掉 `cmd /c` + `runInShell: true` 双重 shell；变量经 `cmd_escape.dart` 转义后写入临时 `.cmd` 再执行
  - 验收：含特殊字符的变量值不再被二次解析（单测覆盖空格/引号/`&|`/`%`/`!`/换行）
- [x] **文件夹打开注入面**
  - `folder_opener.dart` 三处去掉 `runInShell`
  - 验收：特殊字符路径可安全打开
- [x] **热键安全解析与冲突检测**
  - 未知 modifier 跳过并告警（不再静默 control）；保存前冲突确认框；注册期去重
  - 持久化 `keyId`（usbHidUsage），`key` 仅作展示；旧配置自动迁移
  - 验收：冲突绑定被确认/拒绝；未知按键不注册；重启后绑定可还原
- [x] **run_task_now 回执语义**
  - 跨窗口回执三态 `started` / `not_found` / `error`；超时本地合成「已提交（响应超时）」
  - 子窗口不再误报「任务已执行完成」
  - 验收：长任务不再被误报为已完成
- [x] **子窗口 WindowManagerService 流泄漏**
  - 子窗口不启动 `onWindowsChanged` 订阅；`dispose()`/`closeAll()`；json_formatter 子窗口禁止触碰该服务
  - 验收：子窗口退出后无残留订阅
- [x] **退出清理子窗口**
  - `_exitApp` 先 `WindowManagerService.closeAll()`（`force_close` 逐个销毁）再关主窗口
  - 验收：主窗口退出后无残留进程/窗口（需手动实测）
- [x] **主窗口尺寸不一致**
  - native `main.cpp` 与 Dart `WindowOptions` 统一 **680×520**
  - 验收：启动无尺寸跳变
- [x] **单实例标题字符串耦合**
  - 改为 `SetPropW` + `EnumWindows`/`GetProp`；子窗口 `multi_window` 跳过单实例检测
  - 验收：改窗口标题后第二实例仍能激活已有窗口
- [x] **run_task_now 与调度器加载竞态**
  - handler `await schedulerProvider.future`（3s 超时）；`reload()` 保留 previous value
  - 验收：启动瞬间手动触发不误报「任务不存在」

### P2 架构收敛

- [x] **合并两份备份页**
  - 抽 `BackupRestoreView`，`backup_settings_page` / `backup_restore_page` 只留壳
- [x] **folder_mapping 拆巨石**
  - 985 行 → 页面约 216 行；抽 `shortcut_card` / `collection_panel` / `shortcuts_panel` / editor dialogs / `core/widgets/popup_menu.dart`
  - 确认框统一 `showConfirmDialog`；id 走 `IdGenerator`
  - 验收：页面 < 300 行
  - 未做：Riverpod 跨窗口同步（可选后续）
- [x] **IconContainer 统一**
  - `core/widgets/icon_container.dart`；settings / hotkey / backup / home 已替换（theme 模式卡保留选中态自定义）
- [x] **弹窗 API 统一**
  - folder_mapping 改用 `showConfirmDialog`；核心 API 不再是死代码
- [x] **theme_provider `state.value!` 空安全**
  - `valueOrNull` + loading 直接 return
- [x] **JSON smartRepair Isolate 化**
  - 走 `Isolate.run`，与 format/minify 一致
- [x] **JSON `_removeTrailingCommas` 字符串态感知**
  - 扫描器实现，字符串内 `",}"` 不再被误删
- [x] **备份导入后刷新内存态**
  - `ref.invalidate(schedulerProvider / hotkeyProvider / themeProvider)`；toast 去掉「重新进入功能页」
- [x] **SchedulerService 空壳 / HotkeyActionRegistry 分层 / 备份 schema 迁移 / 全面 Provider DI**
  - 按分析结论降级或跳过（YAGNI / 零行为 / 以 `FileStore.debugBasePath` 满足可测性）

### P3 质量基建

- [x] **删除死代码**
  - `SkeletonLoader`、`ModernLoadingSpinner`、`CustomSegmentedButton`、`HoverScaleButton`、`AnimatedElevatedCard`、`app_routes.backupRestore`、`Spacing.pageHorizontalPadding`、`Typography.buttonLabel`、死 import
  - `EmptyStateWidget` 保留（仍在使用）→ `empty_state.dart`
- [x] **Style Guide 对齐**
  - `home_page`：`IconContainer` + 描述 `bodySmall`
  - `theme_settings`：`CustomScaffold` + `CustomCircularProgressIndicator`
  - `surface_cards` 圆角改 `BorderRadiusTokens.card`（md=12，与 token 表一致）
- [x] **补数据层单测**
  - `FileStore` 写串行/读写删、`FolderCollection.fromJson` per-item skip、`TaskVariable.copyWith` clearValue、cmd 转义、trailing commas
- [x] **补视觉回归**
  - 未做全量 golden（按分析降级）；现有 visual smoke 保持
- [x] **更新 AGENTS.md**
  - SharedPreferences → FileStore；单实例描述改为 SetProp 方案

### 小改进

- [x] `where node` 探测结果缓存
- [x] 进程日志加 `LineSplitter`
- [x] `TaskVariable.copyWith` 可 `clearValue`
- [x] Collection 内单条脏数据 per-item skip
- [x] `IdGenerator` 抽取
- [x] `providers.dart` 导出 `task_runner_provider.dart`
- [x] `page_header` 字面量 → `Spacing.xs`
- [x] `window_reveal` 180ms → `AnimationDuration.windowReveal`

## 可选后续

- [ ] folder_mapping 状态迁 Riverpod + FileStore watch（跨窗口/备份导入同步 UI）
- [ ] theme 模式选中态图标容器可选参数并入 `IconContainer`
- [ ] 关键组件尺寸/spacing 断言测试（替代 golden）
- [ ] 手动验收清单：终端特殊字符变量、长任务 run_task_now 文案、二次启动激活、托盘退出无残留、热键冲突框、备份导入即时刷新
