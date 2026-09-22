---
feature: p0-correctness
status: delivered
updated: 2026-02-11
branch: optimize/p0-correctness
commits: e1128baea2d7d8217afeaf97bfc1a60904445e73..optimize/p0-correctness
---

# P0 正确性优化

> Workspace 覆盖：环境禁止 `git worktree add`，改为在主检出上切分支 `optimize/p0-correctness` 实现。

## Report

**What was built** — 一次交付 7 项 P0 正确性修复：FileStore 同路径写串行化，防止并发写坏 JSON；备份导入拒绝非 String 值并采用先校验后落盘的两阶段写入，避免 `toString()` 破坏目标文件；`openToolWindow` 窗口 id 改为 append 去重，多开后不再产生孤儿窗口；托盘 `initialize` 以共享 Future 幂等，失败可重试且不重复挂监听；调度器任务加 in-flight 集合防并发重入；`tasks.json` 目录 watch 前强制创建目录，失败时 30s 轮询兜底；`StaggeredAnimationBuilder` 按 index 延迟入场。审查后另收口三处 Nit：窗口失效只移除单个 windowId、托盘失败路径摘监听、watch 流 `onError` 转入轮询。

**Verification** — `flutter analyze --no-pub` → PASS（No issues found）；`flutter test` → PASS（14/14 All tests passed）。独立审查 T1–T7 全部 PASS，无 Critical。

**Journey log** — 环境禁止 `git worktree add`，compose-next 默认 worktree 流程改为当前检出切分支；`entry.value.toString()` 与固定 `.tmp` 并发写是审查中最易被忽略的数据损坏面；`Directory.watch` 既可能同步抛也可能在流上异步抛，只包 try/catch 不够。

## [S1] Problem

架构审查发现 7 处 Critical 级正确性缺陷，会在真实使用中导致数据损坏、任务重入、窗口泄漏、托盘失效或动画失效。需要在一次变更内全部修复，并以单次提交交付。

## [S2] Design

### D1. FileStore 同文件写串行化

`writeJson` 对同一 `relativePath` 必须进程内串行。实现：模块级 `Map<String, Future<void>>` 写锁，后写等待前写完成。tmp 文件名保持 `path.tmp`（锁已保证同路径不交错）；崩溃清理逻辑不变。不引入跨进程锁。

### D2. 备份导入安全写入

`importBackup` 对每个 entry：

1. `entry.value` 必须是 `String`，否则跳过并计数，绝不 `toString()`。
2. 两阶段：先校验并收集 `Map<String, String>` 到内存，全部通过后再逐个 `writeJson`。中途写失败则中止并抛错。
3. `schemaVersion` 缺失视为 1；非 int 或大于当前版本拒绝。

### D3. 窗口 id 缓存 append

`openToolWindow` 在已有缓存时向列表 append 去重，而不是整体覆盖。失效清理按单个 windowId 粒度移除。

### D4. 托盘初始化幂等

`AppTrayService.initialize` 缓存 `Future<void>`，并发/重入共享同一 Future。成功后置位 `_initialized`；失败清空 Future 并摘掉监听，允许安全重试。

### D5. 调度任务 in-flight

`TaskRunner` 维护 `Set<String> _inFlightTaskIds`。`_execute` 开始时若已在集合中则跳过本次 occurrence（写日志说明），结束后移除。`runNow` 同样受 in-flight 约束。

### D6. 目录 watch 前确保目录存在

`_watchTasksFileForChanges` 在 `Directory.watch` 前 `create(recursive: true)`。watch 失败或流上异步错误时启动 30s 轮询 fallback 调用 `_syncTasksFromDiskIfChanged`，直到 dispose。

### D7. Stagger 动画使用 index

`StaggeredAnimationBuilder` 将 `index` 用于入场延迟：`delay = stagger * index`，其中 `stagger` 默认 `AnimationDuration.stagger`（若为 0 则回退 `Duration(milliseconds: 40)`）。index=0 立即播放入场动画。

### 统一验收语义

- 不改变对外 API 签名（除内部私有结构）。
- 不引入新依赖。
- 不扩大到 P1/P2/P3 项。

## [S3] Out of Scope

- shell 调用边界、热键冲突检测、run_task_now 三态回执、子窗口 dispose 门控（P1）
- 合并备份页、folder_mapping 重构、Provider 注入化（P2）
- 死代码清理、Style Guide 对齐、golden/单测补齐、AGENTS.md 文档修正（P3）
- 备份导入前自动快照
- 跨进程文件锁
- watch 失败后自动重挂 `watch()`（当前仅轮询兜底）

## Tasks

- [x] T1: FileStore 按 relativePath 写串行化 — acceptance: 并发两次 writeJson 同路径最终文件为后写内容且无混杂；异路径可并行 (covers: D1)
- [x] T2: importBackup 拒绝非 String value 并两阶段写入 — acceptance: 嵌套对象 entry 被跳过；目标文件不被 toString 破坏；校验失败不落盘 (covers: D2)
- [x] T3: openToolWindow 窗口 id append 去重 — acceptance: 多开后再次 openToolWindow 不丢失已有 windowId (covers: D3)
- [x] T4: AppTrayService.initialize 幂等 — acceptance: 并发调用 initialize 只执行一次底层初始化 (covers: D4)
- [x] T5: TaskRunner in-flight 防重入 — acceptance: 同任务执行期间到期不并发启动第二次 (covers: D5)
- [x] T6: tasks 目录 watch 前创建 + 失败轮询 fallback — acceptance: 目录不存在时后续外部修改仍能同步 (covers: D6)
- [x] T7: StaggeredAnimationBuilder 按 index 延迟入场 — acceptance: index 越大入场越晚；index=0 行为接近现状 (covers: D7)
