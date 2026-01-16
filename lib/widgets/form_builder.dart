import 'package:club_connect/models/question.dart';
import 'package:flutter/material.dart';

class FormBuilder extends StatefulWidget {
  final List<Question> questions;
  final Function(List<Question>) onChanged;
  final bool isEnabled; // Visual toggle state if needed, or purely list management

  const FormBuilder({
    super.key,
    required this.questions,
    required this.onChanged,
    this.isEnabled = true,
  });

  @override
  State<FormBuilder> createState() => _FormBuilderState();
}

class _FormBuilderState extends State<FormBuilder> {
  late List<Question> _questions;

  @override
  void initState() {
    super.initState();
    _questions = List.from(widget.questions);
  }

  void _addQuestion(Question q) {
    setState(() {
      _questions.add(q);
      widget.onChanged(_questions);
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions.removeAt(index);
      widget.onChanged(_questions);
    });
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AddQuestionDialog(
        onAdd: _addQuestion,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();

    return Column(
      children: [
        ..._questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(q.text),
              subtitle: Text('Type: ${_formatType(q.type)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _removeQuestion(index),
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: _showAddDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Question'),
        ),
      ],
    );
  }

  String _formatType(String type) {
    if (type == 'text') return 'Free Response';
    if (type == 'multiple_choice') return 'Multiple Choice';
    return type;
  }
}

class AddQuestionDialog extends StatefulWidget {
  final Function(Question) onAdd;
  const AddQuestionDialog({super.key, required this.onAdd});

  @override
  State<AddQuestionDialog> createState() => _AddQuestionDialogState();
}

class _AddQuestionDialogState extends State<AddQuestionDialog> {
  final _textController = TextEditingController();
  String _type = 'text'; // 'text' or 'multiple_choice'
  final _optionsController = TextEditingController(); // Comma separated for simplicity

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Question'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(labelText: 'Question Text'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'text', child: Text('Free Response')),
                DropdownMenuItem(value: 'multiple_choice', child: Text('Multiple Choice')),
              ],
              onChanged: (val) => setState(() => _type = val!),
              decoration: const InputDecoration(labelText: 'Question Type'),
            ),
            if (_type == 'multiple_choice')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: _optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma separated)',
                    hintText: 'Option A, Option B...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_textController.text.isEmpty) return;

            final q = Question(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: _textController.text,
              type: _type,
              options: _type == 'multiple_choice'
                  ? _optionsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
                  : [],
            );
            widget.onAdd(q);
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
