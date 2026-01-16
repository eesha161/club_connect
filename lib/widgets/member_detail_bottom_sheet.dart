import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/widgets/loading_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:club_connect/models/club.dart'; // NEW IMPORT
import 'package:club_connect/services/event_service.dart'; // NEW


class MemberDetailBottomSheet extends StatefulWidget {
  final String clubId;
  final UserProfile member;
  final bool isCurrentUserAdmin;
  final VoidCallback onUpdate; // Callback to refresh parent list

  const MemberDetailBottomSheet({
    super.key,
    required this.clubId,
    required this.member,
    required this.isCurrentUserAdmin,
    required this.isMemberMainAdmin,
    required this.onUpdate,
  });

  final bool isMemberMainAdmin;

  @override
  State<MemberDetailBottomSheet> createState() => _MemberDetailBottomSheetState();
}

class _MemberDetailBottomSheetState extends State<MemberDetailBottomSheet> {
  bool _isLoading = true;
  String _adminNote = '';
  final TextEditingController _noteController = TextEditingController();
  
  // Stats (Placeholders for now until EventService is fully integrated for queries)
  int _eventsAttended = 0;
  int _eventsSignedUp = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Club? _club; // NEW: Store club for permission checks

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Load Club Data (for permissions)
      _club = await ClubService().getClubById(widget.clubId);

      // Load Metadata (Notes)
      final metadata = await ClubService().getMemberMetadata(widget.clubId, widget.member.uid);
      if (metadata != null && metadata.containsKey('note')) {
        _adminNote = metadata['note'] ?? '';
        _noteController.text = _adminNote;
      }

      // Load Event Stats
      final stats = await EventService().getMemberStats(widget.clubId, widget.member.uid);
      if (mounted) {
        setState(() {
           _eventsSignedUp = stats['signedUp'] ?? 0;
           _eventsAttended = stats['attended'] ?? 0;
        });
      }
      
    } catch (e) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await ClubService().updateMemberNote(
        widget.clubId, 
        widget.member.uid, 
        _noteController.text.trim(),
        currentUser.uid
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Note saved')));
        Navigator.pop(context); // Close sheet to confirm? or just stay
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _promoteToOfficer() async {
    // 1. Show Dialog to get Title and Permissions
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        final titleController = TextEditingController();
        // Permission states (Default to true for convenience)
        bool manageEvents = true;
        bool manageMembers = false;
        bool manageNotes = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Promote to Officer'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter title and select permissions.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Officer Title',
                        hintText: 'e.g. Vice President',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Align(alignment: Alignment.centerLeft, child: Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold))),
                    CheckboxListTile(
                      title: const Text('Manage Events'),
                      subtitle: const Text('Create, edit, delete events'),
                      value: manageEvents,
                      onChanged: (val) => setState(() => manageEvents = val!),
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('Manage Members'),
                      subtitle: const Text('Kick/Remove members'),
                      value: manageMembers,
                      onChanged: (val) => setState(() => manageMembers = val!),
                      dense: true,
                    ),
                    CheckboxListTile(
                      title: const Text('Private Notes'),
                      subtitle: const Text('View and add admin notes'),
                      value: manageNotes,
                      onChanged: (val) => setState(() => manageNotes = val!),
                      dense: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    if (titleController.text.trim().isNotEmpty) {
                      Navigator.pop(ctx, {
                        'title': titleController.text.trim(),
                        'permissions': {
                          'manageEvents': manageEvents,
                          'manageMembers': manageMembers,
                          'manageNotes': manageNotes,
                        }
                      });
                    }
                  },
                  child: const Text('Promote'),
                ),
              ],
            );
          }
        );
      }
    );

    if (result == null) return;

    final title = result['title'] as String;
    final permissions = result['permissions'] as Map<String, bool>;

    // 2. Assign Role
    try {
      await ClubService().assignOfficerRole(widget.clubId, widget.member.uid, title, permissions);
      
      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Promoted to $title!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _revokeOfficer() async {
     try {
      await ClubService().removeOfficerRole(widget.clubId, widget.member.uid);
      
      if (mounted) {
        Navigator.pop(context); // Close sheet
        widget.onUpdate();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role revoked')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _kickMember() async {
    // Show confirmation dialog with reason
    final reasonController = TextEditingController();
    
    // We need to show another dialog ON TOP of the bottom sheet
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kick Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remove ${widget.member.displayName} from the club?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (Required)',
                hintText: 'e.g., Violation of rules',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                return; // Require reason
              }
              Navigator.pop(ctx, true);
            }, 
            child: const Text('Kick', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ClubService().kickMember(widget.clubId, widget.member.uid, reasonController.text.trim());
        if (mounted) {
          Navigator.pop(context); // Close bottom sheet
          widget.onUpdate();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 200, child: LoadingOverlay());

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    widget.member.displayName.isNotEmpty ? widget.member.displayName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.member.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(widget.member.email, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stats Grid
            const Text('Member Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStatCard('Signed Up', '$_eventsSignedUp Events'),
                const SizedBox(width: 12),
                _buildStatCard('Attended', '$_eventsAttended Events'),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Strikes', 
                  '${widget.member.activeStrikes}', 
                  isAlert: widget.member.activeStrikes > 0
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Admin Notes
            if (_club != null && ClubService().hasPermission(_club!, FirebaseAuth.instance.currentUser?.uid ?? '', 'manageNotes')) ...[
              const Text('Admin Notes (Private)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  hintText: 'Add private notes about this member...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _saveNote,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save Note'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const Divider(height: 32),
            ],

            // Actions
            if (FirebaseAuth.instance.currentUser?.uid != widget.member.uid) // Hide actions for self
            Row(
              children: [
                if (!widget.isMemberMainAdmin) // Cannot change role of Main Admin
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.isCurrentUserAdmin 
                        ? _revokeOfficer 
                        : _promoteToOfficer,
                    child: Text(widget.isCurrentUserAdmin ? 'Revoke Officer Role' : 'Make Officer'),
                  ),
                ),
                if (!widget.isMemberMainAdmin && 
                    _club != null && 
                    ClubService().hasPermission(_club!, FirebaseAuth.instance.currentUser?.uid ?? '', 'manageMembers')
                   ) ...[ 
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _kickMember,
                      child: const Text('Kick Member', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAlert ? Colors.red[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAlert ? Colors.red[200]! : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Text(
              value, 
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: isAlert ? Colors.red[900] : Colors.black,
              )
            ),
            Text(label, style: TextStyle(fontSize: 12, color: isAlert ? Colors.red[700] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
