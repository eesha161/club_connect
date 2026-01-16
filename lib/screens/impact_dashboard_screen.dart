import 'package:club_connect/models/attendance.dart';
import 'package:club_connect/widgets/common_app_bar.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/screens/my_clubs_screen.dart';
import 'package:club_connect/screens/event_list_screen.dart';
import 'package:club_connect/screens/profile_screen.dart';
import 'package:club_connect/services/attendance_service.dart';
import 'package:club_connect/screens/inbox_screen.dart';
import 'package:club_connect/services/inbox_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:club_connect/models/club.dart';
import 'package:club_connect/models/event.dart';
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/screens/admin/create_club_screen.dart';
import 'package:club_connect/screens/admin/create_event_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:club_connect/services/volunteer_service.dart';
// This screen shows charts of your volunteer hours and impact.
import 'package:club_connect/screens/volunteer_history_screen.dart';
import 'package:google_fonts/google_fonts.dart'; // NEW

class ImpactDashboardScreen extends StatefulWidget {
  const ImpactDashboardScreen({super.key});

  @override
  State<ImpactDashboardScreen> createState() => _ImpactDashboardScreenState();
}

class _ImpactDashboardScreenState extends State<ImpactDashboardScreen> {
  // Tutorial Keys
  final GlobalKey _inboxKey = GlobalKey();
  final GlobalKey _createClubKey = GlobalKey();
  final GlobalKey _createEventKey = GlobalKey();
  final GlobalKey _statsKey = GlobalKey();
  
  TutorialCoachMark? tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('tutorial_seen') ?? false;

    if (!seen && mounted) {
      // Small delay to ensure UI is built
      Future.delayed(const Duration(seconds: 1), () {
        _showTutorial();
      });
    }
  }

  void _showTutorial() {
    tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('tutorial_seen', true);
      },
      onClickTarget: (target) {
        // Continue
      },
      onSkip: () {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('tutorial_seen', true);
        });
        return true;
      },
    )..show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "inbox",
        keyTarget: _inboxKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Global Inbox",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(
                        "All your messages, notifications, and announcements are now here. Access them from any screen.",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "create_actions",
        keyTarget: _createClubKey, // Focusing on Create Club, but describing both
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Quick Actions",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Start your own community or organize an event directly from your dashboard.",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "stats",
        keyTarget: _statsKey,
        alignSkip: Alignment.bottomRight,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Impact Stats",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 10.0),
                      child: Text(
                        "Track your participation and engagement here. Watch these numbers grow as you join clubs and attend events!",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    ];
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: const CommonAppBar(
        title: 'Impact Dashboard',
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Removed (User Request)
            // Header moved from AppBar (Styled)
            // Header Removed (User Request)
            // Header moved from AppBar (Styled)
            const SizedBox(height: 8),
            // GAP REDUCED: Removed extra SizedBox(height: 16)

            // Stats Cards
            Padding(
              padding: const EdgeInsets.all(16),
              child: StreamBuilder<List<Attendance>>(
                stream: AttendanceService().getUserAttendance(user.uid),
                builder: (context, attendanceSnapshot) {
                  // Changed to StreamBuilder for real-time profile updates (e.g. club count)
                  return StreamBuilder<UserProfile?>(
                    stream: UserService().getProfileStream(user.uid),
                    builder: (context, profileSnapshot) {
                      final attendance = attendanceSnapshot.data ?? [];
                      final profile = profileSnapshot.data;
                      final clubCount = profile?.joinedClubIds.length ?? 0;

                      return Column(
                        children: [


                          // Management Overview
                              // Removed invalid children: [ line
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.green.shade50, Colors.white],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.1),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.admin_panel_settings, color: Colors.green[800]),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Management Overview',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[900],
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    // QUICK ACTIONS ROW (New)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            key: _createClubKey,
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (context) => const CreateClubScreen()),
                                              );
                                            },
                                            icon: const Icon(Icons.add_business, size: 20),
                                            label: const Text('Create Club'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green[700],
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            key: _createEventKey,
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(builder: (context) => const CreateEventScreen()),
                                              );
                                            },
                                            icon: const Icon(Icons.event_note, size: 20),
                                            label: const Text('Create Event'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal[600],
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(vertical: 12),
                                              elevation: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    
                                    Row(
                                      children: [
                                        Expanded(
                                          child: StreamBuilder<List<Club>>(
                                            stream: ClubService().getClubs(),
                                            builder: (context, snapshot) {
                                              final managedClubs = snapshot.data?.where((c) => c.adminIds.contains(user.uid)).length ?? 0;
                                              return InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (context) => const MyClubsScreen(initialIndex: 1)),
                                                  );
                                                },
                                                child: _buildStatItem(
                                                  context,
                                                  'Managed Clubs',
                                                  managedClubs.toString(),
                                                  Icons.security,
                                                  Colors.green[700]!,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        Container(width: 1, height: 40, color: Colors.grey[300]), // Divider
                                        Expanded(
                                          child: StreamBuilder<List<Event>>(
                                            stream: EventService().getAllEvents(),
                                            builder: (context, snapshot) {
                                              final count = snapshot.data?.length ?? 0;
                                              return InkWell(
                                                onTap: () {
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(builder: (context) => const EventListScreen()),
                                                  );
                                                },
                                                child: _buildStatItem(
                                                  context,
                                                  'Total Events',
                                                  count.toString(),
                                                  Icons.calendar_today,
                                                  Colors.teal[700]!,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                                const SizedBox(height: 24),
                            // Removed invalid ], line

                          // Stats Row
                          Row(
                            key: _statsKey,
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Events Attended',
                                  attendance.length.toString(),
                                  Icons.event,
                                  Colors.lightGreen[700]!,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Clubs Joined',
                                  clubCount.toString(),
                                  Icons.groups,
                                  Colors.green[600]!,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Hours Invested',
                                  (attendance.length * 2).toString(),
                                  Icons.access_time,
                                  Colors.teal[500]!,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  context,
                                  'Badges Earned',
                                  profile?.badges.length.toString() ?? '0',
                                  Icons.military_tech,
                                  Colors.lime[800]!,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Activity Chart
                          if (attendance.isNotEmpty) ...[
                            _buildActivityChart(context, attendance),
                            const SizedBox(height: 24),
                          ],

                          // VOLUNTEER HOURS CARD (Moved)
                          FutureBuilder<double>(
                            future: VolunteerService().getTotalVolunteerHours(user.uid),
                            builder: (context, hoursSnapshot) {
                              final hours = hoursSnapshot.data ?? 0.0;
                              return GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const VolunteerHistoryScreen()),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 24),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.green.shade800, Colors.green.shade600],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withValues(alpha: 0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.volunteer_activism, color: Colors.white, size: 28),
                                      ),
                                      const SizedBox(width: 16),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Volunteer Impact',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                hours.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 28,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Padding(
                                                padding: EdgeInsets.only(bottom: 4.0),
                                                child: Text(
                                                  'hours',
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Recent Activity
                          _buildRecentActivity(context, attendance),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActivityChart(BuildContext context, List<Attendance> attendance) {
    // Group by month
    final monthCounts = <int, int>{};
    for (var record in attendance) {
      final month = record.checkInTime.month;
      monthCounts[month] = (monthCounts[month] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity This Year',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (monthCounts.values.isEmpty ? 10 : monthCounts.values.reduce((a, b) => a > b ? a : b)).toDouble() + 2,
                barGroups: List.generate(12, (index) {
                  final month = index + 1;
                  final count = monthCounts[month] ?? 0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: Colors.teal,
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                        return Text(
                          months[value.toInt()],
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, List<Attendance> attendance) {
    final recent = attendance.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (recent.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(
                      'No activity yet',
                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Attend events to see your history here',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          else
            ...recent.map((record) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.green.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  ),
                  title: const Text('Event Check-in', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    '${record.checkInTime.month}/${record.checkInTime.day}/${record.checkInTime.year}',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                )),
        ],
      ),
    );
  }
}
