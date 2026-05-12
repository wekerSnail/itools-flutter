# itools-flutter

Flutter Windows desktop toolkit app. Multi-window architecture with system tray.

## Commands

```
flutter pub get                  # install deps
flutter run -d windows           # dev mode
flutter analyze                  # lint (strict: strict-casts, strict-inference, strict-raw-types)
flutter test                     # run tests
flutter build windows --release  # release build → build/windows/x64/runner/Release/
```

No CI/CD configured. Run `flutter analyze` before committing.

## Architecture

```
lib/
  main.dart          # entrypoint, multi-window dispatch, tray init
  app.dart           # ShadApp root, routes
  core/
    router/          # app_routes.dart (route constants), app_router.dart (onGenerateRoute)
    system/          # app_tray_service.dart, single_instance_manager.dart, window_manager_service.dart
    tools/           # tool_registry.dart (tool list), tool_descriptor.dart (tool model)
    widgets/         # page_header.dart (standard AppBar replacement)
  features/
    home/            # main grid page
    scheduler/       # timed tasks (JS scripts + terminal commands)
    folder_mapping/  # folder shortcuts with collections
    json_formatter/  # JSON editor with re_editor
    backup_restore/  # export/import SharedPreferences data
    settings/        # settings menu (backup, autostart, hotkey)
    hotkey_settings/ # global hotkey configuration
```

Each feature follows: `domain/` (models), `data/` (persistence), `application/` (logic), `presentation/` (UI).

## Key patterns

- **UI framework**: shadcn_ui (`ShadTheme`, `ShadCard`, `ShadButton`, `ShadToaster`). Material only for `Scaffold`/`Navigator` base.
- **Page header**: Use `PageHeader` widget (implements `PreferredSizeWidget`), not Material `AppBar`.
- **Data persistence**: `SharedPreferences` with versioned keys (e.g. `scheduler.tasks.v1`, `folder.mapping.v2`).
- **Multi-window**: Child windows detect `args.first == 'multi_window'`, extract toolId from `args[2]`. Each tool has its own window size.
- **Single instance**: Windows FFI via kernel32 `CreateMutexW` + user32 `FindWindowW`. Not portable.
- **Tray icon**: `assets/tray_icon.ico`. Path resolution differs between dev and release builds (multiple candidate paths checked).
- **Launch at startup**: Uses `launch_at_startup` package. Registry verification via PowerShell. VBS fallback for elevated setup.
- **JSON editor**: `re_editor` package (`CodeLineEditingController`).
- **JS editor**: `code_text_field` package (`CodeController` with `highlight/languages/javascript`).

## UI Style Guide

All settings pages must follow this consistent structure:

### Page Structure

```
Scaffold (background: shad.colorScheme.background)
  └── appBar: PageHeader (title, subtitle, showBack: true)
  └── body: ListView (padding: Spacing.lg)
        ├── PageSectionHeader (title, subtitle, icon)
        ├── SizedBox(height: Spacing.md)
        ├── [卡片内容...]
        ├── SizedBox(height: Spacing.xl)      ← 段落之间用 xl(32px) 分隔
        └── 重复以上模式...
```

### Spacing Constants

| Constant | Value | Usage |
|----------|-------|-------|
| `Spacing.xs` | 4px | 标题与副标题间距 |
| `Spacing.sm` | 8px | 图标与文字间距 |
| `Spacing.md` | 16px | 卡片默认 padding、SectionHeader 与内容间距 |
| `Spacing.lg` | 24px | 页面 ListView padding |
| `Spacing.xl` | 32px | 功能段落之间的间距 |

### Color Scheme

All colors via `ShadTheme.of(context).colorScheme`:

| Token | Usage |
|-------|-------|
| `background` | Scaffold 背景 |
| `card` | SurfaceCard 背景 |
| `foreground` | 主要文字（标题、标签） |
| `mutedForeground` | 次要文字（描述、副标题） |
| `primary` | 强调色（选中态、SectionHeader 图标） |
| `secondary` | 图标容器默认背景 |

### Card Components

- **SurfaceCard**: 静态信息展示卡片
- **InteractiveSurfaceCard**: 可交互卡片（onTap, isSelected）

### Icon Container (44x44)

```dart
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: shad.colorScheme.secondary.withValues(alpha: 0.45),
    borderRadius: BorderRadius.circular(BorderRadiusTokens.md),
  ),
  child: Icon(icon, size: 18, color: shad.colorScheme.secondaryForeground),
)
```

### Typography

| Style | Usage |
|-------|-------|
| `Typography.h4` + `foreground` | PageHeader/SectionHeader 标题 |
| `Typography.label` + `foreground` | 卡片标题 |
| `Typography.bodySmall` + `mutedForeground` | 描述文字 |

## Adding a New Tool

1. Create `lib/features/{name}/` with domain/data/application/presentation layers
2. Add `ToolDescriptor` to `lib/core/tools/tool_registry.dart`
3. Add route constant to `lib/core/router/app_routes.dart`
4. Register backup key in `lib/features/backup_restore/data/app_backup_service.dart` `managedKeys` if data should be backed up
5. Register hotkey action in `main.dart` `_registerBuiltinHotkeyActions()`:
```dart
registry.register(
  HotkeyActionDescriptor(
    id: 'open_{name}',
    title: '打开{功能名}',
    description: '打开{功能名}页面',
    icon: tool.icon,
    onTrigger: () => WindowManagerService.instance.openToolWindow(tool),
  ),
);
```

## Adding a Settings Page

1. Create `lib/features/settings/presentation/{name}_settings_page.dart`
2. Add menu entry in `lib/features/settings/presentation/settings_page.dart`:
```dart
_SettingsMenuItem(
  icon: LucideIcons.xxx,
  title: '设置项标题',
  description: '设置项描述',
  pageBuilder: () => const XxxSettingsPage(),
),
```
3. Follow the UI Style Guide for page structure
4. If data needs backup, add to `managedFiles` in `app_backup_service.dart`

## Adding a Global Hotkey Action

Register in `main.dart` `_registerBuiltinHotkeyActions()`:
```dart
registry.register(
  HotkeyActionDescriptor(
    id: 'action_id',
    title: '动作名称',
    description: '动作描述',
    icon: LucideIcons.xxx,
    onTrigger: () {
      // 触发逻辑
    },
  ),
);
```

## Lint rules (non-default, enforced)

- `require_trailing_commas` — trailing commas required
- `prefer_final_locals` / `prefer_final_fields` / `prefer_final_in_for_each`
- `directives_ordering` — sort imports alphabetically within sections
- `avoid_redundant_argument_values` — don't pass defaults explicitly
- `sort_child_properties_last` — `child:` must be last property
- `use_super_parameters` — use `super.key` syntax
- `cascade_invocations` — use cascades when possible

## Windows-specific

- Build requires Visual Studio C++ desktop development workload
- Deploy requires entire Release folder (not just exe)
- Target needs VC++ Redistributable 2022+
- `win32` package used for registry and system calls

## MCP

- When you need to search docs or reference library APIs, use `context7` tools.

## Docs

- `docs/tray/README.md` — tray diagnostics
- `docs/deployment/README.md` — deployment guide
- `docs/AUTOSTART_TROUBLESHOOTING.md` — startup issues
- `docs/features/json-formatter.md` — JSON formatter details
