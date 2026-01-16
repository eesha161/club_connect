import 'dart:async';


import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/screens/login_screen.dart';
import 'package:club_connect/screens/settings_screen.dart';
import 'package:club_connect/services/auth_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
// This screen shows your personal profile, including badges and volunteer hours.
import 'package:club_connect/auth_wrapper.dart';
import 'package:club_connect/screens/user_list_screen.dart'; // NEW
import 'package:club_connect/screens/splash_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Use Stream for real-time updates of followers
  Stream<UserProfile?>? _profileStream;
  final _userService = UserService();
  final _auth = FirebaseAuth.instance;
  bool _isMe = false;
  bool _isFollowing = false;
  bool _canSeeStrikes = false; // NEW: Visibility Flag

  @override
  void initState() {
    super.initState();
    _initProfile();
  }

  void _initProfile() {
    final currentUser = _auth.currentUser;
    final targetId = widget.userId ?? currentUser?.uid;

    if (currentUser != null && targetId != null) {
      _isMe = (widget.userId == null || widget.userId == currentUser.uid);
      _profileStream = _userService.getProfileStream(targetId);

      // Check if following (if not me)
      if (!_isMe) {
        _checkIfFollowing(currentUser.uid, targetId);
        _checkStrikeVisibility(currentUser.uid, targetId); // NEW
      } else {
        _canSeeStrikes = true; // Always see own
      }
    }
  }

  Future<void> _checkStrikeVisibility(String currentUserId, String targetUserId) async {
    // Check if current user is admin of any club that target user is in
    try {
      final canSee = await _userService.canViewStrikes(currentUserId, targetUserId);
      if (mounted) setState(() => _canSeeStrikes = canSee);
    } catch (e) {
    }
  }

  void _checkIfFollowing(String currentUserId, String targetId) async {
    final currentUserProfile = await _userService.getProfile(currentUserId);
    if (currentUserProfile != null) {
      if (mounted) {
        setState(() {
          _isFollowing = currentUserProfile.following.contains(targetId);
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUser = _auth.currentUser;
    final targetId = widget.userId;
    if (currentUser == null || targetId == null) return;

    try {
      final amIFollowing = await _userService.getProfile(targetId).then((p) => p?.followers.contains(currentUser.uid) ?? false);
      
      if (amIFollowing) {
        await _userService.unfollowUser(currentUser.uid, targetId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Unfollowed")));
      } else {
        await _userService.sendFollowRequest(currentUser.uid, targetId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Follow request sent")));
      }
      // State updates automatically via stream
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _confirmDeleteAccount(BuildContext context, String uid) {
     // ... (Existing delete logic kept same, simplified for brevity here to focus on logic inject)
     // To keep file size manageable I will restore the logic below in a helper
     // For this rewrite I will include essential UI and restoration of features.
     _showDeleteDialog(context, uid);
  }

  /// RESTORED DELETE LOGIC
  void _showDeleteDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
            'Are you sure you want to delete your account? This will:\n\n'
            '• Delete your profile data\n'
            '• Remove you from all clubs\n'
            '• Delete your authentication account\n\n'
            'This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); 
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);

               try {
                showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));
                
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) throw Exception('No user');

                await _userService.deleteProfile(uid);
                try {
                  await user.delete();
                } on FirebaseAuthException catch (e) {
                   if (e.code == 'requires-recent-login') {
                     if (navigator.mounted) navigator.pop();
                     messenger.showSnackBar(const SnackBar(content: Text('Please log out and log back in to delete account.')));
                     return;
                   }
                }
                await FirebaseAuth.instance.signOut();
                if (navigator.mounted) {
                   navigator.pop();
                   navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                }
               } catch (e) {
                 if (navigator.mounted) navigator.pop();
                 messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
               }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isMe ? 'My Profile' : 'Profile'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
           final profile = snapshot.data;
          if (profile == null) {
            return const Center(child: Text('User profile not found.'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // --- AVATAR & NAME ---
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (_isMe)
                Text(
                  profile.email,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                ),
                
                // NEW: Location & Education Info
                const SizedBox(height: 12),
                if (profile.city != null || profile.state != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.city ?? ""}${profile.city != null && profile.state != null ? ", " : ""}${profile.state ?? ""}',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                if (profile.educationLevel != null)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        profile.educationLevel!,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),
                
                // --- ACTION BUTTONS (Follow vs Edit) ---
                if (!_isMe)
                  SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (context) {
                          final currentUser = FirebaseAuth.instance.currentUser;
                          final iDeleted = false; // safety check
                          final amIFollowing = profile.followers.contains(currentUser?.uid);
                          final isPending = profile.pendingRequests.contains(currentUser?.uid);
                          
                          if (amIFollowing) {
                             return ElevatedButton.icon(
                                onPressed: _toggleFollow, // This will be Unfollow
                                icon: const Icon(Icons.check),
                                label: const Text('Following'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                             );
                          } else if (isPending) {
                             return ElevatedButton.icon(
                                onPressed: null, // Disabled
                                icon: const Icon(Icons.hourglass_empty),
                                label: const Text('Requested'),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300], foregroundColor: Colors.grey[700]),
                             );
                          } else {
                             return ElevatedButton.icon(
                                onPressed: _toggleFollow, // This will be Request Follow
                                icon: const Icon(Icons.person_add),
                                label: const Text('Request to Follow'),
                                style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
                             );
                          }
                      }
                    ),
                  ),

                const SizedBox(height: 24),
                
                // --- PRIVACY LOCK ---
                if (!_isMe && !profile.followers.contains(FirebaseAuth.instance.currentUser?.uid)) ...[
                   const SizedBox(height: 40),
                   const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text(
                     "This account is private",
                     style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                   ),
                   const Text(
                     "Follow to see their clubs, badges, and stats.",
                     style: TextStyle(color: Colors.grey),
                   ),
                   const SizedBox(height: 40),
                ] else ...[
                    // --- SOCIAL STATS ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserListScreen(
                                title: 'Following',
                                userIds: profile.following,
                              ),
                            ),
                          ),
                          child: _buildStatCol("Following", profile.following.length),
                        ),
                        InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserListScreen(
                                title: 'Followers',
                                userIds: profile.followers,
                              ),
                            ),
                          ),
                          child: _buildStatCol("Followers", profile.followers.length),
                        ),
                        _buildStatCol("Badges", profile.badges.length),
                      ],
                    ),
                  ],

                 const SizedBox(height: 24),
                 const Divider(),

                // --- MENU OPTIONS (Only if Me) ---
                if (_isMe) ...[
                  // 1. Settings
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: const Icon(Icons.settings),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SettingsScreen()));
                      },
                    ),
                  ),
                  
                  // 2. Logout
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12, top: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.green[700]),
                      title: Text('Log Out', style: TextStyle(color: Colors.green[700])),
                      onTap: () async {
                         await AuthService().signOut();
                         if (context.mounted) {
                           Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
                         }
                      },
                    ),
                  ),

                  // 3. Delete Account
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Icon(Icons.delete_forever, color: Colors.green[600]),
                      title: Text('Delete Account', style: TextStyle(color: Colors.green[600])),
                      onTap: () => _confirmDeleteAccount(context, profile.uid),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCol(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}
