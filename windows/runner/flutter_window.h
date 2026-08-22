#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <cstdint>
#include <memory>
#include <windows.h>

#include "win32_window.h"

// A window that hosts a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(
      const flutter::DartProject& project);

  virtual ~FlutterWindow();

 protected:
  bool OnCreate() override;

  void OnDestroy() override;

  LRESULT MessageHandler(
      HWND window,
      UINT const message,
      WPARAM const wparam,
      LPARAM const lparam) noexcept override;

 private:
  // ---------------------------------------
  // Flutter
  // ---------------------------------------

  flutter::DartProject project_;

  std::unique_ptr<
      flutter::FlutterViewController>
      flutter_controller_;

  // ---------------------------------------
  // Keyboard activity tracking
  // ---------------------------------------

  std::atomic<int64_t>
      keyboard_press_count_{0};

  bool keyboard_tracking_enabled_ = false;

  std::unique_ptr<
      flutter::MethodChannel<
          flutter::EncodableValue>>
      keyboard_channel_;

  // ---------------------------------------
  // Mouse activity tracking
  // ---------------------------------------

  std::atomic<int64_t>
      mouse_movement_count_{0};

  bool mouse_tracking_enabled_ = false;

  std::unique_ptr<
      flutter::MethodChannel<
          flutter::EncodableValue>>
      mouse_channel_;

  // Previous mouse position.
  // Used only for comparison.
  // Coordinates are never stored in database.
  POINT last_mouse_position_{0, 0};

  bool has_last_mouse_position_ = false;

  // Windows timer used to check the cursor.
  UINT_PTR mouse_timer_id_ = 0;

  // 200 ms = approximately 5 checks per second.
  static constexpr UINT
      kMouseCheckIntervalMs = 200;

  static constexpr UINT_PTR
      kMouseTimerId = 1001;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_