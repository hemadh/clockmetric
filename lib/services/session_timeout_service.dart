import 'dart:async';

class SessionTimeoutService {
  SessionTimeoutService._();

  static final SessionTimeoutService instance =
      SessionTimeoutService._();

  Timer? _timer;

  static const Duration timeout = Duration(minutes: 10);

  void start(VoidCallback onTimeout) {
    stop();

    _timer = Timer(timeout, () {
      onTimeout();
    });
  }

  void reset(VoidCallback onTimeout) {
    start(onTimeout);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

typedef VoidCallback = void Function();