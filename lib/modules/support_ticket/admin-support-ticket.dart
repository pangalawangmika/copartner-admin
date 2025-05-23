import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'support-ticket-function.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:intl/intl.dart';

class SupportTicketPage extends StatefulWidget {
  const SupportTicketPage({super.key});

  @override
  State<SupportTicketPage> createState() => _SupportTicketPageState();
}

class _SupportTicketPageState extends State<SupportTicketPage> {
  List<Map<String, dynamic>> tickets = [];
  List<Map<String, dynamic>> filteredTickets = [];
  bool isLoading = true;
  int currentPage = 0;
  final double rowHeight = 60.0;
  final double headerHeight = 56.0;
  final double paginationHeight = 60.0;
  late int rowsPerPage;
  final TextEditingController _searchController = TextEditingController();
  String? selectedStatus;
  String sortOrder = 'Recent to Oldest';
  late final RealtimeChannel _ticketSubscription;
  bool showChatbox = false;
  Map<String, dynamic>? selectedTicket;

  final filterStatusOptions = ['All', 'Pending', 'Open', 'Resolved'];
  final ticketStatusOptions = ['PENDING', 'OPEN', 'RESOLVED'];
  final sortOrderOptions = ['Recent to Oldest', 'Oldest to Recent'];

  @override
  void initState() {
    super.initState();
    fetchTickets();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    _ticketSubscription = Supabase.instance.client
        .channel('public:support_ticket')
        .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'support_ticket',
            callback: (payload) {
              if (mounted) {
                setState(() {
                  tickets.removeWhere((ticket) =>
                      ticket['id'].toString() ==
                      payload.oldRecord['id'].toString());
                });
              }
            })
        .subscribe();
  }

  @override
  void dispose() {
    _ticketSubscription.unsubscribe();
    _searchController.dispose();
    super.dispose();
  }

  void filterTickets(String query) {
    List<Map<String, dynamic>> temp = SupportTicketFunctions.filterTickets(
      tickets: tickets,
      query: query,
      selectedStatus: selectedStatus,
    );
    // Sort tickets based on sortOrder
    temp.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
      final bDate = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
      if (sortOrder == 'Recent to Oldest') {
        return bDate.compareTo(aDate);
      } else {
        return aDate.compareTo(bDate);
      }
    });
    setState(() {
      filteredTickets = temp;
      currentPage = 0;
    });
  }

  Future<void> fetchTickets() async {
    setState(() => isLoading = true);
    final response = await SupportTicketFunctions.fetchTickets();
    setState(() {
      tickets = response;
      filteredTickets = List.from(tickets);
      // Sort tickets initially
      filterTickets(_searchController.text);
      isLoading = false;
    });
  }

  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    await SupportTicketFunctions.updateTicketStatus(ticketId, newStatus);
    fetchTickets();
  }

  Future<void> deleteTicket(String ticketId) async {
    final bool confirm = await showDialog(
          context: context,
          builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.3,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Delete Ticket",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Are you sure you want to delete this support ticket? This action cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  child: const Text("Cancel"),
                ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ) ?? false;

    if (confirm) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          },
        );

        await SupportTicketFunctions.deleteTicket(ticketId);

        // Close loading indicator
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Update local state after successful deletion
        setState(() {
          tickets.removeWhere((ticket) => ticket['id'].toString() == ticketId);
          filteredTickets
              .removeWhere((ticket) => ticket['id'].toString() == ticketId);

          if (currentPage > 0 &&
              currentPage * rowsPerPage >= filteredTickets.length) {
            currentPage--;
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ticket permanently deleted'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop();
        }

        debugPrint('Error deleting ticket: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete the ticket. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void showTicketDetails(Map<String, dynamic> ticket) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.4,
            padding: const EdgeInsets.all(24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Ticket Details",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildDetailRow("Full Name", ticket['full_name'] ?? '-'),
                _buildDetailRow("Subject", ticket['subject'] ?? '-'),
                _buildDetailRow("Description", ticket['description'] ?? '-'),
                _buildDetailRow("Created At", 
                  ticket['created_at'] != null 
                    ? DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(ticket['created_at']))
                    : '-'
                ),
                _buildStatusRow("Status", ticket['status']?.toString().toUpperCase() ?? 'PENDING'),
                if (ticket['imagesURL'] != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    "Attached Images",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildImagePreview(ticket['imagesURL']),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String status) {
    Color statusColor;
    switch (status) {
      case 'RESOLVED':
        statusColor = const Color(0xFF2F3296);
        break;
      case 'PENDING':
        statusColor = const Color(0xFF962F2F);
        break;
      case 'OPEN':
        statusColor = const Color(0xFFD4DC5B);
        break;
      default:
        statusColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
                  ),
                ],
              ),
    );
  }

  Widget _buildImagePreview(dynamic imageUrls) {
    List<String> urls = [];
    try {
      if (imageUrls is String) {
        if (imageUrls.startsWith('[')) {
          // Parse JSON array string
          urls = List<String>.from(jsonDecode(imageUrls));
        } else {
          urls = [imageUrls];
        }
      } else if (imageUrls is List) {
        urls = List<String>.from(imageUrls);
      }
      
      return SizedBox(
        height: 120,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: urls.length,
          itemBuilder: (context, index) {
            String imageUrl = urls[index];
            // Ensure URL is properly formatted
            if (!imageUrl.startsWith('http')) {
              imageUrl = 'https://$imageUrl';
            }
            
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () => _showFullImage(context, imageUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    height: 120,
                    width: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Error loading image: $error');
                      return Container(
                        height: 120,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                            const SizedBox(height: 4),
                            Text(
                              'Image Error',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Error processing images: $e');
      return const SizedBox.shrink();
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading full image: $error');
                  return Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey[400], size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void openChatbox(Map<String, dynamic> ticket) async {
    final status = (ticket['status'] ?? '').toString().toUpperCase();
    
    // If status is RESOLVED, just open chatbox for viewing
    if (status == 'RESOLVED') {
      setState(() {
        showChatbox = true;
        selectedTicket = ticket;
      });
      return;
    }
    
    // If status is OPEN, just open chatbox
    if (status == 'OPEN') {
      setState(() {
        showChatbox = true;
        selectedTicket = ticket;
      });
      return;
    }
    
    // For PENDING status, show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: Container(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2C3390),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Initiate Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(false),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Do you want to initiate a chat with the user regarding this support ticket? This will set the ticket status to OPEN.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2C3390),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text(
                            'Yes, Initiate Chat',
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (confirm == true) {
      try {
      // Update ticket status to OPEN
      await Supabase.instance.client
          .from('support_ticket')
            .update({
              'status': 'OPEN'
            })
          .eq('id', ticket['id']);
      
      // Fetch the updated ticket
      final updated = await Supabase.instance.client
          .from('support_ticket')
          .select()
          .eq('id', ticket['id'])
            .single();
      
      // Refresh tickets list
      await fetchTickets();
      
      // Open chatbox with updated ticket
      setState(() {
        showChatbox = true;
          selectedTicket = updated;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating ticket status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void closeChatbox() {
    setState(() {
      showChatbox = false;
      selectedTicket = null;
    });
  }

  // Add this helper function for picking and uploading images
  Future<void> pickAndUploadImage(Function(String url) onSuccess) async {
    try {
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result != null && result.files.single.bytes != null) {
          final fileName = 'admin_ticket_${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
          final supabase = Supabase.instance.client;
          final response = await supabase.storage
              .from('support-ticket-chat-images')
              .uploadBinary(fileName, result.files.single.bytes!, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
          if (response.isEmpty) throw Exception('Upload failed');
          final url = supabase.storage.from('support-ticket-chat-images').getPublicUrl(fileName);
          onSuccess(url);
        }
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          final file = File(picked.path);
          final fileName = 'admin_ticket_${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
          final supabase = Supabase.instance.client;
          final response = await supabase.storage
              .from('support-ticket-chat-images')
              .upload(fileName, file);
          if (response.isEmpty) throw Exception('Upload failed');
          final url = supabase.storage.from('support-ticket-chat-images').getPublicUrl(fileName);
          onSuccess(url);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void calculateRowsPerPage(double availableHeight) {
    // Calculate how many rows can fit in the available height
    final maxRows = ((availableHeight - headerHeight - paginationHeight) / rowHeight).floor();
    rowsPerPage = maxRows > 0 ? maxRows : 1;
  }

  List<Map<String, dynamic>> getPaginatedTickets() {
    if (filteredTickets.isEmpty) return [];
    final startIndex = currentPage * rowsPerPage;
    final endIndex = startIndex + rowsPerPage;
    return filteredTickets.sublist(
      startIndex,
      endIndex > filteredTickets.length ? filteredTickets.length : endIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Support Ticket Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 8)
                          ],
                        ),
                        child: Column(
                          children: [
                            // Search and Filter Row
                            Row(
                              children: [
                                // Search Bar
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: filterTickets,
                                    decoration: InputDecoration(
                                      hintText:
                                          'Search by name, subject, or description...',
                                      prefixIcon: const Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Status Filter
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedStatus ?? 'All',
                                        isExpanded: true,
                                        hint: const Text('Filter by Status'),
                                        items: filterStatusOptions
                                            .map((String status) {
                                          return DropdownMenuItem<String>(
                                            value: status,
                                            child: Text(status),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            selectedStatus = newValue;
                                            filterTickets(_searchController.text);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Sort Order Filter
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: sortOrder,
                                        isExpanded: true,
                                        hint: const Text('Sort by'),
                                        items: sortOrderOptions.map((String order) {
                                          return DropdownMenuItem<String>(
                                            value: order,
                                            child: Text(order),
                                          );
                                        }).toList(),
                                        onChanged: (String? newValue) {
                                          setState(() {
                                            sortOrder = newValue!;
                                            filterTickets(_searchController.text);
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: filteredTickets.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.search_off,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No tickets found for "${_searchController.text}"',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          if (selectedStatus != null &&
                                              selectedStatus != 'All')
                                            Text(
                                              'Status filter: $selectedStatus',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey,
                                              ),
                                            ),
                                        ],
                                      ),
                                    )
                                  : LayoutBuilder(
                                      builder: (context, constraints) {
                                        calculateRowsPerPage(constraints.maxHeight);
                                        final paginatedTickets = getPaginatedTickets();
                                        
                                        return Column(
                                      children: [
                                        Expanded(
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: DataTable(
                                                  headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                                                  dataRowHeight: rowHeight,
                                                columnSpacing: 32.0,
                                                  headingTextStyle: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black,
                                                  ),
                                                  columns: [
                                                  DataColumn(
                                                      label: Container(
                                                        width: 50,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'No',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                      label: Container(
                                                        width: 100,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'Full Name',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                      label: Container(
                                                        width: 120,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'Subject',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                      label: Container(
                                                        width: 180,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'Description',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                      label: Container(
                                                        width: 100,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'Date',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                      label: Container(
                                                        width: 100,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'Status',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                  DataColumn(
                                                      label: Container(
                                                        width: 300,
                                                        alignment: Alignment.center,
                                                        child: const Text(
                                                        'Actions',
                                                          style: TextStyle(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                  rows: List.generate(paginatedTickets.length, (index) {
                                                    final ticket = paginatedTickets[index];
                                                  return DataRow(
                                                    cells: [
                                                      DataCell(
                                                          Text(
                                                            '${index + 1}',
                                                            style: const TextStyle(fontSize: 14),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                            alignment: Alignment.center,
                                                          width: 100,
                                                          child: Text(
                                                              ticket['full_name'] ?? '-',
                                                              style: const TextStyle(fontSize: 12),
                                                              textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                            alignment: Alignment.center,
                                                          width: 120,
                                                          child: Text(
                                                              ticket['subject'] ?? '-',
                                                              style: const TextStyle(fontSize: 12),
                                                              textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                            alignment: Alignment.center,
                                                          width: 180,
                                                          child: Text(
                                                              (ticket['description'] ?? '-').toString().length > 40
                                                                ? '${ticket['description'].toString().substring(0, 40)}...'
                                                                  : ticket['description'] ?? '-',
                                                              style: const TextStyle(fontSize: 12),
                                                              textAlign: TextAlign.center,
                                                              overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                            alignment: Alignment.center,
                                                          child: Text(
                                                              ticket['created_at'] != null
                                                                  ? DateFormat('MMM dd, yyyy').format(DateTime.parse(ticket['created_at']))
                                                                : '-',
                                                              style: const TextStyle(fontSize: 12),
                                                              textAlign: TextAlign.center,
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                            alignment: Alignment.center,
                                                          child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                              decoration: BoxDecoration(
                                                                color: (ticket['status']?.toString().toUpperCase() == 'OPEN')
                                                                    ? const Color(0xFFFFFBE6)
                                                                    : SupportTicketFunctions.getStatusColor(ticket['status']).withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Text(
                                                              (ticket['status'] ?? '').toString().toUpperCase(),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                  color: (ticket['status']?.toString().toUpperCase() == 'OPEN')
                                                                      ? Colors.yellow.shade700
                                                                      : SupportTicketFunctions.getStatusColor(ticket['status']),
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      DataCell(
                                                        Container(
                                                            alignment: Alignment.center,
                                                          child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                            children: [
                                                                ElevatedButton.icon(
                                                                  onPressed: () => openChatbox(ticket),
                                                                  icon: Icon(Icons.chat, size: 16, color: const Color(0xFF1F1F1F)),
                                                                  label: Text("Chat", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1F1F1F))),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: Colors.green,
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                              ElevatedButton.icon(
                                                                  onPressed: () => showTicketDetails(ticket),
                                                                  icon: const Icon(Icons.remove_red_eye, size: 16, color: Color(0xFF1F1F1F)),
                                                                  label: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1F1F1F))),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: Colors.blue,
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                              ElevatedButton.icon(
                                                                  onPressed: () => deleteTicket(ticket['id'].toString()),
                                                                  icon: const Icon(Icons.delete_forever, size: 16, color: Color(0xFF1F1F1F)),
                                                                  label: const Text("Delete", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1F1F1F))),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: Colors.red,
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }),
                                              ),
                                            ),
                                          ),
                                            SizedBox(
                                              height: paginationHeight,
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                                child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text(
                                                      'Page ${currentPage + 1} of ${(filteredTickets.length / rowsPerPage).ceil()}',
                                                      style: const TextStyle(fontSize: 14),
                                            ),
                                                    const SizedBox(width: 16),
                                            IconButton(
                                              icon: const Icon(Icons.chevron_left),
                                              onPressed: currentPage > 0
                                                          ? () => setState(() => currentPage--)
                                                  : null,
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.chevron_right),
                                                      onPressed: (currentPage + 1) * rowsPerPage < filteredTickets.length
                                                          ? () => setState(() => currentPage++)
                                                  : null,
                                            ),
                                          ],
                                                ),
                                              ),
                                        ),
                                      ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (showChatbox && selectedTicket != null)
          Positioned(
            bottom: 32,
            right: 32,
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 400,
                height: 720,
                constraints: BoxConstraints(
                  maxHeight: 620,
                  minHeight: 320,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: AdminFloatingChatbox(
                  ticket: selectedTicket!,
                  onClose: closeChatbox,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class AdminFloatingChatbox extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onClose;
  const AdminFloatingChatbox({required this.ticket, required this.onClose, Key? key}) : super(key: key);

  @override
  State<AdminFloatingChatbox> createState() => _AdminFloatingChatboxState();
}

class _AdminFloatingChatboxState extends State<AdminFloatingChatbox> {
  bool sentInitial = false;
  bool isLoading = false;
  bool isUploading = false;
  List<Map<String, dynamic>> messages = [];
  final TextEditingController _messageController = TextEditingController();
  String? userEmail;
  final _supabase = Supabase.instance.client;
  late RealtimeChannel? _chatChannel;
  final ScrollController _scrollController = ScrollController();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    sentInitial = true;
    fetchUserEmail();
    fetchMessages();
    _subscribeToMessages();
  }

  void _subscribeToMessages() {
    _chatChannel = _supabase
        .channel('admin_ticket_chat_${widget.ticket['id']}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'support_ticket_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ticket_id',
            value: widget.ticket['id'].toString(),
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord != null) {
              setState(() {
                messages.add(newRecord);
              });
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    if (_chatChannel != null) {
      _supabase.removeChannel(_chatChannel!);
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchUserEmail() async {
    final email = await SupportTicketFunctions.fetchUserEmail(widget.ticket['userid']);
    setState(() {
      userEmail = email;
    });
  }

  Future<void> fetchMessages() async {
    setState(() => isLoading = true);
    final msgs = await SupportTicketFunctions.fetchMessages(widget.ticket['id'].toString());
    // Ensure messages are sorted by created_at ascending
    msgs.sort((a, b) => DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
    setState(() {
      messages = msgs;
      isLoading = false;
      sentInitial = msgs.isNotEmpty;
    });
    _scrollToBottom();
  }

  Future<void> sendChatMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    try {
      final message = _messageController.text.trim();
      _messageController.clear();
      
      // Add message to local state immediately for instant feedback
      final newMessage = {
        'ticket_id': widget.ticket['id'],
        'user_id': _supabase.auth.currentUser?.id,
        'message': message,
        'is_admin': true,
        'is_image': false,
        'created_at': DateTime.now().toIso8601String(),
      };
      setState(() {
        messages.add(newMessage);
      });
      _scrollToBottom();

      // Send message to server
      await _supabase
          .from('support_ticket_messages')
          .insert({
            'ticket_id': widget.ticket['id'],
            'user_id': _supabase.auth.currentUser?.id,
            'message': message,
            'is_admin': true,
            'is_image': false,
          });

    } catch (e) {
      debugPrint('Error sending chat message: $e');
      // Remove error snackbar to prevent error message from showing
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => isUploading = true);
      String? imageUrl;
      if (kIsWeb) {
        final result = await FilePicker.platform.pickFiles(type: FileType.image);
        if (result != null && result.files.single.bytes != null) {
          final fileName = 'chat_image_${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
          final response = await _supabase.storage
              .from('support-ticket-chat-images')
              .uploadBinary(fileName, result.files.single.bytes!, fileOptions: const FileOptions(cacheControl: '3600', upsert: false));
          if (response.isEmpty) throw Exception('Upload failed');
          imageUrl = _supabase.storage.from('support-ticket-chat-images').getPublicUrl(fileName);
        }
      } else {
        final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final fileName = 'chat_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final response = await _supabase.storage
              .from('support-ticket-chat-images')
              .upload(fileName, file);
          if (response.isEmpty) throw Exception('Upload failed');
          imageUrl = _supabase.storage.from('support-ticket-chat-images').getPublicUrl(fileName);
        }
      }
      if (imageUrl != null) {
        // Add image message to local state immediately
        final newMessage = {
          'ticket_id': widget.ticket['id'],
          'user_id': _supabase.auth.currentUser?.id,
          'message': imageUrl,
          'is_admin': true,
          'is_image': true,
          'created_at': DateTime.now().toIso8601String(),
        };
        setState(() {
          messages.add(newMessage);
        });
        _scrollToBottom();

        // Send image message to server directly
        await _supabase
            .from('support_ticket_messages')
            .insert({
              'ticket_id': widget.ticket['id'],
              'user_id': _supabase.auth.currentUser?.id,
              'message': imageUrl,
              'is_admin': true,
              'is_image': true,
            });
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      // Remove the error snackbar
    } finally {
      setState(() => isUploading = false);
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('Error loading full image: $error');
                  return Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.white,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, color: Colors.grey[400], size: 64),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load image',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      height: 720,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3390),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.ticket['subject'] ?? 'Support Chat',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.ticket['status']?.toString().toUpperCase() != 'RESOLVED')
                  TextButton.icon(
                    onPressed: () async {
                      final bool confirm = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text("Resolve Ticket"),
                            content: const Text(
                                "Are you sure you want to mark this ticket as resolved?"),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: const Text("Resolve"),
                              ),
                            ],
                          );
                        },
                      ) ?? false;

                      if (confirm) {
                        await SupportTicketFunctions.updateTicketStatus(
                          widget.ticket['id'].toString(),
                          'RESOLVED',
                        );
                        widget.onClose();
                      }
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text(
                      'Resolve Ticket',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isAdmin = message['is_admin'] ?? false;
                        final isImage = message['is_image'] ?? false;
                        return Align(
                          alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
                          child: Row(
                            mainAxisAlignment: isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
                            children: [
                              if (!isAdmin) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue,
                                  child: Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isAdmin ? const Color(0xFFD9DCF7) : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (!isAdmin)
                                        Text(
                                          'User',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      if (isImage)
                                        GestureDetector(
                                          onTap: () => _showFullImage(context, message['message']),
                                          child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              constraints: BoxConstraints(
                                                maxWidth: 200,
                                                maxHeight: 200,
                                              ),
                                          child: Image.network(
                                            message['message'],
                                                fit: BoxFit.contain,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                                  return Container(
                                                width: 200,
                                                    height: 150,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                                  debugPrint('Error loading chat image: $error');
                                                  return Container(
                                                width: 200,
                                                    height: 150,
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey[200],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                                                        const SizedBox(height: 8),
                                                        Text(
                                                          'Failed to load image',
                                                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Text(
                                          message['message'],
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isAdmin) ...[
                                const SizedBox(width: 8),
                                
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                IconButton(
                  icon: isUploading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.image, color: Color(0xFF2C3390), size: 28),
                  onPressed: isUploading ? null : _pickAndUploadImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: widget.ticket['status']?.toString().toUpperCase() != 'RESOLVED',
                    decoration: InputDecoration(
                      hintText: widget.ticket['status']?.toString().toUpperCase() == 'RESOLVED' 
                          ? 'This ticket has been resolved'
                          : 'Type your message...',
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 11),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2C3390), size: 32),
                  onPressed: widget.ticket['status']?.toString().toUpperCase() == 'RESOLVED' 
                      ? null 
                      : (isLoading ? null : sendChatMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
