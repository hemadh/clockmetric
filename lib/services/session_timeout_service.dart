class SessionTimeoutService {
  SessionTimeoutService._();

  static final SessionTimeoutService instance =
      SessionTimeoutService._();

  void start(VoidCallback onTimeout) {
    // Automatic logout disabled.
  }

  void reset(VoidCallback onTimeout) {
    // Automatic logout disabled.
  }

  void stop() {
    // Nothing to stop.
  }
}

typedef VoidCallback = void Function();