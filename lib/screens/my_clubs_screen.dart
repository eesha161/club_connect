import 'package:club_connect/widgets/common_app_bar.dart'; // NEW
// This screen shows just the clubs you are a member of.
import 'package:club_connect/models/club.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/screens/admin/club_management_screen.dart';
import 'package:club_connect/screens/club_details_screen.dart';
import 'package:club_connect/screens/profile_screen.dart'; // Import ProfileScreen
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/screens/inbox_screen.dart'; // NEW
import 'package:club_connect/services/inbox_service.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyClubsScreen extends StatefulWidget {
  final int initialIndex;

  const MyClubsScreen({super.key, this.initialIndex = 0});

  @override
  State<MyClubsScreen> createState() => _MyClubsScreenState();
}

class _MyClubsScreenState extends State<MyClubsScreen> {
  final UserService _userService = UserService();
  final ClubService _clubService = ClubService();
  
  late Set<int> _viewSelection; // 0: Joined, 1: Created
  Future<List<Club>>? _clubsFuture;

  @override
  void initState() {
    super.initState();
    _viewSelection = {widget.initialIndex};
    _loadClubs();
  }

  void _loadClubs() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (_viewSelection.first == 0) {
        // Load Joined Clubs
        _clubsFuture = _userService.getProfile(user.uid).then((profile) {
          if (profile != null && profile.joinedClubIds.isNotEmpty) {
            return _clubService.getClubsByIds(profile.joinedClubIds).then((clubs) {
               // Filter out clubs where I am admin (they belong in 'Created')
               return clubs.where((c) => !c.adminIds.contains(user.uid)).toList();
            });
          }
          return [];
        });
      } else {
        // Load Created/Managed Clubs
        _clubsFuture = _clubService.getClubsByAdmin(user.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'My Clubs',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  icon: Icon(Icons.group),
                  label: Text('Joined'),
                ),
                ButtonSegment(
                  value: 1,
                  icon: Icon(Icons.security),
                  label: Text('Created'),
                ),
              ],
              selected: _viewSelection,
              onSelectionChanged: (Set<int> newSelection) {
                setState(() {
                  _viewSelection = newSelection;
                  _loadClubs();
                });
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Club>>(
        future: _clubsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final clubs = snapshot.data ?? [];

          if (clubs.isEmpty) {
             return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _viewSelection.first == 0 ? Icons.group_off : Icons.domain_disabled, 
                    size: 64, 
                    color: Colors.grey
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _viewSelection.first == 0 
                      ? 'You haven\'t joined any clubs yet.' 
                      : 'You haven\'t created any clubs yet.',
                    style: const TextStyle(fontSize: 18, color: Colors.grey)
                  ),
                  const SizedBox(height: 8),
                  if (_viewSelection.first == 0)
                    const Text('Go to "Find Clubs" to join one!', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              final currentUserId = FirebaseAuth.instance.currentUser?.uid;
              // Check if user is admin of this specific club
              final isClubAdmin = currentUserId != null && club.adminIds.contains(currentUserId);
              
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          club.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(Icons.group),
                          ),
                        ),
                      ),
                      title: Text(
                        club.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text('${club.memberCount} Members'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ClubDetailsScreen(club: club),
                          ),
                        ).then((_) {
                          _loadClubs();
                        });
                      },
                    ),
                    // Show Manage button if user is admin of this club
                    if (isClubAdmin)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.settings),
                            label: const Text('Manage Club'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => ClubManagementScreen(club: club),
                                ),
                              ).then((_) => _loadClubs());
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
