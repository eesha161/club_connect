// This screen shows all your notifications and messages in one place.
import 'package:club_connect/models/inbox_message.dart';
import 'package:club_connect/services/inbox_service.dart';
import 'package:club_connect/services/user_service.dart'; // NEW
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text("Please login")));

    final inboxService = InboxService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbox'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Inbox',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Clear Inbox"),
                  content: const Text("Are you sure you want to delete all messages? This cannot be undone."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text("Delete All"),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                 await inboxService.deleteAllMessages(user.uid);
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Inbox cleared")),
                   );
                 }
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<InboxMessage>>(
        stream: inboxService.getInboxStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final messages = snapshot.data ?? [];

          if (messages.isEmpty) {
             return Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.mail_outline, size: 60, color: Colors.grey),
                   const SizedBox(height: 16),
                   Text("Your inbox is empty", style: TextStyle(color: Colors.grey[600])),
                 ],
               ),
             );
          }

          return ListView.builder(
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              final isFollowRequest = msg.type == 'follow_request';

              return Dismissible(
                key: Key(msg.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  // For follow requests, dismissing acts as Reject
                  if (isFollowRequest && msg.relatedId != null) {
                      UserService().rejectFollowRequest(user.uid, msg.relatedId!, msg.id);
                  } else {
                      inboxService.deleteMessage(user.uid, msg.id);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Message deleted")),
                  );
                },
                child: Card(
                  color: msg.isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getIconColor(msg.type),
                          child: Icon(_getIcon(msg.type), color: Colors.white, size: 20),
                        ),
                        title: Text(
                          msg.title,
                          style: TextStyle(
                            fontWeight: msg.isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(
                              msg.body, 
                              maxLines: 2, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM d, h:mm a').format(msg.timestamp),
                              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        onTap: () {
                          if (!msg.isRead) inboxService.markAsRead(user.uid, msg.id);
                          _showDetails(context, msg);
                        },
                      ),
                      if (isFollowRequest && msg.relatedId != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  await UserService().rejectFollowRequest(user.uid, msg.relatedId!, msg.id);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request ignored")));
                                },
                                child: const Text("Ignore"),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () async {
                                  await UserService().acceptFollowRequest(user.uid, msg.relatedId!, msg.id);
                                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request accepted")));
                                },
                                child: const Text("Accept"),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'announcement': return Icons.campaign;
      case 'reminder': return Icons.alarm;
      case 'summary': return Icons.insights; // For Weekly Summary
      default: return Icons.info;
    }
  }

  Color _getIconColor(String type) {
     switch (type) {
      case 'announcement': return Colors.green[700]!;
      case 'reminder': return Colors.teal[600]!;
       case 'summary': return Colors.lightGreen[700]!;
      case 'follow_request': return Colors.green[800]!;
      default: return Colors.grey;
    }
  }

  void _showDetails(BuildContext context, InboxMessage msg) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _getIconColor(msg.type).withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getIconColor(msg.type),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getIcon(msg.type), color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            msg.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMMM d, y • h:mm a').format(msg.timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    msg.body,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                  ),
                ),
              ),
              // Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: _getIconColor(msg.type),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
