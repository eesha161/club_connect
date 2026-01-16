import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/announcement.dart';
import 'package:club_connect/models/inbox_message.dart';
import 'package:club_connect/services/inbox_service.dart';
import 'package:club_connect/services/user_service.dart';

class AnnouncementService {
  final CollectionReference _announcementsCollection =
      FirebaseFirestore.instance.collection('announcements');
  final UserService _userService = UserService();
  final InboxService _inboxService = InboxService();

  // Create a new announcement (admin only)
  Future<void> createAnnouncement(Announcement announcement) async {
    try {
      await _announcementsCollection.doc(announcement.id).set(announcement.toMap());
      
      // Distribute to all club members' inboxes
      // Note: For large clubs this should be done via Cloud Functions to avoid timeout/rate limits
      // For this MVP/Simulator, we do it client-side.
      final membersStream = _userService.getMembersOfClub(announcement.clubId);
      final members = await membersStream.first;
      
      for (var user in members) {
        final msg = InboxMessage(
          id: '', // Let Firestore generate ID
          title: announcement.title,
          body: announcement.message,
          timestamp: DateTime.now(),
          type: 'announcement',
          relatedId: announcement.clubId,
        );
        await _inboxService.addMessage(user.uid, msg);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get announcements for a specific club
  Stream<List<Announcement>> getAnnouncementsForClub(String clubId) {
    return _announcementsCollection
        .where('clubId', isEqualTo: clubId)
        // .orderBy('timestamp', descending: true)  <-- Removed to avoid Index requirement
        .snapshots()
        .map((snapshot) {
      final announcements = snapshot.docs.map((doc) {
        return Announcement.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Client-side sort
      announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return announcements;
    });
  }

  // Get all announcements (for admin dashboard)
  Stream<List<Announcement>> getAllAnnouncements() {
    return _announcementsCollection
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Announcement.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }
  
  // Get recent announcements for a club (for student club details view)
  Future<List<Announcement>> getRecentAnnouncements(String clubId, {int limit = 3}) async {
    try {
      final snapshot = await _announcementsCollection
          .where('clubId', isEqualTo: clubId)
          // .orderBy('timestamp', descending: true) <-- Removed
          .get();
      
      final announcements = snapshot.docs.map((doc) {
        return Announcement.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      // Client-side sort
      announcements.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return announcements.take(limit).toList();
    } catch (e) {
      return [];
    }
  }
  // Delete an announcement
  Future<void> deleteAnnouncement(String id) async {
    try {
      await _announcementsCollection.doc(id).delete();
    } catch (e) {
      rethrow;
    }
  }
}
