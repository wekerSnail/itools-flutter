# 后续优化 TODO

> 承接 `docs/compose/spec/p0-correctness.md`。P0 七项已完成（`8bcc5de`）；本清单为 P1–P3 待办，按优先级排列。
> 分支策略：`optimize/p0-correctness` 先保持，后续优化可续用本分支或再切 `optimize/p1-*` 等。

## P1 安全与语义

- [ ] **终端/JS 执行边界**
  - `task_runner.dart`：`cmd /c` + `runInShell: true` 双重 shell；`_applyVariables` 裸字符串替换后可能被 cmd 二次解析（`&`/`|`/`>`）
  - 建议：变量改走环境变量或临时文件传参；或在 UI/文档明确「变量值需自行转义」
  - 验收：含特殊字符的变量值不再被二次解析

- [ ] **文件夹打开注入面**
  - `folder_opener.dart:8`：`Process.start('explorer', [path], runInShell: true)`，路径含 `&` 等可能被 shell 重解析
  - 建议：去掉 `runInShell`，或用 `ShellExecute` / `url_launcher`
  - 验收：特殊字符路径可安全打开

- [ ] **热键安全解析与冲突检测**
  - `hotkey_service.dart`：未知 modifier 静默回退 control；无冲突检测；`PhysicalKeyboardKey(code + 0x00070000 - 65 + 4)` HID 魔法数
  - 持久化存 `keyLabel`（`hotkey_settings_page.dart:254`），小键盘/符号键易丢
  - 建议：未知 modifier 跳过并告警；保存前查重；存 usbHidUsage / 稳定 id；显式 key 映射表
  - 验收：冲突绑定被拒绝；未知按键不注册

- [ ] **run_task_now 回执语义**
  - `main.dart:192-202` + `scheduler_page.dart:108-135`：fire-and-forget 后立刻 toast「任务已执行完成」，长任务误报；超时 `onTimeout: () => true` 吞失败
  - 建议：跨窗口只回「已提交」；完成态靠日志/状态通道；回执三态（成功/已提交/失败）
  - 验收：长任务不再被误报为已完成

- [ ] **子窗口 WindowManagerService 流泄漏**
  - `main.dart:106` 注释要求子窗口不碰 `WindowManagerService`，但 `json_formatter` 子窗口仍会 `onWindowsChanged.listen`（`window_manager_service.dart:67-85`）且永不取消
  - 建议：按 `AppRuntime.isChildWindow` 拆分，或提供 `dispose`
  - 验收：子窗口退出后无残留订阅

- [ ] **退出清理子窗口**
  - `app_tray_service.dart` `_exitApp` 只关主窗口，工具子窗口/引擎可能残留
  - 建议：退出前销毁全部子窗口
  - 验收：主窗口退出后无残留进程/窗口

- [ ] **主窗口尺寸不一致**
  - `main.cpp` native 创建 1280×720，Dart `WindowOptions` 680×520，启动可见尺寸跳变
  - 建议：统一常量
  - 验收：启动无尺寸跳变

- [ ] **单实例标题字符串耦合**
  - `main.cpp` `FindWindowW(..., kAppWindowTitle)` 与 Dart `title: '工具集'` 靠字符串匹配，改名/本地化会失效
  - 建议：native 记录主窗口 HWND 或用属性/自定义消息
  - 验收：改窗口标题后第二实例仍能激活已有窗口

- [ ] **run_task_now 与调度器加载竞态**
  - `main.dart:186-187`：provider 尚在 loading 时任务被判定不存在
  - 建议：等 ready 或 repository 直读
  - 验收：启动瞬间手动触发不误报「任务不存在」

## P2 架构收敛

- [ ] **合并两份备份页**
  - `backup_settings_page.dart` 与 `backup_restore_page.dart` 约 350 行逻辑/UI 整页复制
  - 建议：抽 `BackupRestoreView`，两入口只留壳
  - 验收：单一实现源；两入口行为一致

- [ ] **folder_mapping 拆巨石 + 迁 Riverpod**
  - `folder_mapping_page.dart`（约 985 行）CRUD/排序/自研 `_PopupMenu` 全塞 presentation；纯 `setState`，多窗口/备份导入无法同步
  - 与 `_ShortcutCard` 的 `ShadContextMenu` 重复造轮子
  - 建议：弹层抽 `core/widgets`；CRUD 下沉 application；状态迁 Riverpod + FileStore watch
  - 验收：页面 < 300 行；状态可跨窗口同步

- [ ] **IconContainer 统一**
  - 44×44 Icon 容器在 settings / hotkey / backup / theme 等 5 处手工复制
  - 建议：`core/widgets/icon_container.dart`
  - 验收：全站单一组件

- [ ] **弹窗 API 统一**
  - `custom_show_dialog.dart` 的 `showConfirmDialog`/`showInputDialog` 零调用；folder_mapping 自写 `_showConfirmDialog`
  - 建议：业务迁到核心 API，或删除死 API
  - 验收：只有一套弹窗体系

- [ ] **Provider 依赖可注入**
  - `theme_provider.dart:30`、`scheduler_provider.dart` 等 Service 字段直接 `new`，无法 mock
  - 建议：在 `build()` 内创建，或经 Provider 注入
  - 验收：关键 Service 可 override 做单测

- [ ] **theme_provider `state.value!` 空安全**
  - `theme_provider.dart:48,56`：AsyncLoading/Error 时 `setStyle`/`setMode` 会 NPE
  - 建议：判空或等待 ready
  - 验收：加载中改主题不崩溃

- [ ] **SchedulerService 空壳下沉**
  - `scheduler_service.dart` 仅透传 + debugPrint
  - 建议：合并进 store/provider，或下沉真正用例（校验、默认超时策略）
  - 验收：application 层有实际职责

- [ ] **HotkeyActionRegistry 分层**
  - 放在 `data/` 但属运行时注册表
  - 建议：移到 `application/` 或 `domain/`

- [ ] **JSON smartRepair Isolate 化**
  - `json_formatter_page.dart:213-214` 主 Isolate 执行，大 JSON 卡 UI（format/minify 已用 Isolate）
  - 建议：同样走 `_runInIsolate`
  - 验收：大文件 repair 不卡 UI

- [ ] **JSON `_removeTrailingCommas` 字符串态感知**
  - `json_formatter_service.dart:268-270` 正则会误删字符串内 `,}`
  - 建议：复用扫描器而非正则
  - 验收：字符串内容不被误改

- [ ] **备份导入后刷新内存态**
  - `backup_restore_page.dart:111` 导入成功仅 toast，不刷新 `schedulerProvider` 等
  - 建议：`ref.invalidate` 各 provider（tasks.json watch 只覆盖 scheduler）
  - 验收：导入后无需重开页面

- [ ] **备份 schema 迁移**
  - `app_backup_service.dart`：有 v1 也无 v1→v2 字段迁移
  - 建议：按版本做 key/字段迁移表

## P3 质量基建

- [ ] **删除死代码**
  - `SkeletonLoader`、`ModernLoadingSpinner`、`CustomSegmentedButton`、`HoverScaleButton`、`AnimatedElevatedCard`、`showConfirmDialog`/`showInputDialog`（若 P2 未采用则删）
  - `AnimationDuration.stagger` 已用；`Spacing.pageHorizontalPadding`、`Typography.buttonLabel` 基本闲置
  - `app_routes.dart:7` `backupRestore` 死常量

- [ ] **Style Guide 对齐**
  - `home_page.dart:112-137`：Icon 非 44×44、描述用 `labelSmall`（应为 `bodySmall`）、圆角 `lg` vs `md`
  - `theme_settings_page.dart:41-62`：Material `Scaffold` + `CircularProgressIndicator`，应统一 `CustomScaffold` + `CustomCircularProgressIndicator`
  - `json_formatter_page.dart`：`ShadCard`/`CircularProgressIndicator` 偏离设计系统
  - `surface_cards.dart:33` 卡片圆角写死，不随 Modern(12)/Luxury(16) 主题

- [ ] **补数据层单测**
  - 优先：`FileStore` 写串行、`app_backup_service` 导入校验、scheduler occurrence/in-flight、hotkey 解析
  - 验收：上述路径有行为级单测

- [ ] **补视觉回归**
  - `test/visual/*` 目前只是文案 smoke，无 golden
  - 建议：`matchesGoldenFile` + Icon/Spacing 尺寸断言；覆盖 dark / Luxury

- [ ] **更新 AGENTS.md**
  - 仍写「Settings via SharedPreferences」，实际已全走 FileStore
  - 补充多窗口/调度所有权说明与本 TODO 链接

## 小改进（可顺手）

- [ ] `task_runner.dart:230` 每次 JS 执行 `where node`，应缓存探测结果
- [ ] `task_runner.dart:205-210` 日志按 chunk 切，应加 `LineSplitter`
- [ ] `scheduled_task.dart:48-52` `copyWith` 无法将 `value` 置 null
- [ ] `folder_mapping.dart:83-92` Collection 内单条脏数据整条丢弃，应 per-item skip
- [ ] ID 生成 `timestamp_Random` 多处复制，抽 `IdGenerator`
- [ ] `providers.dart` barrel 未导出 `task_runner_provider.dart`
- [ ] `page_header.dart:45` 字面量 `4` 改 `Spacing.xs`
- [ ] `window_reveal_container.dart:34` 180ms 硬编码接入 `AnimationDuration`
