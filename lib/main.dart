import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner_app/src/features/calendar/presentation/widgets/monthly_calendar.dart';
import 'package:study_planner_app/src/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:study_planner_app/src/features/settings/data/repositories/settings_repository_prefs.dart';
import 'package:study_planner_app/src/features/settings/domain/entities/app_settings.dart';
import 'package:study_planner_app/src/features/settings/domain/repositories/settings_repository.dart';
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

  Future<(TaskRepository, SettingsRepository)> _initRepositories() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final TaskLocalDataSourcePrefs taskDs = TaskLocalDataSourcePrefs(prefs);
    final SettingsLocalDataSourcePrefs settingsDs =
        SettingsLocalDataSourcePrefs(prefs);
    return (TaskRepositoryPrefs(taskDs), SettingsRepositoryPrefs(settingsDs));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(TaskRepository, SettingsRepository)>(
      future: _initRepositories(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<(TaskRepository, SettingsRepository)> snapshot,
          ) {
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
            final (TaskRepository taskRepo, SettingsRepository settingsRepo) =
                snapshot.data!;
            final List<Widget> screens = <Widget>[
              TodayScreen(
                taskRepository: taskRepo,
                settingsRepository: settingsRepo,
              ),
              CalendarScreen(repository: taskRepo),
              SettingsScreen(settingsRepository: settingsRepo),
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
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
    );
  }
}

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    super.key,
    required this.taskRepository,
    required this.settingsRepository,
  });

  final TaskRepository taskRepository;
  final SettingsRepository settingsRepository;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  List<Task> _tasks = <Task>[];
  bool _loading = false;
  AppSettings _settings = const AppSettings();
  final Set<String> _surfacedReminderIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeShowReminders();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final DateTime today = DateTime.now();
    final List<Task> tasks = await widget.taskRepository.getForDate(today);
    final AppSettings settings = await widget.settingsRepository.load();
    setState(() {
      _tasks = tasks;
      _settings = settings;
      _loading = false;
    });
    _maybeShowReminders();
  }

  Future<void> _maybeShowReminders() async {
    if (!_settings.remindersEnabled) return;
    final DateTime now = DateTime.now();

    DateTime thresholdFor(Task t) {
      final List<Duration> offsets = <Duration>[];
      if (t.notifyOneHourBefore) offsets.add(const Duration(hours: 1));
      if (t.notifyOneDayBefore) offsets.add(const Duration(days: 1));
      if (offsets.isEmpty)
        return DateTime.fromMillisecondsSinceEpoch(1 << 62); // far future
      final DateTime earliest = offsets
          .map((Duration d) => t.dueDate.subtract(d))
          .reduce((DateTime a, DateTime b) => a.isBefore(b) ? a : b);
      return earliest;
    }

    final List<Task> due = _tasks
        .where(
          (Task t) =>
              !_surfacedReminderIds.contains(t.id) &&
              (t.notifyOneHourBefore || t.notifyOneDayBefore) &&
              now.isAfter(thresholdFor(t)),
        )
        .toList();

    if (due.isEmpty) return;
    _surfacedReminderIds.addAll(due.map((Task t) => t.id));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Reminders'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: due.length,
              itemBuilder: (BuildContext context, int index) {
                final Task task = due[index];
                return ListTile(
                  dense: true,
                  title: Text(task.title),
                  subtitle:
                      task.description != null && task.description!.isNotEmpty
                      ? Text(task.description!)
                      : null,
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openCreateTask() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            TaskFormScreen(repository: widget.taskRepository),
      ),
    );
    if (created == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task created')));
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

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settingsRepository});

  final SettingsRepository settingsRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings _settings = const AppSettings();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppSettings s = await widget.settingsRepository.load();
    setState(() {
      _settings = s;
      _loading = false;
    });
  }

  Future<void> _toggleReminders(bool value) async {
    final AppSettings updated = _settings.copyWith(remindersEnabled: value);
    await widget.settingsRepository.save(updated);
    setState(() => _settings = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SwitchListTile(
            value: _settings.remindersEnabled,
            onChanged: _toggleReminders,
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Reminders'),
            subtitle: const Text('Enable or disable task reminders'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.storage_outlined),
            title: Text('Storage'),
            subtitle: Text('Using shared_preferences'),
          ),
        ],
      ),
    );
  }
}
