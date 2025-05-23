import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupportTicketFunctions {
  static Future<List<Map<String, dynamic>>> fetchTickets() async {
    final acceptedUserIDs = await Supabase.instance.client
        .from('user_management')
        .select('userID')
        .eq('status', 'Accepted');

    final userIds = List<String>.from(acceptedUserIDs.map((u) => u['userID']));

    final response = await Supabase.instance.client
        .from('support_ticket')
        .select()
        .inFilter('userid', userIds)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    await Supabase.instance.client
        .from('support_ticket')
        .update({'status': newStatus}).eq('id', ticketId);
  }

  static Future<void> deleteTicket(String ticketId) async {
    await Supabase.instance.client
        .from('support_ticket')
        .delete()
        .eq('id', ticketId);
  }

  static Future<String> fetchUserEmail(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('user_management')
          .select('email')
          .eq('userID', userId)
          .single();

      return response?['email'] ?? "Email not found";
    } catch (e) {
      debugPrint('Error fetching user email: $e');
      return "Error fetching email";
    }
  }

  static Future<List<Map<String, dynamic>>> fetchMessages(String ticketId) async {
    final response = await Supabase.instance.client
        .from('support_ticket_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> sendMessage({
    required String ticketId,
    required String message,
    required String userId,
    required String subject,
    bool isAdmin = true,
    bool isImage = false,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    final adminId = user?.id ?? 'dee12dcf-a1e1-40eb-bb93-be7ef448e49e'; // Replace with your admin uuid if needed
    final intTicketId = ticketId is int ? ticketId : int.tryParse(ticketId);
    final usedUserId = isAdmin ? adminId : userId;
    // Debug prints
    debugPrint('Attempting to send message with:');
    debugPrint('ticket_id: $intTicketId (type: ${intTicketId.runtimeType})');
    debugPrint('user_id: $usedUserId (type: ${usedUserId.runtimeType})');
    debugPrint('message: $message');
    debugPrint('is_admin: $isAdmin');
    debugPrint('is_image: $isImage');
    if (intTicketId == null || usedUserId == null || usedUserId.toString().isEmpty || message.isEmpty) {
      debugPrint('Error: One or more required fields are invalid or missing.');
      return;
    }
    try {
      await Supabase.instance.client.from('support_ticket_messages').insert({
        'ticket_id': intTicketId,
        'user_id': usedUserId,
        'message': message,
        'is_admin': isAdmin,
        'is_image': isImage,
      });
      debugPrint('Message insert succeeded');
      
      // Set chat_started=true if admin is sending and not already set
      if (isAdmin) {
        final ticket = await Supabase.instance.client
            .from('support_ticket')
            .select('chat_started')
            .eq('id', intTicketId)
            .maybeSingle();
        if (ticket != null && ticket['chat_started'] != true) {
          await Supabase.instance.client
              .from('support_ticket')
              .update({'chat_started': true})
              .eq('id', intTicketId);
        }
      }
      // Try to insert notification, but don't fail if it doesn't work
      try {
        await Supabase.instance.client.from('notifications').insert({
          'user_id': userId, // uuid of the user to notify
          'message': 'CoPartner-Admin has initiated a chat.',
          'ticket_id': intTicketId,
          // 'created_at' and 'is_read' are set automatically
        });
        debugPrint('Notification insert succeeded');
      } catch (notificationError) {
        debugPrint('Failed to insert notification: $notificationError');
        // Don't rethrow the error, just log it
      }
    } catch (e) {
      debugPrint('PostgrestException when sending message: $e');
      rethrow;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'open':
        return Colors.yellow; // Yellow color for OPEN status
      case 'on-going':
        return Colors.orange;
      default:
        return Colors.red;
    }
  }

  static String toTitleCase(String input) {
    return input.isEmpty
        ? input
        : input[0].toUpperCase() + input.substring(1).toLowerCase();
  }

  static List<Map<String, dynamic>> filterTickets({
    required List<Map<String, dynamic>> tickets,
    required String query,
    String? selectedStatus,
  }) {
    var tempTickets = List<Map<String, dynamic>>.from(tickets);

    // Apply status filter first
    if (selectedStatus != null && selectedStatus != 'All') {
      tempTickets = tempTickets.where((ticket) {
        return ticket['status']?.toString().toLowerCase() ==
            selectedStatus?.toLowerCase();
      }).toList();
    }

    // Then apply search query
    if (query.isNotEmpty) {
      tempTickets = tempTickets.where((ticket) {
        final fullName = ticket['full_name']?.toString().toLowerCase() ?? '';
        final subject = ticket['subject']?.toString().toLowerCase() ?? '';
        final description = ticket['description']?.toString().toLowerCase() ?? '';
        final searchLower = query.toLowerCase();

        return fullName.contains(searchLower) ||
            subject.contains(searchLower) ||
            description.contains(searchLower);
      }).toList();
    }

    return tempTickets;
  }

  static void showImageDialog(BuildContext context, dynamic imageField) async {
    List<String> imageUrls = [];

    try {
      // Check if imageField is null or empty, if so, no images to show
      if (imageField == null || imageField.toString().trim().isEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("No Images"),
            content: const Text("No images were attached to this support ticket."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close")),
            ],
          ),
        );
        return;
      }

      // Check if the imageField is a String (i.e., possibly a JSON-encoded list of image URLs)
      if (imageField is String) {
        try {
          final decoded = json.decode(imageField);
          if (decoded is List) {
            imageUrls = List<String>.from(decoded);
          } else {
            imageUrls = [imageField];
          }
        } catch (e) {
          debugPrint("Error decoding JSON: $e");
          imageUrls = [imageField];
        }
      } else if (imageField is List) {
        imageUrls = List<String>.from(imageField);
      }

      // Filter out any null or empty URLs from the list
      imageUrls = imageUrls
          .where((url) => url != null && url.trim().isNotEmpty)
          .toList();

      // If no valid image URLs were found, show the "No Images" dialog
      if (imageUrls.isEmpty) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("No Images"),
            content: const Text("No images were attached to this support ticket."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close")),
            ],
          ),
        );
        return;
      }

      // Proceed to display the images if valid URLs were found
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Attached Images"),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: imageUrls.length,
              itemBuilder: (context, index) {
                final url = imageUrls[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    width: 300,
                    height: 400,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Text("Could not display image");
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close")),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error displaying images: $e");
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Error"),
          content: const Text("An error occurred while loading the images."),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close")),
          ],
        ),
      );
    }
  }
} 