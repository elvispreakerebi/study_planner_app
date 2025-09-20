import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';
import 'package:study_planner_app/src/features/tasks/domain/repositories/task_repository.dart';

class TaskRepositorySqlite implements TaskRepository {
  TaskRepositorySqlite(this._db);

  final Database _db;

  static const String _table = 'tasks';

  static Future<TaskRepositorySqlite> open() async {
    final String dbPath = await getDatabasesPath();
    final String path = p.join(dbPath, 'study_planner.db');
    final Database db = await openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
CREATE TABLE $_table (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  description TEXT,
  dueDateIso TEXT NOT NULL,
  notifyOneHourBefore INTEGER NOT NULL,
  notifyOneDayBefore INTEGER NOT NULL,
  isCompleted INTEGER NOT NULL,
  createdAtIso TEXT NOT NULL,
  updatedAtIso TEXT NOT NULL
)
''');
      },
    );
    return TaskRepositorySqlite(db);
  }

  Map<String, Object?> _toRow(Task t) => <String, Object?>{
    'id': t.id,
    'title': t.title,
    'description': t.description,
    'dueDateIso': t.dueDate.toIso8601String(),
    'notifyOneHourBefore': t.notifyOneHourBefore ? 1 : 0,
    'notifyOneDayBefore': t.notifyOneDayBefore ? 1 : 0,
    'isCompleted': t.isCompleted ? 1 : 0,
    'createdAtIso': t.createdAt.toIso8601String(),
    'updatedAtIso': t.updatedAt.toIso8601String(),
  };

  Task _fromRow(Map<String, Object?> row) => Task(
    id: row['id']! as String,
    title: row['title']! as String,
    description: row['description'] as String?,
    dueDate: DateTime.parse(row['dueDateIso']! as String),
    notifyOneHourBefore: (row['notifyOneHourBefore']! as int) == 1,
    notifyOneDayBefore: (row['notifyOneDayBefore']! as int) == 1,
    isCompleted: (row['isCompleted']! as int) == 1,
    createdAt: DateTime.parse(row['createdAtIso']! as String),
    updatedAt: DateTime.parse(row['updatedAtIso']! as String),
  );

  @override
  Future<void> create(Task task) async {
    await _db.insert(
      _table,
      _toRow(task),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> update(Task task) async {
    await _db.update(
      _table,
      _toRow(task),
      where: 'id = ?',
      whereArgs: <Object?>[task.id],
    );
  }

  @override
  Future<void> delete(String id) async {
    await _db.delete(_table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  @override
  Future<List<Task>> getAll() async {
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      orderBy: 'dueDateIso ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<Task>> getForDate(DateTime day) async {
    final DateTime start = DateTime(day.year, day.month, day.day);
    final DateTime end = start.add(const Duration(days: 1));
    final List<Map<String, Object?>> rows = await _db.query(
      _table,
      where: 'dueDateIso >= ? AND dueDateIso < ?',
      whereArgs: <Object?>[start.toIso8601String(), end.toIso8601String()],
      orderBy: 'dueDateIso ASC',
    );
    return rows.map(_fromRow).toList();
  }
}
