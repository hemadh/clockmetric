import 'package:flutter/material.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() =>
      _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  bool loading = true;
  String? errorMessage;
  String? updatingRequestId;

  String selectedFilter = 'pending';

  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final response = await supabase
          .from('leave_requests')
          .select(
            'id, employee_name, leave_type, start_date, '
            'end_date, reason, status, created_at',
          )
          .eq('workspace_id', currentWorkspaceId)
          .order('created_at', ascending: false);

      if (!mounted) return;

      setState(() {
        requests = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (error) {
      debugPrint('Leave approval loading error: $error');

      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage =
            'Unable to load leave requests. Please try again.';
      });
    }
  }

  List<Map<String, dynamic>> get filteredRequests {
    return requests.where((request) {
      final status = request['status']
              ?.toString()
              .trim()
              .toLowerCase() ??
          'pending';

      return status == selectedFilter;
    }).toList();
  }

  int countForStatus(String status) {
    return requests.where((request) {
      return request['status']
              ?.toString()
              .trim()
              .toLowerCase() ==
          status;
    }).length;
  }

  Future<void> confirmApprove(
    Map<String, dynamic> request,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text(
                'Approve Leave Request?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogInformation(
                  'Employee',
                  employeeName(request),
                ),
                _dialogInformation(
                  'Leave type',
                  leaveType(request),
                ),
                _dialogInformation(
                  'Dates',
                  '${formatDate(request['start_date'])} — '
                      '${formatDate(request['end_date'])}',
                ),
                const SizedBox(height: 10),
                const Text(
                  'The employee will see this request as approved.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.check),
              label: const Text('Approve'),
            ),
          ],
        );
      },
    );

    if (approved == true) {
      await updateStatus(
        request['id'].toString(),
        'approved',
      );
    }
  }

  Future<void> confirmReject(
    Map<String, dynamic> request,
  ) async {
    final rejected = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                color: AppColors.danger,
              ),
              SizedBox(width: 10),
              Text(
                'Reject Leave Request?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _dialogInformation(
                  'Employee',
                  employeeName(request),
                ),
                _dialogInformation(
                  'Leave type',
                  leaveType(request),
                ),
                _dialogInformation(
                  'Dates',
                  '${formatDate(request['start_date'])} — '
                      '${formatDate(request['end_date'])}',
                ),
                const SizedBox(height: 10),
                const Text(
                  'This action will mark the leave request as rejected.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.close),
              label: const Text('Reject'),
            ),
          ],
        );
      },
    );

    if (rejected == true) {
      await updateStatus(
        request['id'].toString(),
        'rejected',
      );
    }
  }

  Widget _dialogInformation(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> updateStatus(
    String id,
    String status,
  ) async {
    if (updatingRequestId != null) return;

    setState(() {
      updatingRequestId = id;
    });

    try {
      final updatedRows = await supabase
    .from('leave_requests')
    .update({
      'status': status,
    })
    .eq('id', id)
    .eq('workspace_id', currentWorkspaceId)
    .select('id, status');

if (updatedRows.isEmpty) {
  throw Exception(
    'No leave request was updated. Check the Supabase update policy.',
  );
}

      _showMessage(
        status == 'approved'
            ? 'Leave request approved.'
            : 'Leave request rejected.',
      );

      await loadRequests();
    } catch (error) {
      debugPrint('Leave status update error: $error');

      _showMessage(
        'Unable to update the leave request.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          updatingRequestId = null;
        });
      }
    }
  }

  String employeeName(Map<String, dynamic> request) {
    final value = request['employee_name']?.toString().trim();

    return value == null || value.isEmpty
        ? 'Employee'
        : value;
  }

  String leaveType(Map<String, dynamic> request) {
    final value = request['leave_type']?.toString().trim();

    if (value == null || value.isEmpty) {
      return 'Leave';
    }

    return value
        .split(RegExp(r'[_\s]+'))
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}'
                  '${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  String initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) {
      return 'E';
    }

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts[1][0]}'
        .toUpperCase();
  }

  String formatDate(dynamic value) {
    if (value == null) {
      return 'Unknown date';
    }

    final parsed = DateTime.tryParse(
      value.toString(),
    );

    if (parsed == null) {
      return value.toString();
    }

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

    return '${months[parsed.month - 1]} '
        '${parsed.day}, ${parsed.year}';
  }

  int leaveDays(Map<String, dynamic> request) {
    final start = DateTime.tryParse(
      request['start_date']?.toString() ?? '',
    );

    final end = DateTime.tryParse(
      request['end_date']?.toString() ?? '',
    );

    if (start == null || end == null) {
      return 0;
    }

    return end.difference(start).inDays + 1;
  }

  Color statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  Color statusBackground(String status) {
    switch (status) {
      case 'approved':
        return AppColors.success.withOpacity(0.12);
      case 'rejected':
        return AppColors.danger.withOpacity(0.10);
      default:
        return AppColors.warning.withOpacity(0.14);
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule;
    }
  }

  Widget buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: statusBackground(status),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon(status),
            color: statusColor(status),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: statusColor(status),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment<String>(
            value: 'pending',
            icon: const Icon(Icons.schedule),
            label: Text(
              'Pending (${countForStatus('pending')})',
            ),
          ),
          ButtonSegment<String>(
            value: 'approved',
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              'Approved (${countForStatus('approved')})',
            ),
          ),
          ButtonSegment<String>(
            value: 'rejected',
            icon: const Icon(Icons.cancel_outlined),
            label: Text(
              'Rejected (${countForStatus('rejected')})',
            ),
          ),
        ],
        selected: {selectedFilter},
        showSelectedIcon: false,
        style: ButtonStyle(
          foregroundColor:
              WidgetStateProperty.resolveWith<Color>(
            (states) {
              return states.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.textSecondary;
            },
          ),
          backgroundColor:
              WidgetStateProperty.resolveWith<Color>(
            (states) {
              return states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : Colors.transparent;
            },
          ),
          side: const WidgetStatePropertyAll(
            BorderSide.none,
          ),
        ),
        onSelectionChanged: (selection) {
          setState(() {
            selectedFilter = selection.first;
          });
        },
      ),
    );
  }

  Widget buildRequestCard(
    Map<String, dynamic> request,
  ) {
    final id = request['id'].toString();
    final name = employeeName(request);

    final status = request['status']
            ?.toString()
            .trim()
            .toLowerCase() ??
        'pending';

    final reason =
        request['reason']?.toString().trim() ?? '';

    final days = leaveDays(request);
    final isUpdating = updatingRequestId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  initials(name),
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      leaveType(request),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _informationChip(
                icon: Icons.calendar_today_outlined,
                text: formatDate(request['start_date']),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 9),
                child: Icon(
                  Icons.arrow_forward,
                  color: AppColors.textMuted,
                  size: 18,
                ),
              ),
              _informationChip(
                icon: Icons.event_available_outlined,
                text: formatDate(request['end_date']),
              ),
              if (days > 0)
                _informationChip(
                  icon: Icons.timelapse,
                  text: '$days ${days == 1 ? 'day' : 'days'}',
                ),
            ],
          ),
          const SizedBox(height: 19),
          const Text(
            'Reason',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Text(
              reason.isEmpty
                  ? 'No reason provided.'
                  : reason,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(
                      color: AppColors.danger,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                  onPressed: isUpdating
                      ? null
                      : () => confirmReject(request),
                  icon: const Icon(Icons.close),
                  label: const Text(
                    'Reject',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                  ),
                  onPressed: isUpdating
                      ? null
                      : () => confirmApprove(request),
                  icon: isUpdating
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text(
                    'Approve',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _informationChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primaryLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: AppColors.primary,
            size: 18,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 30,
        vertical: 75,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              selectedFilter == 'approved'
                  ? Icons.check_circle_outline
                  : selectedFilter == 'rejected'
                      ? Icons.cancel_outlined
                      : Icons.event_note_outlined,
              color: AppColors.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 17),
          Text(
            'No ${selectedFilter.toLowerCase()} leave requests',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Leave requests will appear here when available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
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
  Widget build(BuildContext context) {
    final visibleRequests = filteredRequests;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Leave Approvals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh leave requests',
            onPressed: loading ? null : loadRequests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_outlined,
                          color: AppColors.textMuted,
                          size: 58,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: loadRequests,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: loadRequests,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      26,
                      26,
                      26,
                      50,
                    ),
                    children: [
                      const Text(
                        'Manage Leave Requests',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 27,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Review and manage employee leave requests.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 22),
                      buildFilterBar(),
                      const SizedBox(height: 24),
                      if (visibleRequests.isEmpty)
                        buildEmptyState()
                      else
                        ...visibleRequests.map(
                          buildRequestCard,
                        ),
                    ],
                  ),
                ),
    );
  }
}