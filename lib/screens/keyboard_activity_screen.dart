import 'package:flutter/material.dart';
import '../main.dart';

class KeyboardActivityScreen extends StatefulWidget {
  const KeyboardActivityScreen({super.key});

  @override
  State<KeyboardActivityScreen> createState() =>
      _KeyboardActivityScreenState();
}

class _KeyboardActivityScreenState extends State<KeyboardActivityScreen> {
  bool loading = true;

  List<Map<String, dynamic>> activities = [];

  // Employee identity is always the profile UUID.
  // The visible name comes from profiles.full_name.
  String selectedEmployeeId = 'all';
  Map<String, String> employeeNamesById = {};

  // 0 = Today, 1 = Yesterday, etc.
  int selectedDayIndex = 0;

  static const int maxHistoryDays = 14;

  // Hours are CLOSED by default.
  // Only hours inside this set are expanded.
  final Set<String> _expandedHours = {};

  bool get isAdmin =>
      currentUserRole.trim().toLowerCase() == 'admin';

  @override
  void initState() {
    super.initState();
    loadActivities();
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime get selectedDay {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    return today.subtract(
      Duration(days: selectedDayIndex),
    );
  }

  String get selectedDayLabel {
    final date = selectedDay;

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

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String get quickDayLabel {
    if (selectedDayIndex == 0) {
      return 'Today';
    }

    if (selectedDayIndex == 1) {
      return 'Yesterday';
    }

    return '$selectedDayIndex days ago';
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> loadActivities() async {
    if (!mounted) return;

    setState(() {
      loading = true;
    });

    try {
      final dayStart = selectedDay;
      final dayEnd = dayStart.add(
        const Duration(days: 1),
      );

      final startUtc =
          dayStart.toUtc().toIso8601String();

      final endUtc =
          dayEnd.toUtc().toIso8601String();

      final response = isAdmin
          ? await supabase
              .from('activity_samples')
              .select(
                'employee_name, '
                'employee_id, '
                'sample_start, '
                'sample_end, '
                'keyboard_presses, '
                'mouse_movements',
              )
              .eq(
                'workspace_id',
                currentWorkspaceId,
              )
              .gte(
                'sample_start',
                startUtc,
              )
              .lt(
                'sample_start',
                endUtc,
              )
              .order(
                'sample_start',
                ascending: false,
              )
          : await supabase
              .from('activity_samples')
              .select(
                'employee_name, '
                'employee_id, '
                'sample_start, '
                'sample_end, '
                'keyboard_presses, '
                'mouse_movements',
              )
              .eq(
                'workspace_id',
                currentWorkspaceId,
              )
              .eq(
                'employee_id',
                currentUserId,
              )
              .gte(
                'sample_start',
                startUtc,
              )
              .lt(
                'sample_start',
                endUtc,
              )
              .order(
                'sample_start',
                ascending: false,
              );

      final profileResponse = await supabase
          .from('profiles')
          .select('id, full_name')
          .eq('workspace_id', currentWorkspaceId);

      final profileRows =
          List<Map<String, dynamic>>.from(profileResponse);

      final namesById = <String, String>{};

      for (final profile in profileRows) {
        final id =
            profile['id']?.toString().trim() ?? '';
        final name =
            profile['full_name']?.toString().trim() ?? '';

        if (id.isNotEmpty && name.isNotEmpty) {
          namesById[id] = name;
        }
      }

      if (!mounted) return;

      setState(() {
        activities =
            List<Map<String, dynamic>>.from(response);
        employeeNamesById = namesById;

        loading = false;

        // Always start closed after loading.
        _expandedHours.clear();

        if (selectedEmployeeId != 'all' &&
            !employeeOptions.any(
              (option) => option.key == selectedEmployeeId,
            )) {
          selectedEmployeeId = 'all';
        }
      });
    } catch (e) {
      debugPrint('Activity load error: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // EMPLOYEE FILTER
  // ============================================================

  String _employeeDisplayName(
    Map<String, dynamic> activity,
  ) {
    final employeeId =
        activity['employee_id']?.toString().trim() ?? '';

    final profileName =
        employeeNamesById[employeeId]?.trim() ?? '';

    if (profileName.isNotEmpty) {
      return profileName;
    }

    final savedName =
        activity['employee_name']?.toString().trim() ?? '';

    if (savedName.isNotEmpty) {
      return savedName;
    }

    return 'Unknown Employee';
  }

  List<MapEntry<String, String>> get employeeOptions {
    final ids = <String>{};

    for (final activity in activities) {
      final id =
          activity['employee_id']?.toString().trim() ?? '';

      if (id.isNotEmpty) {
        ids.add(id);
      }
    }

    final options = ids
        .map(
          (id) => MapEntry(
            id,
            employeeNamesById[id] ??
                activities
                    .where(
                      (activity) =>
                          activity['employee_id']
                              ?.toString()
                              .trim() ==
                          id,
                    )
                    .map(_employeeDisplayName)
                    .firstWhere(
                      (name) => name.isNotEmpty,
                      orElse: () => 'Unknown Employee',
                    ),
          ),
        )
        .toList();

    options.sort(
      (a, b) => a.value
          .toLowerCase()
          .compareTo(b.value.toLowerCase()),
    );

    return options;
  }

  List<Map<String, dynamic>>
      get filteredActivities {
    if (!isAdmin || selectedEmployeeId == 'all') {
      return activities;
    }

    return activities.where(
      (activity) {
        final employeeId =
            activity['employee_id']?.toString().trim() ?? '';

        return employeeId == selectedEmployeeId;
      },
    ).toList();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DateTime? parseTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  int readInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString(),
        ) ??
        0;
  }

  String formatTime(DateTime date) {
    final rawHour = date.hour % 12;
    final hour = rawHour == 0 ? 12 : rawHour;

    final minute = date.minute
        .toString()
        .padLeft(2, '0');

    final amPm =
        date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $amPm';
  }

  String formatHourOnly(DateTime date) {
    final rawHour = date.hour % 12;
    final hour = rawHour == 0 ? 12 : rawHour;

    final amPm =
        date.hour >= 12 ? 'PM' : 'AM';

    return '$hour $amPm';
  }

  // ============================================================
  // FIXED 15-MINUTE SLOT
  // ============================================================

  DateTime getFifteenMinuteStart(
    DateTime time,
  ) {
    final minute =
        (time.minute ~/ 15) * 15;

    return DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      minute,
    );
  }

  String formatFifteenMinuteInterval(
    DateTime start,
  ) {
    final end = start.add(
      const Duration(minutes: 15),
    );

    return '${formatTime(start)} - ${formatTime(end)}';
  }

  String formatHourGroup(
    DateTime start,
  ) {
    final end = start.add(
      const Duration(hours: 1),
    );

    return '${formatHourOnly(start)} - ${formatHourOnly(end)}';
  }

  // ============================================================
  // BUILD 15-MINUTE SLOTS
  // ============================================================

  List<_HourActivityGroup>
      get groupedActivities {
    // First merge all raw samples into real 15-minute slots.
    final Map<String, _ActivitySlot> realSlots = {};

    for (final activity in filteredActivities) {
      final sampleStart = parseTime(
        activity['sample_start'],
      );

      if (sampleStart == null) {
        continue;
      }

      final employeeId =
          activity['employee_id']?.toString().trim() ?? '';

      if (employeeId.isEmpty) {
        continue;
      }

      final employeeName =
          _employeeDisplayName(activity);

      final slotStart =
          getFifteenMinuteStart(sampleStart);

      final key =
          '${employeeId}_${slotStart.toIso8601String()}';

      final slot = realSlots.putIfAbsent(
        key,
        () => _ActivitySlot(
          slotStart: slotStart,
          employeeName: employeeName,
          employeeId: employeeId,
          keyboard: 0,
          mouse: 0,
          hasSample: true,
        ),
      );

      slot.keyboard += readInt(
        activity['keyboard_presses'],
      );

      slot.mouse += readInt(
        activity['mouse_movements'],
      );
    }

    // Group real slots by employee + hour.
    final Map<String, List<_ActivitySlot>>
        slotsByEmployeeHour = {};
    final Map<String, DateTime> hourStarts = {};
    final Map<String, String> hourEmployeeIds = {};
    final Map<String, String> hourEmployeeNames = {};

    for (final slot in realSlots.values) {
      final hourStart = DateTime(
        slot.slotStart.year,
        slot.slotStart.month,
        slot.slotStart.day,
        slot.slotStart.hour,
      );

      final hourKey =
          '${slot.employeeId}_${hourStart.toIso8601String()}';

      slotsByEmployeeHour.putIfAbsent(
        hourKey,
        () => <_ActivitySlot>[],
      );

      slotsByEmployeeHour[hourKey]!.add(slot);
      hourStarts[hourKey] = hourStart;
      hourEmployeeIds[hourKey] = slot.employeeId;
      hourEmployeeNames[hourKey] = slot.employeeName;
    }

    final result = <_HourActivityGroup>[];

    for (final entry in slotsByEmployeeHour.entries) {
      final key = entry.key;
      final hourStart = hourStarts[key]!;
      final employeeId = hourEmployeeIds[key]!;
      final employeeName = hourEmployeeNames[key]!;

      // Only show 15-minute intervals that have a real activity record.
      // Missing intervals are not created or displayed.
      final realHourSlots = entry.value.toList()
        ..sort(
          (a, b) => a.slotStart.compareTo(b.slotStart),
        );

      int keyboardTotal = 0;
      int mouseTotal = 0;

      for (final slot in realHourSlots) {
        keyboardTotal += slot.keyboard;
        mouseTotal += slot.mouse;
      }

      result.add(
        _HourActivityGroup(
          employeeId: employeeId,
          employeeName: employeeName,
          hourStart: hourStart,
          slots: realHourSlots,
          keyboardTotal: keyboardTotal,
          mouseTotal: mouseTotal,
        ),
      );
    }

    result.sort(
      (a, b) {
        final employeeCompare = a.employeeName
            .toLowerCase()
            .compareTo(b.employeeName.toLowerCase());

        if (employeeCompare != 0) {
          return employeeCompare;
        }

        return b.hourStart.compareTo(a.hourStart);
      },
    );

    return result;
  }

  List<_EmployeeActivityGroup>
      get employeeActivityGroups {
    final grouped =
        <String, List<_HourActivityGroup>>{};

    for (final hourGroup in groupedActivities) {
      grouped.putIfAbsent(
        hourGroup.employeeId,
        () => <_HourActivityGroup>[],
      );

      grouped[hourGroup.employeeId]!.add(hourGroup);
    }

    final result = grouped.entries.map(
      (entry) {
        final hours = entry.value
          ..sort(
            (a, b) =>
                b.hourStart.compareTo(a.hourStart),
          );

        final employeeName = hours.isEmpty
            ? employeeNamesById[entry.key] ??
                'Unknown Employee'
            : hours.first.employeeName;

        return _EmployeeActivityGroup(
          employeeId: entry.key,
          employeeName: employeeName,
          hours: hours,
        );
      },
    ).toList();

    result.sort(
      (a, b) => a.employeeName
          .toLowerCase()
          .compareTo(b.employeeName.toLowerCase()),
    );

    return result;
  }

  int get dailyKeyboardTotal {
    return groupedActivities.fold(
      0,
      (total, group) =>
          total + group.keyboardTotal,
    );
  }

  int get dailyMouseTotal {
    return groupedActivities.fold(
      0,
      (total, group) =>
          total + group.mouseTotal,
    );
  }

  int get dailyActivityTotal {
    return dailyKeyboardTotal +
        dailyMouseTotal;
  }

  int get dailyIntervalCount {
    return groupedActivities.fold(
      0,
      (total, group) =>
          total + group.slots.length,
    );
  }

  // ============================================================
  // EXPAND / COLLAPSE
  // ============================================================

  String hourKey(
    _HourActivityGroup group,
  ) {
    return '${group.employeeId}_${group.hourStart.toIso8601String()}';
  }

  bool isHourExpanded(
    _HourActivityGroup group,
  ) {
    return _expandedHours.contains(
      hourKey(group),
    );
  }

  void toggleHour(
    _HourActivityGroup group,
  ) {
    final key = hourKey(group);

    setState(() {
      if (_expandedHours.contains(key)) {
        _expandedHours.remove(key);
      } else {
        _expandedHours.add(key);
      }
    });
  }

  // ============================================================
  // DATE NAVIGATION
  // ============================================================

  Future<void>
      goToPreviousDay() async {
    if (selectedDayIndex >=
        maxHistoryDays) {
      return;
    }

    setState(() {
      selectedDayIndex++;
      selectedEmployeeId = 'all';
      _expandedHours.clear();
    });

    await loadActivities();
  }

  Future<void>
      goToNextDay() async {
    if (selectedDayIndex <= 0) {
      return;
    }

    setState(() {
      selectedDayIndex--;
      selectedEmployeeId = 'all';
      _expandedHours.clear();
    });

    await loadActivities();
  }

  Future<void> selectQuickDay(
    int dayIndex,
  ) async {
    if (dayIndex < 0 ||
        dayIndex > maxHistoryDays) {
      return;
    }

    setState(() {
      selectedDayIndex = dayIndex;
      selectedEmployeeId = 'all';
      _expandedHours.clear();
    });

    await loadActivities();
  }

  // ============================================================
  // DATE SELECTOR - LARGE
  // ============================================================

  Widget buildDateSelector() {
    final canGoPrevious =
        selectedDayIndex <
            maxHistoryDays;

    final canGoNext =
        selectedDayIndex > 0;

    return Container(
      height: 62,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF8F5F1,
        ),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed:
                  canGoPrevious
                      ? goToPreviousDay
                      : null,
              icon: const Icon(
                Icons.chevron_left,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 44,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 18,
              ),
              decoration:
                  BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
                border: Border.all(
                  color: const Color(
                    0xFFE2E8F0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons
                        .calendar_today_rounded,
                    size: 18,
                    color: Color(
                      0xFF64748B,
                    ),
                  ),
                  const SizedBox(
                    width: 14,
                  ),
                  Expanded(
                    child: Text(
                      selectedDayLabel,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight
                                .w700,
                        color: Color(
                          0xFF1F2937,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 34,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed:
                  canGoNext
                      ? goToNextDay
                      : null,
              icon: const Icon(
                Icons.chevron_right,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY BADGE - LARGE
  // ============================================================

  Widget buildSummaryBadge({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Container(
      height: 34,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(
              0xFF64748B,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              color: Color(
                0xFF64748B,
              ),
              fontSize: 12,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
          Text(
            '$value',
            style: const TextStyle(
              fontWeight:
                  FontWeight.w600,
              fontSize: 13,
              color: Color(
                0xFF0F172A,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN EMPLOYEE FILTER
  // ============================================================

  Widget buildEmployeeFilter() {
    return SizedBox(
      width: 220,
      height: 34,
      child: DropdownButtonFormField<String>(
        initialValue: selectedEmployeeId,
        isExpanded: true,
        isDense: true,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(
            Icons.people_alt_rounded,
            size: 17,
            color: Color(0xFF64748B),
          ),
          contentPadding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFFE2E8F0),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(10),
            borderSide: const BorderSide(
              color: Color(0xFFF97316),
            ),
          ),
        ),
        items: [
          const DropdownMenuItem(
            value: 'all',
            child: Text('All Employees'),
          ),
          ...employeeOptions.map(
            (option) {
              return DropdownMenuItem(
                value: option.key,
                child: Text(
                  option.value,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ],
        onChanged: (value) {
          if (value == null) {
            return;
          }

          setState(() {
            selectedEmployeeId = value;
            _expandedHours.clear();
          });
        },
      ),
    );
  }

  // ============================================================
  // QUICK DAY FILTER
  // ============================================================

  Widget buildQuickDayFilter() {
    return SizedBox(
      width: 175,
      height: 34,
      child:
          DropdownButtonFormField<
              int>(
        initialValue: selectedDayIndex,
        isExpanded: true,
        isDense: true,
        style: const TextStyle(
          fontSize: 12,
          color: Color(
            0xFF1F2937,
          ),
          fontWeight:
              FontWeight.w600,
        ),
        decoration:
            InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: const Icon(
            Icons
                .calendar_month_rounded,
            size: 17,
            color: Color(
              0xFF64748B,
            ),
          ),
          contentPadding:
              const EdgeInsets
                  .symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            borderSide:
                const BorderSide(
              color: Color(
                0xFFE2E8F0,
              ),
            ),
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              10,
            ),
            borderSide:
                const BorderSide(
              color: Color(
                0xFFF97316,
              ),
            ),
          ),
        ),
        items: List.generate(
          maxHistoryDays + 1,
          (index) {
            String label;

            if (index == 0) {
              label = 'Today';
            } else if (index == 1) {
              label = 'Yesterday';
            } else {
              label =
                  '$index days ago';
            }

            return DropdownMenuItem(
              value: index,
              child: Text(label),
            );
          },
        ),
        onChanged: (value) {
          if (value == null) {
            return;
          }

          selectQuickDay(value);
        },
      ),
    );
  }

  // ============================================================
  // LARGE HOUR HEADER
  // ============================================================

  Widget buildHourHeader(
    _HourActivityGroup group,
  ) {
    final expanded =
        isHourExpanded(group);

    return InkWell(
      onTap: () {
        toggleHour(group);
      },
      child: Container(
        height: 68,
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
        ),
        color: const Color(
          0xFFFFF7ED,
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns:
                  expanded ? 0.25 : 0,
              duration:
                  const Duration(
                milliseconds: 150,
              ),
              child: const Icon(
                Icons
                    .chevron_right_rounded,
                size: 24,
                color: Color(
                  0xFFF97316,
                ),
              ),
            ),

            const SizedBox(width: 12),

            const Icon(
              Icons.access_time_rounded,
              size: 24,
              color: Color(
                0xFFF97316,
              ),
            ),

            const SizedBox(width: 18),

            Text(
              formatHourGroup(
                group.hourStart,
              ),
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 16,
                color: Color(
                  0xFF1F2937,
                ),
              ),
            ),

            const SizedBox(width: 28),

            Text(
              '(${group.slots.length} '
              '${group.slots.length == 1 ? 'interval' : 'intervals'})',
              style: const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w500,
                color: Color(
                  0xFF64748B,
                ),
              ),
            ),

            const Spacer(),

            const Icon(
              Icons.keyboard_rounded,
              size: 18,
              color: Color(
                0xFF64748B,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              '${group.keyboardTotal}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
                color: Color(
                  0xFF0F172A,
                ),
              ),
            ),

            const SizedBox(width: 28),

            Container(
              width: 1,
              height: 28,
              color: const Color(
                0xFFE2E8F0,
              ),
            ),

            const SizedBox(width: 28),

            const Icon(
              Icons.mouse_rounded,
              size: 18,
              color: Color(
                0xFF64748B,
              ),
            ),

            const SizedBox(width: 10),

            Text(
              '${group.mouseTotal}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.w600,
                color: Color(
                  0xFF0F172A,
                ),
              ),
            ),

            const SizedBox(width: 18),

            AnimatedRotation(
              turns:
                  expanded ? 0.5 : 0,
              duration:
                  const Duration(
                milliseconds: 150,
              ),
              child: const Icon(
                Icons
                    .keyboard_arrow_down_rounded,
                size: 24,
                color: Color(
                  0xFFF97316,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TABLE HEADER
  // ============================================================

  Widget buildTableHeader() {
    return Container(
      height: 34,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      color: const Color(
        0xFFF8FAFC,
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'EMPLOYEE',
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 10,
                color: Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '15-MIN INTERVAL',
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 10,
                color: Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'KEYBOARD',
              textAlign:
                  TextAlign.right,
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 10,
                color: Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'MOUSE',
              textAlign:
                  TextAlign.right,
              style: TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 10,
                color: Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // 15-MIN SLOT ROW
  // ============================================================

  Widget buildSlotRow(
    _ActivitySlot slot,
  ) {
    return Container(
      height: 34,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(
              0xFFE2E8F0,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                const Icon(
                  Icons
                      .person_outline_rounded,
                  size: 17,
                  color: Color(
                    0xFF64748B,
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    slot.employeeName,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 12,
                      color: Color(
                        0xFF1F2937,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Text(
              formatFifteenMinuteInterval(
                slot.slotStart,
              ),
              style: const TextStyle(
                fontSize: 13,
                fontWeight:
                    FontWeight.w500,
                color: Color(
                  0xFF475569,
                ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              slot.hasSample
                  ? '${slot.keyboard}'
                  : '—',
              textAlign:
                  TextAlign.right,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 12,
                color: Color(
                  0xFF0F172A,
                ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Text(
              slot.hasSample
                  ? '${slot.mouse}'
                  : '—',
              textAlign:
                  TextAlign.right,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
                fontSize: 12,
                color: Color(
                  0xFF0F172A,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOUR CARD
  // ============================================================

  Widget buildHourCard(
    _HourActivityGroup group,
  ) {
    final expanded =
        isHourExpanded(group);

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 10,
      ),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        children: [
          buildHourHeader(group),

          if (expanded) ...[
            buildTableHeader(),
            ...group.slots.map(
              buildSlotRow,
            ),
          ],
        ],
      ),
    );
  }

  Widget buildEmployeeActivityCard(
    _EmployeeActivityGroup employeeGroup,
  ) {
    final keyboardTotal = employeeGroup.hours.fold<int>(
      0,
      (total, hour) => total + hour.keyboardTotal,
    );

    final mouseTotal = employeeGroup.hours.fold<int>(
      0,
      (total, hour) => total + hour.mouseTotal,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            color: const Color(0xFFFFF7ED),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFF97316),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    employeeGroup.employeeName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  '$keyboardTotal',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 18),
                const Icon(
                  Icons.mouse_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Text(
                  '$mouseTotal',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: employeeGroup.hours
                  .map(buildHourCard)
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final employeeGroups =
        employeeActivityGroups;

    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF8FAFC,
      ),
      appBar: AppBar(
        automaticallyImplyLeading:
            false,
        backgroundColor:
            const Color(
          0xFFF97316,
        ),
        foregroundColor:
            Colors.white,
        centerTitle: true,
        elevation: 0,
        toolbarHeight: 58,
        title: const Text(
          'Keyboard Activity',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            // DATE BAR
            buildDateSelector(),

            const SizedBox(height: 12),

            // SUMMARY + FILTERS
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      buildSummaryBadge(
                        icon:
                            Icons.keyboard_rounded,
                        label: 'Keyboard',
                        value:
                            dailyKeyboardTotal,
                      ),
                      buildSummaryBadge(
                        icon:
                            Icons.mouse_rounded,
                        label: 'Mouse',
                        value:
                            dailyMouseTotal,
                      ),
                      buildSummaryBadge(
                        icon:
                            Icons.touch_app_rounded,
                        label: 'Total',
                        value:
                            dailyActivityTotal,
                      ),
                      buildSummaryBadge(
                        icon:
                            Icons
                                .view_timeline_rounded,
                        label: 'Intervals',
                        value:
                            dailyIntervalCount,
                      ),
                    ],
                  ),
                ),

                if (isAdmin) ...[
                  const SizedBox(
                    width: 14,
                  ),
                  buildEmployeeFilter(),
                ],

                const SizedBox(width: 14),

                buildQuickDayFilter(),
              ],
            ),

            const SizedBox(height: 18),

            // HOURS
            Expanded(
              child: loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(),
                    )
                  : employeeGroups.isEmpty
                      ? Center(
                          child: Text(
                            selectedDayIndex ==
                                    0
                                ? 'No activity today'
                                : 'No activity on $selectedDayLabel',
                            style:
                                const TextStyle(
                              fontSize: 16,
                              color: Color(
                                0xFF64748B,
                              ),
                            ),
                          ),
                        )                       : ListView.builder(
                           itemCount:
                               employeeGroups.length,
                           itemBuilder:
                               (
                             context,
                             index,
                           ) {
                             return buildEmployeeActivityCard(
                               employeeGroups[index],
                             );
                           },
                         ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 15-MINUTE SLOT
// ============================================================

class _ActivitySlot {
  final DateTime slotStart;
  final String employeeName;
  final String employeeId;

  int keyboard;
  int mouse;
  final bool hasSample;

  _ActivitySlot({
    required this.slotStart,
    required this.employeeName,
    required this.employeeId,
    required this.keyboard,
    required this.mouse,
    required this.hasSample,
  });
}

// ============================================================
// HOUR GROUP
// ============================================================

class _HourActivityGroup {
  final String employeeId;
  final String employeeName;
  final DateTime hourStart;
  final List<_ActivitySlot> slots;
  final int keyboardTotal;
  final int mouseTotal;

  const _HourActivityGroup({
    required this.employeeId,
    required this.employeeName,
    required this.hourStart,
    required this.slots,
    required this.keyboardTotal,
    required this.mouseTotal,
  });
}

class _EmployeeActivityGroup {
  final String employeeId;
  final String employeeName;
  final List<_HourActivityGroup> hours;

  const _EmployeeActivityGroup({
    required this.employeeId,
    required this.employeeName,
    required this.hours,
  });
}
