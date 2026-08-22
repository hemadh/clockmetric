import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class LeaveRequestScreen extends StatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  State<LeaveRequestScreen> createState() =>
      _LeaveRequestScreenState();
}

class _LeaveRequestScreenState
    extends State<LeaveRequestScreen> {
  final reasonController = TextEditingController();

  String leaveType = 'Annual Leave';
  DateTime? startDate;
  DateTime? endDate;

  bool loading = false;

  final List<String> leaveTypes = const [
    'Annual Leave',
    'Sick Leave',
    'Emergency Leave',
    'Unpaid Leave',
  ];

  Future<void> pickStartDate() async {
    final today = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 5),
    );

    if (picked == null || !mounted) return;

    setState(() {
      startDate = picked;

      if (endDate != null && endDate!.isBefore(picked)) {
        endDate = null;
      }
    });
  }

  Future<void> pickEndDate() async {
    final today = DateTime.now();
    final earliestDate = startDate ?? today;

    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? earliestDate,
      firstDate: earliestDate,
      lastDate: DateTime(today.year + 5),
    );

    if (picked == null || !mounted) return;

    setState(() {
      endDate = picked;
    });
  }

  Future<void> submitLeaveRequest() async {
    if (startDate == null || endDate == null) {
      _showMessage(
        'Please select the start and end dates.',
        isError: true,
      );
      return;
    }

    if (endDate!.isBefore(startDate!)) {
      _showMessage(
        'The end date cannot be before the start date.',
        isError: true,
      );
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      await supabase.from('leave_requests').insert({
        'workspace_id': currentWorkspaceId,
        'employee_name': currentUserName,
        'leave_type': leaveType,
        'start_date': _databaseDate(startDate!),
        'end_date': _databaseDate(endDate!),
        'reason': reasonController.text.trim(),
        'status': 'pending',
      });

      if (!mounted) return;

      setState(() {
        startDate = null;
        endDate = null;
        leaveType = 'Annual Leave';
      });

      reasonController.clear();

      _showMessage('Leave request submitted successfully.');
    } catch (error) {
      debugPrint('Leave request submission error: $error');

      _showMessage(
        'Unable to submit the leave request.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String _databaseDate(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} '
        '${date.day}, ${date.year}';
  }

  int selectedDays() {
    if (startDate == null || endDate == null) {
      return 0;
    }

    return endDate!.difference(startDate!).inDays + 1;
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final days = selectedDays();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Request Leave',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.border,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 22,
                  offset: Offset(0, 9),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius:
                          BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.beach_access_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Center(
                  child: Text(
                    'Submit Leave Request',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                const Center(
                  child: Text(
                    'Choose your leave type and dates.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                DropdownButtonFormField<String>(
                  initialValue: leaveType,
                  decoration: _inputDecoration(
                    label: 'Leave Type',
                    icon: Icons.event_note_outlined,
                  ),
                  items: leaveTypes.map((type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: loading
                      ? null
                      : (value) {
                          if (value == null) return;

                          setState(() {
                            leaveType = value;
                          });
                        },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _dateButton(
                        label: 'Start Date',
                        value: formatDate(startDate),
                        icon: Icons.calendar_today_outlined,
                        onPressed:
                            loading ? null : pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _dateButton(
                        label: 'End Date',
                        value: formatDate(endDate),
                        icon: Icons.event_available_outlined,
                        onPressed:
                            loading ? null : pickEndDate,
                      ),
                    ),
                  ],
                ),
                if (days > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.timelapse,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '$days ${days == 1 ? 'day' : 'days'} selected',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                TextField(
                  controller: reasonController,
                  enabled: !loading,
                  maxLines: 4,
                  decoration: _inputDecoration(
                    label: 'Reason',
                    icon: Icons.notes_outlined,
                    hint:
                        'Briefly explain the reason for your leave.',
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.border,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    onPressed:
                        loading ? null : submitLeaveRequest,
                    icon: loading
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: Text(
                      loading
                          ? 'Submitting...'
                          : 'Submit Request',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.5,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
    );
  }

  Widget _dateButton({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(
          color: AppColors.border,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}