import 'dart:async';

import 'time_entry_service.dart';

class HeartbeatService {
  static final HeartbeatService instance =
      HeartbeatService._internal();

  HeartbeatService._internal();

  Timer? _timer;
  String? _entryId;

  void start({
    required String entryId,
  }) {
    stop();

    _entryId = entryId;

    // Send one immediately
    TimeEntryService().updateHeartbeat(
      entryId: entryId,
    );

    // Then every 10 minutes
    _timer = Timer.periodic(
      const Duration(minutes: 10),
      (_) async {
        if (_entryId == null) return;

        await TimeEntryService().updateHeartbeat(
          entryId: _entryId!,
        );
      },
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _entryId = null;
  }
}