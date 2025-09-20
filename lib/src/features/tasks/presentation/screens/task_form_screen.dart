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
  final TextEditingController _dueController = TextEditingController();
  DateTime? _due; // holds both date and time
  bool _notifyHour = false;
  bool _notifyDay = false;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueController.dispose();
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

  Future<void> _pickDue() async {
    // pick date
    final DateTime now = DateTime.now();
    final DateTime first = DateTime(now.year - 1);
    final DateTime last = DateTime(now.year + 5);
    final DateTime initialDate = _due ?? now;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
    );
    if (pickedDate == null) return;

    // pick time
    final TimeOfDay initialTime = _due != null
        ? TimeOfDay(hour: _due!.hour, minute: _due!.minute)
        : TimeOfDay.now();
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null) return;

    final DateTime combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    setState(() {
      _due = combined;
      _dueController.text =
          '${pickedDate.toLocal().toString().split(' ').first} ${pickedTime.format(context)}';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_due == null) return;

    setState(() => _saving = true);
    final Task task = Task(
      id: const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      dueDate: _due!,
      notifyOneHourBefore: _notifyHour,
      notifyOneDayBefore: _notifyDay,
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
            const SizedBox(height: 20),
            _label('Description (optional)'),
            TextFormField(
              controller: _descriptionController,
              decoration: _decoration(hintText: 'Add details...'),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            _label('Due *'),
            TextFormField(
              controller: _dueController,
              readOnly: true,
              decoration: _decoration(
                hintText: 'Select date and time',
                suffixIcon: const Icon(Icons.event),
              ),
              onTap: _pickDue,
              validator: (String? value) {
                if (_due == null || _dueController.text.trim().isEmpty) {
                  return 'Please select a due date and time';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notify me 1 hour before'),
                    value: _notifyHour,
                    onChanged: (bool v) => setState(() => _notifyHour = v),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Notify me 1 day before'),
                    value: _notifyDay,
                    onChanged: (bool v) => setState(() => _notifyDay = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
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
