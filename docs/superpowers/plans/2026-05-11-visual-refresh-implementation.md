# Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 itools-flutter 全应用升级为统一的“精致专业”桌面视觉风格，并以主题设置页为样板逐步推广到高频页面。

**Architecture:** 先抽取共享视觉基础组件，再把 `theme_settings_page.dart` 改造成样板页，随后将同一套卡片、区块头、状态反馈和间距体系应用到设置首页、主页和备份还原页。业务逻辑尽量不动，只重构展示层和交互反馈。

**Tech Stack:** Flutter、shadcn_ui、现有 design tokens（spacing/border radius/shadows/typography/duration）、widget tests、flutter analyze

---

### Task 1: 建立共享视觉骨架

**Files:**

- Create: `e:\repo\itools-flutter\lib\core\widgets\surface_cards.dart`
- Modify: `e:\repo\itools-flutter\lib\core\widgets\page_header.dart`
- Modify: `e:\repo\itools-flutter\lib\core\widgets\loading_widgets.dart`
- Test: `e:\repo\itools-flutter\test\visual\surface_cards_test.dart`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 实现共享交互卡片、区块头、主题感知空状态/加载样式**
- [ ] **Step 4: 运行测试确认通过**

### Task 2: 重做主题设置页

**Files:**

- Modify: `e:\repo\itools-flutter\lib\features\settings\presentation\theme_settings_page.dart`
- Modify: `e:\repo\itools-flutter\lib\features\settings\domain\app_theme_style.dart` (only if preview metadata needed)
- Test: `e:\repo\itools-flutter\test\visual\theme_settings_page_test.dart`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 实现样板页布局、统一卡片语言、实时预览区**
- [ ] **Step 4: 运行测试确认通过**

### Task 3: 推广到设置首页与主页

**Files:**

- Modify: `e:\repo\itools-flutter\lib\features\settings\presentation\settings_page.dart`
- Modify: `e:\repo\itools-flutter\lib\features\home\presentation\home_page.dart`
- Test: `e:\repo\itools-flutter\test\visual\navigation_pages_visual_test.dart`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 迁移菜单卡片与工具卡片到共享视觉语言**
- [ ] **Step 4: 运行测试确认通过**

### Task 4: 推广到备份还原页

**Files:**

- Modify: `e:\repo\itools-flutter\lib\features\backup_restore\presentation\backup_restore_page.dart`
- Test: `e:\repo\itools-flutter\test\visual\backup_restore_page_test.dart`

- [ ] **Step 1: 写失败测试**
- [ ] **Step 2: 运行测试确认失败**
- [ ] **Step 3: 统一信息卡、动作卡、说明区与状态反馈**
- [ ] **Step 4: 运行测试确认通过**

### Task 5: 全量验证

**Files:**

- Modify: `e:\repo\itools-flutter\docs\superpowers\plans\2026-05-11-visual-refresh-implementation.md`

- [ ] **Step 1: 运行 `flutter analyze`**
- [ ] **Step 2: 运行 `flutter test`**
- [ ] **Step 3: 记录最终验证结果与剩余风险**
