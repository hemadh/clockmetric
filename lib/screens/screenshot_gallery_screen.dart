import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:encrypter_plus/encrypter_plus.dart' as encrypt;
import 'package:intl/intl.dart';

import '../main.dart';
import '../services/screenshot_cleanup_service.dart';

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
  List<String> employees = ['All Employees'];

String selectedEmployee = 'All Employees';

  final Map<String, Future<Uint8List?>> _imageFutures = {};
  final ScreenshotCleanupService _cleanupService = ScreenshotCleanupService();

  bool get isAdmin =>
      currentUserRole.trim().toLowerCase() == 'admin';

  bool get isToday {
    final today = DateTime.now();

final todayOnly = DateTime(
  today.year,
  today.month,
  today.day,
);

final currentWeekStart = todayOnly.subtract(
  Duration(days: todayOnly.weekday - 1),
);

final earliestScreenshotDate = currentWeekStart.subtract(
  const Duration(days: 14),
);

    return selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;
  }

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

      final loadedScreenshots =
          List<Map<String, dynamic>>.from(response);

      // Load project names separately so screenshot loading does not depend
      // on a direct PostgREST relationship between screenshots and projects.
      // If this lookup ever fails, screenshots still load normally.
      final Map<String, String> projectNamesById = {};

      try {
        final projectRows = await supabase
            .from('projects')
            .select('id, project_name')
            .eq('workspace_id', currentWorkspaceId);

        for (final project in projectRows) {
          final projectId =
              project['id']?.toString().trim() ?? '';

          final projectName =
              project['project_name']?.toString().trim() ?? '';

          if (projectId.isNotEmpty && projectName.isNotEmpty) {
            projectNamesById[projectId] = projectName;
          }
        }
      } catch (error) {
        debugPrint(
          'Project names could not be loaded for screenshots: $error',
        );
      }

      for (final screenshot in loadedScreenshots) {
        final projectId =
            screenshot['project_id']?.toString().trim() ?? '';

        screenshot['project_name'] =
            projectNamesById[projectId] ?? '';
      }

final employeeNames = loadedScreenshots
    .map(
      (e) => (e['employee_name'] ?? 'Employee')
          .toString(),
    )
    .toSet()
    .toList()
  ..sort();

setState(() {
  screenshots = loadedScreenshots;

  employees = [
    'All Employees',
    ...employeeNames,
  ];

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
  Map<String, dynamic> screenshot,
) async {
  final screenshotId =
      screenshot['id']?.toString().trim() ?? '';

  final imagePath =
      screenshot['secure_image_path']?.toString().trim() ?? '';

  if (screenshotId.isEmpty || imagePath.isEmpty) {
    return null;
  }

  try {
    // Download the encrypted .enc bytes from the CURRENT Supabase project.
    final encryptedBytes = await supabase.storage
        .from('employee-screenshots')
        .download(imagePath);

    if (encryptedBytes.isEmpty) {
      return null;
    }

    // Must match ScreenshotSchedulerService exactly.
    final key = encrypt.Key.fromUtf8(
      '12345678901234567890123456789012',
    );

    final iv = encrypt.IV.fromUtf8(
      '1234567890123456',
    );

    final encrypter = encrypt.Encrypter(
      encrypt.AES(
        key,
        mode: encrypt.AESMode.cbc,
      ),
    );

    final decryptedBytes = encrypter.decryptBytes(
      encrypt.Encrypted(encryptedBytes),
      iv: iv,
    );

    if (decryptedBytes.isEmpty) {
      return null;
    }

    return Uint8List.fromList(
      decryptedBytes,
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Screenshot decrypt failed for $screenshotId: $error',
    );
    debugPrintStack(
      stackTrace: stackTrace,
    );
    return null;
  }
}

  Future<Uint8List?> _imageFutureFor(
    Map<String, dynamic> screenshot,
  ) {
    final screenshotId =
        screenshot['id']?.toString() ?? '';

    return _imageFutures.putIfAbsent(
      screenshotId,
      () => loadDecryptedImage(screenshot),
    );
  }


  void previousDay() {
  final today = DateTime.now();

  final todayOnly = DateTime(
    today.year,
    today.month,
    today.day,
  );

  final currentWeekStart = todayOnly.subtract(
    Duration(days: todayOnly.weekday - 1),
  );

  final earliestScreenshotDate = currentWeekStart.subtract(
    const Duration(days: 14),
  );

  final previousDate = selectedDate.subtract(
    const Duration(days: 1),
  );

  if (previousDate.isBefore(earliestScreenshotDate)) {
    return;
  }

  setState(() {
    selectedDate = previousDate;
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

    final todayOnly = DateTime(
  today.year,
  today.month,
  today.day,
);

final currentWeekStart = todayOnly.subtract(
  Duration(days: todayOnly.weekday - 1),
);

final earliestScreenshotDate = currentWeekStart.subtract(
  const Duration(days: 14),
);

    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: earliestScreenshotDate,
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

  final parsed = DateTime.tryParse(
    value.toString(),
  );

  if (parsed == null) {
    return null;
  }

  return parsed.toLocal();
}

  String formatTime(dynamic value) {
    final date = parseCapturedAt(value);

    if (date == null) {
      return '--:--';
    }

   return DateFormat('h:mm a').format(date);
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

   final localDate = date.toLocal();

final start = DateTime(
  localDate.year,
  localDate.month,
  localDate.day,
  localDate.hour,
);

final end = start.add(
  const Duration(hours: 1),
);

return '${DateFormat('h a').format(start)} - '
    '${DateFormat('h a').format(end)}';
  }

  String _projectDisplayName(Map<String, dynamic> screenshot) {
    final projectName =
        screenshot['project_name']?.toString().trim() ?? '';

    if (projectName.isEmpty) {
      return 'Project: No Project';
    }

    final cleanName = projectName.replaceFirst(
      RegExp(
        r'^project\s*:\s*',
        caseSensitive: false,
      ),
      '',
    );

    return 'Project: ${cleanName.trim()}';
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

    final projectLabel =
        _projectDisplayName(screenshot);

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
                      color: Colors.black.withValues(
                        alpha: 0.72,
                      ),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$employee • $capturedTime',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          projectLabel,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w500,
                          ),
                        ),
                      ],
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

  Future<void> deleteScreenshot(
    Map<String, dynamic> screenshot,
  ) async {
    final screenshotId =
        screenshot['id']?.toString() ?? '';
    final imagePath =
        screenshot['secure_image_path']?.toString() ?? '';

    if (screenshotId.isEmpty || imagePath.isEmpty) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete screenshot?'),
          content: const Text(
            'Are you sure you want to delete this screenshot?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _cleanupService.deleteScreenshot(
      screenshotId: screenshotId,
      imagePath: imagePath,
    );

    _imageFutures.remove(screenshotId);

    if (!mounted) return;

    setState(() {
      screenshots.removeWhere(
        (item) => item['id']?.toString() == screenshotId,
      );
    });
  }

  Widget screenshotCard(
    Map<String, dynamic> screenshot, {
    required double cardWidth,
  }) {
    final capturedTime = formatTime(
      screenshot['captured_at'],
    );

    final employeeName =
        screenshot['employee_name']?.toString() ??
            'Employee';

    final projectLabel =
        _projectDisplayName(screenshot);

    // Keep a 16:9 screenshot shape.
    final imageHeight = cardWidth * 9 / 16;

    return FutureBuilder<Uint8List?>(
      future: _imageFutureFor(screenshot),
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return _loadingScreenshotCard(
            capturedTime: capturedTime,
            cardWidth: cardWidth,
          );
        }

        final imageBytes = snapshot.data;

        if (imageBytes == null) {
          return _missingScreenshotCard(
            capturedTime: capturedTime,
            cardWidth: cardWidth,
          );
        }

        return SizedBox(
          width: cardWidth,
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
                      BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      Container(
                        width: cardWidth,
                        height: imageHeight,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius:
                              BorderRadius.circular(7),
                          border: Border.all(
                            color: borderColor,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(6),
                          child: Image.memory(
                            imageBytes,
                            width: cardWidth,
                            height: imageHeight,
                            fit: BoxFit.contain,
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
                      Positioned(
                        top: 5,
                        right: 5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            tooltip: 'Delete screenshot',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 30,
                              minHeight: 30,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            onPressed: () {
                              deleteScreenshot(screenshot);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
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
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    capturedTime,
                    style: const TextStyle(
                      color: darkText,
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                projectLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _missingScreenshotCard({
    required String capturedTime,
    required double cardWidth,
  }) {
    final imageHeight = cardWidth * 9 / 16;

    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: cardWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_not_supported_outlined,
                    size: 26,
                    color: secondaryText,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Image unavailable',
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              capturedTime,
              style: const TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingScreenshotCard({
    required String capturedTime,
    required double cardWidth,
  }) {
    final imageHeight = cardWidth * 9 / 16;

    return SizedBox(
      width: cardWidth,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: cardWidth,
            height: imageHeight,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius:
                  BorderRadius.circular(7),
              border: Border.all(
                color: borderColor,
              ),
            ),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: orange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              capturedTime,
              style: const TextStyle(
                color: secondaryText,
                fontWeight: FontWeight.w600,
                fontSize: 11,
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
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.all(20),
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
                radius: 22,
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: darkText,
                  ),
                ),
              ),
              Text(
                '${employeeScreenshots.length} Screenshots',
                style: const TextStyle(
                  fontSize: 14,
                  color: secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
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
    const double horizontalGap = 18;
    const double verticalGap = 18;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 26,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // Hour heading
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: orange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: darkText,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '(${items.length} screenshots)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondaryText,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Divider(
                  height: 1,
                  color: borderColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Responsive gallery.
          // Maximum = 6 screenshots on one row.
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth =
                  constraints.maxWidth;

              // Minimum size keeps thumbnails readable.
              // On a normal desktop width this resolves to 6 columns.
              const double minimumCardWidth = 165;

              int columns =
                  ((availableWidth + horizontalGap) /
                          (minimumCardWidth +
                              horizontalGap))
                      .floor();

              if (columns < 1) columns = 1;
              if (columns > 6) columns = 6;

              final cardWidth =
                  (availableWidth -
                          (horizontalGap *
                              (columns - 1))) /
                      columns;

              return Wrap(
                spacing: horizontalGap,
                runSpacing: verticalGap,
                children: items
                    .map(
                      (screenshot) =>
                          screenshotCard(
                        screenshot,
                        cardWidth: cardWidth,
                      ),
                    )
                    .toList(),
              );
            },
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
          if (isAdmin) ...[
  const SizedBox(width: 20),

  SizedBox(
    width: 220,
    child: DropdownButtonFormField<String>(
      initialValue: selectedEmployee,
      decoration: InputDecoration(
        labelText: 'Employee',
        filled: true,
        fillColor: background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(
            color: borderColor,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: employees
          .map(
            (employee) => DropdownMenuItem<String>(
              value: employee,
              child: Text(employee),
            ),
          )
          .toList(),
      onChanged: (value) {
        setState(() {
          selectedEmployee = value!;
        });
      },
    ),
  ),
],
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
    Map<String, List<Map<String, dynamic>>> employeeGroups;

if (selectedEmployee == 'All Employees') {
  employeeGroups = groupByEmployee();
} else {
  employeeGroups = {
    selectedEmployee: screenshots
        .where(
          (e) =>
              (e['employee_name'] ?? '').toString() ==
              selectedEmployee,
        )
        .toList(),
  };
}

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              dateNavigationBar(),
              const SizedBox(height: 20),
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
            color: Colors.black.withValues(
              alpha: 0.48,
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