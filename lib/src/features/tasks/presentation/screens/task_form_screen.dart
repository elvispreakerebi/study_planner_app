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
  final TextEditingController _dueDateController = TextEditingController();
  final TextEditingController _reminderTimeController = TextEditingController();
  DateTime? _dueDate; // start null to enforce required selection
  TimeOfDay? _reminderTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _reminderTimeController.dispose();
    super.dispose();
  }

  OutlineInputBorder _border(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Theme.of(context).colorScheme.outline),
  );

  OutlineInputBorder _focusedBorder(BuildContext context) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(
      color: Theme.of(context).colorScheme.primary,
      width: 2,
    ),
  );

  InputDecoration _decoration({String? hintText, Widget? suffixIcon}) =>
      InputDecoration(
        hintText: hintText,
        border: _border(context),
        enabledBorder: _border(context),
        focusedBorder: _focusedBorder(context),
        errorBorder: _border(context).copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
        focusedErrorBorder: _border(context).copyWith(
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        suffixIcon: suffixIcon,
      );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

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
      setState(() {
        _dueDate = picked;
        _dueDateController.text = picked.toLocal().toString().split(' ').first;
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay now = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? now,
    );
    if (picked != null) {
      setState(() {
        _reminderTime = picked;
        _reminderTimeController.text = picked.format(context);
      });
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
      appBar: AppBar(title: const Text('New task')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _label('Title *'),
            TextFormField(
              controller: _titleController,
              decoration: _decoration(hintText: 'Enter title'),
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Description (optional)'),
            TextFormField(
              controller: _descriptionController,
              decoration: _decoration(hintText: 'Add details...'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _label('Due date *'),
            TextFormField(
              controller: _dueDateController,
              readOnly: true,
              decoration: _decoration(
                hintText: 'Select date',
                suffixIcon: const Icon(Icons.event),
              ),
              onTap: _pickDueDate,
              validator: (String? value) {
                if (_dueDate == null ||
                    _dueDateController.text.trim().isEmpty) {
                  return 'Please select a due date';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            _label('Reminder time (optional)'),
            TextFormField(
              controller: _reminderTimeController,
              readOnly: true,
              decoration: _decoration(
                hintText: 'Set reminder time',
                suffixIcon: const Icon(Icons.alarm),
              ),
              onTap: _pickReminderTime,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('Save task'),
            ),
          ],
        ),
      ),
    );
  }
}
