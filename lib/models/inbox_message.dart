import 'package:cloud_firestore/cloud_firestore.dart';

class InboxMessage {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final String type; // 'announcement', 'reminder', 'system'
  final String? relatedId; // clubId or eventId

  InboxMessage({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.relatedId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      'type': type,
      'relatedId': relatedId,
    };
  }

  factory InboxMessage.fromMap(Map<String, dynamic> map, String documentId) {
    return InboxMessage(
      id: documentId,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] ?? false,
      type: map['type'] ?? 'system',
      relatedId: map['relatedId'],
    );
  }
}
