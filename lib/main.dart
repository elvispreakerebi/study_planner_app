import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner_app/src/features/calendar/presentation/widgets/monthly_calendar.dart';
import 'package:study_planner_app/src/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:study_planner_app/src/features/tasks/data/repositories/task_repository_prefs.dart';
import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';
import 'package:study_planner_app/src/features/tasks/domain/repositories/task_repository.dart';
import 'package:study_planner_app/src/features/tasks/presentation/screens/task_form_screen.dart';

void main() {
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Study Planner',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
      ),
      home: const AppScaffold(),
    );
  }
}

class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;

  Future<TaskRepository> _initRepository() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final TaskLocalDataSourcePrefs ds = TaskLocalDataSourcePrefs(prefs);
    return TaskRepositoryPrefs(ds);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TaskRepository>(
      future: _initRepository(),
      builder: (BuildContext context, AsyncSnapshot<TaskRepository> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: Text('Failed to initialize storage')),
          );
        }
        final TaskRepository repo = snapshot.data!;
        final List<Widget> screens = <Widget>[
          TodayScreen(repository: repo),
          CalendarScreen(repository: repo),
          SettingsScreen(repository: repo),
        ];
        return Scaffold(
          body: SafeArea(
            child: IndexedStack(index: _currentIndex, children: screens),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.today_outlined),
                activeIcon: Icon(Icons.today),
                label: 'Today',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_outlined),
                activeIcon: Icon(Icons.calendar_month),
                label: 'Calendar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.repository});

  final TaskRepository repository;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Task> _tasks = <Task>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final DateTime today = DateTime.now();
    final List<Task> tasks = await widget.repository.getForDate(today);
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<void> _openCreateTask() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            TaskFormScreen(repository: widget.repository),
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? const Center(child: Text('No tasks for today yet'))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _tasks.length,
              itemBuilder: (BuildContext context, int index) {
                final Task task = _tasks[index];
                return ListTile(
                  leading: Icon(
                    task.isCompleted
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(task.title),
                  subtitle:
                      task.description != null && task.description!.isNotEmpty
                      ? Text(task.description!)
                      : null,
                );
              },
              separatorBuilder: (_, __) => const Divider(height: 1),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository});

  final TaskRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  List<Task> _tasks = <Task>[];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadForDay(_selectedDay);
  }

  Future<void> _loadForDay(DateTime day) async {
    setState(() => _loading = true);
    final List<Task> tasks = await widget.repository.getForDate(day);
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<Set<DateTime>> _loadMarkedDaysForMonth(DateTime month) async {
    final List<Task> all = await widget.repository.getAll();
    final Set<DateTime> days = all
        .map(
          (Task t) => DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day),
        )
        .toSet();
    return days;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Column(
        children: <Widget>[
          FutureBuilder<Set<DateTime>>(
            future: _loadMarkedDaysForMonth(_selectedDay),
            builder:
                (BuildContext context, AsyncSnapshot<Set<DateTime>> snapshot) {
                  final Set<DateTime> marked = snapshot.data ?? <DateTime>{};
                  return MonthlyCalendar(
                    selectedDay: _selectedDay,
                    markedDays: marked,
                    onDaySelected: (DateTime day) {
                      setState(() => _selectedDay = day);
                      _loadForDay(day);
                    },
                  );
                },
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                ? const Center(child: Text('No tasks on this date'))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _tasks.length,
                    itemBuilder: (BuildContext context, int index) {
                      final Task task = _tasks[index];
                      return ListTile(
                        leading: Icon(
                          task.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(task.title),
                        subtitle:
                            task.description != null &&
                                task.description!.isNotEmpty
                            ? Text(task.description!)
                            : null,
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                  ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repository});

  final TaskRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Reminders'),
            subtitle: Text('Enable or disable task reminders'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(),
          ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage'),
            subtitle: Text('Using shared_preferences by default'),
          ),
        ],
      ),
    );
  }
}
