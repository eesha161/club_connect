// This service talks to Firestore to get club data and manage memberships.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/club.dart';

class ClubService {
  final CollectionReference _clubsCollection =
      FirebaseFirestore.instance.collection('clubs');

  // Create a new club in Firestore
  Future<void> createClub(Club club) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // 1. Create the Club Document
      final clubRef = _clubsCollection.doc(club.id);
      batch.set(clubRef, club.toMap());

      // 2. Add creator (first admin) to the club's member list (User collection)
      if (club.adminIds.isNotEmpty) {
        final creatorId = club.adminIds.first;
        final userRef = firestore.collection('users').doc(creatorId);
        
        batch.update(userRef, {
          'joinedClubIds': FieldValue.arrayUnion([club.id])
        });
      }

      await batch.commit();
    } catch (e) {
      // Rethrow so the UI can handle the error (show snackbar etc)
      rethrow;
    }
  }

  // Get a Stream of all clubs (Real-time updates)
  Stream<List<Club>> getClubs() {
    return _clubsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        // Convert each Firestore document into a Club object
        return Club.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get a single club by ID
  Future<Club?> getClubById(String id) async {
    try {
      DocumentSnapshot doc = await _clubsCollection.doc(id).get();
      if (doc.exists) {
        return Club.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  // Get multiple clubs by their IDs (for Profile Page)
  Future<List<Club>> getClubsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    // Firestore 'whereIn' is limited to 10 items.
    // For this MVP, we will just fetch the first 10 if there are more.
    final List<String> chunk = ids.take(10).toList();

    try {
      // FieldPath.documentId allows us to query by the document's key
      final snapshot = await _clubsCollection
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      return snapshot.docs.map((doc) {
        return Club.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      // Return empty list on error during UI prototyping
      return [];
    }
  }

  // Get a club by its Join Code
  Future<Club?> getClubByCode(String code) async {
    try {
      final snapshot = await _clubsCollection
          .where('joinCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        return Club.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
  
  // Update an existing club
  Future<void> updateClub(Club club) async {
    try {
      await _clubsCollection.doc(club.id).update(club.toMap()).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return;
        },
      );
    } catch (e) {
      rethrow;
    }
  }
  
  // Get club members count (for analytics)
  Future<int> getClubMembers(String clubId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('joinedClubIds', arrayContains: clubId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }
  
  // Delete a club and perform cleanup
  Future<void> deleteClub(String clubId, {String? announcement}) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();

    try {
      // 1. Remove Club ID from all members' joinedClubIds
      // Note: In a real large-scale app, this would be done via a Cloud Function
      // to avoid client-side timeouts on large collections.
      final membersSnapshot = await firestore
          .collection('users')
          .where('joinedClubIds', arrayContains: clubId)
          .get();

      for (var doc in membersSnapshot.docs) {
        batch.update(doc.reference, {
          'joinedClubIds': FieldValue.arrayRemove([clubId])
        });
        
        // Optional: Add an announcement/notification document for the user
        if (announcement != null && announcement.isNotEmpty) {
           // This assumes a 'notifications' subcollection or top-level collection exists
           // For now, we'll skip creating documents to avoid cluttering DB without a defined model,
           // but this is where you'd queue the notification.
        }
      }

      // 2. Delete all Events associated with the club
      final eventsSnapshot = await firestore
          .collection('events')
          .where('clubId', isEqualTo: clubId)
          .get();

      for (var doc in eventsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // 3. Delete the Club document itself
      batch.delete(_clubsCollection.doc(clubId));

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  // Get clubs managed by a specific admin
  Future<List<Club>> getClubsByAdmin(String adminId) async {
    try {
      final snapshot = await _clubsCollection
          .where('adminIds', arrayContains: adminId)
          .get();

      return snapshot.docs.map((doc) {
        return Club.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // Alias for getClubsByAdmin to fix build error
  Future<List<Club>> getClubsManagedByUser(String uid) => getClubsByAdmin(uid);

  // --- Member Management Methods ---

  /// Kicks a member from the club
  Future<void> kickMember(String clubId, String uid, String reason) async {
    try {
      // 1. Remove from user's joinedClubIds
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'joinedClubIds': FieldValue.arrayRemove([clubId])
      });

      // 2. Decrement member count
      await _clubsCollection.doc(clubId).update({
         'memberCount': FieldValue.increment(-1),
      });

      // 3. (Optional) Send notification - placeholder for now
      // NotificationService().sendNotification(uid, "You were removed from club", reason);
      
      // 4. Log the kick (optional, for audit)
      await _clubsCollection.doc(clubId).collection('audit_logs').add({
        'action': 'kick',
        'targetUid': uid,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      rethrow;
    }
  }

  /// Assigns an Officer Role (and Admin permissions)
  Future<void> assignOfficerRole(String clubId, String uid, String title, Map<String, bool> permissions) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final clubRef = _clubsCollection.doc(clubId);

      // 1. Add to adminIds (for permissions)
      batch.update(clubRef, {
        'adminIds': FieldValue.arrayUnion([uid])
      });

      // 2. Add to officerRoles map (for UI/Tag)
      batch.update(clubRef, {
        'officerRoles.$uid': title
      });
      
      // 3. Add to officerPermissions map
      batch.update(clubRef, {
        'officerPermissions.$uid': permissions
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }

  /// Removes Officer Role (and Admin permissions)
  Future<void> removeOfficerRole(String clubId, String uid) async {
    try {
      final clubDoc = await _clubsCollection.doc(clubId).get();
      final clubData = clubDoc.data() as Map<String, dynamic>;
      final List<dynamic> adminIds = List.from(clubData['adminIds'] ?? []);

      if (adminIds.length <= 1) {
         throw Exception("Cannot remove the last admin/officer");
      }

      final batch = FirebaseFirestore.instance.batch();
      final clubRef = _clubsCollection.doc(clubId);

      // 1. Remove from adminIds
      batch.update(clubRef, {
        'adminIds': FieldValue.arrayRemove([uid])
      });

      // 2. Remove from officerRoles and permissions maps
      batch.update(clubRef, {
        'officerRoles.$uid': FieldValue.delete(),
        'officerPermissions.$uid': FieldValue.delete(),
      });

      await batch.commit();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Helper to check permissions
  /// permissionKey: 'manageEvents', 'manageMembers', 'manageNotes'
  bool hasPermission(Club club, String uid, String permissionKey) {
    if (!club.adminIds.contains(uid)) return false; // Not admin/officer at all
    
    // Club Creator / First Admin ALWAYS has all permissions logic could go here
    if (club.adminIds.isNotEmpty && club.adminIds.first == uid) return true;
    
    // If no permissions defined for this user (Legacy Admin), default to TRUE
    if (!club.officerPermissions.containsKey(uid)) return true;
    
    // Check specific permission
    final perms = club.officerPermissions[uid];
    return perms != null && perms[permissionKey] == true;
  }

  /// Updates or creates a private admin note for a member
  Future<void> updateMemberNote(String clubId, String uid, String note, String adminUid) async {
    try {
      await _clubsCollection
          .doc(clubId)
          .collection('member_metadata')
          .doc(uid)
          .set({
            'note': note,
            'updatedBy': adminUid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches member metadata (notes, etc.)
  Future<Map<String, dynamic>?> getMemberMetadata(String clubId, String uid) async {
    try {
      final doc = await _clubsCollection
          .doc(clubId)
          .collection('member_metadata')
          .doc(uid)
          .get();
      
      return doc.exists ? doc.data() : null;
    } catch (e) {
      return null;
    }
  }

  // --- Questionnaire Responses ---

  // Get Join Responses
  Future<List<Map<String, dynamic>>> getJoinResponses(String clubId) async {
    try {
      final snapshot = await _clubsCollection
          .doc(clubId)
          .collection('join_responses')
          .orderBy('timestamp', descending: true)
          .get();
          
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // Get Leave Responses
  Future<List<Map<String, dynamic>>> getLeaveResponses(String clubId) async {
    try {
      final snapshot = await _clubsCollection
          .doc(clubId)
          .collection('leave_responses')
          .orderBy('timestamp', descending: true)
          .get();
          
      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      return [];
    }
  }

  // Check if a club name exists
  Future<bool> checkNameAvailability(String name) async {
    try {
      final snapshot = await _clubsCollection
          .where('name', isEqualTo: name)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty; // True if available (empty)
    } catch (e) {
      return true; // Use optimistically
    }
  }
}
