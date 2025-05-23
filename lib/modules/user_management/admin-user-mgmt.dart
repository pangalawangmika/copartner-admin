// admin-user-mgmt.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:bcrypt/bcrypt.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final int _rowsPerPage = 6;
  int _currentPage = 0;
  TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  bool _sortDescending = true;
  String _searchText = '';
  String _selectedStatusFilter = 'All';


  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Future<String?> _getAdminUid() async {
    final supabase = Supabase.instance.client;
    final response = await supabase
        .from('copartner-admin-account')
        .select('uid')
        .limit(1)
        .maybeSingle();
    return response?['uid'] as String?;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _acceptUserRequest(String email, String userID) async {
    final supabase = Supabase.instance.client;
    try {
      final uid = await _getAdminUid();
      if (uid == null) throw "Admin UID not found";
      final response = await supabase
          .from('user_management')
          .select('status, email')
          .eq('userID', userID)
          .single();
      final currentStatus = response['status'] as String?;
      final fetchedEmail = response['email'] as String?;
      if (fetchedEmail == null) return;
      if (currentStatus == 'Pending' ||
          currentStatus == 'Removed Access, Pending') {
        await supabase
            .from('user_management')
            .update({'status': 'Accepted'}).eq('userID', userID);
      }
    } catch (e) {
      print("Error processing user request: $e");
    }
  }

  Future<void> _rejectUserRequest(String userId) async {
    final supabase = Supabase.instance.client;
    try {
      final uid = await _getAdminUid();
      if (uid == null) throw "Admin UID not found";
      final response = await supabase
          .from('user_management')
          .select('status')
          .eq('userID', userId)
          .single();
      final currentStatus = response['status'] as String?;
      if (currentStatus == 'Pending' ||
          currentStatus == 'Removed Access, Pending') {
        await supabase
            .from('user_management')
            .update({'status': 'Rejected'}).eq('userID', userId);
      }
    } catch (e) {
      print("Error rejecting user request: $e");
    }
  }

  Future<void> _removeUserAccess(String userId, String email) async {
    final supabase = Supabase.instance.client;
    try {
      final uid = await _getAdminUid();
      if (uid == null) throw "Admin UID not found";
      await supabase
          .from('user_management')
          .update({'status': 'Pending'}).eq('userID', userId);
      
      // Show notification
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed access for $email'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      print("Error removing user access: $e");
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Accepted':
        return Colors.green;
      case 'Pending':
      case 'Removed Access, Pending':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showFilterDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      String? tempStatus = _selectedStatus;
      bool tempSort = _sortDescending;

      return AlertDialog(
        title: const Text('Filter Options'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: tempStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [null, 'Pending', 'Accepted', 'Rejected', 'Removed Access, Pending']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status ?? 'All'),
                      ))
                  .toList(),
              onChanged: (value) => tempStatus = value,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('Sort: '),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Recent to Oldest'),
                  selected: tempSort,
                  onSelected: (_) => tempSort = true,
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('Oldest to Recent'),
                  selected: !tempSort,
                  onSelected: (_) => tempSort = false,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedStatus = tempStatus;
                _sortDescending = tempSort;
                _currentPage = 0;
              });
              Navigator.pop(context);
            },
            child: const Text('Apply'),
          ),
        ],
      );
    },
  );
}


 @override
Widget build(BuildContext context) {
  final supabase = Supabase.instance.client;
  return Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'User Management',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('user_management')
                  .stream(primaryKey: ['userID'])
                  .inFilter('status', [
                    'Pending',
                    'Accepted',
                    'Rejected',
                    'Removed Access, Pending'
                  ])
                  .order('requested_at', ascending: false),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawData = snapshot.data!;
                final filteredData = rawData
                    .where((item) =>
                        item['email']
                            .toString()
                            .toLowerCase()
                            .contains(_searchText.toLowerCase()) &&
                        (_selectedStatusFilter == 'All' ||
                            item['status'] == _selectedStatusFilter))
                    .toList();

                final sortedData = List<Map<String, dynamic>>.from(filteredData); // clone before sorting
                sortedData.sort((a, b) {
                  final aDate =
                      DateTime.tryParse(a['requested_at'] ?? '') ?? DateTime.now();
                  final bDate =
                      DateTime.tryParse(b['requested_at'] ?? '') ?? DateTime.now();
                  return _sortDescending
                      ? bDate.compareTo(aDate)
                      : aDate.compareTo(bDate);
                });

                final totalPages = (sortedData.length / _rowsPerPage).ceil();
                final paginatedData = sortedData
                    .skip(_currentPage * _rowsPerPage)
                    .take(_rowsPerPage)
                    .toList();

                return Column(
                  children: [
                    // White Box Container
                    Container(
                      width: 900,
                      height: 470,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Search + Filter Row inside white box
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _searchText = value;
                                        _currentPage = 0;
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search by email...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 0),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.filter_list),
                                  onSelected: (value) {
                                    if (value == 'Recent to Oldest') {
                                      setState(() {
                                        _sortDescending = true;
                                      });
                                    } else if (value == 'Oldest to Recent') {
                                      setState(() {
                                        _sortDescending = false;
                                      });
                                    } else {
                                      setState(() {
                                        _selectedStatusFilter = value;
                                      });
                                    }
                                    _currentPage = 0;
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'All', child: Text('All Status')),
                                    const PopupMenuItem(
                                        value: 'Pending', child: Text('Pending')),
                                    const PopupMenuItem(
                                        value: 'Accepted', child: Text('Accepted')),
                                    const PopupMenuItem(
                                        value: 'Rejected', child: Text('Rejected')),
                                    const PopupMenuItem(
                                        value: 'Removed Access, Pending',
                                        child: Text('Removed Access, Pending')),
                                    const PopupMenuDivider(),
                                    const PopupMenuItem(
                                        value: 'Recent to Oldest',
                                        child: Text('Recent to Oldest')),
                                    const PopupMenuItem(
                                        value: 'Oldest to Recent',
                                        child: Text('Oldest to Recent')),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Table UI
                          Expanded(
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor:
                                    MaterialStateProperty.all(Colors.grey[200]),
                                columnSpacing: 10,
                                horizontalMargin: 20,
                                dataRowHeight: 50,
                                headingRowHeight: 45,
                                columns: const [
                                  DataColumn(
                                      label: SizedBox(
                                        width: 40,
                                        child: Center(
                                          child: Text('No.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              )),
                                        ),
                                      )),
                                  DataColumn(
                                      label: SizedBox(
                                        width: 200,
                                        child: Center(
                                          child: Text('Email',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              )),
                                        ),
                                      )),
                                  DataColumn(
                                      label: SizedBox(
                                        width: 150,
                                        child: Center(
                                          child: Text('Requested At',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              )),
                                        ),
                                      )),
                                  DataColumn(
                                      label: SizedBox(
                                        width: 170,
                                        child: Center(
                                          child: Text('Status',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              )),
                                        ),
                                      )),
                                  DataColumn(
                                      label: SizedBox(
                                        width: 200,
                                        child: Center(
                                          child: Text('Actions',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              )),
                                        ),
                                      )),
                                ],
                                rows: List<DataRow>.generate(
                                  paginatedData.length,
                                  (index) {
                                    final item = paginatedData[index];
                                    final email = item['email'] ?? '';
                                    final ts = DateTime.tryParse(item['requested_at'] ?? '') ?? DateTime.now();
                                    final status = item['status'] ?? 'Pending';
                                    final userID = item['userID'];

                                    return DataRow(
                                      cells: [
                                        DataCell(Center(
                                          child: SizedBox(
                                            width: 40,
                                            child: Text(
                                              '${index + 1 + (_currentPage * _rowsPerPage)}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        )),
                                        DataCell(Center(
                                          child: SizedBox(
                                            width: 200,
                                            child: Text(
                                              email,
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        )),
                                        DataCell(Center(
                                          child: SizedBox(
                                            width: 150,
                                            child: Text(
                                              _formatDate(ts),
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        )),
                                        DataCell(Center(
                                          child: SizedBox(
                                            width: 140,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: _statusColor(status).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status,
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: _statusColor(status),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ),
                                        )),
                                        DataCell(
                                          SizedBox(
                                            width: 200,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (status == 'Pending' || status == 'Removed Access, Pending') ...[
                                                  SizedBox(
                                                    height: 32,
                                                    child: TextButton(
                                                      style: TextButton.styleFrom(
                                                        backgroundColor: const Color(0xFF66BB6A).withOpacity(0.8),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                      ),
                                                      onPressed: () => _acceptUserRequest(email, userID),
                                                      child: const Text(
                                                        'Accept',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  SizedBox(
                                                    height: 32,
                                                    child: TextButton(
                                                      style: TextButton.styleFrom(
                                                        backgroundColor: const Color(0xFFEF5350).withOpacity(0.8),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                      ),
                                                      onPressed: () => _rejectUserRequest(userID),
                                                      child: const Text(
                                                        'Reject',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ] else if (status == 'Accepted') ...[
                                                  SizedBox(
                                                    height: 32,
                                                    child: TextButton(
                                                      style: TextButton.styleFrom(
                                                        backgroundColor: const Color(0xFFFFA726).withOpacity(0.8),
                                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                      ),
                                                      onPressed: () => _removeUserAccess(userID, email),
                                                      child: const Text(
                                                        'Remove Access',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${min((_currentPage + 1) * _rowsPerPage, sortedData.length)} of ${sortedData.length}'),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

}
