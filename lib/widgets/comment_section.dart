import 'package:club_connect/models/comment.dart';
import 'package:club_connect/services/comment_service.dart';
import 'package:club_connect/services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CommentSection extends StatefulWidget {
  final String entityId; // Club ID or Event ID
  final bool isAdmin;
  final bool enableInternalScrolling;

  const CommentSection({super.key, required this.entityId, this.isAdmin = false, this.enableInternalScrolling = true});

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final _commentController = TextEditingController();
  final _commentService = CommentService();
  final _userService = UserService();
  bool _isSending = false;
  bool _isPrivate = false; // Toggle for private admin messages

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to comment.')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      // Fetch user profile to get display name
      final profile = await _userService.getProfile(user.uid);
      final userName = profile?.displayName ?? 'Anonymous';

      final newComment = Comment(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID
        entityId: widget.entityId,
        userId: user.uid,
        userName: userName,
        text: text,
        timestamp: DateTime.now(),
        isPrivate: _isPrivate,
      );

      await _commentService.addComment(newComment);
      _commentController.clear();
      setState(() => _isPrivate = false); // Reset toggle
      FocusScope.of(context).unfocus(); // Dismiss keyboard
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine content height for layout inside other screens
    return Column(
      children: [
        // Conditional Expanded: Only expand if we have internal scrolling (fixed height container)
        widget.enableInternalScrolling 
          ? Expanded(child: _buildCommentList())
          : _buildCommentList(),
        
        // Input Area
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
               BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, -2))
            ],
          ),
          child: SafeArea( // Handle bottom notch
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPrivate ? Icons.lock : Icons.lock_open,
                    color: _isPrivate ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => _isPrivate = !_isPrivate);
                    if (_isPrivate) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Private Mode: Visible only to Admins"), duration: Duration(milliseconds: 1500)));
                    }
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: _isPrivate ? 'Message admins...' : 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    minLines: 1,
                    maxLines: 4,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    onPressed: _isSending ? null : _sendComment,
                    icon: _isSending
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentList() {
    return StreamBuilder<List<Comment>>(
      stream: _commentService.getCommentsForEntity(widget.entityId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final comments = snapshot.data ?? [];

        if (comments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('No messages yet', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                ],
              ),
            ),
          );
        }

        // Taking a safe bet to sort clientside for now to guarantee order.
        comments.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // Oldest first

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          // IMPORTANT: Scroll behavior control
          shrinkWrap: !widget.enableInternalScrolling,
          physics: widget.enableInternalScrolling ? null : const NeverScrollableScrollPhysics(),
          
          itemCount: comments.length,
          itemBuilder: (context, index) {
            final comment = comments[index];
            final isMe = comment.userId == FirebaseAuth.instance.currentUser?.uid;
            
             // Privacy Filter
            if (comment.isPrivate && !isMe && !widget.isAdmin) {
               return const SizedBox.shrink(); 
            }

            return _buildChatBubble(comment, isMe);
          },
        );
      },
    );
  }

  Widget _buildChatBubble(Comment comment, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
             if (!isMe) 
               Padding(
                 padding: const EdgeInsets.only(left: 8.0, bottom: 2),
                 child: Text(comment.userName, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
               ),
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
               decoration: BoxDecoration(
                 color: isMe ? Colors.blue[600] : (comment.isPrivate ? Colors.red[50] : Colors.grey[200]),
                 borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                 ),
                 border: comment.isPrivate ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   if (comment.isPrivate)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock, size: 10, color: isMe ? Colors.white70 : Colors.red),
                          const SizedBox(width: 4),
                          Text('Private', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: isMe ? Colors.white70 : Colors.red)),
                        ],
                      ),
                   Text(
                     comment.text,
                     style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                   ),
                 ],
               ),
             ),
             Padding(
               padding: const EdgeInsets.only(left: 4, right: 4, top: 2),
               child: Text(
                 DateFormat('h:mm a').format(comment.timestamp),
                 style: const TextStyle(fontSize: 10, color: Colors.grey),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
