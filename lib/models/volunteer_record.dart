import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerRecord {
  final String id;
  final String userId;
  final String eventId;
  final String shiftId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool emailSent;

  VolunteerRecord({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.shiftId,
    required this.checkInTime,
    this.checkOutTime,
    this.emailSent = false,
  });

  double get hoursEarned {
    if (checkOutTime == null) return 0.0;
    return checkOutTime!.difference(checkInTime).inMinutes / 60.0;
  }

  bool get isComplete => checkOutTime != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'eventId': eventId,
      'shiftId': shiftId,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'emailSent': emailSent,
    };
  }

  factory VolunteerRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return VolunteerRecord(
      id: documentId,
      userId: map['userId'] ?? '',
      eventId: map['eventId'] ?? '',
      shiftId: map['shiftId'] ?? '',
      checkInTime: (map['checkInTime'] as Timestamp).toDate(),
      checkOutTime: map['checkOutTime'] != null 
          ? (map['checkOutTime'] as Timestamp).toDate() 
          : null,
      emailSent: map['emailSent'] ?? false,
    );
  }

  VolunteerRecord copyWith({
    String? id,
    String? userId,
    String? eventId,
    String? shiftId,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    bool? emailSent,
  }) {
    return VolunteerRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      eventId: eventId ?? this.eventId,
      shiftId: shiftId ?? this.shiftId,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      emailSent: emailSent ?? this.emailSent,
    );
  }
}
