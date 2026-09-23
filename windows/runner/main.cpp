#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

// 主窗口识别属性。第二实例通过 EnumWindows + GetProp 查找，
// 不依赖窗口标题（可本地化）或共享的 Flutter 窗口类名。
constexpr const wchar_t kMainWindowProp[] = L"itools_flutter_main_wnd";

// 与 Dart 侧 WindowOptions(size: Size(680, 520)) 保持一致，
// 避免启动时 native 默认尺寸被 Dart 重设造成可见跳变。
constexpr int kMainWindowWidth = 680;
constexpr int kMainWindowHeight = 520;

namespace {

bool CommandLineContainsMultiWindow(const wchar_t* command_line) {
  return command_line != nullptr &&
         std::wstring(command_line).find(L"multi_window") != std::wstring::npos;
}

BOOL CALLBACK FindMainWindowByProp(HWND hwnd, LPARAM lparam) {
  if (::GetPropW(hwnd, kMainWindowProp) != nullptr) {
    *reinterpret_cast<HWND*>(lparam) = hwnd;
    return FALSE;
  }
  return TRUE;
}

HWND FindExistingMainWindow() {
  HWND found = nullptr;
  ::EnumWindows(FindMainWindowByProp, reinterpret_cast<LPARAM>(&found));
  return found;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command)
{
  // 多窗口子引擎不参与单实例检测，避免被误判为第二实例而提前退出。
  const bool is_multi_window = CommandLineContainsMultiWindow(command_line);

  HANDLE single_instance_mutex = nullptr;
  if (!is_multi_window)
  {
    single_instance_mutex =
        ::CreateMutexW(nullptr, FALSE, L"Global\\itools_flutter_single_instance_v1");
    if (single_instance_mutex == nullptr)
    {
      return EXIT_FAILURE;
    }

    if (::GetLastError() == ERROR_ALREADY_EXISTS)
    {
      HWND existing_window = FindExistingMainWindow();
      if (existing_window != nullptr)
      {
        if (::IsIconic(existing_window))
        {
          ::ShowWindow(existing_window, SW_RESTORE);
        }
        else
        {
          ::ShowWindow(existing_window, SW_SHOW);
        }
        ::SetForegroundWindow(existing_window);
      }
      ::CloseHandle(single_instance_mutex);
      return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent())
  {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(kMainWindowWidth, kMainWindowHeight);
  if (!window.Create(L"工具集", origin, size))
  {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  // 仅主窗口打标，供第二实例激活；子窗口/子引擎不设置。
  if (!is_multi_window)
  {
    HWND hwnd = window.GetHandle();
    if (hwnd != nullptr)
    {
      ::SetPropW(hwnd, kMainWindowProp, reinterpret_cast<HANDLE>(1));
    }
  }

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0))
  {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance_mutex != nullptr)
  {
    ::CloseHandle(single_instance_mutex);
  }
  return EXIT_SUCCESS;
}
