import 'package:club_connect/models/club.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/services/club_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:flutter/material.dart';

class ManageMembersScreen extends StatefulWidget {
  const ManageMembersScreen({super.key});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  Club? _selectedClub;
  final _userService = UserService();

  Future<void> _kickUser(String uid, String userName) async {
    if (_selectedClub == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Kick $userName?'),
        content: Text(
            'Are you sure you want to remove this user from ${_selectedClub!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Kick'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _userService.leaveClub(uid, _selectedClub!.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $userName from the club.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Members')),
      body: Column(
        children: [
          // 1. Club Selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: StreamBuilder<List<Club>>(
              stream: ClubService().getClubs(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }
                final clubs = snapshot.data!;
                return DropdownButtonFormField<Club>(
                  value: _selectedClub,
                  decoration: const InputDecoration(
                    labelText: 'Select Club to Manage',
                    border: OutlineInputBorder(),
                  ),
                  items: clubs.map((club) {
                    return DropdownMenuItem(
                      value: club,
                      child: Text(club.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedClub = val;
                    });
                  },
                );
              },
            ),
          ),
          
          const Divider(height: 1),

          // 2. Member List
          Expanded(
            child: _selectedClub == null
                ? const Center(
                    child: Text('Please select a club above to see members.'),
                  )
                : StreamBuilder<List<UserProfile>>(
                    stream: _userService.getMembersOfClub(_selectedClub!.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final members = snapshot.data ?? [];

                      if (members.isEmpty) {
                        return const Center(
                          child: Text('No members found in this club.'),
                        );
                      }

                      return ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final user = members[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?'),
                            ),
                            title: Text(user.displayName),
                            subtitle: Text(user.email),
                            trailing: IconButton(
                              icon: const Icon(Icons.person_remove,
                                  color: Colors.redAccent),
                              tooltip: 'Kick Member',
                              onPressed: () =>
                                  _kickUser(user.uid, user.displayName),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
