import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';

abstract class TaskRepository {
  Future<void> create(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
  Future<List<Task>> getAll();
  Future<List<Task>> getForDate(DateTime day);
}
