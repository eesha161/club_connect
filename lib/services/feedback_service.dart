import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/event_feedback.dart';

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add Feedback and Update Event Stats
  Future<void> submitFeedback(EventFeedback feedback) async {
    final eventRef = _firestore.collection('events').doc(feedback.eventId);
    final feedbackRef = eventRef.collection('feedback').doc(feedback.userId); // Limit 1 per user per event

    await _firestore.runTransaction((transaction) async {
      final eventSnapshot = await transaction.get(eventRef);
      if (!eventSnapshot.exists) throw Exception('Event does not exist');

      final feedbackSnapshot = await transaction.get(feedbackRef);
      if (feedbackSnapshot.exists) throw Exception('You have already rated this event');

      // Save Feedback
      transaction.set(feedbackRef, feedback.toMap());

      // Update Stats
      final eventData = eventSnapshot.data() as Map<String, dynamic>;
      final currentCount = (eventData['ratingCount'] ?? 0) as int;
      final currentAvg = (eventData['averageRating'] ?? 0.0) as double;

      final newCount = currentCount + 1;
      final newAvg = ((currentAvg * currentCount) + feedback.rating) / newCount;

      transaction.update(eventRef, {
        'ratingCount': newCount,
        'averageRating': newAvg,
      });
    });
  }

  // Check if User already Provided Feedback
  Future<bool> hasUserProvidedFeedback(String eventId, String userId) async {
    final doc = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('feedback')
        .doc(userId)
        .get();
    return doc.exists;
  }

  // Get Feedback Stream for an Event
  Stream<List<EventFeedback>> getFeedbackForEvent(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('feedback')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => EventFeedback.fromMap(doc.data())).toList();
    });
  }
}
