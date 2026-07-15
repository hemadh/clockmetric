import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';

class ScreenshotGalleryScreen extends StatefulWidget {
  const ScreenshotGalleryScreen({super.key});

  @override
  State<ScreenshotGalleryScreen> createState() =>
      _ScreenshotGalleryScreenState();
}

class _ScreenshotGalleryScreenState
    extends State<ScreenshotGalleryScreen> {
  static const Color orange = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color darkText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color borderColor = Color(0xFFE2E8F0);

  bool loading = true;
  String? loadError;

  DateTime selectedDate = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  List<Map<String, dynamic>> screenshots = [];

  final Map<String, Future<Uint8List?>> _imageFutures = {};

  bool get isAdmin =>
      currentUserRole.trim().toLowerCase() == 'admin';

  bool get isToday {
    final today = DateTime.now();

    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

  final _key = encrypt.Key.fromUtf8(
    '12345678901234567890123456789012',
  );

  final _iv = encrypt.IV.fromUtf8(
    '1234567890123456',
  );

  @override
  void initState() {
    super.initState();
    loadScreenshots();
  }

  Future<void> loadScreenshots() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      loadError = null;
      _imageFutures.clear();
    });

    try {
      final localDayStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
      );

      final localDayEnd = localDayStart.add(
        const Duration(days: 1),
      );

      final startUtc = localDayStart
          .toUtc()
          .toIso8601String();

      final endUtc = localDayEnd
          .toUtc()
          .toIso8601String();

      var query = supabase
          .from('screenshots')
          .select(
            'id, employee_id, employee_name, '
            'secure_image_path, captured_at, '
            'project_id, time_entry_id',
          )
          .eq('workspace_id', currentWorkspaceId)
          .gte('captured_at', startUtc)
          .lt('captured_at', endUtc);

      if (!isAdmin) {
        query = query.eq(
          'employee_id',
          currentUserId,
        );
      }

      final response = await query.order(
        'captured_at',
        ascending: false,
      );

      if (!mounted) return;

      setState(() {
        screenshots =
            List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (error) {
      debugPrint(
        'Failed to load screenshots: $error',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
        loadError =
            'Unable to load screenshots. Please try again.';
      });
    }
  }

  Future<Uint8List?> loadDecryptedImage(
    String secureImagePath,
  ) async {
    if (secureImagePath.trim().isEmpty) {
      return null;
    }

    try {
      final signedUrl = await supabase.storage
          .from('employee-screenshots')
          .createSignedUrl(
            secureImagePath,
            60,
          );

      final encryptedData = await NetworkAssetBundle(
        Uri.parse(signedUrl),
      ).load('');

      final encryptedBytes =
          encryptedData.buffer.asUint8List(
        encryptedData.offsetInBytes,
        encryptedData.lengthInBytes,
      );

      final encrypter = encrypt.Encrypter(
        encrypt.AES(
          _key,
          mode: encrypt.AESMode.cbc,
        ),
      );

      final decryptedBytes = encrypter.decryptBytes(
        encrypt.Encrypted(encryptedBytes),
        iv: _iv,
      );

      return Uint8List.fromList(
        decryptedBytes,
      );
    } catch (error) {
      // Missing or expired files are silently hidden.
      debugPrint(
        'Screenshot unavailable for '
        '$secureImagePath: $error',
      );

      return null;
    }
  }

  Future<Uint8List?> _imageFutureFor(
    Map<String, dynamic> screenshot,
  ) {
    final screenshotId =
        screenshot['id']?.toString() ?? '';

    final path =
        screenshot['secure_image_path']?.toString() ??
            '';

    final cacheKey = screenshotId.isNotEmpty
        ? screenshotId
        : path;

    return _imageFutures.putIfAbsent(
      cacheKey,
      () => loadDecryptedImage(path),
    );
  }

  void previousDay() {
    setState(() {
      selectedDate = selectedDate.subtract(
        const Duration(days: 1),
      );
    });

    loadScreenshots();
  }

  void nextDay() {
    if (isToday) return;

    final nextDate = selectedDate.add(
      const Duration(days: 1),
    );

    final today = DateTime.now();

    final todayOnly = DateTime(
      today.year,
      today.month,
      today.day,
    );

    if (nextDate.isAfter(todayOnly)) {
      return;
    }

    setState(() {
      selectedDate = nextDate;
    });

    loadScreenshots();
  }

  Future<void> chooseDate() async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: today.subtract(
        const Duration(days: 365),
      ),
      lastDate: today,
      helpText: 'Select screenshot date',
    );

    if (selected == null) return;

    setState(() {
      selectedDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
      );
    });

    await loadScreenshots();
  }

  DateTime? parseCapturedAt(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  String formatTime(dynamic value) {
    final date = parseCapturedAt(value);

    if (date == null) {
      return '--:--';
    }

    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String selectedDateText() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[selectedDate.month - 1]} '
        '${selectedDate.day}, '
        '${selectedDate.year}';
  }

  String hourGroupKey(dynamic value) {
    final date = parseCapturedAt(value);

    if (date == null) {
      return 'unknown';
    }

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}-'
        '${date.hour.toString().padLeft(2, '0')}';
  }

  String hourGroupLabel(
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return 'Unknown time';
    }

    final date = parseCapturedAt(
      items.first['captured_at'],
    );

    if (date == null) {
      return 'Unknown time';
    }

    final startHour = date.hour;
    final endHour = (date.hour + 1) % 24;

    return '${startHour.toString().padLeft(2, '0')}:00 - '
        '${endHour.toString().padLeft(2, '0')}:00';
  }

  String initials(String name) {
    final cleanName = name.trim();

    if (cleanName.isEmpty) {
      return 'E';
    }

    final parts = cleanName
        .split(RegExp(r'\s+'))
        .where(
          (part) => part.isNotEmpty,
        )
        .toList();

    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'
          .toUpperCase();
    }

    return parts.first[0].toUpperCase();
  }

  Map<String, List<Map<String, dynamic>>>
      groupByEmployee() {
    final grouped =
        <String, List<Map<String, dynamic>>>{};

    for (final screenshot in screenshots) {
      final employeeName =
          screenshot['employee_name']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? screenshot['employee_name'].toString()
              : 'Employee';

      grouped.putIfAbsent(
        employeeName,
        () => [],
      );

      grouped[employeeName]!.add(
        screenshot,
      );
    }

    return grouped;
  }

  Map<String, List<Map<String, dynamic>>> groupByHour(
    List<Map<String, dynamic>> employeeScreenshots,
  ) {
    final grouped =
        <String, List<Map<String, dynamic>>>{};

    for (final screenshot
        in employeeScreenshots) {
      final key = hourGroupKey(
        screenshot['captured_at'],
      );

      grouped.putIfAbsent(
        key,
        () => [],
      );

      grouped[key]!.add(
        screenshot,
      );
    }

    return grouped;
  }

  void openImage(
    Uint8List bytes,
    Map<String, dynamic> screenshot,
  ) {
    final employee =
        screenshot['employee_name']?.toString() ??
            'Employee';

    final capturedTime = formatTime(
      screenshot['captured_at'],
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(22),
          child: SizedBox(
            width: 1250,
            height: 780,
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 5,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  top: 16,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(
                        0.72,
                      ),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$employee • $capturedTime',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.of(
                        dialogContext,
                      ).pop();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget screenshotCard(
    Map<String, dynamic> screenshot,
  ) {
    final capturedTime = formatTime(
      screenshot['captured_at'],
    );

    final employeeName =
        screenshot['employee_name']?.toString() ??
            'Employee';

    return FutureBuilder<Uint8List?>(
      future: _imageFutureFor(screenshot),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _loadingScreenshotCard(
            capturedTime: capturedTime,
          );
        }

        final imageBytes = snapshot.data;

        // Do not display missing files or lock cards.
        if (imageBytes == null) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () {
                    openImage(
                      imageBytes,
                      screenshot,
                    );
                  },
                  borderRadius:
                      BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        width: 300,
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(7),
                          child: Image.memory(
                            imageBytes,
                            width: 300,
                            height: 170,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child:
                            _ScreenshotHoverOverlay(
                          onView: () {
                            openImage(
                              imageBytes,
                              screenshot,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      employeeName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: orange,
                        fontWeight:
                            FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    capturedTime,
                    style: const TextStyle(
                      color: darkText,
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingScreenshotCard({
    required String capturedTime,
  }) {
    return SizedBox(
      width: 300,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 300,
            height: 170,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius:
                  BorderRadius.circular(8),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 25,
                height: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: orange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              capturedTime,
              style: const TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget employeeSection(
    String employeeName,
    List<Map<String, dynamic>>
        employeeScreenshots,
  ) {
    final sortedScreenshots = [
      ...employeeScreenshots,
    ];

    sortedScreenshots.sort((a, b) {
      final first =
          parseCapturedAt(a['captured_at']) ??
              DateTime(1970);

      final second =
          parseCapturedAt(b['captured_at']) ??
              DateTime(1970);

      return second.compareTo(first);
    });

    final hourlyGroups = groupByHour(
      sortedScreenshots,
    );

    final sortedGroupEntries =
        hourlyGroups.entries.toList()
          ..sort((a, b) {
            final first = parseCapturedAt(
                  a.value.first['captured_at'],
                ) ??
                DateTime(1970);

            final second = parseCapturedAt(
                  b.value.first['captured_at'],
                ) ??
                DateTime(1970);

            return second.compareTo(first);
          });

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                    const Color(0xFFFFEDD5),
                child: Text(
                  initials(employeeName),
                  style: const TextStyle(
                    color: Color(0xFFC2410C),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  employeeName,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ),
              Text(
                '${employeeScreenshots.length}',
                style: const TextStyle(
                  fontSize: 16,
                  color: secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          ...sortedGroupEntries.map(
            (entry) {
              return _hourTimelineSection(
                label: hourGroupLabel(
                  entry.value,
                ),
                items: entry.value,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _hourTimelineSection({
    required String label,
    required List<Map<String, dynamic>> items,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 34,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Padding(
              padding:
                  const EdgeInsets.only(top: 1),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  color: orange,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 225,
                color: borderColor,
              ),
            ],
          ),
          const SizedBox(width: 22),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  height: 1,
                  margin:
                      const EdgeInsets.only(top: 6),
                  color: borderColor,
                ),
                const SizedBox(height: 25),
                Wrap(
                  spacing: 28,
                  runSpacing: 28,
                  children: items
                      .map(screenshotCard)
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget dateNavigationBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Screenshots',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Previous day',
            onPressed: previousDay,
            icon: const Icon(
              Icons.chevron_left,
            ),
          ),
          InkWell(
            onTap: chooseDate,
            borderRadius:
                BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 220,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius:
                    BorderRadius.circular(8),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: Row(
                mainAxisSize:
                    MainAxisSize.min,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 20,
                    color: secondaryText,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    selectedDateText(),
                    style: const TextStyle(
                      color: darkText,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next day',
            onPressed:
                isToday ? null : nextDay,
            icon: const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employeeGroups =
        groupByEmployee();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: orange,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Text(
          isAdmin
              ? 'Team Screenshots'
              : 'My Screenshots',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh screenshots',
            onPressed:
                loading ? null : loadScreenshots,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: orange,
        onRefresh: loadScreenshots,
        child: SingleChildScrollView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              dateNavigationBar(),
              const SizedBox(height: 26),
              if (loading)
                const SizedBox(
                  height: 400,
                  child: Center(
                    child:
                        CircularProgressIndicator(
                      color: orange,
                    ),
                  ),
                )
              else if (loadError != null)
                _errorView()
              else if (screenshots.isEmpty)
                _emptyView()
              else
                ...employeeGroups.entries.map(
                  (entry) {
                    return employeeSection(
                      entry.key,
                      entry.value,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 80,
        horizontal: 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.photo_library_outlined,
            size: 62,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            'No screenshots found for '
            '${selectedDateText()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: darkText,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use the date arrows above to check another day.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 80,
        horizontal: 30,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 58,
            color: Color(0xFF94A3B8),
          ),
          const SizedBox(height: 16),
          Text(
            loadError ??
                'Unable to load screenshots.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: orange,
            ),
            onPressed: loadScreenshots,
            icon: const Icon(
              Icons.refresh,
            ),
            label: const Text(
              'Try Again',
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotHoverOverlay
    extends StatefulWidget {
  const _ScreenshotHoverOverlay({
    required this.onView,
  });

  final VoidCallback onView;

  @override
  State<_ScreenshotHoverOverlay> createState() =>
      _ScreenshotHoverOverlayState();
}

class _ScreenshotHoverOverlayState
    extends State<_ScreenshotHoverOverlay> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          hovering = false;
        });
      },
      child: AnimatedOpacity(
        duration: const Duration(
          milliseconds: 160,
        ),
        opacity: hovering ? 1 : 0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(
              0.48,
            ),
            borderRadius:
                BorderRadius.circular(8),
          ),
          child: Center(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 14,
                ),
              ),
              onPressed: widget.onView,
              child: const Text(
                'VIEW',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}