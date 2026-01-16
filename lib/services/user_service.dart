// This service manages user profiles and friend stuff.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/user_profile.dart';
import 'package:club_connect/models/inbox_message.dart'; // NEW
import 'package:club_connect/services/inbox_service.dart'; // NEW
import 'package:club_connect/services/notification_service.dart';
import 'package:club_connect/models/club.dart'; // NEW

class UserService {
  final CollectionReference _usersCollection =
      FirebaseFirestore.instance.collection('users');

  /// Creates or Updates a User Profile in Firestore.
  /// Call this after a user successfully registers/logs in.
  Future<void> createOrUpdateProfile(UserProfile user) async {
    try {
      // .set(..., SetOptions(merge: true)) is safer.
      // It creates the doc if it doesn't exist, or updates fields if it does.
      // passing 'merge: true' creates a 'patch' instead of overwriting everything.
      await _usersCollection
          .doc(user.uid)
          .set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Partially updates specific fields of a User Profile.
  Future<void> updateProfileData(String uid, Map<String, dynamic> data) async {
    try {
      await _usersCollection.doc(uid).update(data);
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches a User Profile by their UID (One-time)
  Future<UserProfile?> getProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _usersCollection.doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  /// Streams a User Profile by their UID (Real-time updates)
  Stream<UserProfile?> getProfileStream(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    });
  }

  /// Adds a Club ID to the user's 'joinedClubIds' list.
  /// Optionally saves form answers if provided.
  Future<void> joinClub(String uid, String clubId, {Map<String, String>? answers}) async {
    try {
      // 0. Check if already joined to prevent double-counting
      DocumentSnapshot userDoc = await _usersCollection.doc(uid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        List<dynamic> joinedClubs = data['joinedClubIds'] ?? [];
        if (joinedClubs.contains(clubId)) {
          // Already joined. Skip DB updates to prevent double increment.
        } else {
          // 1. Add club to user's list
          await _usersCollection.doc(uid).update({
            'joinedClubIds': FieldValue.arrayUnion([clubId])
          });
          
          // 2. Increment club's member count
          await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
            'memberCount': FieldValue.increment(1),
          });
        }
      } else {
         // Should not happen for authenticated user, but handle it
          await _usersCollection.doc(uid).set({
            'joinedClubIds': [clubId]
          }, SetOptions(merge: true));
          
          await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
            'memberCount': FieldValue.increment(1),
          });
      }

      // 3. Save Form Answers (if any)
      if (answers != null && answers.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('join_responses')
            .doc(uid)
            .set({
          'uid': uid,
          'answers': answers,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      // 4. Subscribe to push notifications for this club
      try {
        await NotificationService().subscribeToClub(clubId);
      } catch (e) {
      }

      // 4.5 Send Welcome Inbox Message
      try {
        final clubDoc = await FirebaseFirestore.instance.collection('clubs').doc(clubId).get();
        final clubName = clubDoc.data()?['name'] ?? 'The Club';

        final welcomeMsg = InboxMessage(
          id: '',
          title: 'Welcome to $clubName!',
          body: 'Thanks for joining. We are excited to have you! Check out our events tab to see what is coming up.',
          timestamp: DateTime.now(),
          type: 'system',
          relatedId: clubId,
        );
        await InboxService().addMessage(uid, welcomeMsg);
      } catch (e) {
      }

      // 5. Auto-signup for future MANDATORY events
      try {
        // Find all future events for this club that are mandatory
        final now = DateTime.now();
        // NOTE: This query might require a composite index (clubId + isMandatory + date).
        // If the index is missing, this will throw. We catch it so the user still "Joins".
        final mandatoryEventsSnapshot = await FirebaseFirestore.instance
            .collection('events')
            .where('clubId', isEqualTo: clubId)
            .where('isMandatory', isEqualTo: true)
            .where('date', isGreaterThan: Timestamp.fromDate(now))
            .get();

        for (var doc in mandatoryEventsSnapshot.docs) {
          await doc.reference.update({
            'attendeeIds': FieldValue.arrayUnion([uid])
          });
        }
      } catch (e) {
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Removes a Club ID from the user's list.
  /// Optionally saves feedback answers.
  Future<void> leaveClub(String uid, String clubId, {Map<String, String>? answers}) async {
    try {
      // 1. Remove club from user's list
      await _usersCollection.doc(uid).update({
        'joinedClubIds': FieldValue.arrayRemove([clubId])
      });
      
      // 2. Decrement club's member count
      await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
        'memberCount': FieldValue.increment(-1),
      });

      // 3. Save Form Answers (if any)
      if (answers != null && answers.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('leave_responses')
            .doc(uid)
            .set({
          'uid': uid,
          'answers': answers,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      // 4. Unsubscribe from push notifications for this club
      try {
        await NotificationService().unsubscribeFromClub(clubId);
      } catch (e) {
      }
    } catch (e) {
      rethrow;
    }
  }



  /// Deletes the user profile from Firestore AND handles Club cleanup.
  Future<void> deleteProfile(String uid) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final Set<String> clubsBeingDeleted = {};

      // 1. Fetch User Profile to get joined clubs
      final userDoc = await _usersCollection.doc(uid).get();
      List<String> joinedClubIds = [];
      if (userDoc.exists) {
         final data = userDoc.data() as Map<String, dynamic>;
         joinedClubIds = List<String>.from(data['joinedClubIds'] ?? []);
      }

      // 2. Find clubs where this user is an Admin (Potential Deletion)
      final adminClubsQuery = await FirebaseFirestore.instance
          .collection('clubs')
          .where('adminIds', arrayContains: uid)
          .get();

      // 3. Handle Admin Clubs (Delete or Leave)
      for (var doc in adminClubsQuery.docs) {
        final club = Club.fromMap(doc.data(), doc.id);
        
        final otherAdmins = club.adminIds.where((id) => id != uid).toList();
        final hasOfficers = club.officerRoles.isNotEmpty; 

        // CONDITION: Delete club if NO other admins AND NO officers
        if (otherAdmins.isEmpty && !hasOfficers) {
           // QUEUE CLUB DELETION
           batch.delete(doc.reference);
           clubsBeingDeleted.add(doc.id);
           
           // QUEUE EVENTS DELETION (Cascading)
           final clubEvents = await FirebaseFirestore.instance
               .collection('events')
               .where('clubId', isEqualTo: doc.id)
               .get();
           for (var eventDoc in clubEvents.docs) {
             batch.delete(eventDoc.reference);
           }
        } else {
           // TRANSFER/LEAVE: Remove user from adminIds/officers
           batch.update(doc.reference, {
             'adminIds': FieldValue.arrayRemove([uid]),
             'officerRoles.$uid': FieldValue.delete(),
             'officerPermissions.$uid': FieldValue.delete(),
           });
           // Note: We will also strictly decrement memberCount below if they are in joinedClubIds
        }
      }

      // 4. Leave Joined Clubs (Decrement Member Count)
      // Only for clubs NOT already being deleted
      for (var clubId in joinedClubIds) {
        if (!clubsBeingDeleted.contains(clubId)) {
           final clubRef = FirebaseFirestore.instance.collection('clubs').doc(clubId);
           batch.update(clubRef, {
             'memberCount': FieldValue.increment(-1),
             // We don't need to arrayRemove from 'joinedClubIds' on the Club because Clubs don't store member lists (Users do).
             // But if specific Clubs utilize a 'memberIds' array (rare in this app, usually it's inverse), check that.
             // Based on Club model, there is NO 'memberIds' field. Only 'adminIds'.
             // So memberCount decrement is sufficient.
           });
        }
      }

      // 5. Delete the User Profile
      batch.delete(_usersCollection.doc(uid));
      
      await batch.commit();
      
      // 6. Delete Auth happens in UI
      
    } catch (e) {
      rethrow;
    }
  }


  /// Fetches all users who are members of a specific club.
  Stream<List<UserProfile>> getMembersOfClub(String clubId) {
    return _usersCollection
        .where('joinedClubIds', arrayContains: clubId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
  /// Fetches all users (for Admin Dashboard)
  Stream<List<UserProfile>> getAllUsers() {
    return _usersCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
         return UserProfile.fromMap(doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
  // --- Social Features ---

  // --- Social Features ---

  /// Send a Follow Request
  Future<void> sendFollowRequest(String currentUserId, String targetUserId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Add target to current user's 'sentRequests'
      batch.update(
        _usersCollection.doc(currentUserId),
        {
          'sentRequests': FieldValue.arrayUnion([targetUserId])
        },
      );

      // 2. Add current to target's 'pendingRequests'
      batch.update(
        _usersCollection.doc(targetUserId),
        {
          'pendingRequests': FieldValue.arrayUnion([currentUserId])
        },
      );

      // 3. Notify target user via Inbox
      final currentUserDoc = await _usersCollection.doc(currentUserId).get();
      final displayName = (currentUserDoc.data() as Map<String, dynamic>)['displayName'] ?? 'Someone';

      final inboxRef = _usersCollection.doc(targetUserId).collection('inbox').doc();
      batch.set(inboxRef, {
        'id': inboxRef.id,
        'title': 'New Follow Request',
        'body': '$displayName wants to follow you.',
        'timestamp': Timestamp.now(),
        'isRead': false,
        'type': 'follow_request', // Special type for UI to show Accept/Reject buttons
        'relatedId': currentUserId, // The ID of the person asking to follow
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Accept a Follow Request
  Future<void> acceptFollowRequest(String currentUserId, String requesterUid, String messageId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Add to 'followers' and 'following'
      batch.update(
        _usersCollection.doc(currentUserId),
        {
          'followers': FieldValue.arrayUnion([requesterUid]),
          'pendingRequests': FieldValue.arrayRemove([requesterUid]),
        },
      );
      batch.update(
        _usersCollection.doc(requesterUid),
        {
          'following': FieldValue.arrayUnion([currentUserId]),
          'sentRequests': FieldValue.arrayRemove([currentUserId]),
        },
      );

      // 2. Update Inbox Message (Mark read or delete)
      // Here we mark it as read and perhaps update body or title to indicate accepted
      // For simplicity, let's just delete the request message or mark it handled.
      // Better UX: Delete the request message so it doesn't clutter.
      final messageRef = _usersCollection.doc(currentUserId).collection('inbox').doc(messageId);
      batch.delete(messageRef); 
      
      // Optionally serve a notification back to requester "X accepted your follow request"
      
      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Reject a Follow Request
  Future<void> rejectFollowRequest(String currentUserId, String requesterUid, String messageId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // 1. Remove from lists
      batch.update(
        _usersCollection.doc(currentUserId),
        {
          'pendingRequests': FieldValue.arrayRemove([requesterUid]),
        },
      );
      batch.update(
        _usersCollection.doc(requesterUid),
        {
          'sentRequests': FieldValue.arrayRemove([currentUserId]),
        },
      );

      // 2. Delete Invitation Message
      final messageRef = _usersCollection.doc(currentUserId).collection('inbox').doc(messageId);
      batch.delete(messageRef);

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Unfollow a user (Same as before but ensures cleanup)
  Future<void> unfollowUser(String currentUserId, String targetUserId) async {
    try {
      final batch = FirebaseFirestore.instance.batch();

      // Remove target from current user's following
      batch.update(
        _usersCollection.doc(currentUserId),
        {
          'following': FieldValue.arrayRemove([targetUserId])
        },
      );

      // Remove current from target user's followers
      batch.update(
        _usersCollection.doc(targetUserId),
        {
          'followers': FieldValue.arrayRemove([currentUserId])
        },
      );

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Toggles saving an event bookmark for a user
  Future<void> toggleSavedEvent(String userId, String eventId, bool isSaved) async {
    try {
      if (isSaved) {
        // Remove from saved
        await _usersCollection.doc(userId).update({
          'savedEventIds': FieldValue.arrayRemove([eventId])
        });
      } else {
        // Add to saved
        await _usersCollection.doc(userId).update({
          'savedEventIds': FieldValue.arrayUnion([eventId])
        });
      }
    } catch (e) {
      rethrow;
    }
  }


  /// Check if an admin can view a user's strikes (Common Club Admin)
  Future<bool> canViewStrikes(String adminId, String targetUserId) async {
    try {
      if (adminId == targetUserId) return true; // Can always see own

      // 1. Get Target User's joined clubs
      final targetDoc = await _usersCollection.doc(targetUserId).get();
      if (!targetDoc.exists) return false;
      final data = targetDoc.data() as Map<String, dynamic>;
      final List<dynamic> joinedClubIds = data['joinedClubIds'] ?? [];
      
      if (joinedClubIds.isEmpty) return false;

      // 2. Get Clubs where adminId is an admin
      // Requires index on adminIds array. If not present, might error or need index creation.
      // Assuming index exists or limited data in dev.
      final adminClubsSnapshot = await FirebaseFirestore.instance
          .collection('clubs')
          .where('adminIds', arrayContains: adminId)
          .get();

      // 3. Check for intersection
      for (var doc in adminClubsSnapshot.docs) {
        if (joinedClubIds.contains(doc.id)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}
