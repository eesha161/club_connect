import 'package:club_connect/models/question.dart';
import 'package:flutter/material.dart';

class FormSubmissionScreen extends StatefulWidget {
  final String title;
  final List<Question> questions;
  final Function(Map<String, String>) onSubmit;

  const FormSubmissionScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.onSubmit,
  });

  @override
  State<FormSubmissionScreen> createState() => _FormSubmissionScreenState();
}

class _FormSubmissionScreenState extends State<FormSubmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              ...widget.questions.map((q) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          q.text,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (q.type == 'text')
                          TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Your answer...',
                              border: OutlineInputBorder(),
                            ),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                            onSaved: (val) => _answers[q.id] = val!,
                          )
                        else if (q.type == 'multiple_choice')
                          Column(
                            children: q.options.map((option) {
                              return RadioListTile<String>(
                                title: Text(option),
                                value: option,
                                groupValue: _answers[q.id],
                                onChanged: (val) {
                                  setState(() {
                                    _answers[q.id] = val!;
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        if (q.type == 'multiple_choice' &&
                            !_answers.containsKey(q.id))
                          // Validation warning for radio buttons if needed (visually handled by form validation usually, but custom here)
                          const Padding(
                              padding: EdgeInsets.only(top: 5),
                              child: Text("", style: TextStyle(color: Colors.red))), 
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Manual validation for radio buttons
                    bool allanswered = true;
                    for (var q in widget.questions) {
                       if (q.type == 'multiple_choice' && !_answers.containsKey(q.id)) {
                         allanswered = false;
                       }
                    }

                    if (_formKey.currentState!.validate() && allanswered) {
                      _formKey.currentState!.save();
                      widget.onSubmit(_answers);
                    } else if (!allanswered) {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please answer all questions')));
                    }
                  },
                  child: const Text('Submit'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
