class Question {
  final String id;
  final String text;
  final String type; // 'text' or 'multiple_choice'
  final List<String> options; // Only for multiple_choice

  Question({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'type': type,
      'options': options,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      options: List<String>.from(map['options'] ?? []),
    );
  }
}
