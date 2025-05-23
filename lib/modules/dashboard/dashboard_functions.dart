// TODO Implement this library.import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_panel/modules/services/storage_service.dart';
import 'package:flutter/material.dart';

class DashboardFunctions {
  static Future<int> fetchUserCount() async {
    try {
      final users = await Supabase.instance.client
          .from('user_management')
          .select('userID')
          .eq('status', 'Accepted');
      return users.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> fetchTicketCount() async {
    try {
      final acceptedUserIDs = await Supabase.instance.client
          .from('user_management')
          .select('userID')
          .eq('status', 'Accepted');
      final userIds = List<String>.from(acceptedUserIDs.map((u) => u['userID']));
      final tickets = await Supabase.instance.client
          .from('support_ticket')
          .select('id')
          .inFilter('userid', userIds);
      return tickets.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<int> fetchDocCount(StorageService storage) async {
    try {
      final files = await storage.listFiles();
      return files.length;
    } catch (e) {
      return 0;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchLatestLogs() async {
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('activity_log')
          .select()
          .order('created_at', ascending: false)
          .limit(5);
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllLogs() async {
    try {
      final List<dynamic> res = await Supabase.instance.client
          .from('activity_log')
          .select()
          .order('created_at', ascending: false);
      return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      return [];
    }
  }

  static String getGreeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good Morning!';
    if (h < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  static IconData getActivityIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('support ticket')) return Icons.mail_outline;
    if (a.contains('password')) return Icons.vpn_key_outlined;
    if (a.contains('access')) return Icons.person_add_alt_1;
    if (a.contains('reset')) return Icons.refresh;
    return Icons.info_outline;
  }

  static Color getActivityColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('support ticket')) return Colors.blueAccent;
    if (a.contains('password')) return Colors.orangeAccent;
    if (a.contains('access')) return Colors.green;
    if (a.contains('reset')) return Colors.purple;
    return Colors.grey;
  }

  static Map<String, int> prevMonth(int displayMonth, int displayYear) {
    if (displayMonth == 1) {
      return {'month': 12, 'year': displayYear - 1};
    } else {
      return {'month': displayMonth - 1, 'year': displayYear};
    }
  }

  static Map<String, int> nextMonth(int displayMonth, int displayYear) {
    if (displayMonth == 12) {
      return {'month': 1, 'year': displayYear + 1};
    } else {
      return {'month': displayMonth + 1, 'year': displayYear};
    }
  }

  static Future<int> fetchTodayNewTicketsCount() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));
      final res = await Supabase.instance.client
          .from('activity_log')
          .select()
          .gte('created_at', todayStart.toIso8601String())
          .lt('created_at', todayEnd.toIso8601String())
          .ilike('action', '%support ticket%');
      return res.length;
    } catch (e) {
      return 0;
    }
  }
} 