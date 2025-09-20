import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
  });

  final Task task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatDue(DateTime dt) {
    final DateFormat df = DateFormat('EEE, MMM d • h:mm a');
    return 'Due at ${df.format(dt)}';
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDelete();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(Icons.event, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _formatDue(task.dueDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (task.description != null && task.description!.isNotEmpty)
                Text(task.description!)
              else
                const Text('No description'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  bool _doesOverflowSingleLine(
    BuildContext context,
    String text,
    double maxWidth,
  ) {
    final TextStyle style =
        Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    final TextPainter tp = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final String dueText = _formatDue(task.dueDate);
    final String description = task.description ?? '';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool showSeeMore =
                description.isNotEmpty &&
                _doesOverflowSingleLine(
                  context,
                  description,
                  constraints.maxWidth - 24,
                ); // padding allowance

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(dueText, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                if (description.isNotEmpty)
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'No description',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    if (showSeeMore)
                      TextButton(
                        onPressed: () => _showDetails(context),
                        child: const Text('See more'),
                      )
                    else
                      const SizedBox.shrink(),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
