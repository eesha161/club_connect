import 'package:cloud_firestore/cloud_firestore.dart';

class EventFeedback {
  final String id;
  final String eventId;
  final String userId;
  final String? userName; // Denormalized for display
  final double rating; // 1.0 to 5.0
  final String comment;
  final DateTime timestamp;

  EventFeedback({
    required this.id,
    required this.eventId,
    required this.userId,
    this.userName,
    required this.rating,
    required this.comment,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory EventFeedback.fromMap(Map<String, dynamic> map) {
    return EventFeedback(
      id: map['id'] ?? '',
      eventId: map['eventId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'],
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
