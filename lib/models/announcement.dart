import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String id;
  final String clubId;
  final String title;
  final String message;
  final String authorId;
  final String authorName;
  final DateTime timestamp;

  Announcement({
    required this.id,
    required this.clubId,
    required this.title,
    required this.message,
    required this.authorId,
    required this.authorName,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'title': title,
      'message': message,
      'authorId': authorId,
      'authorName': authorName,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory Announcement.fromMap(Map<String, dynamic> map, String documentId) {
    return Announcement(
      id: documentId,
      clubId: map['clubId'] ?? '',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Admin',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
