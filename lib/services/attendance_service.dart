import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/attendance.dart';

class AttendanceService {
  final CollectionReference _attendanceCollection =
      FirebaseFirestore.instance.collection('attendance');

  // Check in to an event
  Future<void> checkIn({
    required String eventId,
    required String userId,
    required String userName,
  }) async {
    final attendance = Attendance(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventId: eventId,
      userId: userId,
      userName: userName,
      checkInTime: DateTime.now(),
    );

    await _attendanceCollection.doc(attendance.id).set(attendance.toMap());
  }

  // Get all attendees for an event
  Stream<List<Attendance>> getEventAttendees(String eventId) {
    return _attendanceCollection
        .where('eventId', isEqualTo: eventId)
        // .orderBy('checkInTime', descending: true)  <-- Removed to avoid index error
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime)); // Client-side sort
      return list;
    });
  }

  // Get user's attendance history
  Stream<List<Attendance>> getUserAttendance(String userId) {
    return _attendanceCollection
        .where('userId', isEqualTo: userId)
        // .orderBy('checkInTime', descending: true) <-- Removed to avoid index error
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime)); // Client-side sort
      return list;
    });
  }

  // Check if user has already checked in
  Future<bool> hasCheckedIn(String eventId, String userId) async {
    final snapshot = await _attendanceCollection
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  // Get attendance count for an event
  Future<int> getAttendanceCount(String eventId) async {
    final snapshot = await _attendanceCollection
        .where('eventId', isEqualTo: eventId)
        .get();

    return snapshot.docs.length;
  }
}
