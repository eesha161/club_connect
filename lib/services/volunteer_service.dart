// This service calculates hours and records when people check in/out.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/volunteer_record.dart';
import 'package:club_connect/models/volunteer_shift.dart';

class VolunteerService {
  final CollectionReference _volunteerRecordsCollection =
      FirebaseFirestore.instance.collection('volunteer_records');

  /// Check in a volunteer for their shift
  Future<VolunteerRecord> checkInVolunteer({
    required String eventId,
    required String userId,
    required String shiftId,
  }) async {
    try {
      final recordId = '${eventId}_$userId';
      
      // Check if already checked in
      final existing = await _volunteerRecordsCollection.doc(recordId).get();
      if (existing.exists) {
        final record = VolunteerRecord.fromMap(existing.data() as Map<String, dynamic>, recordId);
        if (record.checkOutTime == null) {
          throw Exception('Already checked in. Please check out first.');
        }
      }

      final record = VolunteerRecord(
        id: recordId,
        userId: userId,
        eventId: eventId,
        shiftId: shiftId,
        checkInTime: DateTime.now(),
      );

      await _volunteerRecordsCollection.doc(recordId).set(record.toMap());
      
      // Also update event's checkedInIds
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
        'checkedInIds': FieldValue.arrayUnion([userId])
      });

      return record;
    } catch (e) {
      rethrow;
    }
  }

  /// Check out a volunteer and calculate hours
  Future<VolunteerRecord> checkOutVolunteer({
    required String eventId,
    required String userId,
  }) async {
    try {
      final recordId = '${eventId}_$userId';
      final doc = await _volunteerRecordsCollection.doc(recordId).get();
      
      if (!doc.exists) {
        throw Exception('No check-in record found. Please check in first.');
      }

      final record = VolunteerRecord.fromMap(doc.data() as Map<String, dynamic>, recordId);
      
      if (record.checkOutTime != null) {
        throw Exception('Already checked out.');
      }

      final updatedRecord = record.copyWith(
        checkOutTime: DateTime.now(),
      );

      await _volunteerRecordsCollection.doc(recordId).update({
        'checkOutTime': Timestamp.fromDate(updatedRecord.checkOutTime!),
      });

      // Update event's checkOutIds
      await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .update({
        'checkOutIds': FieldValue.arrayUnion([userId])
      });

      return updatedRecord;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all volunteer records for a user
  Stream<List<VolunteerRecord>> getUserVolunteerRecords(String userId) {
    return _volunteerRecordsCollection
        .where('userId', isEqualTo: userId)
        // .orderBy('checkInTime', descending: true) // Removed to avoid index requirement
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((doc) => VolunteerRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      
      // Sort client-side to avoid needing a composite index
      records.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      
      return records;
    });
  }

  /// Get volunteer record for a specific event
  Future<VolunteerRecord?> getVolunteerRecord(String eventId, String userId) async {
    try {
      final recordId = '${eventId}_$userId';
      final doc = await _volunteerRecordsCollection.doc(recordId).get();
      
      if (!doc.exists) return null;
      
      return VolunteerRecord.fromMap(doc.data() as Map<String, dynamic>, recordId);
    } catch (e) {
      return null;
    }
  }

  /// Get all volunteer records for an event
  Stream<List<VolunteerRecord>> getEventVolunteerRecords(String eventId) {
    return _volunteerRecordsCollection
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => VolunteerRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Calculate total volunteer hours for a user
  Future<double> getTotalVolunteerHours(String userId) async {
    try {
      final snapshot = await _volunteerRecordsCollection
          .where('userId', isEqualTo: userId)
          .get();

      double totalHours = 0.0;
      for (var doc in snapshot.docs) {
        final record = VolunteerRecord.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        totalHours += record.hoursEarned;
      }

      return totalHours;
    } catch (e) {
      return 0.0;
    }
  }

  /// Mark verification email as sent
  Future<void> markEmailSent(String recordId) async {
    try {
      await _volunteerRecordsCollection.doc(recordId).update({
        'emailSent': true,
      });
    } catch (e) {
    }
  }

  Future<void> signUpForShift({
    required String eventId,
    required String userId,
    required String shiftId,
  }) async {
    try {
      final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) throw Exception('Event not found');

        final shifts = List<Map<String, dynamic>>.from(eventDoc.data()!['volunteerShifts'] ?? []);
        bool found = false;

        for (var i = 0; i < shifts.length; i++) {
          if (shifts[i]['id'] == shiftId) {
            found = true;
            final shift = VolunteerShift.fromMap(shifts[i]);
            
            if (shift.isFull) throw Exception('Shift is full');
            if (shift.signedUpIds.contains(userId)) throw Exception('Already signed up');

            final newIds = List<String>.from(shift.signedUpIds)..add(userId);
            shifts[i]['signedUpIds'] = newIds;
            break;
          }
        }

        if (!found) throw Exception('Shift not found');

        transaction.update(eventRef, {
          'volunteerShifts': shifts,
          'attendeeIds': FieldValue.arrayUnion([userId]), // Add to main event list 
        });
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Leave a volunteer shift
  Future<void> leaveShift({
    required String eventId,
    required String userId,
    required String shiftId,
  }) async {
    try {
      final eventRef = FirebaseFirestore.instance.collection('events').doc(eventId);
      
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final eventDoc = await transaction.get(eventRef);
        if (!eventDoc.exists) throw Exception('Event not found');

        final shifts = List<Map<String, dynamic>>.from(eventDoc.data()!['volunteerShifts'] ?? []);
        bool userStillInOtherShifts = false;
        
        // Find and update the shift
        for (var i = 0; i < shifts.length; i++) {
          final shift = VolunteerShift.fromMap(shifts[i]);
          
          if (shift.id == shiftId) {
            // Remove user from target shift
            if (shift.signedUpIds.contains(userId)) {
              final newIds = List<String>.from(shift.signedUpIds)..remove(userId);
              shifts[i]['signedUpIds'] = newIds;
            }
          } else {
            // Check if user is in this other shift
            if (shift.signedUpIds.contains(userId)) {
              userStillInOtherShifts = true;
            }
          }
        }

        transaction.update(eventRef, {'volunteerShifts': shifts});
        
        // If user is not in ANY remaining shifts, remove from main attendee list
        if (!userStillInOtherShifts) {
           transaction.update(eventRef, {
            'attendeeIds': FieldValue.arrayRemove([userId])
          });
        }
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Assign a strike to a volunteer
  Future<void> assignStrike({
    required String userId,
    required String clubId,
    required String reason,
  }) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
      
      final strikeData = {
        'date': Timestamp.now(),
        'clubId': clubId,
        'reason': reason,
      };

      await userRef.update({
        'strikeHistory': FieldValue.arrayUnion([strikeData]),
      });
      
    } catch (e) {
      rethrow;
    }
  }
  /// Manually award hours (e.g., if admin forgot check-out)
  Future<void> manuallyAwardHours({
    required String eventId,
    required String userId,
    required String shiftId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final recordId = '${eventId}_$userId';
      
      // Overwrite or create record
      final record = VolunteerRecord(
        id: recordId,
        userId: userId,
        eventId: eventId,
        shiftId: shiftId,
        checkInTime: startTime,
        checkOutTime: endTime,
        emailSent: false, // Reset verification email status since we modified it
      );

      await _volunteerRecordsCollection.doc(recordId).set(record.toMap());

      // Ensure they are marked as checked in/out in event
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'checkedInIds': FieldValue.arrayUnion([userId]),
        'checkOutIds': FieldValue.arrayUnion([userId]),
      });

    } catch (e) {
      rethrow;
    }
  }
}
