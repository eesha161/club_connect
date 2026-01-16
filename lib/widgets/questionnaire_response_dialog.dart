import 'package:club_connect/models/club_form.dart';
import 'package:flutter/material.dart';

class QuestionnaireResponseDialog extends StatefulWidget {
  final Map<String, dynamic> formMap;
  final String title;
  final String? submitLabel;

  const QuestionnaireResponseDialog({
    super.key,
    required this.formMap,
    this.title = 'Questionnaire',
    this.submitLabel,
  });

  @override
  State<QuestionnaireResponseDialog> createState() => _QuestionnaireResponseDialogState();
}

class _QuestionnaireResponseDialogState extends State<QuestionnaireResponseDialog> {
  late ClubForm _form;
  final Map<String, String> _answers = {};
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _form = ClubForm.fromMap(widget.formMap);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _form.questions.map((q) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.text, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (q.type == 'text')
                      TextFormField(
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Required';
                          return null;
                        },
                        onSaved: (val) => _answers[q.id] = val!,
                      )
                    else if (q.type == 'multiple_choice')
                      DropdownButtonFormField<String>(
                        items: q.options.map((opt) {
                          return DropdownMenuItem(value: opt, child: Text(opt));
                        }).toList(),
                        onChanged: (val) {},
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        validator: (val) => val == null ? 'Required' : null,
                        onSaved: (val) => _answers[q.id] = val!,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context), // Return null (Cancel)
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              Navigator.pop(context, _answers); // Return answers
            }
          },
          child: Text(widget.submitLabel ?? 'Submit'),
        ),
      ],
    );
  }
}
