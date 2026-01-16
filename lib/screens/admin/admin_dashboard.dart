import 'package:club_connect/screens/admin/create_announcement_screen.dart';
import 'package:club_connect/screens/admin/create_event_screen.dart';
import 'package:club_connect/screens/admin/manage_members_screen.dart';
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAdminOption(
            context,
            title: 'Create New Club',
            subtitle: 'Start a new student organization',
            icon: Icons.group_add,
            color: Colors.blue,
            onTap: () {
              // TODO: Navigate to Create Club Form
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Create Club coming next!')),
              );
            },
          ),
          _buildAdminOption(
            context,
            title: 'Create Event',
            subtitle: 'Schedule a new event for your clubs',
            icon: Icons.event,
            color: Colors.orange,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const CreateEventScreen()),
              );
            },
          ),
          _buildAdminOption(
            context,
            title: 'Post Announcement',
            subtitle: 'Share updates with club members',
            icon: Icons.campaign,
            color: Colors.green,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const CreateAnnouncementScreen()),
              );
            },
          ),
          _buildAdminOption(
            context,
            title: 'Manage Members',
            subtitle: 'View members, promote leaders, or kick users',
            icon: Icons.supervisor_account,
            color: Colors.purple,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const ManageMembersScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
