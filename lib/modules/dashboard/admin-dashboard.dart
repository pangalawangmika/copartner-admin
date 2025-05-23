import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:admin_panel/modules/support_ticket/admin-support-ticket.dart';
import 'package:admin_panel/modules/user_management/admin-user-mgmt.dart';
import 'package:admin_panel/modules/faqs/admin-faqs.dart';
import 'package:admin_panel/modules/documents/admin-docs.dart';
import 'package:admin_panel/modules/login/admin-login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'activity_log.dart';
import 'package:admin_panel/modules/services/storage_service.dart';
import 'dashboard_functions.dart';

class ClockPainter extends CustomPainter {
  final DateTime dateTime;
  ClockPainter(this.dateTime);
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final fillBrush = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius, fillBrush);
    final outlineBrush = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius, outlineBrush);
    final hourHandBrush = Paint()
      ..color = Colors.black
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final hourAngle =
        (dateTime.hour % 12 + dateTime.minute / 60) * 30 * pi / 180;
    final hourHandLength = radius * 0.5;
    final hourHandOffset = Offset(
      center.dx + hourHandLength * sin(hourAngle),
      center.dy - hourHandLength * cos(hourAngle),
    );
    canvas.drawLine(center, hourHandOffset, hourHandBrush);
    final minuteHandBrush = Paint()
      ..color = Colors.black87
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    final minuteAngle =
        (dateTime.minute + dateTime.second / 60) * 6 * pi / 180;
    final minuteHandLength = radius * 0.7;
    final minuteHandOffset = Offset(
      center.dx + minuteHandLength * sin(minuteAngle),
      center.dy - minuteHandLength * cos(minuteAngle),
    );
    canvas.drawLine(center, minuteHandOffset, minuteHandBrush);
    final secondHandBrush = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final secondAngle = dateTime.second * 6 * pi / 180;
    final secondHandLength = radius * 0.9;
    final secondHandOffset = Offset(
      center.dx + secondHandLength * sin(secondAngle),
      center.dy - secondHandLength * cos(secondAngle),
    );
    canvas.drawLine(center, secondHandOffset, secondHandBrush);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class DashboardPage extends StatefulWidget {
  final void Function(int) onSelectPage;
  const DashboardPage({Key? key, required this.onSelectPage}) : super(key: key);
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  DateTime _now = DateTime.now();
  Timer? _timer;
  int _displayYear = DateTime.now().year;
  int _displayMonth = DateTime.now().month;
  int _userCount = 0;
  int _ticketCount = 0;
  int _docCount = 0;
  int _todayNewTickets = 0;
  List<Map<String, dynamic>> _latestLogs = [];
  List<Map<String, dynamic>> _allLogs = [];
  final StorageService _storage = StorageService();
  bool _isCalendarMaximized = false;
  bool _moreDetailsHovering = false;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _fetchLatestLogs();
    _fetchTodayNewTickets();
  }

  Future<void> _fetchCounts() async {
    final userCount = await DashboardFunctions.fetchUserCount();
    final ticketCount = await DashboardFunctions.fetchTicketCount();
    final docCount = await DashboardFunctions.fetchDocCount(_storage);
    setState(() {
      _userCount = userCount;
      _ticketCount = ticketCount;
      _docCount = docCount;
    });
  }

  Future<void> _fetchLatestLogs() async {
    final logs = await DashboardFunctions.fetchLatestLogs();
    setState(() {
      _latestLogs = logs;
    });
  }

  Future<void> _fetchAllLogs() async {
    final logs = await DashboardFunctions.fetchAllLogs();
    setState(() {
      _allLogs = logs;
    });
  }

  Future<void> _fetchTodayNewTickets() async {
    final count = await DashboardFunctions.fetchTodayNewTicketsCount();
    setState(() {
      _todayNewTickets = count;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _prevMonth() {
    final result = DashboardFunctions.prevMonth(_displayMonth, _displayYear);
    setState(() {
      _displayMonth = result['month']!;
      _displayYear = result['year']!;
    });
  }

  void _nextMonth() {
    final result = DashboardFunctions.nextMonth(_displayMonth, _displayYear);
    setState(() {
      _displayMonth = result['month']!;
      _displayYear = result['year']!;
    });
  }

  void _showAllLogs() async {
  await _fetchAllLogs();
  showDialog(
    context: context,
    builder: (_) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 500, // reduced width
        height: 600, // reduced height
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Blue header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF23225C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: const Text(
                'Activity Log',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Log content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ListView.builder(
                  itemCount: _allLogs.length,
                  itemBuilder: (context, i) {
                    final e = _allLogs[i];
                    final email = e['email'] ?? '-';
                    final action = e['action'] ?? '-';
                    final createdAt = e['created_at'];
                    String formattedDate = '-';
                    try {
                      final dt = DateTime.parse(createdAt);
                      formattedDate = DateFormat('EEEE, MMMM d, y').format(dt) +
                          ' at ' + DateFormat('h:mm a').format(dt);
                    } catch (_) {
                      formattedDate = createdAt ?? '-';
                    }
                    return ListTile(
                      title: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black),
                          children: [
                            TextSpan(
                              text: email,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const TextSpan(text: '  '),
                            TextSpan(text: action),
                          ],
                        ),
                      ),
                      subtitle: Text(formattedDate),
                    );
                  },
                ),
              ),
            ),

            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 12),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


  void _showCalendarDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          insetPadding: _isCalendarMaximized ? EdgeInsets.zero : const EdgeInsets.all(32),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: _isCalendarMaximized ? BorderRadius.zero : BorderRadius.circular(24),
            ),
            width: _isCalendarMaximized ? double.infinity : 700,
            height: _isCalendarMaximized ? double.infinity : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal AppBar
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF23225C),
                    borderRadius: _isCalendarMaximized ? BorderRadius.zero : const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48),
                      Text(
                        DateFormat.yMMMM().format(DateTime(_displayYear, _displayMonth)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _isCalendarMaximized = false;
                        },
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _isCalendarMaximized
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            final int numWeeks = ((DateUtils.getDaysInMonth(_displayYear, _displayMonth) + DateTime(_displayYear, _displayMonth, 1).weekday - 2) / 7).ceil();
                            final double cellWidth = constraints.maxWidth / 7;
                            final double cellHeight = constraints.maxHeight / (numWeeks + 1); // +1 for days row
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                                      .map((d) => SizedBox(
                                            width: cellWidth,
                                            height: cellHeight,
                                            child: Center(
                                              child: Text(d,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600)),
                                            ),
                                          ))
                                      .toList(),
                                ),
                                ...List.generate(
                                  numWeeks,
                                  (week) {
                                    final firstDay = DateTime(_displayYear, _displayMonth, 1);
                                    final daysInMonth = DateUtils.getDaysInMonth(_displayYear, _displayMonth);
                                    return Row(
                                      children: List.generate(7, (weekday) {
                                        final i = week * 7 + weekday;
                                        final dayNum = i - (firstDay.weekday - 2);
                                        final isToday = dayNum == DateTime.now().day &&
                                            _displayMonth == DateTime.now().month &&
                                            _displayYear == DateTime.now().year;
                                        return SizedBox(
                                          width: cellWidth,
                                          height: cellHeight,
                                          child: Center(
                                            child: dayNum < 1 || dayNum > daysInMonth
                                                ? const SizedBox.shrink()
                                                : Container(
                                                    width: cellWidth * 0.6,
                                                    height: cellHeight * 0.6,
                                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isToday
                                                            ? Colors.blueAccent
                                                            : Colors.transparent),
                                                    alignment: Alignment.center,
                                                    child: Text('$dayNum',
                                                        style: TextStyle(
                                                            fontSize: 15,
                                                            color: isToday
                                                                ? Colors.white
                                                                : Colors.black,
                                                            fontWeight: FontWeight.normal)),
                                                  ),
                                          ),
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          child: Column(
                            children: [
                              Row(
                                children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                                    .map((d) => Expanded(
                                        child: Center(
                                            child: Text(d,
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600)))))
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Table(
                                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                    children: [
                                      ...List.generate(
                                        ((DateUtils.getDaysInMonth(_displayYear, _displayMonth) + DateTime(_displayYear, _displayMonth, 1).weekday - 1) / 7).ceil(),
                                        (week) {
                                          final firstDay = DateTime(_displayYear, _displayMonth, 1);
                                          final daysInMonth = DateUtils.getDaysInMonth(_displayYear, _displayMonth);
                                          final firstWeekday = firstDay.weekday % 7; // Convert to 0-based index (0 = Sunday)
                                          return TableRow(
                                            children: List.generate(7, (weekday) {
                                              final dayNum = week * 7 + weekday - firstWeekday + 1;
                                              final isToday = dayNum == DateTime.now().day &&
                                                  _displayMonth == DateTime.now().month &&
                                                  _displayYear == DateTime.now().year;
                                              return Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                                child: Center(
                                                  child: dayNum < 1 || dayNum > daysInMonth
                                                      ? const SizedBox.shrink()
                                                      : Container(
                                                          width: 40,
                                                          height: 40,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: isToday
                                                                  ? Colors.blueAccent
                                                                  : Colors.transparent),
                                                          alignment: Alignment.center,
                                                          child: Text('$dayNum',
                                                              style: TextStyle(
                                                                  fontSize: 15,
                                                                  color: isToday
                                                                      ? Colors.white
                                                                      : Colors.black,
                                                                  fontWeight: FontWeight.normal)),
                                                        ),
                                                ),
                                              );
                                            }),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_displayYear, _displayMonth, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_displayYear, _displayMonth);
    final int numWeeks = (((daysInMonth + firstDay.weekday - 2) / 7).ceil()).clamp(5, 6); // Always at least 5, max 6
    final double cardHeight = 130;
    final double cardSpacing = 16;
    final double lowerPanelHeight = 140.0 + numWeeks * 64.0; // More space for calendar panel
    final Color appBarColor = const Color(0xFF23225C);
    final Color appBarTextColor = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 1),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('Dashboard',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(DateFormat.EEEE().add_jm().format(_now),
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(DashboardFunctions.getGreeting(_now), style: const TextStyle(fontSize: 18)),
                ],
              ),
              const SizedBox(width: 1),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: cardHeight,
                  child: StatCard(
                    title: 'USERS',
                    value: _userCount.toString(),
                    onTap: () => widget.onSelectPage(1),
                    imagePath: 'lib/assets/images/copartner-container-summary.png',
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: cardHeight,
                  child: StatCard(
                    title: 'SUPPORT TICKETS',
                    value: _ticketCount.toString(),
                    onTap: () => widget.onSelectPage(4),
                    imagePath: 'lib/assets/images/copartner-container-summary.png',
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  height: cardHeight,
                  child: StatCard(
                    title: 'DOCUMENTS',
                    value: _docCount.toString(),
                    onTap: () => widget.onSelectPage(3),
                    imagePath: 'lib/assets/images/copartner-container-summary.png',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              children: [
                // Calendar Panel
                Expanded(
                  flex: 11,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsive calendar panel
                      return Container(
                        margin: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            // AppBar-like header
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: appBarColor,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Left: Previous button
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: IconButton(
                                      onPressed: _prevMonth,
                                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                                    ),
                                  ),
                                  // Center: Month/Year
                                  Center(
                                    child: Text(
                                      DateFormat.yMMMM().format(DateTime(_displayYear, _displayMonth)),
                                      style: TextStyle(
                                        color: appBarTextColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                      ),
                                    ),
                                  ),
                                  // Right: Next and Expand buttons
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: _nextMonth,
                                          icon: const Icon(Icons.arrow_forward_ios, color: Colors.white),
                                        ),
                                        IconButton(
                                          onPressed: _showCalendarDialog,
                                          icon: const Icon(Icons.open_in_full, color: Color(0xFF6EBEFF)),
                                          tooltip: 'Maximize',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Stack(
                                children: [
                                  Column(
                                    children: [
                                      Row(
                                        children: ['Sun','Mon','Tue','Wed','Thu','Fri','Sat']
                                            .map((d) => Expanded(
                                                child: Center(
                                                    child: Text(d,
                                                        style: const TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.w600)))))
                                            .toList(),
                                      ),
                                      const SizedBox(height: 12),
                                      Expanded(
                                        child: SingleChildScrollView(
                                          child: Table(
                                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                            children: [
                                              ...List.generate(
                                                ((DateUtils.getDaysInMonth(_displayYear, _displayMonth) + DateTime(_displayYear, _displayMonth, 1).weekday - 1) / 7).ceil(),
                                                (week) {
                                                  final firstDay = DateTime(_displayYear, _displayMonth, 1);
                                                  final daysInMonth = DateUtils.getDaysInMonth(_displayYear, _displayMonth);
                                                  final firstWeekday = firstDay.weekday % 7; // Convert to 0-based index (0 = Sunday)
                                                  return TableRow(
                                                    children: List.generate(7, (weekday) {
                                                      final dayNum = week * 7 + weekday - firstWeekday + 1;
                                                      final isToday = dayNum == DateTime.now().day &&
                                                          _displayMonth == DateTime.now().month &&
                                                          _displayYear == DateTime.now().year;
                                                      return Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                                                        child: Center(
                                                          child: dayNum < 1 || dayNum > daysInMonth
                                                              ? const SizedBox.shrink()
                                                              : Container(
                                                                  width: 40,
                                                                  height: 40,
                                                                  decoration: BoxDecoration(
                                                                      shape: BoxShape.circle,
                                                                      color: isToday
                                                                          ? Colors.blueAccent
                                                                          : Colors.transparent),
                                                                  alignment: Alignment.center,
                                                                  child: Text('$dayNum',
                                                                      style: TextStyle(
                                                                          fontSize: 15,
                                                                          color: isToday
                                                                              ? Colors.white
                                                                              : Colors.black,
                                                                          fontWeight: FontWeight.normal)),
                                                                ),
                                                        ),
                                                      );
                                                    }),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Activity Log Panel
                Expanded(
                  flex: 13,
                  child: Container(
                    height: lowerPanelHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // AppBar-like header
                        Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: appBarColor,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'Activity Log',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        // --- White space content: Recent Summary and Tip ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Recent Summary
                              Row(
                                children: [
                                  const Icon(Icons.trending_up, color: Colors.deepPurple, size: 22),
                                  const SizedBox(width: 6),
                                  Text('${_todayNewTickets} new activity log/s today', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.deepPurple[700])),
                                ],
                              ),
                              // Tip of the Day
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 22),
                                  const SizedBox(width: 6),
                                  Text('Tip: Click "More Details" for full logs.', style: TextStyle(fontWeight: FontWeight.w500, color: Colors.amber[900])),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 16),
                                Expanded(
                                  child: ListView.separated(
                                    itemCount: _latestLogs.length,
                                    separatorBuilder: (context, i) => const SizedBox(height: 16),
                                    itemBuilder: (c, i) {
                                      final e = _latestLogs[i];
                                      final email = e['email'] ?? '-';
                                      final action = e['action'] ?? '-';
                                      final createdAt = e['created_at'];
                                      String formattedDate = '-';
                                      try {
                                        final dt = DateTime.parse(createdAt);
                                        formattedDate = DateFormat('EEEE, MMMM d, y').format(dt) +
                                            ' at ' + DateFormat('h:mm a').format(dt);
                                      } catch (_) {
                                        formattedDate = createdAt ?? '-';
                                      }
                                      return ListTile(
                                        dense: true,
                                        visualDensity: const VisualDensity(vertical: -2),
                                        leading: CircleAvatar(
                                          backgroundColor: DashboardFunctions.getActivityColor(action).withOpacity(0.15),
                                          child: Icon(DashboardFunctions.getActivityIcon(action), color: DashboardFunctions.getActivityColor(action)),
                                        ),
                                        title: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(color: Colors.black),
                                            children: [
                                              TextSpan(
                                                text: email,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              const TextSpan(text: ' · '),
                                              TextSpan(text: action),
                                            ],
                                          ),
                                        ),
                                        subtitle: Text(formattedDate),
                                      );
                                    },
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: MouseRegion(
                                    onEnter: (_) => setState(() => _moreDetailsHovering = true),
                                    onExit: (_) => setState(() => _moreDetailsHovering = false),
                                    child: TextButton(
                                      onPressed: _showAllLogs,
                                      child: Text(
                                        'More Details',
                                        style: TextStyle(
                                          color: _moreDetailsHovering ? Color(0xFF489CFD) : Color(0xFF6C63FF),
                                        ),
                                      ),
                                    ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({Key? key}) : super(key: key);
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  int? _selectedSidebarIndex = 0; // 0 = first nav, 1 = second, ..., -1 = admin, null = none selected
  bool _isSidebarOpen = true;
  Timer? _sessionTimer;
  int? _hoveredIndex;

  late final List<Widget> _pages;
  final List<String> _titles = ['Dashboard','Users','Issues & Concerns','Documents','Support Tickets'];
  final List<IconData> _icons = [Icons.dashboard,Icons.person,Icons.help_outline,Icons.description,Icons.support_agent];

  // Add a key for the admin section's popup menu
  final GlobalKey _adminMenuKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _pages = [
      DashboardPage(onSelectPage: (i) {
        setState(() => _selectedIndex = i);
        _startSessionTimer();
      }),
      const UserManagementPage(),
      const FaqsManagementPage(),
      const DocsManagementPage(),
      SupportTicketPage(),
    ];
    _startSessionTimer();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 15), () {
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => LoginScreen()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: LayoutBuilder(builder: (c, constraints) {
        if (constraints.maxWidth < 600) {
          return Scaffold(
            drawer: _buildSidebar(),
            body:
                GestureDetector(onTap: _startSessionTimer, child: _pages[_selectedIndex]),
          );
        }
        return Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _isSidebarOpen ? 250 : 0,
                child: _isSidebarOpen ? _buildSidebar() : null,
              ),
              Expanded(
                child:
                    GestureDetector(onTap: _startSessionTimer, child: _pages[_selectedIndex]),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: const Color(0xFF131440),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Image.asset('lib/assets/images/copartner-withname.png', height: 150),
          const SizedBox(height: 50),
          ...List.generate(_titles.length, (i) => _buildNavItem(i)),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _hoveredIndex = -1),
                    onExit: (_) => setState(() => _hoveredIndex = null),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_selectedSidebarIndex == -1) {
                            _selectedSidebarIndex = null;
                          } else {
                            _selectedSidebarIndex = -1;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        key: _adminMenuKey,
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _hoveredIndex == -1 || _selectedSidebarIndex == -1 ? const Color(0xFF23225C) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        margin: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: _selectedSidebarIndex == -1 ? 6 : 0,
                              height: 40,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _selectedSidebarIndex == -1 ? Colors.yellow : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const Icon(Icons.person, color: Colors.white, size: 24),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'admin',
                                style: TextStyle(fontSize: 15, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.arrow_right, color: Colors.white, size: 32),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Logout button beside admin section
                if (_selectedSidebarIndex == -1)
                  Container(
                    margin: const EdgeInsets.only(left: 4, right: 10),
                    constraints: const BoxConstraints(maxWidth: 100),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      elevation: 2,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                              (route) => false,
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'Logout',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.logout, color: Colors.red, size: 16),
                            ],
                          ),
                        ),
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

  Widget _buildNavItem(int index) {
    final isSelected = _selectedSidebarIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
            _selectedSidebarIndex = index;
          });
          _startSessionTimer();
        },
        child: Container(
          color: isSelected
              ? const Color(0xFF393A6E)
              : (_hoveredIndex == index ? const Color(0xFF23225C) : Colors.transparent),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 6 : 0,
                height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.yellow : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: ListTile(
                  leading: Icon(_icons[index], color: Colors.white),
                  title: Text(_titles[index], style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatCard extends StatefulWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final String imagePath;
  const StatCard({
    required this.title,
    required this.value,
    required this.onTap,
    required this.imagePath,
    Key? key,
  }) : super(key: key);

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _hovering = false;
  bool _detailsHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 130,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: AssetImage(widget.imagePath),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                // --- Blur dark overlay (not affected by padding) ---
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                      ),
                    ),
                  ),
                ),
                // --- Content with padding above the overlay ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            )),
                        const SizedBox(height: 8),
                        Text(widget.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            )),
                        const SizedBox(height: 6),
                        MouseRegion(
                          onEnter: (_) => setState(() => _detailsHovering = true),
                          onExit: (_) => setState(() => _detailsHovering = false),
                          child: Text(
                            'More Details',
                            style: TextStyle(
                              color: _detailsHovering ? Colors.amber : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              decoration: TextDecoration.underline,
                              decorationColor: _detailsHovering ? Colors.amber : Colors.white,
                            ),
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
    );
  }
}
