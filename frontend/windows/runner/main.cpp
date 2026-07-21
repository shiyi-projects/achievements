#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// Unique mutex name for single-instance enforcement.
static constexpr const wchar_t kSingleInstanceMutex[] =
    L"Global\\AchievementsApp_SingleInstance_Mutex";

// Window class name from win32_window.cpp - used to find existing instance.
static constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // ── Single-instance guard ──
  HANDLE mutex = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running – bring it to front and exit.
    if (mutex) ::CloseHandle(mutex);
    HWND existing = ::FindWindowW(kWindowClassName, nullptr);
    if (existing) {
      if (::IsIconic(existing)) {
        ::ShowWindow(existing, SW_RESTORE);
      } else if (!::IsWindowVisible(existing)) {
        // 已有实例可能驻留托盘(窗口隐藏而非最小化);若托盘图标已丢失
        // (如 explorer 重启),用户将永远无法唤出窗口 → 这里直接显示。
        ::ShowWindow(existing, SW_SHOW);
      }
      ::SetForegroundWindow(existing);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
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
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"achievements", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  // Release the mutex when the app exits.
  if (mutex) {
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
