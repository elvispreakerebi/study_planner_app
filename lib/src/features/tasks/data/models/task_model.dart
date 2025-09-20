import 'dart:convert';

import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String dueDateIso;
  final bool notifyOneHourBefore;
  final bool notifyOneDayBefore;
  final bool isCompleted;
  final String createdAtIso;
  final String updatedAtIso;

  const TaskModel({
    required this.id,
    required this.title,
    required this.dueDateIso,
    required this.notifyOneHourBefore,
    required this.notifyOneDayBefore,
    required this.isCompleted,
    required this.createdAtIso,
    required this.updatedAtIso,
    this.description,
  });

  factory TaskModel.fromTask(Task task) {
    return TaskModel(
      id: task.id,
      title: task.title,
      description: task.description,
      dueDateIso: task.dueDate.toIso8601String(),
      notifyOneHourBefore: task.notifyOneHourBefore,
      notifyOneDayBefore: task.notifyOneDayBefore,
      isCompleted: task.isCompleted,
      createdAtIso: task.createdAt.toIso8601String(),
      updatedAtIso: task.updatedAt.toIso8601String(),
    );
  }

  Task toTask() {
    return Task(
      id: id,
      title: title,
      description: description,
      dueDate: DateTime.parse(dueDateIso),
      notifyOneHourBefore: notifyOneHourBefore,
      notifyOneDayBefore: notifyOneDayBefore,
      isCompleted: isCompleted,
      createdAt: DateTime.parse(createdAtIso),
      updatedAt: DateTime.parse(updatedAtIso),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDateIso,
      'notifyOneHourBefore': notifyOneHourBefore,
      'notifyOneDayBefore': notifyOneDayBefore,
      'isCompleted': isCompleted,
      'createdAt': createdAtIso,
      'updatedAt': updatedAtIso,
    };
  }

  factory TaskModel.fromMap(Map<String, dynamic> map) {
    return TaskModel(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      dueDateIso: map['dueDate'] as String,
      notifyOneHourBefore: map['notifyOneHourBefore'] as bool? ?? false,
      notifyOneDayBefore: map['notifyOneDayBefore'] as bool? ?? false,
      isCompleted: map['isCompleted'] as bool? ?? false,
      createdAtIso: map['createdAt'] as String,
      updatedAtIso: map['updatedAt'] as String,
    );
  }

  String toJson() => json.encode(toMap());
  factory TaskModel.fromJson(String source) =>
      TaskModel.fromMap(json.decode(source) as Map<String, dynamic>);

  static String encodeList(List<TaskModel> tasks) =>
      json.encode(tasks.map((e) => e.toMap()).toList());
  static List<TaskModel> decodeList(String source) {
    final dynamic decoded = json.decode(source);
    if (decoded is List) {
      return decoded
          .cast<Map<String, dynamic>>()
          .map(TaskModel.fromMap)
          .toList();
    }
    return <TaskModel>[];
  }
}
