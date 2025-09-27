/// TaskRepository implementation backed by Shared Preferences (JSON list).
library;

import 'package:study_planner_app/src/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:study_planner_app/src/features/tasks/data/models/task_model.dart';
import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';
import 'package:study_planner_app/src/features/tasks/domain/repositories/task_repository.dart';

/// Stores and retrieves tasks via a JSON array persisted in Shared Preferences.
class TaskRepositoryPrefs implements TaskRepository {
  TaskRepositoryPrefs(this._ds);

  final TaskLocalDataSourcePrefs _ds;

  /// Appends a task to storage.
  @override
  Future<void> create(Task task) async {
    final List<TaskModel> all = await _ds.readAll();
    final TaskModel model = TaskModel.fromTask(task);
    final List<TaskModel> updated = <TaskModel>[...all, model];
    await _ds.writeAll(updated);
  }

  /// Updates a task by id (creates if missing).
  @override
  Future<void> update(Task task) async {
    final List<TaskModel> all = await _ds.readAll();
    final int index = all.indexWhere((TaskModel m) => m.id == task.id);
    if (index == -1) {
      await create(task);
      return;
    }
    final List<TaskModel> updated = List<TaskModel>.from(all);
    updated[index] = TaskModel.fromTask(task);
    await _ds.writeAll(updated);
  }

  /// Deletes a task by id.
  @override
  Future<void> delete(String id) async {
    final List<TaskModel> all = await _ds.readAll();
    final List<TaskModel> updated = all
        .where((TaskModel m) => m.id != id)
        .toList();
    await _ds.writeAll(updated);
  }

  /// Returns all tasks.
  @override
  Future<List<Task>> getAll() async {
    final List<TaskModel> all = await _ds.readAll();
    return all.map((TaskModel m) => m.toTask()).toList();
  }

  /// Returns tasks whose due date falls on the given calendar day.
  @override
  Future<List<Task>> getForDate(DateTime day) async {
    final List<Task> all = await getAll();
    return all
        .where(
          (Task t) =>
              t.dueDate.year == day.year &&
              t.dueDate.month == day.month &&
              t.dueDate.day == day.day,
        )
        .toList();
  }
}
