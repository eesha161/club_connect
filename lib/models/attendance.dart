class Attendance {
  final String id;
  final String eventId;
  final String userId;
  final String userName;
  final DateTime checkInTime;
  final Map<String, String> answers; // NEW: Questionnaire answers

  Attendance({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.userName,
    required this.checkInTime,
    this.answers = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eventId': eventId,
      'userId': userId,
      'userName': userName,
      'checkInTime': checkInTime.toIso8601String(),
      'answers': answers,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] ?? '',
      eventId: map['eventId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      checkInTime: DateTime.parse(map['checkInTime']),
      answers: Map<String, String>.from(map['answers'] ?? {}),
    );
  }
}
