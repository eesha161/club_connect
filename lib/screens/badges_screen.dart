// This screen shows all the cool badges you've earned.
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/services/attendance_service.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/screens/inbox_screen.dart'; // NEW
import 'package:club_connect/screens/profile_screen.dart'; // NEW
import 'package:club_connect/services/inbox_service.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:club_connect/widgets/common_app_bar.dart';
import 'package:google_fonts/google_fonts.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _userService = UserService();
  final _clubService = ClubService();
  final _attendanceService = AttendanceService();
  final _auth = FirebaseAuth.instance;

  // Badge Definitions (30+)
  final List<Map<String, dynamic>> _allBadges = [
    // --- SOCIAL CATEGORY ---
    {'id': 'newcomer', 'name': 'Newcomer', 'description': 'Welcome to ClubConnect!', 'icon': Icons.waving_hand, 'color': Colors.lightGreen},
    {'id': 'member', 'name': 'Club Member', 'description': 'Joined your first club', 'icon': Icons.card_membership, 'color': Colors.green[600]},
    {'id': 'socialite', 'name': 'Socialite', 'description': 'Joined 3 clubs', 'icon': Icons.groups, 'color': Colors.teal[400]},
    {'id': 'connector', 'name': 'Connector', 'description': 'Followed 5 users', 'icon': Icons.person_add, 'color': Colors.teal[600]},
    {'id': 'friend', 'name': 'Friend', 'description': 'Followed 10 users', 'icon': Icons.people, 'color': Colors.green[700]},
    {'id': 'networker', 'name': 'Networker', 'description': 'Joined 5 clubs', 'icon': Icons.hub, 'color': Colors.green[800]},
    {'id': 'influencer', 'name': 'Influencer', 'description': 'Have 5 followers', 'icon': Icons.star, 'color': Colors.lightGreen[700]},
    {'id': 'community', 'name': 'Pillar', 'description': 'Joined 10 clubs', 'icon': Icons.location_city, 'color': Colors.green[900]},
    {'id': 'recruiter', 'name': 'Recruiter', 'description': 'Shared a club link', 'icon': Icons.share, 'color': Colors.teal[300]},
    {'id': 'chatty', 'name': 'Chatty', 'description': 'Posted 5 comments', 'icon': Icons.forum, 'color': Colors.lightGreen[600]},

    // --- LEADER CATEGORY ---
    {'id': 'organizer', 'name': 'Organizer', 'description': 'Admin of a club', 'icon': Icons.security, 'color': Colors.green[700]},
    {'id': 'founder', 'name': 'Founder', 'description': 'Created a new club', 'icon': Icons.add_business, 'color': Colors.teal[700]},
    {'id': 'planner', 'name': 'Planner', 'description': 'Created an event', 'icon': Icons.calendar_today, 'color': Colors.green[600]},
    {'id': 'host', 'name': 'Host', 'description': 'Created 5 events', 'icon': Icons.campaign, 'color': Colors.teal[800]},
    {'id': 'executive', 'name': 'Executive', 'description': 'Admin of 3 clubs', 'icon': Icons.gavel, 'color': Colors.green[900]},
    {'id': 'visionary', 'name': 'Visionary', 'description': 'Created 3 clubs', 'icon': Icons.lightbulb, 'color': Colors.lime[700]},
    
    // --- EVENT CATEGORY ---
    {'id': 'attendee', 'name': 'Attendee', 'description': 'Attended 1 event', 'icon': Icons.event_available, 'color': Colors.green[500]},
    {'id': 'regular', 'name': 'Regular', 'description': 'Attended 5 events', 'icon': Icons.repeat, 'color': Colors.lightGreen[600]},
    {'id': 'super_fan', 'name': 'Super Fan', 'description': 'Attended 10 events', 'icon': Icons.favorite, 'color': Colors.green[700]},
    {'id': 'dedicated', 'name': 'Dedicated', 'description': 'Attended 20 events', 'icon': Icons.verified, 'color': Colors.teal[600]},
    {'id': 'early_bird', 'name': 'Early Bird', 'description': 'RSVP within 1 hour', 'icon': Icons.alarm, 'color': Colors.lightGreen[700]},
    {'id': 'explorer', 'name': 'Explorer', 'description': 'Attended events in 3 different locations', 'icon': Icons.map, 'color': Colors.teal[500]},
    {'id': 'marathon', 'name': 'Marathon', 'description': 'Attended 3 events in a week', 'icon': Icons.run_circle, 'color': Colors.green[600]},
    
    // --- SPECIAL CATEGORY ---
    {'id': 'beta_tester', 'name': 'Beta', 'description': 'Joined during beta', 'icon': Icons.bug_report, 'color': Colors.green[400]},
    {'id': 'streak_3', 'name': 'On Fire', 'description': '3 week attendance streak', 'icon': Icons.local_fire_department, 'color': Colors.lime[800]},
    {'id': 'night_owl', 'name': 'Night Owl', 'description': 'Attended an event after 8 PM', 'icon': Icons.nights_stay, 'color': Colors.teal[700]},
    {'id': 'weekend', 'name': 'Weekender', 'description': 'Attended a weekend event', 'icon': Icons.weekend, 'color': Colors.lightGreen[500]},
    {'id': 'scholar', 'name': 'Scholar', 'description': 'Read 5 weekly reports', 'icon': Icons.menu_book, 'color': Colors.green[700]},
    {'id': 'volunteer', 'name': 'Volunteer', 'description': 'Checked in early', 'icon': Icons.handshake, 'color': Colors.teal[900]},
    {'id': 'legend', 'name': 'Legend', 'description': 'Earned 20 badges', 'icon': Icons.military_tech, 'color': Colors.lime[900]},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: 'My Achievements',
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _calculateBadges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(child: Text("Error loading badges: ${snapshot.error}"));
          }

          final earnedBadges = snapshot.data?['earned'] as List<String>? ?? [];
          final newBadges = snapshot.data?['new'] as List<String>? ?? [];
          final eventCount = snapshot.data?['eventCount'] as int? ?? 0;
          final hours = eventCount * 2;

          // Show dialog if new badges earned (only once)
          if (newBadges.isNotEmpty) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("You earned ${newBadges.length} new badge(s)!"),
                  backgroundColor: Colors.green,
                ));
             });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ANALYTICS CARD
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Badges', '${earnedBadges.length}/${_allBadges.length}', Icons.military_tech, Colors.green[700]!),
                        _buildStatItem('Hours', '$hours+', Icons.history, Colors.teal[600]!),
                        _buildStatItem('Events', '$eventCount', Icons.event_available, Colors.lightGreen[700]!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Text(
                  'Collection',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap or hold a badge to see how to unlock it.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // BADGES GRID
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, // DENSE GRID (Smaller icons)
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _allBadges.length,
                  itemBuilder: (context, index) {
                    final badge = _allBadges[index];
                    final isEarned = earnedBadges.contains(badge['id']);

                    // Main Badge Widget
                    Widget badgeWidget = Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isEarned 
                                ? (badge['color'] as Color).withValues(alpha: 0.15) 
                                : Colors.grey[200],
                            border: isEarned ? Border.all(color: badge['color'], width: 1.5) : null,
                          ),
                          child: Icon(
                            badge['icon'],
                            size: 20, // Smaller icon
                            color: isEarned ? badge['color'] : Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badge['name'],
                          style: TextStyle(
                            fontSize: 9, // Small text
                            fontWeight: isEarned ? FontWeight.bold : FontWeight.normal,
                            color: isEarned ? Colors.black87 : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    );

                    // Wrap in Tooltip for "Hover/Tap" info
                    return Tooltip(
                      message: "${badge['name']}\n${badge['description']}",
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(color: Colors.white),
                      triggerMode: TooltipTriggerMode.tap, // Tap to see on mobile
                      child: Opacity(
                        opacity: isEarned ? 1.0 : 0.5,
                        child: badgeWidget,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Future<Map<String, dynamic>> _calculateBadges() async {
    final user = _auth.currentUser;
    if (user == null) return {'earned': <String>[], 'new': <String>[], 'eventCount': 0};

    // Fetch Data
    final profile = await _userService.getProfile(user.uid);
    if (profile == null) return {'earned': <String>[], 'new': <String>[], 'eventCount': 0};

    final clubs = await _clubService.getClubs().first; 
    final attendance = await _attendanceService.getUserAttendance(user.uid).first;

    final Set<String> earned = Set.from(profile.badges);
    final Set<String> newlyEarned = {};

    // --- CHECK LOGIC ---
    
    // BASIC
    _checkBadge(earned, newlyEarned, 'newcomer', true);
    _checkBadge(earned, newlyEarned, 'member', profile.joinedClubIds.isNotEmpty);
    _checkBadge(earned, newlyEarned, 'socialite', profile.joinedClubIds.length >= 3);
    _checkBadge(earned, newlyEarned, 'networker', profile.joinedClubIds.length >= 5);
    _checkBadge(earned, newlyEarned, 'community', profile.joinedClubIds.length >= 10);
    
    // ATTENDANCE
    final eventCount = attendance.length;
    _checkBadge(earned, newlyEarned, 'attendee', eventCount >= 1);
    _checkBadge(earned, newlyEarned, 'regular', eventCount >= 5);
    _checkBadge(earned, newlyEarned, 'super_fan', eventCount >= 10);
    _checkBadge(earned, newlyEarned, 'dedicated', eventCount >= 20);

    // LEADERSHIP
    final managedCount = clubs.where((c) => c.adminIds.contains(user.uid)).length;
    final createdCount = clubs.where((c) => c.adminIds.contains(user.uid)).length; // Uses adminIds
    
    _checkBadge(earned, newlyEarned, 'organizer', managedCount >= 1);
    _checkBadge(earned, newlyEarned, 'executive', managedCount >= 3);
    // For now assuming creator/founder logic if available, else skip or use admin logic
    _checkBadge(earned, newlyEarned, 'founder', createdCount >= 1); 

    // SOCIAL (Placeholder logic as we don't have follower counts in profile easily right now without fetching)
    // Assuming we added followers/following to UserProfile earlier
    final followers = profile.followers.length;
    final following = profile.following.length;

    _checkBadge(earned, newlyEarned, 'connector', following >= 5);
    _checkBadge(earned, newlyEarned, 'friend', following >= 10);
    _checkBadge(earned, newlyEarned, 'influencer', followers >= 5);

    // LEGEND
    if (earned.length >= 20) {
       _checkBadge(earned, newlyEarned, 'legend', true);
    }

    // Persist Updates
    if (newlyEarned.isNotEmpty) {
      await _userService.createOrUpdateProfile(profile.copyWith(badges: earned.toList()));
    }
    
    return {
      'earned': earned.toList(),
      'new': newlyEarned.toList(),
      'eventCount': eventCount,
    };
  }

  void _checkBadge(Set<String> earned, Set<String> newBadges, String id, bool condition) {
    if (condition && !earned.contains(id)) {
      earned.add(id);
      newBadges.add(id);
    }
  }
}


