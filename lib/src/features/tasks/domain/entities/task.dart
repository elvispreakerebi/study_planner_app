import 'package:flutter/foundation.dart';

@immutable
class Task {
  final String id;
  final String title;
  final String? description;
  // dueDate holds both date and time
  final DateTime dueDate;
  final bool notifyOneHourBefore;
  final bool notifyOneDayBefore;
  final bool isCompleted;
  final DateTime createdAt;
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
