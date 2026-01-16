import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/inbox_message.dart';

class InboxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get stream of inbox messages (ordered by newest first)
  Stream<List<InboxMessage>> getInboxStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return InboxMessage.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  // Get unread count
  Stream<int> getUnreadCountStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('inbox')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Add a message to a specific user's inbox
  Future<void> addMessage(String uid, InboxMessage message) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('inbox')
          .add(message.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Mark a message as read
  Future<void> markAsRead(String uid, String messageId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('inbox')
          .doc(messageId)
          .update({'isRead': true});
    } catch (e) {
    }
  }

  // Delete message
  Future<void> deleteMessage(String uid, String messageId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('inbox')
          .doc(messageId)
          .delete();
    } catch (e) {
    }
  }
  // Delete all messages
  Future<void> deleteAllMessages(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('inbox')
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
    }
  }
}
