// This screen shows all the info about a specific club. You can join, leave, or see events here.
import 'package:club_connect/models/club.dart';
import 'package:club_connect/models/event.dart';
import 'package:club_connect/models/user_profile.dart'; // Fixed missing import
import 'package:club_connect/models/announcement.dart';
import 'package:club_connect/screens/admin/club_management_screen.dart'; // NEW
import 'package:club_connect/screens/admin/create_announcement_screen.dart'; // NEW
import 'package:club_connect/screens/event_details_screen.dart'; // NEW
import 'package:club_connect/screens/profile_screen.dart'; // Add Import
import 'package:club_connect/services/announcement_service.dart';
import 'package:club_connect/services/club_service.dart'; // Add import
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/widgets/comment_section.dart'; // NEW
import 'package:club_connect/widgets/club_image.dart';
import 'package:club_connect/services/notification_service.dart'; // NEW
import 'package:club_connect/widgets/questionnaire_response_dialog.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:add_2_calendar/add_2_calendar.dart' as calendar;

/// This screen displays the full details of a single Club.
/// It expects a [Club] object to be passed in so it knows what data to show.
class ClubDetailsScreen extends StatefulWidget {
  final Club club;

  const ClubDetailsScreen({
    super.key,
    required this.club,
  });

  @override
  State<ClubDetailsScreen> createState() => _ClubDetailsScreenState();
}

class _ClubDetailsScreenState extends State<ClubDetailsScreen> {
  UserProfile? _userProfile;
  bool _isLoadingProfile = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await UserService().getProfile(user.uid);
      
      // Auto-Fix: If user is admin but not in joinedClubIds, fix it.
      if (profile != null && 
          widget.club.adminIds.contains(user.uid) && 
          !profile.joinedClubIds.contains(widget.club.id)) {
            
        await UserService().joinClub(user.uid, widget.club.id);
        // Refresh profile after fixing
        _fetchProfile();
        return; 
      }

      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoadingProfile = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Access widget.club since it's now stateful
    final club = widget.club; 

    return Scaffold(
      body: DefaultTabController(
        length: 5, // Increased to 5
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(club.name, style: const TextStyle(fontSize: 16)), // Small title when collapsed
                  background: Hero(
                    tag: 'club-${club.id}',
                    child: ClubImage(
                      imageUrl: club.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.share),
                    onPressed: () {
                      Share.share(
                        'Check out ${club.name} on ClubConnect!\n\n${club.description}\n\n#ClubConnect',
                      );
                    },
                  ),
                ],
              ),
              SliverPersistentHeader(
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    labelColor: Theme.of(context).primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Theme.of(context).primaryColor,
                    tabs: const [
                      Tab(text: 'About'),
                      Tab(text: 'News'),
                      Tab(text: 'Events'),
                      Tab(text: 'Chat'),
                      Tab(text: 'Members'), // New Tab
                    ],
                  ),
                ),
                pinned: true,
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildAboutTab(club),
              _buildNewsTab(club),
              _buildEventsTab(club),
              _buildChatTab(club),
              _buildMembersTab(club), // New content
            ],
          ),
        ),
      ),
      floatingActionButton: _isLoadingProfile 
          ? null 
          : (_userProfile != null && widget.club.adminIds.contains(FirebaseAuth.instance.currentUser?.uid)
                  // Owner View
              ? FloatingActionButton.extended(
                  onPressed: () {
                     // Navigate to Edit Club
                     Navigator.of(context).push(
                       MaterialPageRoute(
                         builder: (context) => ClubManagementScreen(club: widget.club),
                       ),
                     ).then((_) {
                       // Refresh club details when returning from management
                       // Since we pass the Club object, updating it might require re-fetching or using a Stream for Details.
                       // For now, setState to re-render if we modified the local object, but ideally we re-fetch.
                       setState(() {}); 
                     });
                  },
                  label: const Text('Manage Club'),
                  icon: const Icon(Icons.settings),
                )
              // Non-Owner View
              : Builder(
                  builder: (context) {
                    final isMember = _userProfile?.joinedClubIds.contains(widget.club.id) ?? false;
                     return FloatingActionButton.extended(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;

                        try {
                          if (isMember) {
                             // LEAVE CLUB
                             // 1. Check Leave Questionnaire
                             Map<String, String>? answers;
                             if (widget.club.leaveForm != null && widget.club.leaveForm!.isEnabled) {
                               final result = await showDialog<Map<String, String>>(
                                 context: context,
                                 builder: (context) => QuestionnaireResponseDialog(
                                   formMap: widget.club.leaveForm!.toMap(),
                                   title: 'Leave Questionnaire',
                                   submitLabel: 'Leave Club',
                                 ),
                               );
                               if (result == null) return; // User cancelled questionnaire
                               answers = result;
                             }

                             // 2. Proceed to Leave
                             await UserService().leaveClub(
                               user.uid, 
                               widget.club.id,
                               answers: answers
                             );
                             
                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left club')));
                               setState(() { _fetchProfile(); });
                             }
                          } else {
                             // JOIN CLUB
                             // 1. Check Privacy
                             if (widget.club.isPrivate) {
                               bool? codeVerified = await showDialog<bool>(
                                 context: context,
                                 builder: (context) => _JoinCodeDialog(correctCode: widget.club.joinCode ?? ''),
                               );
                               if (codeVerified != true) return; // Cancelled or wrong code
                             }

                             // 2. Check Join Questionnaire
                             Map<String, String>? answers;
                             if (widget.club.joinForm != null && widget.club.joinForm!.isEnabled) {
                               final result = await showDialog<Map<String, String>>(
                                 context: context,
                                 builder: (context) => QuestionnaireResponseDialog(
                                   formMap: widget.club.joinForm!.toMap(),
                                   title: 'Join Questionnaire',
                                 ),
                               );
                               if (result == null) return; // User cancelled questionnaire
                               answers = result;
                             }

                             // 3. Proceed to Join
                             await UserService().joinClub(
                               user.uid, 
                               widget.club.id,
                               answers: answers
                             );

                             if (context.mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined successfully!')));
                               setState(() { _fetchProfile(); });
                             }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        }
                      },
                      label: Text(isMember ? 'Leave Club' : 'Join Club${widget.club.isPrivate ? " (Private)" : ""}'),
                      icon: Icon(isMember ? Icons.exit_to_app : (widget.club.isPrivate ? Icons.lock : Icons.add)),
                      backgroundColor: isMember ? Colors.redAccent : null,
                    );
                  }
                )),
    );
  }

  Widget _buildAboutTab(Club club) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  club.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${club.memberCount} Members',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'About',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(club.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 24),
          Text(
            'Tags',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: club.tags.map((tag) {
              return Chip(
                label: Text(tag),
                backgroundColor: Colors.green[100],
              );
            }).toList(),
          ),
          const SizedBox(height: 80), // Fab padding
        ],
      ),
    );
  }

  Widget _buildNewsTab(Club club) {
    return StreamBuilder<List<Announcement>>(
      stream: AnnouncementService().getAnnouncementsForClub(club.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final announcements = snapshot.data ?? [];
        if (announcements.isEmpty) {
          return const Center(child: Text('No announcements yet', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: announcements.length + 1, // +1 for Fab padding
          itemBuilder: (context, index) {
            if (index == announcements.length) return const SizedBox(height: 80);
            final announcement = announcements[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            announcement.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        Text(
                          DateFormat('MMM d').format(announcement.timestamp),
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(announcement.message),
                    const SizedBox(height: 8),
                    Text(
                      'By ${announcement.authorName}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEventsTab(Club club) {
    return StreamBuilder<List<Event>>(
      stream: EventService().getEventsForClub(club.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const Center(child: Text('No events scheduled', style: TextStyle(color: Colors.grey)));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length + 1,
          itemBuilder: (context, index) {
            if (index == events.length) return const SizedBox(height: 80);
            final event = events[index];
            final user = FirebaseAuth.instance.currentUser;
            final isAttending = user != null && event.attendeeIds.contains(user.uid);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('MMM').format(event.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text(DateFormat('d').format(event.date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(event.location),
                trailing: Icon(
                  isAttending ? Icons.check_circle : Icons.event,
                  color: isAttending ? Colors.green : Colors.grey,
                ),
                onTap: () {
                   Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EventDetailsScreen(event: event),
                      ),
                   );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildChatTab(Club club) {
     final currentUser = FirebaseAuth.instance.currentUser;
     final isAdmin = currentUser != null && club.adminIds.contains(currentUser.uid);

     // Using inline scrolling (enableInternalScrolling: false) inside SingleChildScrollView
     // protects against layout expansion errors within NestedScrollView.
     return SingleChildScrollView(
       child: Padding(
         padding: const EdgeInsets.all(16.0),
         child: Column(
           children: [
             CommentSection(entityId: club.id, isAdmin: isAdmin, enableInternalScrolling: false),
             const SizedBox(height: 80),
           ],
         ),
       ),
     );
  }

  Widget _buildMembersTab(Club club) {
    return StreamBuilder<List<UserProfile>>(
      stream: UserService().getMembersOfClub(club.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('No members found', style: TextStyle(color: Colors.grey)));
        }

        // Filter
        final leaders = members.where((m) => club.adminIds.contains(m.uid)).toList();
        final regularMembers = members.where((m) => !club.adminIds.contains(m.uid)).toList();

        // Combine lists (Leaders first)
        final allMembers = [...leaders, ...regularMembers];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allMembers.length + 1,
          itemBuilder: (context, index) {
            if (index == allMembers.length) return const SizedBox(height: 80);
            final member = allMembers[index];
            final isLeader = club.adminIds.contains(member.uid);
            return _buildMemberCard(context, member, club, isLeader: isLeader);
          },
        );
      },
    );
  }

  Widget _buildMemberCard(BuildContext context, UserProfile member, Club club, {bool isLeader = false}) {
      final isMe = member.uid == FirebaseAuth.instance.currentUser?.uid;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: isLeader ? 3 : 1,
        shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(12),
           side: isLeader ? BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)) : BorderSide.none,
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isLeader ? Colors.amber[100] : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            child: Text(
              member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
              style: TextStyle(
                  color: isLeader ? Colors.amber[900] : Theme.of(context).colorScheme.primary, 
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(child: Text(member.displayName + (isMe ? ' (You)' : ''), overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: isLeader ? FontWeight.bold : FontWeight.normal))),
              if (club.adminIds.contains(member.uid)) ...[
                  const SizedBox(width: 8),
                  _buildRoleTag(context, club, member.uid),
              ]
            ],
          ),
          subtitle: Text(member.email),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => ProfileScreen(userId: member.uid)),
            );
          },
        ),
      );
  }

  Widget _buildRoleTag(BuildContext context, Club club, String uid) {
    String roleText = 'ADMIN';
    final officerTitle = club.officerRoles[uid];
    final isMainAdmin = club.adminIds.isNotEmpty && club.adminIds.first == uid;

    if (officerTitle != null) {
      roleText = 'OFFICER: ${officerTitle.toUpperCase()}';
    } else if (isMainAdmin) {
      roleText = 'PRESIDENT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Theme.of(context).primaryColor, width: 0.5),
      ),
      child: Text(
        roleText, 
        style: TextStyle(fontSize: 10, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

class _JoinCodeDialog extends StatefulWidget {
  final String correctCode;
  const _JoinCodeDialog({required this.correctCode});

  @override
  State<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends State<_JoinCodeDialog> {
  final _codeController = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter Join Code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('This is a private club. Please enter the invitation code to join.'),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            decoration: InputDecoration(
              labelText: 'Join Code',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_codeController.text.trim() == widget.correctCode) {
              Navigator.pop(context, true);
            } else {
              setState(() => _error = 'Incorrect code');
            }
          },
          child: const Text('Join'),
        ),
      ],
    );
  }
}
