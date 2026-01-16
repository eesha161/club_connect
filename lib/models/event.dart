import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/club_form.dart'; // NEW

class Event {
  final String id;
  final String clubId;
  final String title;
  final String description;
  final DateTime date;
  final String location;
  final List<String> attendeeIds; // Restored missing field
  final bool isMandatory;
  final int? lockDaysBeforeEvent;
  final List<String> checkedInIds;
  final List<String> signupQuestions; // Replaces signupQuestionnaire
  final int? maxAttendees; // NEW
  final List<String> waitlist; // NEW
  final ClubForm? registrationForm; // NEW: Questionnaire
  
  // Feedback Stats
  final double averageRating; // NEW
  final int ratingCount; // NEW
  
  // Volunteer Event Fields
  final bool isVolunteerEvent;
  final bool requiresCheckOut; // For non-volunteer events that still need check-out
  final List<Map<String, dynamic>> volunteerShifts; // Stored as maps for Firestore
  final List<String> checkOutIds; // UIDs who have checked out

  final DateTime? signupLockDateTime; // NEW: Precise Lock Date
  
  // NEW Location Fields for Smart Discovery
  final String? city;
  final String? state;
  final String? educationLevel;

  Event({
    required this.id,
    required this.clubId,
    required this.title,
    required this.description,
    required this.date,
    required this.location,
    required this.attendeeIds,
    this.isMandatory = false,
    this.lockDaysBeforeEvent,
    this.checkedInIds = const [],
    this.signupQuestions = const [],
    this.maxAttendees,
    this.waitlist = const [],
    this.isVolunteerEvent = false,
    this.requiresCheckOut = false,
    this.volunteerShifts = const [],
    this.checkOutIds = const [],
    this.registrationForm,
    this.averageRating = 0.0,
    this.ratingCount = 0,
    this.signupLockDateTime,
    this.city,
    this.state,
    this.educationLevel,
  });

  // Convert to Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clubId': clubId,
      'title': title,
      'description': description,
      'date': Timestamp.fromDate(date),
      'location': location,
      'attendeeIds': attendeeIds,
      'isMandatory': isMandatory,
      'lockDaysBeforeEvent': lockDaysBeforeEvent,
      'checkedInIds': checkedInIds,
      'signupQuestions': signupQuestions,
      'maxAttendees': maxAttendees,
      'waitlist': waitlist,
      'isVolunteerEvent': isVolunteerEvent,
      'requiresCheckOut': requiresCheckOut,
      'volunteerShifts': volunteerShifts,
      'checkOutIds': checkOutIds,
      'registrationForm': registrationForm?.toMap(),
      'averageRating': averageRating,
      'ratingCount': ratingCount,
      'signupLockDateTime': signupLockDateTime != null ? Timestamp.fromDate(signupLockDateTime!) : null,
      'city': city,
      'state': state,
      'educationLevel': educationLevel,
    };
  }

  // Create Event from Firestore Map
  factory Event.fromMap(Map<String, dynamic> map, String documentId) {
    return Event(
      id: documentId,
      clubId: map['clubId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      // Handle potential null or wrong type for Timestamp
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      location: map['location'] ?? '',
      attendeeIds: List<String>.from(map['attendeeIds'] ?? []),
      isMandatory: map['isMandatory'] ?? false,
      lockDaysBeforeEvent: map['lockDaysBeforeEvent'],
      checkedInIds: List<String>.from(map['checkedInIds'] ?? []),
      signupQuestions: List<String>.from(map['signupQuestions'] ?? []),
      maxAttendees: map['maxAttendees'],
      waitlist: List<String>.from(map['waitlist'] ?? []),
      isVolunteerEvent: map['isVolunteerEvent'] ?? false,
      requiresCheckOut: map['requiresCheckOut'] ?? false,
      volunteerShifts: List<Map<String, dynamic>>.from(map['volunteerShifts'] ?? []),
      checkOutIds: List<String>.from(map['checkOutIds'] ?? []),
      registrationForm: map['registrationForm'] != null
          ? ClubForm.fromMap(map['registrationForm'] as Map<String, dynamic>)
          : null,
      averageRating: (map['averageRating'] ?? 0.0).toDouble(),
      ratingCount: (map['ratingCount'] ?? 0).toInt(),
      signupLockDateTime: (map['signupLockDateTime'] as Timestamp?)?.toDate(),
      city: map['city'],
      state: map['state'],
      educationLevel: map['educationLevel'],
    );
  }

  /// Computed property to check if the event is locked based on lockDaysBeforeEvent
  bool get isLocked {
    // Priority: Specific Lock Date
    if (signupLockDateTime != null) {
      return DateTime.now().isAfter(signupLockDateTime!);
    }
    // Fallback: Legacy "Days Before" logic
    if (lockDaysBeforeEvent == null) return false;
    final deadline = date.subtract(Duration(days: lockDaysBeforeEvent!));
    return DateTime.now().isAfter(deadline);
  }
}
