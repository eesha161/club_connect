import 'package:club_connect/models/club_form.dart';

class Club {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int memberCount;
  final List<String> tags;
  final bool isPrivate;
  final String? joinCode;
  final ClubForm? joinForm;
  final ClubForm? leaveForm;
  final List<String> adminIds; // Track club owners/admins
  final Map<String, String> officerRoles; // Track custom titles (Uid -> Title)
  final Map<String, Map<String, dynamic>> officerPermissions; // NEW: Track permissions (Uid -> {manageEvents: bool, ...})
  
  // Location & School Data
  final String? city;
  final String? state;
  final String? schoolName;
  final String? educationLevel;

  Club({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.memberCount,
    required this.tags,
    this.isPrivate = false,
    this.joinCode,
    this.joinForm,
    this.leaveForm,
    this.adminIds = const [],
    this.officerRoles = const {},
    this.officerPermissions = const {},
    this.city,
    this.state,
    this.schoolName,
    this.educationLevel,
  });

  // Convert a Club object into a Map (for saving to Firestore)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'memberCount': memberCount,
      'tags': tags,
      'isPrivate': isPrivate,
      'joinCode': joinCode,
      'joinForm': joinForm?.toMap(),
      'leaveForm': leaveForm?.toMap(),
      'adminIds': adminIds,
      'officerRoles': officerRoles,
      'officerPermissions': officerPermissions,
      'city': city,
      'state': state,
      'schoolName': schoolName,
      'educationLevel': educationLevel,
    };
  }

  // Create a Club object from a Map (reading from Firestore)
  factory Club.fromMap(Map<String, dynamic> map, String documentId) {
    return Club(
      id: documentId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      memberCount: map['memberCount']?.toInt() ?? 0,
      tags: List<String>.from(map['tags'] ?? []),
      isPrivate: map['isPrivate'] ?? false,
      joinCode: map['joinCode'],
      joinForm: map['joinForm'] != null
          ? ClubForm.fromMap(map['joinForm'] as Map<String, dynamic>)
          : null,
      leaveForm: map['leaveForm'] != null
          ? ClubForm.fromMap(map['leaveForm'] as Map<String, dynamic>)
          : null,
      adminIds: List<String>.from(map['adminIds'] ?? []),
      officerRoles: Map<String, String>.from(map['officerRoles'] ?? {}),
      officerPermissions: (map['officerPermissions'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, Map<String, dynamic>.from(value)),
      ) ?? {},
      city: map['city'],
      state: map['state'],
      schoolName: map['schoolName'],
      educationLevel: map['educationLevel'],
    );
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Club && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
