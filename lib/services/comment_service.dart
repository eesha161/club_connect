import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:club_connect/models/comment.dart';

class CommentService {
  final CollectionReference _commentsCollection =
      FirebaseFirestore.instance.collection('comments');

  // Add a new comment
  Future<void> addComment(Comment comment) async {
    try {
      await _commentsCollection.doc(comment.id).set(comment.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Get comments for a specific entity (Club/Event)
  Stream<List<Comment>> getCommentsForEntity(String entityId) {
    return _commentsCollection
        .where('entityId', isEqualTo: entityId)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs.map((doc) {
        return Comment.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort client-side to avoid needing a Composite Index
      comments.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return comments;
    });
  }
}
