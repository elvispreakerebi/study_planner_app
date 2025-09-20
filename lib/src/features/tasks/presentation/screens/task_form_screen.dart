import 'package:flutter/material.dart';
import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';
import 'package:study_planner_app/src/features/tasks/domain/repositories/task_repository.dart';
import 'package:uuid/uuid.dart';

class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, required this.repository});

  final TaskRepository repository;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  DateTime? _dueDate = DateTime.now();
  TimeOfDay? _reminderTime;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year - 1);
    final DateTime last = DateTime(now.year + 5);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay now = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? now,
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dueDate == null) return;

    DateTime? reminderDateTime;
    if (_reminderTime != null) {
      final DateTime date = _dueDate!;
      reminderDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        _reminderTime!.hour,
        _reminderTime!.minute,
      );
      if (reminderDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder time must be in the future')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final Task task = Task(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dueDate: _dueDate!,
      reminderTime: reminderDateTime,
    );
    await widget.repository.create(task);
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Task')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title *'),
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(
                _dueDate == null
                    ? 'Pick due date'
                    : _dueDate!.toLocal().toString().split(' ').first,
              ),
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.alarm),
              title: Text(
                _reminderTime == null
                    ? 'Set reminder (optional)'
                    : _reminderTime!.format(context),
              ),
              onTap: _pickReminderTime,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save Task'),
            ),
          ],
        ),
      ),
    );
  }
}
