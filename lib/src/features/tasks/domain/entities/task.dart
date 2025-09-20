import 'package:flutter/foundation.dart';

/// Immutable task entity representing a study task with due date and reminder flags.
@immutable
class Task {
  /// Unique identifier (UUID).
  final String id;

  /// Short title describing the task.
  final String title;

  /// Optional detailed description.
  final String? description;

  /// Due date and time for the task.
  final DateTime dueDate;

  /// Whether to surface a reminder one hour before due.
  final bool notifyOneHourBefore;

  /// Whether to surface a reminder one day before due.
  final bool notifyOneDayBefore;

  /// Completion flag.
  final bool isCompleted;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.title,
    required this.dueDate,
    this.description,
    this.notifyOneHourBefore = false,
    this.notifyOneDayBefore = false,
    this.isCompleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Returns a new copy of this task with select fields replaced.
  Task copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dueDate,
    bool? notifyOneHourBefore,
    bool? notifyOneDayBefore,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dueDate: dueDate ?? this.dueDate,
      notifyOneHourBefore: notifyOneHourBefore ?? this.notifyOneHourBefore,
      notifyOneDayBefore: notifyOneDayBefore ?? this.notifyOneDayBefore,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Task &&
        other.id == id &&
        other.title == title &&
        other.description == description &&
        other.dueDate == dueDate &&
        other.notifyOneHourBefore == notifyOneHourBefore &&
        other.notifyOneDayBefore == notifyOneDayBefore &&
        other.isCompleted == isCompleted &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    dueDate,
    notifyOneHourBefore,
    notifyOneDayBefore,
    isCompleted,
    createdAt,
    updatedAt,
  );
}
