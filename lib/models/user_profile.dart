import 'package:cloud_firestore/cloud_firestore.dart';
/// Represents a User on the ClubConnect platform.
/// We store this in the 'users' collection in Firestore.
class UserProfile {
  // Unique ID from Firebase Auth
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  
  // A list of Club IDs that this user has joined.
  final List<String> joinedClubIds;
  
  // 'user' or 'admin'
  final String role;
  final List<String> badges; // NEW: Digital badges
  final List<String> following; // NEW
  final List<String> followers; // NEW
  final List<String> pendingRequests; // NEW: Users waiting for approval
  final List<String> sentRequests; // NEW: Users I have requested to follow
  final List<String> savedEventIds; // NEW: Bookmarks
  final List<Map<String, dynamic>> strikeHistory; // NEW: Volunteer Strikes

  // Location & School Data
  final String? city;
  final String? state;
  final String? schoolName;
  final String? educationLevel; // 'Middle School', 'High School', 'University', 'Professional/None'

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.joinedClubIds,
    this.role = 'user',
    this.badges = const [],
    this.following = const [],
    this.followers = const [],
    this.pendingRequests = const [],
    this.sentRequests = const [],
    this.savedEventIds = const [],
    this.strikeHistory = const [],
    this.city,
    this.state,
    this.schoolName,
    this.educationLevel,
  });

  // Convert to Map for saving to Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'joinedClubIds': joinedClubIds,
      'role': role,
      'badges': badges,
      'following': following,
      'followers': followers,
      'pendingRequests': pendingRequests,
      'sentRequests': sentRequests,
      'savedEventIds': savedEventIds,
      'strikeHistory': strikeHistory,
      'city': city,
      'state': state,
      'schoolName': schoolName,
      'educationLevel': educationLevel,
    };
  }

  // Create UserProfile from Firestore Map
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      // Safely convert the list from Firestore
      joinedClubIds: List<String>.from(map['joinedClubIds'] ?? []),
      role: map['role'] ?? 'user',
      badges: List<String>.from(map['badges'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
      pendingRequests: List<String>.from(map['pendingRequests'] ?? []),
      sentRequests: List<String>.from(map['sentRequests'] ?? []),
      savedEventIds: List<String>.from(map['savedEventIds'] ?? []),
      strikeHistory: List<Map<String, dynamic>>.from(map['strikeHistory'] ?? []),
      city: map['city'],
      state: map['state'],
      schoolName: map['schoolName'],
      educationLevel: map['educationLevel'],
    );
  }

  UserProfile copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    List<String>? joinedClubIds,
    String? role,
    List<String>? badges,
    List<String>? following,
    List<String>? followers,
    List<String>? pendingRequests,
    List<String>? sentRequests,
    List<String>? savedEventIds,
    List<Map<String, dynamic>>? strikeHistory,
    String? city,
    String? state,
    String? schoolName,
    String? educationLevel,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      joinedClubIds: joinedClubIds ?? this.joinedClubIds,
      role: role ?? this.role,
      badges: badges ?? this.badges,
      following: following ?? this.following,
      followers: followers ?? this.followers,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      savedEventIds: savedEventIds ?? this.savedEventIds,
      strikeHistory: strikeHistory ?? this.strikeHistory,
      city: city ?? this.city,
      state: state ?? this.state,
      schoolName: schoolName ?? this.schoolName,
      educationLevel: educationLevel ?? this.educationLevel,
    );
  }
  
  // Computed: Active Strikes (Current Calendar Year)
  int get activeStrikes {
    final now = DateTime.now();
    
    return strikeHistory.where((s) {
      if (s['date'] == null) return false;
      final date = (s['date'] as dynamic); // Timestamp or String
      DateTime? strikeDate;
      if (date is Timestamp) strikeDate = date.toDate();
      if (date is String) strikeDate = DateTime.tryParse(date);
      
      if (strikeDate == null) return false;

      // Check if strike is in current year
      return strikeDate.year == now.year;
    }).length;
  }
}
