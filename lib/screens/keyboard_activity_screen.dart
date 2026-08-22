import 'package:flutter/material.dart';
import '../main.dart';

class KeyboardActivityScreen extends StatefulWidget {
  const KeyboardActivityScreen({super.key});

  @override
  State<KeyboardActivityScreen> createState() =>
      _KeyboardActivityScreenState();
}

class _KeyboardActivityScreenState
    extends State<KeyboardActivityScreen> {
  bool loading = true;

  List<Map<String, dynamic>> activities = [];

  String selectedEmployee = 'All Employees';

  // 0 = Today
// 1 = Yesterday
// ...
// 13 = 13 days ago
int selectedDayIndex = 0;

static const int maxHistoryDays = 14;

  // Hours inside this set are collapsed.
  // By default all hours are OPEN.
  final Set<String> _collapsedHours = {};

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

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
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

      if (!mounted) return;

      setState(() {
        activities =
            List<Map<String, dynamic>>.from(
          response,
        );

        loading = false;

        if (selectedEmployee !=
                'All Employees' &&
            !employeeNames.contains(
              selectedEmployee,
            )) {
          selectedEmployee =
              'All Employees';
        }
      });
    } catch (e) {
      debugPrint(
        'Activity load error: $e',
      );

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  // ============================================================
  // EMPLOYEE FILTER
  // ============================================================

  List<String> get employeeNames {
    final names = activities
        .map(
          (activity) =>
              activity['employee_name']
                  ?.toString()
                  .trim() ??
              '',
        )
        .where(
          (name) => name.isNotEmpty,
        )
        .toSet()
        .toList();

    names.sort();

    return names;
  }

  List<Map<String, dynamic>>
      get filteredActivities {
    if (!isAdmin) {
      return activities;
    }

    if (selectedEmployee ==
        'All Employees') {
      return activities;
    }

    return activities.where(
      (activity) {
        final name =
            activity['employee_name']
                    ?.toString()
                    .trim() ??
                '';

        return name ==
            selectedEmployee;
      },
    ).toList();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  DateTime? parseTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toLocal();
  }

  int readInt(
    dynamic value,
  ) {
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

  String formatTime(
    DateTime date,
  ) {
    final rawHour =
        date.hour % 12;

    final hour =
        rawHour == 0
            ? 12
            : rawHour;

    final minute =
        date.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final amPm =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $amPm';
  }

  String formatHourOnly(
    DateTime date,
  ) {
    final rawHour =
        date.hour % 12;

    final hour =
        rawHour == 0
            ? 12
            : rawHour;

    final amPm =
        date.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour $amPm';
  }

  // ============================================================
  // FIXED 5-MINUTE SLOT
  // ============================================================

  DateTime getFiveMinuteStart(
    DateTime time,
  ) {
    final minute =
        (time.minute ~/ 5) * 5;

    return DateTime(
      time.year,
      time.month,
      time.day,
      time.hour,
      minute,
    );
  }

  String formatFiveMinuteInterval(
    DateTime start,
  ) {
    final end =
        start.add(
      const Duration(minutes: 5),
    );

    return '${formatTime(start)}  –  '
        '${formatTime(end)}';
  }

  String formatHourGroup(
    DateTime start,
  ) {
    final end =
        start.add(
      const Duration(hours: 1),
    );

    return '${formatHourOnly(start)} – '
        '${formatHourOnly(end)}';
  }

  // ============================================================
  // BUILD 5-MINUTE SLOTS
  // ============================================================

  List<_HourActivityGroup>
      get groupedActivities {
    final Map<String, _ActivitySlot>
        slots = {};

    for (final activity
        in filteredActivities) {
      final sampleStart =
          parseTime(
        activity['sample_start'],
      );

      if (sampleStart == null) {
        continue;
      }

      final employee =
          activity['employee_name']
                  ?.toString()
                  .trim() ??
              'Employee';

      final employeeId =
          activity['employee_id']
                  ?.toString() ??
              '';

      final slotStart =
          getFiveMinuteStart(
        sampleStart,
      );

      final key =
          '${slotStart.toIso8601String()}_$employeeId';

      if (!slots.containsKey(key)) {
        slots[key] =
            _ActivitySlot(
          slotStart:
              slotStart,
          employeeName:
              employee,
          employeeId:
              employeeId,
          keyboard:
              0,
          mouse:
              0,
        );
      }

      final existing =
          slots[key]!;

      existing.keyboard +=
          readInt(
        activity['keyboard_presses'],
      );

      existing.mouse +=
          readInt(
        activity['mouse_movements'],
      );
    }

    final Map<DateTime, List<_ActivitySlot>>
        hourMap = {};

    for (final slot
        in slots.values) {
      final hourStart =
          DateTime(
        slot.slotStart.year,
        slot.slotStart.month,
        slot.slotStart.day,
        slot.slotStart.hour,
      );

      hourMap.putIfAbsent(
        hourStart,
        () => [],
      );

      hourMap[hourStart]!.add(
        slot,
      );
    }

    final hourKeys =
        hourMap.keys.toList();

    hourKeys.sort(
      (a, b) =>
          b.compareTo(a),
    );

    final result =
        <_HourActivityGroup>[];

    for (final hourStart
        in hourKeys) {
      final hourSlots =
          hourMap[hourStart]!;

      hourSlots.sort(
        (a, b) {
          final timeCompare =
              b.slotStart.compareTo(
            a.slotStart,
          );

          if (timeCompare != 0) {
            return timeCompare;
          }

          return a.employeeName
              .compareTo(
            b.employeeName,
          );
        },
      );

      int keyboardTotal = 0;
      int mouseTotal = 0;

      for (final slot
          in hourSlots) {
        keyboardTotal +=
            slot.keyboard;

        mouseTotal +=
            slot.mouse;
      }

      result.add(
        _HourActivityGroup(
          hourStart:
              hourStart,
          slots:
              hourSlots,
          keyboardTotal:
              keyboardTotal,
          mouseTotal:
              mouseTotal,
        ),
      );
    }

    return result;
  }

  int get dailyKeyboardTotal {
  return groupedActivities.fold(
    0,
    (total, group) => total + group.keyboardTotal,
  );
}

int get dailyMouseTotal {
  return groupedActivities.fold(
    0,
    (total, group) => total + group.mouseTotal,
  );
}

int get dailyActivityTotal {
  return dailyKeyboardTotal + dailyMouseTotal;
}

int get dailyIntervalCount {
  return groupedActivities.fold(
    0,
    (total, group) => total + group.slots.length,
  );
}

  // ============================================================
  // EXPAND / COLLAPSE HOUR
  // ============================================================

  String hourKey(
    DateTime hourStart,
  ) {
    return hourStart.toIso8601String();
  }

  bool isHourExpanded(
    DateTime hourStart,
  ) {
    return !_collapsedHours.contains(
      hourKey(hourStart),
    );
  }

  void toggleHour(
    DateTime hourStart,
  ) {
    final key =
        hourKey(hourStart);

    setState(() {
      if (_collapsedHours.contains(key)) {
        _collapsedHours.remove(key);
      } else {
        _collapsedHours.add(key);
      }
    });
  }

  // ============================================================
  // DATE NAVIGATION
  // ============================================================

  Future<void>
      goToPreviousDay() async {
    if (selectedDayIndex >= maxHistoryDays) {
  return;
}

setState(() {
  selectedDayIndex++;
  selectedEmployee = 'All Employees';

  _collapsedHours.clear();
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
  selectedEmployee = 'All Employees';

  _collapsedHours.clear();
});

    await loadActivities();
  }

  // ============================================================
  // DATE SELECTOR
  // ============================================================

  Widget buildDateSelector() {
   final canGoPrevious =
    selectedDayIndex < maxHistoryDays;

final canGoNext =
    selectedDayIndex > 0;

    return Container(
      height: 88,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
          0xFFF8F5F1,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child:
          Row(
        children: [
          IconButton(
            onPressed:
                canGoPrevious
                    ? goToPreviousDay
                    : null,
            icon:
                const Icon(
              Icons.chevron_left,
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child:
                Container(
              height: 58,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 20,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFE2E8F0,
                  ),
                ),
              ),
              child:
                  Row(
                children: [
                  const Icon(
                    Icons
                        .calendar_today_rounded,
                    size:
                        21,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                  const SizedBox(
                    width:
                        14,
                  ),
                  Text(
                    selectedDayLabel,
                    style:
                        const TextStyle(
                      fontSize:
                          16,
                      fontWeight:
                          FontWeight
                              .w600,
                      color:
                          Color(
                        0xFF1F2937,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          IconButton(
            onPressed:
                canGoNext
                    ? goToNextDay
                    : null,
            icon:
                const Icon(
              Icons.chevron_right,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADMIN EMPLOYEE FILTER - UNCHANGED
  // ============================================================

  Widget buildEmployeeFilter() {
    return Container(
      height: 88,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color:
            const Color(
          0xFFF8F5F1,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child:
          Row(
        children: [
          const Icon(
            Icons
                .person_outline_rounded,
            color:
                Color(
              0xFF64748B,
            ),
          ),
          const SizedBox(
            width:
                12,
          ),
          const Text(
            'Employee',
            style:
                TextStyle(
              fontSize:
                  15,
              fontWeight:
                  FontWeight
                      .w600,
            ),
          ),
          const SizedBox(
            width:
                16,
          ),
          Expanded(
            child:
                DropdownButtonFormField<
                    String>(
              value:
                  selectedEmployee,
              isExpanded:
                  true,
              decoration:
                  InputDecoration(
                filled:
                    true,
                fillColor:
                    Colors.white,
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      16,
                  vertical:
                      14,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value:
                      'All Employees',
                  child:
                      Text(
                    'All Employees',
                  ),
                ),
                ...employeeNames.map(
                  (
                    employee,
                  ) {
                    return DropdownMenuItem(
                      value:
                          employee,
                      child:
                          Text(
                        employee,
                      ),
                    );
                  },
                ),
              ],
              onChanged:
                  (value) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  selectedEmployee =
                      value;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY BADGE
  // ============================================================

  Widget buildSummaryBadge({
    required IconData icon,
    required String label,
    required int value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          10,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      child:
          Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size:
                16,
            color:
                const Color(
              0xFF64748B,
            ),
          ),
          const SizedBox(
            width:
                8,
          ),
          Text(
            '$label: ',
            style:
                const TextStyle(
              color:
                  Color(
                0xFF64748B,
              ),
              fontSize:
                  13,
            ),
          ),
          Text(
            '$value',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize:
                  14,
              color:
                  Color(
                0xFF0F172A,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HOUR HEADER WITH ORANGE EXPAND / COLLAPSE ARROW
  // ============================================================

  Widget buildHourHeader(
    _HourActivityGroup group,
  ) {
    final expanded =
        isHourExpanded(
      group.hourStart,
    );

    return InkWell(
      onTap: () {
        toggleHour(
          group.hourStart,
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        color:
            const Color(
          0xFFFFF7ED,
        ),
        child:
            Row(
          children: [
            // ------------------------------------------
            // ORANGE EXPAND / COLLAPSE ARROW
            // ------------------------------------------

            AnimatedRotation(
              turns:
                  expanded
                      ? 0.25
                      : 0,
              duration:
                  const Duration(
                milliseconds: 150,
              ),
              child:
                  const Icon(
                Icons.chevron_right_rounded,
                size:
                    27,
                color:
                    Color(
                  0xFFF97316,
                ),
              ),
            ),

            const SizedBox(
              width:
                  8,
            ),

            // ------------------------------------------
            // CLOCK ICON
            // ------------------------------------------

            Container(
              width:
                  40,
              height:
                  40,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFFFEDD5,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  11,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .access_time_rounded,
                color:
                    Color(
                  0xFFF97316,
                ),
                size:
                    21,
              ),
            ),

            const SizedBox(
              width:
                  14,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Text(
                    formatHourGroup(
                      group.hourStart,
                    ),
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,
                      fontSize:
                          18,
                      color:
                          Color(
                        0xFF1F2937,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height:
                        4,
                  ),
                  Text(
                    '${group.slots.length} '
                    '5-minute intervals',
                    style:
                        const TextStyle(
                      fontSize:
                          13,
                      color:
                          Color(
                        0xFF64748B,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------------
            // TOTALS STAY VISIBLE EVEN WHEN COLLAPSED
            // ------------------------------------------

            buildSummaryBadge(
              icon:
                  Icons.keyboard_rounded,
              label:
                  'Keyboard',
              value:
                  group.keyboardTotal,
            ),

            const SizedBox(
              width:
                  10,
            ),

            buildSummaryBadge(
              icon:
                  Icons.mouse_rounded,
              label:
                  'Mouse',
              value:
                  group.mouseTotal,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COLUMN HEADER
  // ============================================================

  Widget buildTableHeader() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      color:
          const Color(
        0xFFF8FAFC,
      ),
      child:
          const Row(
        children: [
          Expanded(
            flex:
                3,
            child:
                Text(
              'EMPLOYEE',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize:
                    12,
                color:
                    Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
          Expanded(
            flex:
                3,
            child:
                Text(
              '5-MIN INTERVAL',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize:
                    12,
                color:
                    Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
          Expanded(
            flex:
                2,
            child:
                Text(
              'KEYBOARD',
              textAlign:
                  TextAlign.right,
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize:
                    12,
                color:
                    Color(
                  0xFF64748B,
                ),
              ),
            ),
          ),
          Expanded(
            flex:
                2,
            child:
                Text(
              'MOUSE',
              textAlign:
                  TextAlign.right,
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize:
                    12,
                color:
                    Color(
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
  // SLOT ROW - SAME AS BEFORE
  // ============================================================

  Widget buildSlotRow(
    _ActivitySlot slot,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 17,
      ),
      decoration:
          const BoxDecoration(
        color:
            Colors.white,
        border:
            Border(
          top:
              BorderSide(
            color:
                Color(
              0xFFE2E8F0,
            ),
          ),
        ),
      ),
      child:
          Row(
        children: [
          Expanded(
            flex:
                3,
            child:
                Row(
              children: [
                Container(
                  width:
                      36,
                  height:
                      36,
                  decoration:
                      const BoxDecoration(
                    color:
                        Color(
                      0xFFF1F5F9,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child:
                      const Icon(
                    Icons
                        .person_outline_rounded,
                    size:
                        18,
                    color:
                        Color(
                      0xFF64748B,
                    ),
                  ),
                ),
                const SizedBox(
                  width:
                      12,
                ),
                Expanded(
                  child:
                      Text(
                    slot.employeeName,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w600,
                      color:
                          Color(
                        0xFF1F2937,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex:
                3,
            child:
                Text(
              formatFiveMinuteInterval(
                slot.slotStart,
              ),
              style:
                  const TextStyle(
                fontSize:
                    14,
                fontWeight:
                    FontWeight.w500,
                color:
                    Color(
                  0xFF475569,
                ),
              ),
            ),
          ),

          Expanded(
            flex:
                2,
            child:
                Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.keyboard_rounded,
                  size:
                      16,
                  color:
                      Color(
                    0xFF64748B,
                  ),
                ),
                const SizedBox(
                  width:
                      8,
                ),
                Text(
                  '${slot.keyboard}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize:
                        16,
                    color:
                        Color(
                      0xFF0F172A,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex:
                2,
            child:
                Row(
              mainAxisAlignment:
                  MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.mouse_rounded,
                  size:
                      16,
                  color:
                      Color(
                    0xFF64748B,
                  ),
                ),
                const SizedBox(
                  width:
                      8,
                ),
                Text(
                  '${slot.mouse}',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize:
                        16,
                    color:
                        Color(
                      0xFF0F172A,
                    ),
                  ),
                ),
              ],
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
        isHourExpanded(
      group.hourStart,
    );

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE2E8F0,
          ),
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child:
          Column(
        children: [
          // Hour always visible
          buildHourHeader(
            group,
          ),

          // Table only visible when hour is open
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final groups =
        groupedActivities;

    return Scaffold(
      backgroundColor:
          const Color(
        0xFFF8FAFC,
      ),
      appBar:
          AppBar(
        backgroundColor:
            Colors.white,
        foregroundColor:
            const Color(
          0xFF0F172A,
        ),
        elevation:
            0,
        title:
            const Text(
          'Activity',
          style:
              TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body:
          Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child:
            Column(
          children: [
            // ================================================
            // DATE + ADMIN EMPLOYEE FILTER
            // ================================================

            Row(
              children: [
                Expanded(
                  child:
                      buildDateSelector(),
                ),

                // ADMIN FILTER IS STILL HERE
                if (isAdmin) ...[
                  const SizedBox(
                    width:
                        20,
                  ),
                  Expanded(
                    child:
                        buildEmployeeFilter(),
                  ),
                ],
              ],
            ),

            const SizedBox(
              height:
                  22,
            ),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                buildSummaryBadge(
                  icon: Icons.keyboard_rounded,
                  label: 'Keyboard',
                  value: dailyKeyboardTotal,
                ),
                buildSummaryBadge(
                  icon: Icons.mouse_rounded,
                  label: 'Mouse',
                  value: dailyMouseTotal,
                ),
                buildSummaryBadge(
                  icon: Icons.touch_app_rounded,
                  label: 'Total Activity',
                  value: dailyActivityTotal,
                ),
                buildSummaryBadge(
                  icon: Icons.view_timeline_rounded,
                  label: 'Intervals',
                  value: dailyIntervalCount,
                ),
              ],
            ),

            const SizedBox(height: 22),

            // ================================================
            // HOURS
            // ================================================

            Expanded(
              child:
                  loading
                      ? const Center(
                          child:
                              CircularProgressIndicator(),
                        )
                      : groups.isEmpty
                          ? Center(
                              child:
                                  Text(
                                selectedDayIndex ==
                                        0
                                    ? 'No activity today'
                                    : 'No activity on $selectedDayLabel',
                                style:
                                    const TextStyle(
                                  fontSize:
                                      16,
                                  color:
                                      Color(
                                    0xFF64748B,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount:
                                  groups.length,
                              itemBuilder:
                                  (
                                context,
                                index,
                              ) {
                                return buildHourCard(
                                  groups[
                                      index],
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
// 5-MINUTE SLOT
// ============================================================

class _ActivitySlot {
  final DateTime slotStart;

  final String employeeName;

  final String employeeId;

  int keyboard;

  int mouse;

  _ActivitySlot({
    required this.slotStart,
    required this.employeeName,
    required this.employeeId,
    required this.keyboard,
    required this.mouse,
  });
}

// ============================================================
// HOUR GROUP
// ============================================================

class _HourActivityGroup {
  final DateTime hourStart;

  final List<_ActivitySlot> slots;

  final int keyboardTotal;

  final int mouseTotal;

  const _HourActivityGroup({
    required this.hourStart,
    required this.slots,
    required this.keyboardTotal,
    required this.mouseTotal,
  });
}