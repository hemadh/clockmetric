#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>
#include <vector>

#include "flutter_window.h"
#include "utils.h"

void RegisterTimeTrackerProtocol() {
  wchar_t executable_path[MAX_PATH];

  const DWORD path_length = GetModuleFileNameW(
      nullptr,
      executable_path,
      MAX_PATH
  );

  if (path_length == 0 || path_length == MAX_PATH) {
    return;
  }

  HKEY protocol_key;

  const wchar_t* protocol_path =
      L"Software\\Classes\\timetracker";

  if (RegCreateKeyExW(
          HKEY_CURRENT_USER,
          protocol_path,
          0,
          nullptr,
          REG_OPTION_NON_VOLATILE,
          KEY_WRITE,
          nullptr,
          &protocol_key,
          nullptr) != ERROR_SUCCESS) {
    return;
  }

  const wchar_t* description =
      L"URL:FloraTime Protocol";

  RegSetValueExW(
      protocol_key,
      nullptr,
      0,
      REG_SZ,
      reinterpret_cast<const BYTE*>(description),
      static_cast<DWORD>(
          (wcslen(description) + 1) *
          sizeof(wchar_t)));

  const wchar_t* empty_value = L"";

  RegSetValueExW(
      protocol_key,
      L"URL Protocol",
      0,
      REG_SZ,
      reinterpret_cast<const BYTE*>(empty_value),
      sizeof(wchar_t));

  RegCloseKey(protocol_key);

  HKEY command_key;

  const wchar_t* command_path =
      L"Software\\Classes\\timetracker\\shell\\open\\command";

  if (RegCreateKeyExW(
          HKEY_CURRENT_USER,
          command_path,
          0,
          nullptr,
          REG_OPTION_NON_VOLATILE,
          KEY_WRITE,
          nullptr,
          &command_key,
          nullptr) != ERROR_SUCCESS) {
    return;
  }

  const std::wstring command =
      L"\"" +
      std::wstring(executable_path) +
      L"\" \"%1\"";

  RegSetValueExW(
      command_key,
      nullptr,
      0,
      REG_SZ,
      reinterpret_cast<const BYTE*>(command.c_str()),
      static_cast<DWORD>(
          (command.length() + 1) *
          sizeof(wchar_t)));

  RegCloseKey(command_key);
}

int APIENTRY wWinMain(
    _In_ HINSTANCE instance,
    _In_opt_ HINSTANCE prev,
    _In_ wchar_t* command_line,
    _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) &&
      ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(
      nullptr,
      COINIT_APARTMENTTHREADED);

  // Registers timetracker:// links for FloraTime.
  RegisterTimeTrackerProtocol();

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(
      std::move(command_line_arguments));

  FlutterWindow window(project);

  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.Create(
          L"FloraTime",
          origin,
          size)) {
    return EXIT_FAILURE;
  }

  window.SetQuitOnClose(true);

  ::MSG msg;

  while (::GetMessage(
      &msg,
      nullptr,
      0,
      0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();

  return EXIT_SUCCESS;
}