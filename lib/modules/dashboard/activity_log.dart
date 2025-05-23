import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogService {
  final SupabaseClient supabase;

  ActivityLogService(this.supabase);

  // Function to log activities
  Future<void> logActivity(String action, String email, int userId) async {
    final timestamp = DateTime.now().toIso8601String();

    try {
      final response = await supabase
          .from('activity_log')
          .insert([
            {
              'created_at': timestamp,
              'act_userid': userId,
              'email': email,
              'action': action,
            }
          ]);

      if (response.error != null) {
        throw Exception('Error logging activity: ${response.error!.message}');
      }
    } catch (e) {
      print('Error logging activity: $e');
      // Handle your custom error message or logging here
    }
  }

  // Function for user password change activity
  Future<void> logPasswordChanged(int userId, String email) async {
    String action = '$email changed their password';
    await logActivity(action, email, userId);
  }

  // Function for user access request activity
  Future<void> logAccessRequested(int userId, String email) async {
    String action = '$email requested access';
    await logActivity(action, email, userId);
  }

  // Function for support ticket submission activity
  Future<void> logSupportTicketSubmitted(int userId, String email) async {
    String action = '$email submitted a support ticket';
    await logActivity(action, email, userId);
  }
}
