import 'package:flutter/material.dart';
import '../main.dart';

class LeaveApprovalScreen extends StatefulWidget {
  const LeaveApprovalScreen({super.key});

  @override
  State<LeaveApprovalScreen> createState() => _LeaveApprovalScreenState();
}

class _LeaveApprovalScreenState extends State<LeaveApprovalScreen> {
  bool loading = true;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    loadRequests();
  }

  Future<void> loadRequests() async {
    final response = await supabase
        .from('leave_requests')
        .select()
        .eq('workspace_id', currentWorkspaceId)
        .order('created_at', ascending: false);

    setState(() {
      requests = List<Map<String, dynamic>>.from(response);
      loading = false;
    });
  }

  Future<void> updateStatus(String id, String status) async {
    await supabase
        .from('leave_requests')
        .update({'status': status})
        .eq('id', id)
        .eq('workspace_id', currentWorkspaceId);

    await loadRequests();
  }

  Color statusColor(String status) {
    if (status == 'approved') return Colors.green;
    if (status == 'rejected') return Colors.red;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFA8D5BA),
        title: const Text(
          "Leave Approvals",
          style: TextStyle(
            color: Color(0xFF2F4F2F),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : requests.isEmpty
              ? const Center(child: Text("No leave requests found"))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    final status = request['status'] ?? 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request['employee_name'] ?? '',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2F4F2F),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text("Type: ${request['leave_type']}"),
                            Text(
                              "Dates: ${request['start_date']} to ${request['end_date']}",
                            ),
                            Text("Reason: ${request['reason'] ?? 'No reason'}"),
                            const SizedBox(height: 10),
                            Text(
                              "Status: ${status.toString().toUpperCase()}",
                              style: TextStyle(
                                color: statusColor(status),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (status == 'pending')
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      updateStatus(
                                        request['id'],
                                        'approved',
                                      );
                                    },
                                    icon: const Icon(Icons.check),
                                    label: const Text("Approve"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      updateStatus(
                                        request['id'],
                                        'rejected',
                                      );
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text("Reject"),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}