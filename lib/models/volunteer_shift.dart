class VolunteerShift {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final int maxVolunteers;
  final List<String> signedUpIds;
  final Map<String, String> customFields; // e.g., {"requirements": "Bring gloves", "location": "Park entrance"}

  VolunteerShift({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.maxVolunteers,
    this.signedUpIds = const [],
    this.customFields = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'maxVolunteers': maxVolunteers,
      'signedUpIds': signedUpIds,
      'customFields': customFields,
    };
  }

  factory VolunteerShift.fromMap(Map<String, dynamic> map) {
    return VolunteerShift(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      startTime: DateTime.parse(map['startTime']),
      endTime: DateTime.parse(map['endTime']),
      maxVolunteers: map['maxVolunteers'] ?? 0,
      signedUpIds: List<String>.from(map['signedUpIds'] ?? []),
      customFields: Map<String, String>.from(map['customFields'] ?? {}),
    );
  }

  bool get isFull => signedUpIds.length >= maxVolunteers;

  double get durationHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }
}
