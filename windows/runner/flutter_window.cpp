#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <optional>
#include <vector>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(
    const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ =
      std::make_unique<
          flutter::FlutterViewController>(
          frame.right - frame.left,
          frame.bottom - frame.top,
          project_);

  if (!flutter_controller_->engine() ||
      !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(
      flutter_controller_->engine());

  // =============================================
  // REGISTER KEYBOARD RAW INPUT
  // =============================================

  RAWINPUTDEVICE keyboard_device{};

  keyboard_device.usUsagePage = 0x01;
  keyboard_device.usUsage = 0x06;
  keyboard_device.dwFlags = RIDEV_INPUTSINK;
  keyboard_device.hwndTarget = GetHandle();

  if (!RegisterRawInputDevices(
          &keyboard_device,
          1,
          sizeof(RAWINPUTDEVICE))) {
    OutputDebugString(
        L"Failed to register keyboard input.\n");
  }

  // =============================================
  // KEYBOARD METHOD CHANNEL
  // =============================================

  keyboard_channel_ =
      std::make_unique<
          flutter::MethodChannel<
              flutter::EncodableValue>>(
          flutter_controller_
              ->engine()
              ->messenger(),
          "hamro_time_tracker/keyboard_activity",
          &flutter::StandardMethodCodec::
              GetInstance());

  keyboard_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<
              flutter::EncodableValue>& call,
          std::unique_ptr<
              flutter::MethodResult<
                  flutter::EncodableValue>>
              result) {

        // -----------------------------------------
        // START KEYBOARD TRACKING
        // -----------------------------------------

        if (call.method_name() == "start") {
          keyboard_press_count_.store(0);

          keyboard_tracking_enabled_ = true;

          OutputDebugString(
              L"Keyboard tracking started.\n");

          result->Success();
          return;
        }

        // -----------------------------------------
        // GET + RESET KEYBOARD COUNT
        // -----------------------------------------

        if (call.method_name() ==
            "getAndResetCount") {

          int64_t count =
              keyboard_press_count_
                  .exchange(0);

          result->Success(
              flutter::EncodableValue(
                  count));

          return;
        }

        // -----------------------------------------
        // STOP KEYBOARD TRACKING
        // -----------------------------------------

        if (call.method_name() == "stop") {
          keyboard_tracking_enabled_ = false;

          int64_t count =
              keyboard_press_count_
                  .exchange(0);

          OutputDebugString(
              L"Keyboard tracking stopped.\n");

          result->Success(
              flutter::EncodableValue(
                  count));

          return;
        }

        result->NotImplemented();
      });

  // =============================================
  // MOUSE METHOD CHANNEL
  // =============================================

  mouse_channel_ =
      std::make_unique<
          flutter::MethodChannel<
              flutter::EncodableValue>>(
          flutter_controller_
              ->engine()
              ->messenger(),
          "hamro_time_tracker/mouse_activity",
          &flutter::StandardMethodCodec::
              GetInstance());

  mouse_channel_->SetMethodCallHandler(
      [this](
          const flutter::MethodCall<
              flutter::EncodableValue>& call,
          std::unique_ptr<
              flutter::MethodResult<
                  flutter::EncodableValue>>
              result) {

        // -----------------------------------------
        // START MOUSE TRACKING
        // -----------------------------------------

        if (call.method_name() == "start") {
          mouse_movement_count_.store(0);

          mouse_tracking_enabled_ = true;

          // Get initial cursor position.
          POINT current_position{};

          if (GetCursorPos(
                  &current_position)) {

            last_mouse_position_ =
                current_position;

            has_last_mouse_position_ =
                true;
          } else {
            has_last_mouse_position_ =
                false;
          }

          // Remove old timer if one somehow exists.
          if (mouse_timer_id_ != 0) {
            KillTimer(
                GetHandle(),
                mouse_timer_id_);

            mouse_timer_id_ = 0;
          }

          // Start a 200 ms timer.
          //
          // 1000 / 200 = 5 checks per second.
          mouse_timer_id_ =
              SetTimer(
                  GetHandle(),
                  kMouseTimerId,
                  kMouseCheckIntervalMs,
                  nullptr);

          if (mouse_timer_id_ == 0) {
            mouse_tracking_enabled_ =
                false;

            OutputDebugString(
                L"Failed to start mouse timer.\n");

            result->Error(
                "MOUSE_TIMER_ERROR",
                "Could not start mouse timer.");

            return;
          }

          OutputDebugString(
              L"Mouse tracking started.\n");

          result->Success();
          return;
        }

        // -----------------------------------------
        // GET + RESET MOUSE COUNT
        // -----------------------------------------

        if (call.method_name() ==
            "getAndResetCount") {

          int64_t count =
              mouse_movement_count_
                  .exchange(0);

          result->Success(
              flutter::EncodableValue(
                  count));

          return;
        }

        // -----------------------------------------
        // STOP MOUSE TRACKING
        // -----------------------------------------

        if (call.method_name() == "stop") {
          mouse_tracking_enabled_ = false;

          if (mouse_timer_id_ != 0) {
            KillTimer(
                GetHandle(),
                mouse_timer_id_);

            mouse_timer_id_ = 0;
          }

          int64_t count =
              mouse_movement_count_
                  .exchange(0);

          has_last_mouse_position_ =
              false;

          OutputDebugString(
              L"Mouse tracking stopped.\n");

          result->Success(
              flutter::EncodableValue(
                  count));

          return;
        }

        result->NotImplemented();
      });

  // =============================================
  // SHOW FLUTTER WINDOW
  // =============================================

  SetChildContent(
      flutter_controller_
          ->view()
          ->GetNativeWindow());

  flutter_controller_
      ->engine()
      ->SetNextFrameCallback(
          [&]() {
            this->Show();
          });

  flutter_controller_->ForceRedraw();

  return true;
}

// ===============================================
// DESTROY
// ===============================================

void FlutterWindow::OnDestroy() {
  keyboard_tracking_enabled_ = false;
  mouse_tracking_enabled_ = false;

  // Stop mouse timer.
  if (mouse_timer_id_ != 0) {
    KillTimer(
        GetHandle(),
        mouse_timer_id_);

    mouse_timer_id_ = 0;
  }

  has_last_mouse_position_ = false;

  keyboard_channel_.reset();
  mouse_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

// ===============================================
// WINDOWS MESSAGE HANDLER
// ===============================================

LRESULT FlutterWindow::MessageHandler(
    HWND hwnd,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {

  // =============================================
  // KEYBOARD RAW INPUT
  // =============================================

  if (message == WM_INPUT &&
      keyboard_tracking_enabled_) {

    UINT size = 0;

    GetRawInputData(
        reinterpret_cast<HRAWINPUT>(
            lparam),
        RID_INPUT,
        nullptr,
        &size,
        sizeof(RAWINPUTHEADER));

    if (size > 0) {
      std::vector<BYTE>
          buffer(size);

      UINT raw_result =
          GetRawInputData(
              reinterpret_cast<HRAWINPUT>(
                  lparam),
              RID_INPUT,
              buffer.data(),
              &size,
              sizeof(RAWINPUTHEADER));

      if (raw_result == size) {

        RAWINPUT* raw =
            reinterpret_cast<RAWINPUT*>(
                buffer.data());

        if (raw->header.dwType ==
            RIM_TYPEKEYBOARD) {

          const RAWKEYBOARD& keyboard =
              raw->data.keyboard;

          if (keyboard.Message ==
                  WM_KEYDOWN ||
              keyboard.Message ==
                  WM_SYSKEYDOWN) {

            keyboard_press_count_
                .fetch_add(1);
          }
        }
      }
    }
  }

  // =============================================
  // MOUSE COORDINATE CHECK
  // =============================================

  if (message == WM_TIMER &&
      mouse_tracking_enabled_ &&
      mouse_timer_id_ != 0 &&
      static_cast<UINT_PTR>(wparam) ==
          mouse_timer_id_) {

    POINT current_position{};

    if (GetCursorPos(
            &current_position)) {

      // If there is no previous coordinate yet,
      // save the current position as the starting
      // point without counting movement.
      if (!has_last_mouse_position_) {

        last_mouse_position_ =
            current_position;

        has_last_mouse_position_ =
            true;

      } else {

        // Compare current X/Y against previous X/Y.
        bool mouse_moved =
            current_position.x !=
                last_mouse_position_.x ||
            current_position.y !=
                last_mouse_position_.y;

        if (mouse_moved) {

          // One activity sample detected.
          mouse_movement_count_
              .fetch_add(1);

          // Update comparison position.
          last_mouse_position_ =
              current_position;
        }
      }
    }

    return 0;
  }

  // =============================================
  // LET FLUTTER / PLUGINS HANDLE MESSAGES
  // =============================================

  if (flutter_controller_) {

    std::optional<LRESULT> result =
        flutter_controller_
            ->HandleTopLevelWindowProc(
                hwnd,
                message,
                wparam,
                lparam);

    if (result) {
      return *result;
    }
  }

  switch (message) {

    case WM_FONTCHANGE:

      if (flutter_controller_) {

        flutter_controller_
            ->engine()
            ->ReloadSystemFonts();
      }

      break;
  }

  return Win32Window::MessageHandler(
      hwnd,
      message,
      wparam,
      lparam);
}