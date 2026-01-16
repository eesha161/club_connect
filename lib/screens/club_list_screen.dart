import 'package:club_connect/models/club.dart';
import 'package:club_connect/widgets/common_app_bar.dart';
import 'package:club_connect/models/user_profile.dart';
// This screen lists all the clubs. You can filter them by city or state.
import 'package:club_connect/screens/club_details_screen.dart';
import 'package:club_connect/widgets/club_image.dart';
import 'package:club_connect/screens/form_submission_screen.dart';
import 'package:club_connect/screens/profile_screen.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/widgets/club_card_skeleton.dart';
import 'package:club_connect/widgets/fade_in_animation.dart';
import 'package:club_connect/widgets/loading_overlay.dart';
import 'package:club_connect/screens/inbox_screen.dart'; 
import 'package:club_connect/services/inbox_service.dart'; 
import 'package:club_connect/widgets/empty_state_widget.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClubListScreen extends StatefulWidget {
  const ClubListScreen({super.key});

  @override
  State<ClubListScreen> createState() => _ClubListScreenState();
}

class _ClubListScreenState extends State<ClubListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- JOIN BY CODE LOGIC ---
  void _showJoinByCodeDialog() {
    final _codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_open, size: 40, color: Colors.green[700]),
              ),
              const SizedBox(height: 16),
              // Title
              Text(
                'Join Private Club',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
              ),
              const SizedBox(height: 8),
              // Subtitle
              Text(
                'Enter the club code to join',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Input Field
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 2),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.vpn_key, color: Colors.green[600]),
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final code = _codeController.text.trim();
                        if (code.isEmpty) return;
                        Navigator.pop(ctx);
                        await _processJoinByCode(code);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Join'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processJoinByCode(String code) async {
    setState(() {}); // trigger rebuild/loading if needed

    try {
      final club = await ClubService().getClubByCode(code);
      if (club == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid Code')));
        return;
      }
      
      // Check for Join Form
      if (club.joinForm != null && club.joinForm!.isEnabled) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => FormSubmissionScreen(
            title: 'Join ${club.name}',
            questions: club.joinForm!.questions,
            onSubmit: (answers) async {
              Navigator.pop(context); // Close Form
              await _joinClub(club, answers: answers);
            },
          ),
        ));
      } else {
        await _joinClub(club);
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _joinClub(Club club, {Map<String, String>? answers}) async {
     try {
       final user = FirebaseAuth.instance.currentUser;
       if (user == null) return;
       
       await UserService().joinClub(user.uid, club.id, answers: answers);
       
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Joined ${club.name}!')));
         setState(() {}); 
       }
     } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Join failed: $e')));
     }
  }

  // --- SMART SORTING HELPER ---
  List<Widget> _buildCategorizedList(List<Club> clubs, UserProfile? profile) {
    if (profile == null) return _buildFlatClubList(clubs); // Fallback

    final cityClubs = <Club>[];
    final stateClubs = <Club>[];
    final otherClubs = <Club>[];

    for (var club in clubs) {
      bool matched = false;
      
      // 1. City Match (Highest Priority now)
      if (profile.city != null && club.city == profile.city) {
        cityClubs.add(club);
        matched = true;
      }
      // 2. State Match (Only if not city matched)
      else if (profile.state != null && club.state == profile.state) {
        stateClubs.add(club);
        matched = true;
      }

      if (!matched) {
        otherClubs.add(club);
      }
    }

    // Build the ListView Items
    final items = <Widget>[];

    if (cityClubs.isNotEmpty) {
      items.add(_buildSectionHeader('In ${profile.city}', Icons.location_city));
      items.addAll(cityClubs.map((c) => _buildClubCard(c)));
    }

    if (stateClubs.isNotEmpty) {
      items.add(_buildSectionHeader('In ${profile.state}', Icons.map));
      items.addAll(stateClubs.map((c) => _buildClubCard(c)));
    }

    if (otherClubs.isNotEmpty) {
      final title = items.isEmpty ? 'All Clubs' : 'More Clubs';
      items.add(_buildSectionHeader(title, Icons.public));
      items.addAll(otherClubs.map((c) => _buildClubCard(c)));
    }

    return items;
  }

  List<Widget> _buildFlatClubList(List<Club> clubs) {
    return clubs.map((c) => _buildClubCard(c)).toList();
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubCard(Club club) {
    return FadeInAnimation(
      delay: const Duration(milliseconds: 100), // static delay for list items
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ClubDetailsScreen(club: club),
              ),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Hero(
                  tag: 'club-${club.id}',
                  child: ClubImage(
                    imageUrl: club.imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            club.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (club.memberCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${club.memberCount} Members',
                              style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Location Badge
                    if (club.city != null || club.schoolName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              club.schoolName ?? '${club.city}, ${club.state}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      club.description,
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: club.tags.take(3).map((tag) => Chip(
                        label: Text(tag, style: const TextStyle(fontSize: 10)),
                        backgroundColor: Colors.green[100],
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      )).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Find Clubs',
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key),
            tooltip: 'Join with Code',
            onPressed: _showJoinByCodeDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, tags, or location...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() { _searchController.clear(); _searchQuery = ''; }))
                  : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          
          Expanded(
            child: StreamBuilder<UserProfile?>(
              stream: user != null ? UserService().getProfileStream(user.uid) : Stream.value(null),
              builder: (context, profileSnapshot) {
                // We load clubs regardless of profile, but profile helps sorting
                return StreamBuilder<List<Club>>(
                  stream: ClubService().getClubs(),
                  builder: (context, clubsSnapshot) {
                    if (clubsSnapshot.connectionState == ConnectionState.waiting) {
                      return ListView.builder(itemCount: 3, itemBuilder: (_, __) => const ClubCardSkeleton());
                    }
                    if (clubsSnapshot.hasError) {
                      return EmptyStateWidget(
                        title: 'Error', message: 'Could not load clubs: ${clubsSnapshot.error}', icon: Icons.error,
                      );
                    }

                    var clubs = clubsSnapshot.data ?? [];

                    // Filter Logic
                    clubs = clubs.where((club) {
                       if (club.isPrivate) return false;
                       if (_searchQuery.isEmpty) return true;
                       
                       final query = _searchQuery;
                       // Determine match
                       bool nameMatch = club.name.toLowerCase().contains(query);
                       bool tagMatch = club.tags.any((t) => t.toLowerCase().contains(query));
                       bool locMatch = (club.city?.toLowerCase().contains(query) ?? false) || 
                                       (club.schoolName?.toLowerCase().contains(query) ?? false);
                                       
                       return nameMatch || tagMatch || locMatch;
                    }).toList();

                    if (clubs.isEmpty) {
                       return EmptyStateWidget(
                         title: 'No Clubs Found', 
                         message: 'Try adjusting your search filters.', 
                         icon: Icons.search_off,
                       );
                    }

                    // Build List items
                    // Use Profile for Smart Sorting IF no search query is active (Standard Discovery Mode)
                    // If searching, typically users want simple relevance to the query.
                    // But we can still group them if we want.
                    // Let's group them always for better UX.
                    List<Widget> listItems;
                    if (profileSnapshot.hasData && _searchQuery.isEmpty) {
                       listItems = _buildCategorizedList(clubs, profileSnapshot.data);
                    } else {
                       listItems = _buildFlatClubList(clubs);
                    }

                    return RefreshIndicator(
                      onRefresh: () async { await Future.delayed(const Duration(milliseconds: 500)); setState((){}); },
                      child: ListView.builder(
                        itemCount: listItems.length,
                        itemBuilder: (context, index) => listItems[index],
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
