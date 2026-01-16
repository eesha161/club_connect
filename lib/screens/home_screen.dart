import 'package:club_connect/screens/club_list_screen.dart';
import 'package:club_connect/screens/event_list_screen.dart';
import 'package:club_connect/screens/impact_dashboard_screen.dart'; // NEW
import 'package:club_connect/screens/my_clubs_screen.dart';

// import 'package:club_connect/screens/admin/admin_actions_screen.dart'; // REMOVED
import 'package:club_connect/screens/badges_screen.dart'; // NEW
// This screen is the main dashboard where you can see your profile and quick stats.
import 'package:club_connect/screens/profile_screen.dart'; // Needed for nav
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final bool launchProfile; // NEW param
  const HomeScreen({super.key, this.launchProfile = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    const ImpactDashboardScreen(), // Index 0: Home (Impact)
    const ClubListScreen(),        // Index 1: Find Clubs
    const MyClubsScreen(),         // Index 2: My Clubs
    const EventListScreen(),       // Index 3: Events
    const BadgesScreen(),          // Index 4: Badges
  ];

  @override
  void initState() {
    super.initState();
    // If requested, launch profile screen immediately after build
    if (widget.launchProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Find Clubs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'My Clubs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.military_tech),
            label: 'Badges',
          ),
        ],
      ),
    );
  }
}
