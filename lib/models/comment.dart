import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String entityId; // ID of the Club or Event
  final String userId;
  final String userName; // Denormalized for easy display
  final String text;
  final DateTime timestamp;
  final bool isPrivate; // New: Visible only to admins

  Comment({
    required this.id,
    required this.entityId,
    required this.userId,
    required this.userName,
    required this.text,
    required this.timestamp,
    this.isPrivate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entityId': entityId,
      'userId': userId,
      'userName': userName,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'isPrivate': isPrivate,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map, String documentId) {
    return Comment(
      id: documentId,
      entityId: map['entityId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPrivate: map['isPrivate'] ?? false,
    );
  }
}
