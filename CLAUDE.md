# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Language

Internal operations (tool calls, code comments, skills, analysis) can be in English. All user-facing responses must match the language the user writes in (e.g., if they write in Chinese, respond in Chinese).

## Project Overview

**itools** is a Windows-only Flutter desktop toolkit app with multi-window architecture and system tray integration. Each tool opens in its own OS window.

## Commands

```
flutter pub get                  # install deps
flutter run -d windows           # dev mode
flutter analyze                  # lint (strict mode enabled)
flutter test                     # run all tests
flutter test test/features/json_formatter/json_formatter_page_test.dart  # single test
flutter build windows --release  # release build → build/windows/x64/runner/Release/
```

No CI/CD configured. Run `flutter analyze` before committing. Deploy via `deploy.ps1`.

## Architecture

```
lib/
  main.dart          # entrypoint, multi-window dispatch, tray init, hotkey registration
  app.dart           # ShadApp root, theme, routing
  core/
    data/            # file_store.dart (JSON persistence to $APPDATA/itools/)
    design_tokens/   # spacing, typography, border_radius, duration, shadows
    providers/       # Riverpod providers (theme, scheduler, hotkey, window, tray, task_runner)
    router/          # app_routes.dart (constants), app_router.dart (onGenerateRoute)
    system/          # tray, single instance (FFI mutex), window manager
    themes/          # modern_theme.dart, luxury_theme.dart (ShadThemeData)
    tools/           # tool_registry.dart, tool_descriptor.dart
    widgets/         # page_header, custom_scaffold, surface_cards, etc.
  features/
    home/            # main grid page
    scheduler/       # timed tasks (JS scripts + terminal commands)
    folder_mapping/  # folder shortcuts with collections
    json_formatter/  # JSON editor with re_editor
    backup_restore/  # export/import JSON data files
    settings/        # settings menu (theme, backup, autostart)
    hotkey_settings/ # global hotkey configuration
```

Each feature follows: `domain/` (models), `data/` (persistence), `application/` (logic), `presentation/` (UI).

## Key Patterns

- **UI framework**: shadcn_ui (`ShadApp`, `ShadTheme`, `ShadCard`, `ShadButton`, `ShadToaster`). Do NOT use Material widgets. Material is only used internally for `Scaffold`/`Navigator` base.
- **State management**: Riverpod (`flutter_riverpod`). All providers in `lib/core/providers/`. Use `AsyncNotifierProvider` for data that loads from disk, `NotifierProvider` for imperative logic.
- **Data persistence**: `FileStore` class reads/writes JSON files to `$APPDATA/itools/`. Each feature has its own path (e.g. `scheduler/tasks.json`, `settings/theme.json`).
- **Multi-window**: Child windows detect `args.first == 'multi_window'`, extract toolId from `args[2]`. Each tool has its own window size defined in `ToolDescriptor`.
- **Single instance**: Windows FFI via kernel32 `CreateMutexW` + user32 `FindWindowW` in `single_instance_manager.dart`. Not portable.
- **Tray icon**: `assets/tray_icon.ico`. Path resolution differs between dev and release builds.
- **JSON editor**: `re_editor` package (`CodeLineEditingController`).
- **Design tokens**: Use `Spacing.*`, `Typography.*`, `BorderRadiusTokens.*`, `Shadows.*` from `lib/core/design_tokens/`. Spacing uses 8px grid (xs=4, sm=8, md=16, lg=24, xl=32, xxl=48).

## Page Structure Convention

All settings/tool pages follow this structure:

```
CustomScaffold
  └── PageHeader (title, subtitle, showBack: true)
  └── body: ListView (padding: Spacing.lg)
        ├── Section header with icon
        ├── SizedBox(height: Spacing.md)
        ├── [card content...]
        ├── SizedBox(height: Spacing.xl)   ← 32px between sections
        └── repeat...
```

Colors via `ShadTheme.of(context).colorScheme` — use `background`, `card`, `foreground`, `mutedForeground`, `primary`, `secondary`.

Card components: `SurfaceCard` (static), `InteractiveSurfaceCard` (with onTap/isSelected).

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

## Lint Rules (non-default, enforced)

- `require_trailing_commas` — trailing commas required everywhere
- `prefer_final_locals` / `prefer_final_fields` / `prefer_final_in_for_each`
- `directives_ordering` — sort imports alphabetically within sections
- `avoid_redundant_argument_values` — don't pass defaults explicitly
- `sort_child_properties_last` — `child:` must be last property
- `use_super_parameters` — use `super.key` syntax
- `cascade_invocations` — use cascades when possible
- Strict mode: `strict-casts`, `strict-inference`, `strict-raw-types` all enabled

## Windows-Specific

- Build requires Visual Studio C++ desktop development workload
- Deploy requires entire Release folder (not just exe)
- Target needs VC++ Redistributable 2022+
- `win32` package used for registry and system calls

## Docs

- `docs/tray/README.md` — tray diagnostics
- `docs/deployment/README.md` — deployment guide
- `docs/AUTOSTART_TROUBLESHOOTING.md` — startup issues
- `docs/features/json-formatter.md` — JSON formatter details
