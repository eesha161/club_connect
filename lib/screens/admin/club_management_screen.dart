import 'package:cloud_firestore/cloud_firestore.dart'; // NEW
import 'package:club_connect/models/question.dart'; // NEW
// This is the dashboard for club leaders to manage everything.
import 'package:club_connect/models/club.dart';
import 'package:club_connect/models/event.dart';
import 'package:club_connect/models/user_profile.dart'; // NEW
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/event_service.dart';
import 'package:club_connect/services/user_service.dart'; // NEW
import 'package:club_connect/screens/admin/create_event_screen.dart';
import 'package:club_connect/screens/admin/event_attendees_screen.dart'; // NEW
import 'package:club_connect/models/announcement.dart'; // NEW
import 'package:club_connect/services/announcement_service.dart'; // NEW
import 'package:club_connect/screens/admin/create_announcement_screen.dart'; // NEW
import 'package:club_connect/widgets/member_detail_bottom_sheet.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Club Management Screen for admins to manage their clubs
class ClubManagementScreen extends StatefulWidget {
  final Club club;

  const ClubManagementScreen({super.key, required this.club});

  @override
  State<ClubManagementScreen> createState() => _ClubManagementScreenState();
}

class _ClubManagementScreenState extends State<ClubManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  late List<String> _tags;
  late bool _isPrivate;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Info, Members, Events, Announcements, Responses
    
    // Initialize form fields with current club data
    _nameController = TextEditingController(text: widget.club.name);
    _descriptionController = TextEditingController(text: widget.club.description);
    _imageUrlController = TextEditingController(text: widget.club.imageUrl);
    _tags = List.from(widget.club.tags);
    _isPrivate = widget.club.isPrivate;
    _checkAndFixMembership();
  }

  Future<void> _checkAndFixMembership() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && widget.club.adminIds.contains(user.uid)) {
       final profile = await UserService().getProfile(user.uid);
       if (profile != null && !profile.joinedClubIds.contains(widget.club.id)) {
          // Join the club
          await UserService().joinClub(user.uid, widget.club.id);
          // Force UI refresh if needed, though StreamBuilder should handle it
          if (mounted) setState(() {});
       }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final updatedClub = Club(
        id: widget.club.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: _imageUrlController.text.trim(),
        tags: _tags,
        adminIds: widget.club.adminIds,
        memberCount: widget.club.memberCount,
        isPrivate: _isPrivate,
        joinCode: widget.club.joinCode,
        joinForm: widget.club.joinForm,
        leaveForm: widget.club.leaveForm,
      );
      
      // Show success immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Club updated!')),
        );
        Navigator.pop(context);
      }
      
      // Update in background
      ClubService().updateClub(updatedClub).then((_) {
      }).catchError((e) {
      });
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // We listen to the club stream to get real-time updates (e.g. admin role changes)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').doc(widget.club.id).snapshots(),
      builder: (context, snapshot) {
        // If we have data, we create a fresh Club object. 
        // If not (loading/error), we fall back to 'widget.club' to keep UI stable.
        Club currentClub = widget.club;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
             currentClub = Club.fromMap(snapshot.data!.data() as Map<String, dynamic>, snapshot.data!.id);
          } catch (e) {
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text('Manage ${currentClub.name}'),
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              tabs: const [
                Tab(icon: Icon(Icons.info), text: 'Info'),
                Tab(icon: Icon(Icons.group), text: 'Members'),
                Tab(icon: Icon(Icons.event), text: 'Events'),
                Tab(icon: Icon(Icons.campaign), text: 'News'),
                Tab(icon: Icon(Icons.assignment), text: 'Responses'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildInfoTab(currentClub), // Pass updated club
              _buildMembersTab(currentClub), // Pass updated club
              _buildEventsTab(currentClub), // Pass updated club
              _buildAnnouncementsTab(currentClub), // Pass updated club
              _buildResponsesTab(currentClub), // Pass updated club
            ],
          ),
        );
      }
    );
  }

  Widget _buildInfoTab(Club currentClub) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Club Details'),
                const SizedBox(height: 16),
                
                // Club Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Club Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.group),
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter a club name' : null,
                ),
                const SizedBox(height: 16),
                
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (value) => value!.isEmpty ? 'Please enter a description' : null,
                ),
                const SizedBox(height: 16),
                
                // Image URL
                TextFormField(
                  controller: _imageUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Image URL',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image),
                  ),
                  validator: (value) => value!.isEmpty ? 'Please enter an image URL' : null,
                ),
                const SizedBox(height: 24),
                
                _buildSectionTitle('Settings'),
                const SizedBox(height: 12),
                
                // Privacy Toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Private Club'),
                  subtitle: const Text('Requires join code to join'),
                  value: _isPrivate,
                  onChanged: (value) => setState(() => _isPrivate = value),
                ),
                if (_isPrivate && currentClub.joinCode != null) ...[
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: currentClub.joinCode,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Join Code',
                      border: const OutlineInputBorder(),
                      helperText: 'Share this code with members',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Join Code copied!')));
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                
                // Tags
                const Text('Tags', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _tags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      onDeleted: () => setState(() => _tags.remove(tag)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                // Simple Add Tag
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Add a tag and press enter',
                    isDense: true,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty && !_tags.contains(value)) {
                      setState(() => _tags.add(value));
                    }
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Delete Club Button
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Club'),
                    onPressed: _isSaving ? null : _confirmDeleteClub,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Divider(),
      ],
    );
  }

  Future<void> _confirmDeleteClub() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Club?'),
        content: Text('Are you sure you want to delete "${widget.club.name}"? This action cannot be undone and will delete all associated events.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      setState(() => _isSaving = true); // Show loading
      
      try {
        await ClubService().deleteClub(widget.club.id);
        
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Club deleted successfully')),
           );
           Navigator.pop(context); // Close manage screen
        }
      } catch (e) {
        if (mounted) {
           setState(() => _isSaving = false);
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error deleting club: $e'), backgroundColor: Colors.red),
           );
        }
      }
    }
  }

  Widget _buildMembersTab(Club currentClub) {
    return StreamBuilder<List<UserProfile>>(
      stream: UserService().getMembersOfClub(currentClub.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Center(child: Text('No members yet'));
        }

        // Sort: Admins first
        members.sort((a, b) {
          final aIsAdmin = currentClub.adminIds.contains(a.uid);
          final bIsAdmin = currentClub.adminIds.contains(b.uid);
          if (aIsAdmin && !bIsAdmin) return -1;
          if (!aIsAdmin && bIsAdmin) return 1;
          return a.displayName.compareTo(b.displayName);
        });

        return ListView.separated(
          itemCount: members.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final member = members[index];
            final isAdmin = currentClub.adminIds.contains(member.uid);
            
            final officerTitle = currentClub.officerRoles[member.uid];
            final mainAdminId = currentClub.adminIds.isNotEmpty ? currentClub.adminIds.first : '';
            // If main admin (creator), ensure they have a tag even if not in officerRoles (legacy support)
            final isMainAdmin = member.uid == mainAdminId;
            
            String roleText = '';
            if (officerTitle != null) {
              roleText = 'OFFICER: ${officerTitle.toUpperCase()}';
            } else if (isMainAdmin) {
              roleText = 'PRESIDENT'; // Or Main Admin
            } else if (isAdmin) {
              roleText = 'ADMIN'; // Fallback
            }

            return ListTile(
              leading: CircleAvatar(
                backgroundColor: isAdmin ? Theme.of(context).primaryColor : Colors.grey[300],
                child: Text(
                  member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: isAdmin ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                  )
                ),
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      member.displayName, 
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 8),
                    Container(
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
                    ),
                  ]
                ],
              ),
              subtitle: Text(member.email),
              trailing: member.activeStrikes > 0 
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: member.activeStrikes >= 3 ? Colors.lime[100] : Colors.lightGreen[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${member.activeStrikes} Strike${member.activeStrikes == 1 ? '' : 's'}',
                        style: TextStyle(
                          color: member.activeStrikes >= 3 ? Colors.lime[900] : Colors.lightGreen[900],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => MemberDetailBottomSheet(
                    clubId: currentClub.id,
                    member: member,
                    isCurrentUserAdmin: isAdmin,
                    isMemberMainAdmin: isMainAdmin,
                    onUpdate: () {
                      // Trigger refresh if needed
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEventsTab(Club currentClub) {
    return Stack(
      children: [
        StreamBuilder<List<Event>>(
          stream: EventService().getEventsForClub(widget.club.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            
            final events = snapshot.data ?? [];
            if (events.isEmpty) {
              return const Center(
                child: Text('No events yet', style: TextStyle(color: Colors.grey)),
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: events.length + 1, // Padding for FAB
              itemBuilder: (context, index) {
                if (index == events.length) return const SizedBox(height: 80);
                final event = events[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const Icon(Icons.event, color: Colors.blue),
                    title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM d, y - h:mm a').format(event.date)),
                        if (event.isVolunteerEvent || event.isMandatory || event.signupLockDateTime != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              if (event.isVolunteerEvent)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                                  child: const Text('VOLUNTEER', style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                                ),
                              if (event.isMandatory)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(4)),
                                  child: Text('MANDATORY', style: TextStyle(fontSize: 10, color: Colors.green[900], fontWeight: FontWeight.bold)),
                                ),
                              if (event.signupLockDateTime != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.teal[100], borderRadius: BorderRadius.circular(4)),
                                  child: Text('LOCKED', style: TextStyle(fontSize: 10, color: Colors.teal[800], fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ]
                      ],
                    ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Manage Attendance (Check Permission)
                          if (ClubService().hasPermission(widget.club, FirebaseAuth.instance.currentUser?.uid ?? '', 'manageEvents'))
                          IconButton(
                            icon: const Icon(Icons.assignment_ind, color: Colors.indigo), // Manage Attendance
                            tooltip: 'Manage Attendance',
                            onPressed: () {
                               Navigator.of(context).push(
                                 MaterialPageRoute(
                                   builder: (context) => EventAttendeesScreen(event: event),
                                 ),
                               );
                            },
                          ),
                          // Delete Event (Check Permission)
                          if (ClubService().hasPermission(widget.club, FirebaseAuth.instance.currentUser?.uid ?? '', 'manageEvents'))
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteEvent(event),
                          ),
                        ],
                      ),
                  ),
                );
              },
            );
          },
        ),
        // QUICK ACTION: Create Event
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'createEventQuick',
            onPressed: () {
               // Assuming CreateEventScreen can take a pre-selected club if we modify it or pass it specially.
               // Currently CreateEventScreen allows selecting a club from dropdown.
               // I can update CreateEventScreen to accept a `preSelectedClub` or similar.
               // Or just navigate there and let them pick (less ideal).
               // Let's modify CreateEventScreen to accept preSelectedClubId!
               // For now, I'll push it, and if it doesn't support it, I'll update it next.
               // Checking scanned file: constructor is `CreateEventScreen({super.key, this.eventToEdit});`
               // It needs a `clubId` param. I will add it shortly.
               Navigator.of(context).push(
                 MaterialPageRoute(
                   builder: (context) => CreateEventScreen(preSelectedClubId: currentClub.id),
                 ),
               );
            },
            label: const Text('Create Event'),
            icon: const Icon(Icons.add_task),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteEvent(Event event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Event?'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      // Show success immediately
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event deleted')),
      );
      
      // Delete in background
      EventService().deleteEvent(event.id).then((_) {
      }).catchError((e) {
      });
    }
  }


  Widget _buildAnnouncementsTab(Club currentClub) {
    return Stack(
      children: [
        StreamBuilder<List<Announcement>>(
          stream: AnnouncementService().getAnnouncementsForClub(currentClub.id),
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
                  child: ListTile(
                    title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(DateFormat('MMM d, y - h:mm a').format(announcement.timestamp)),
                        const SizedBox(height: 4),
                        Text(announcement.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteAnnouncement(announcement),
                    ),
                  ),
                );
              },
            );
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'managePostNews',
            onPressed: () {
               Navigator.of(context).push(
                 MaterialPageRoute(builder: (context) => CreateAnnouncementScreen(club: currentClub)),
               );
            },
            label: const Text('Post Announcement'),
            icon: const Icon(Icons.post_add),
          ),
        ),
      ],
    );
  }

  Widget _buildResponsesTab(Club currentClub) {
    // Check if questionnaires exist
    final hasJoin = currentClub.joinForm != null && currentClub.joinForm!.isEnabled;
    final hasLeave = currentClub.leaveForm != null && currentClub.leaveForm!.isEnabled;

    if (!hasJoin && !hasLeave) {
       return const Center(child: Text("No questionnaire is set"));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Theme.of(context).primaryColor,
            unselectedLabelColor: Colors.grey,
            tabs: const [Tab(text: "Join Responses"), Tab(text: "Leave Responses")],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildResponseView(currentClub, true),
                _buildResponseView(currentClub, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseView(Club club, bool isJoin) {
    final questions = isJoin ? club.joinForm?.questions : club.leaveForm?.questions;
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: isJoin 
          ? ClubService().getJoinResponses(club.id)
          : ClubService().getLeaveResponses(club.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final responses = snapshot.data ?? [];
        if (responses.isEmpty) {
          return const Center(child: Text("No responses found"));
        }

        return Column(
          children: [
            // Analytics Section (Only multiple choice)
            if (questions != null)
              _buildAnalyticsSection(responses, questions),
              
            Expanded(
              child: ListView.builder(
                itemCount: responses.length,
                itemBuilder: (context, index) {
                  final data = responses[index];
                  final uid = data['uid'] ?? 'Unknown';
                  final answers = data['answers'] as Map<String, dynamic>? ?? {};
                  final timestamp = data['timestamp'] as Timestamp?;

                  return ExpansionTile(
                    title: FutureBuilder<UserProfile?>(
                      future: UserService().getProfile(uid),
                      builder: (context, userSnap) {
                        return Text(userSnap.data?.displayName ?? "User: $uid");
                      },
                    ),
                    subtitle: Text(timestamp != null 
                        ? DateFormat('MMM d, y - h:mm a').format(timestamp.toDate()) 
                        : 'No date'),
                    children: answers.entries.map((e) {
                      final questionId = e.key;
                      final answerVal = e.value;
                      
                      // Look up question text
                      String questionText = "Q: $questionId";
                      if (questions != null) {
                        try {
                          final q = questions.firstWhere((q) => q.id == questionId);
                          questionText = q.text;
                        } catch (_) {}
                      }

                      return ListTile(
                        title: Text(questionText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Text("$answerVal"),
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnalyticsSection(List<Map<String, dynamic>> responses, List<Question> questions) {
    // Filter for Multiple Choice questions only
    final mcqs = questions.where((q) => q.type == 'multiple_choice').toList();
    if (mcqs.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Keep it compact
          children: [
            const Text('Analytics (Multiple Choice)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...mcqs.map((q) {
              // Calculate stats
              final Map<String, int> counts = {};
              int total = 0;
              
              for (var r in responses) {
                final answers = r['answers'] as Map<String, dynamic>? ?? {};
                if (answers.containsKey(q.id)) {
                   final val = answers[q.id].toString();
                   counts[val] = (counts[val] ?? 0) + 1;
                   total++;
                }
              }
              
              if (total == 0) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...q.options.map((opt) {
                       final count = counts[opt] ?? 0;
                       final percent = total > 0 ? (count / total * 100).toStringAsFixed(1) : "0.0";
                       return Padding(
                         padding: const EdgeInsets.only(left: 8.0, top: 2),
                         child: Row(
                           children: [
                             Expanded(child: Text(opt, style: const TextStyle(fontSize: 12))),
                             Text("$count ($percent%)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                           ],
                         ),
                       );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAnnouncement(Announcement announcement) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: Text('Are you sure you want to delete "${announcement.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement deleted')));
      AnnouncementService().deleteAnnouncement(announcement.id);
    }
  }
}
