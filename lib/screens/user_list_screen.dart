import 'package:flutter/material.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:club_connect/screens/public_dashboard_screen.dart';

class UserListScreen extends StatelessWidget {
  final String title;
  final List<String> userIds;

  const UserListScreen({
    super.key,
    required this.title,
    required this.userIds,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: userIds.isEmpty
          ? Center(
              child: Text(
                'No users found.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          : ListView.builder(
              itemCount: userIds.length,
              itemBuilder: (context, index) {
                final uid = userIds[index];
                return FutureBuilder<UserProfile?>(
                  future: UserService().getProfile(uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const ListTile(
                        leading: CircleAvatar(child: Icon(Icons.person)),
                        title: Text('Loading...'),
                      );
                    }

                    final user = snapshot.data!;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                            ? Text(user.displayName.isNotEmpty
                                ? user.displayName[0].toUpperCase()
                                : '?')
                            : null,
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(user.email),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PublicDashboardScreen(
                              userId: user.uid,
                              displayName: user.displayName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
