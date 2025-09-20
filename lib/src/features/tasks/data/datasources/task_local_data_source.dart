import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner_app/src/core/storage/storage_keys.dart';
import 'package:study_planner_app/src/features/tasks/data/models/task_model.dart';

class TaskLocalDataSourcePrefs {
  TaskLocalDataSourcePrefs(this._prefs);

  final SharedPreferences _prefs;

  Future<List<TaskModel>> readAll() async {
    final String? raw = _prefs.getString(StorageKeys.tasks);
    if (raw == null || raw.isEmpty) {
      return <TaskModel>[];
    }
    return TaskModel.decodeList(raw);
  }

  Future<void> writeAll(List<TaskModel> models) async {
    final String encoded = TaskModel.encodeList(models);
    await _prefs.setString(StorageKeys.tasks, encoded);
  }
}
