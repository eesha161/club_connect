import 'package:club_connect/models/question.dart';

class ClubForm {
  final bool isEnabled;
  final List<Question> questions;

  ClubForm({
    required this.isEnabled,
    required this.questions,
  });

  Map<String, dynamic> toMap() {
    return {
      'isEnabled': isEnabled,
      'questions': questions.map((q) => q.toMap()).toList(),
    };
  }

  factory ClubForm.fromMap(Map<String, dynamic> map) {
    return ClubForm(
      isEnabled: map['isEnabled'] ?? false,
      questions: (map['questions'] as List<dynamic>?)
              ?.map((q) => Question.fromMap(q as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
