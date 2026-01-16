// This service manages events, including creating them and tracking attendees.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/event.dart';

class EventService {
  final CollectionReference _eventsCollection =
      FirebaseFirestore.instance.collection('events');

  // Create a new event
  Future<void> createEvent(Event event) async {
    try {
      await _eventsCollection.doc(event.id).set(event.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Get ALL events (Sorted by date)
  Stream<List<Event>> getAllEvents() {
    return _eventsCollection
        .orderBy('date', descending: false) // Soonest events first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Event.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  // Get events for a specific Club
  Stream<List<Event>> getEventsForClub(String clubId) {
    return _eventsCollection
        .where('clubId', isEqualTo: clubId)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map((doc) => Event.fromMap(doc.data() as Map<String, dynamic>, doc.id))
              .toList();
          events.sort((a, b) => a.date.compareTo(b.date)); // Client-side sort
          return events;
    });
  }

  // Update existing event
  Future<void> updateEvent(Event event) async {
    try {
      await _eventsCollection.doc(event.id).update(event.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // RSVP to an event (Handles Capacity & Waitlist)
  Future<void> rsvpToEvent(String eventId, String uid, {Map<String, String>? answers}) async {
    final eventRef = _eventsCollection.doc(eventId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(eventRef);
      if (!snapshot.exists) throw Exception('Event not found');
      
      final data = snapshot.data() as Map<String, dynamic>;
      final event = Event.fromMap(data, eventId);
      
      if (event.attendeeIds.contains(uid)) return; // Already joined
      if (event.waitlist.contains(uid)) return; // Already on waitlist
     
      // Check Capacity
      if (event.maxAttendees != null && event.attendeeIds.length >= event.maxAttendees!) {
         // Join Waitlist
         transaction.update(eventRef, {
           'waitlist': FieldValue.arrayUnion([uid])
         });
      } else {
         // Join Main List
         transaction.update(eventRef, {
           'attendeeIds': FieldValue.arrayUnion([uid])
         });
         
         // Save Questionnaire Responses
         if (answers != null && answers.isNotEmpty) {
           final responsesRef = eventRef.collection('signup_responses').doc(uid);
           transaction.set(responsesRef, {
              'uid': uid,
              'answers': answers,
              'timestamp': FieldValue.serverTimestamp(),
           });
         }
      }
    });
  }
  
  // Delete an event
  Future<void> deleteEvent(String eventId) async {
    try {
      // 1. Delete all signup responses (Subcollection)
      // Firestore does not automatically delete subcollections
      final responsesSnapshot = await _eventsCollection.doc(eventId).collection('signup_responses').get();
      for (var doc in responsesSnapshot.docs) {
        await doc.reference.delete();
      }
      
      // 2. Delete the event document
      await _eventsCollection.doc(eventId).delete().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          return;
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  // Remove a user from an event (Leave/Un-RSVP)
  Future<void> removeUserFromEvent(String eventId, String userId) async {
    final eventRef = _eventsCollection.doc(eventId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
       final snapshot = await transaction.get(eventRef);
       if (!snapshot.exists) return; // Event might be deleted

       final event = Event.fromMap(snapshot.data() as Map<String, dynamic>, eventId);
       
       if (event.waitlist.contains(userId)) {
          // Just remove from waitlist
          transaction.update(eventRef, {
            'waitlist': FieldValue.arrayRemove([userId])
          });
       } else if (event.attendeeIds.contains(userId)) {
          // Remove from attendees
          transaction.update(eventRef, {
            'attendeeIds': FieldValue.arrayRemove([userId])
          });
          
          // Promote from waitlist if any
          if (event.waitlist.isNotEmpty) {
             final nextUserId = event.waitlist.first;
             // Remove from waitlist AND Add to attendees
             transaction.update(eventRef, {
               'waitlist': FieldValue.arrayRemove([nextUserId]),
               'attendeeIds': FieldValue.arrayUnion([nextUserId])
             });
             // Note: Questionnaire responses for 'nextUserId' (if any) are already preserved since we didn't delete them.
             // Ideally we might notify them here.
          }
       }
    });
  }

  // Toggle Check-In status for a user
  Future<void> toggleCheckIn(String eventId, String userId, bool isCheckedIn) async {
    try {
      if (isCheckedIn) {
        // Add to checkedInIds
        await _eventsCollection.doc(eventId).update({
          'checkedInIds': FieldValue.arrayUnion([userId])
        });
      } else {
        // Remove from checkedInIds
        await _eventsCollection.doc(eventId).update({
          'checkedInIds': FieldValue.arrayRemove([userId])
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get all questionnaire responses for an event
  Future<Map<String, Map<String, dynamic>>> getQuestionnaireResponses(String eventId) async {
    try {
      final snapshot = await _eventsCollection
          .doc(eventId)
          .collection('signup_responses')
          .get();
      
      final Map<String, Map<String, dynamic>> responses = {};
      for (var doc in snapshot.docs) {
        responses[doc.id] = doc.data();
      }
      return responses;
    } catch (e) {
      return {};
    }
  }

  // Get stats for a member in a club (Signed Up vs Attended Count)
  Future<Map<String, int>> getMemberStats(String clubId, String userId) async {
    try {
      final querySnapshot = await _eventsCollection
          .where('clubId', isEqualTo: clubId)
          .get();

      int signedUp = 0;
      int attended = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final attendeeIds = List<String>.from(data['attendeeIds'] ?? []);
        final checkedInIds = List<String>.from(data['checkedInIds'] ?? []);

        if (attendeeIds.contains(userId)) {
          signedUp++;
        }
        if (checkedInIds.contains(userId)) {
          attended++;
        }
      }

      return {
        'signedUp': signedUp,
        'attended': attended,
      };
    } catch (e) {
      return {'signedUp': 0, 'attended': 0};
    }
  }
}
