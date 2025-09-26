// Study Planner App entrypoint and app shell.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner_app/src/features/calendar/presentation/widgets/monthly_calendar.dart';
import 'package:study_planner_app/src/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:study_planner_app/src/features/settings/data/repositories/settings_repository_prefs.dart';
import 'package:study_planner_app/src/features/settings/domain/entities/app_settings.dart';
import 'package:study_planner_app/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:study_planner_app/src/features/tasks/data/datasources/task_local_data_source.dart';
import 'package:study_planner_app/src/features/tasks/data/repositories/task_repository_prefs.dart';
import 'package:study_planner_app/src/features/tasks/data/repositories/task_repository_sqlite.dart';
import 'package:study_planner_app/src/features/tasks/domain/entities/task.dart';
import 'package:study_planner_app/src/features/tasks/domain/repositories/task_repository.dart';
import 'package:study_planner_app/src/features/tasks/presentation/screens/task_form_screen.dart';
import 'package:study_planner_app/src/features/tasks/presentation/widgets/task_card.dart';

/// Root widget configuring Material 3 theme and the tab scaffold.
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

/// Hosts the bottom navigation and wires repositories into screens.
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _currentIndex = 0;
  (TaskRepository, SettingsRepository)? _repos;

  /// Initializes repositories based on saved storage method.
  Future<(TaskRepository, SettingsRepository)> _initRepositories() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final TaskLocalDataSourcePrefs taskDs = TaskLocalDataSourcePrefs(prefs);
    final SettingsLocalDataSourcePrefs settingsDs =
        SettingsLocalDataSourcePrefs(prefs);
    final SettingsRepository settingsRepo = SettingsRepositoryPrefs(settingsDs);
    final AppSettings settings = await settingsRepo.load();

    TaskRepository taskRepo;
    if (settings.storageMethod == 'sqlite') {
      taskRepo = await TaskRepositorySqlite.open();
    } else {
      taskRepo = TaskRepositoryPrefs(taskDs);
    }
    return (taskRepo, settingsRepo);
  }

  Future<void> _ensureRepos() async {
    if (_repos == null) {
      _repos = await _initRepositories();
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureRepos();
  }

  /// Migrates tasks between storage backends and hot-swaps the active repo.
  Future<void> _maybeMigrateStorage(String newMethod) async {
    if (_repos == null) return;
    final (TaskRepository currentTaskRepo, SettingsRepository settingsRepo) =
        _repos!;
    final AppSettings settings = await settingsRepo.load();
    if (settings.storageMethod == newMethod) return;

    final TaskRepository destinationRepo = newMethod == 'sqlite'
        ? await TaskRepositorySqlite.open()
        : TaskRepositoryPrefs(
            TaskLocalDataSourcePrefs(await SharedPreferences.getInstance()),
          );

    final List<Task> all = await currentTaskRepo.getAll();
    for (final Task t in all) {
      await destinationRepo.delete(t.id);
      await destinationRepo.create(t);
    }

    final AppSettings updated = settings.copyWith(storageMethod: newMethod);
    await settingsRepo.save(updated);

    _repos = (destinationRepo, settingsRepo);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_repos == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final (TaskRepository taskRepo, SettingsRepository settingsRepo) = _repos!;

    final List<Widget> screens = <Widget>[
      TodayScreen(taskRepository: taskRepo, settingsRepository: settingsRepo),
      CalendarScreen(repository: taskRepo),
      SettingsScreen(
        settingsRepository: settingsRepo,
        onStorageChanged: _maybeMigrateStorage,
      ),
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
  }
}

/// Displays tasks due today and surfaces reminders.
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
  bool _remindersDialogShown = false;

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
    if (mounted) {
      setState(() => _loading = true);
    }
    final DateTime today = DateTime.now();
    final List<Task> tasks = await widget.taskRepository.getForDate(today);
    final AppSettings settings = await widget.settingsRepository.load();
    if (!mounted) return;
    setState(() {
      _tasks = tasks;
      _settings = settings;
      _loading = false;
    });
    _maybeShowReminders();
  }

  Future<void> _maybeShowReminders() async {
    if (_remindersDialogShown) return;
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
    _remindersDialogShown = true;
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
    final Task? created = await Navigator.of(context).push<Task>(
      MaterialPageRoute<Task>(
        fullscreenDialog: true,
        builder: (BuildContext context) =>
            TaskFormScreen(repository: widget.taskRepository),
      ),
    );
    if (created != null) {
      await _load();
      if (!mounted) return;
      final DateTime now = DateTime.now();
      final bool isToday =
          created.dueDate.year == now.year &&
          created.dueDate.month == now.month &&
          created.dueDate.day == now.day;
      final String msg = isToday
          ? 'New task saved'
          : 'New task saved, check calendar';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              itemCount: _tasks.length,
              itemBuilder: (BuildContext context, int index) {
                final Task task = _tasks[index];
                return TaskCard(
                  task: task,
                  onEdit: () async {
                    final Task? updated = await Navigator.of(context)
                        .push<Task>(
                          MaterialPageRoute<Task>(
                            fullscreenDialog: true,
                            builder: (BuildContext context) => TaskFormScreen(
                              repository: widget.taskRepository,
                              initial: task,
                            ),
                          ),
                        );
                    if (updated != null) {
                      await _load();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task updated')),
                      );
                    }
                  },
                  onDelete: () async {
                    final bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) => AlertDialog(
                        title: const Text('Delete task?'),
                        content: const Text('This action cannot be undone.'),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      final Task deleted = task;
                      await widget.taskRepository.delete(task.id);
                      await _load();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Task deleted'),
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () async {
                              await widget.taskRepository.create(deleted);
                              await _load();
                            },
                          ),
                        ),
                      );
                    }
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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
  final ScrollController _scrollController = ScrollController();
  bool _showSticky = false;

  @override
  void initState() {
    super.initState();
    _loadForDay(_selectedDay);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Threshold at which sticky header appears (approx calendar height)
    const double threshold = 320;
    final bool shouldShow =
        _scrollController.hasClients && _scrollController.offset > threshold;
    if (shouldShow != _showSticky) {
      setState(() => _showSticky = shouldShow);
    }
  }

  Future<void> _loadForDay(DateTime day) async {
    setState(() => _loading = true);
    final List<Task> tasks = await widget.repository.getForDate(day);
    setState(() {
      _tasks = tasks;
      _loading = false;
    });
  }

  Future<Set<DateTime>> _loadMarkedDays() async {
    final List<Task> all = await widget.repository.getAll();
    final Set<DateTime> days = all
        .map(
          (Task t) => DateTime(t.dueDate.year, t.dueDate.month, t.dueDate.day),
        )
        .toSet();
    return days;
  }

  Future<void> _openCalendarSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: FutureBuilder<Set<DateTime>>(
              future: _loadMarkedDays(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<Set<DateTime>> snapshot,
                  ) {
                    final Set<DateTime> marked = snapshot.data ?? <DateTime>{};
                    return MonthlyCalendar(
                      selectedDay: _selectedDay,
                      markedDays: marked,
                      onDaySelected: (DateTime day) {
                        setState(() => _selectedDay = day);
                        _loadForDay(day);
                        Navigator.of(context).pop();
                      },
                    );
                  },
            ),
          ),
        );
      },
    );
  }

  String _stickyDateText() {
    return DateFormat('EEE, MMM d, y').format(_selectedDay);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Stack(
        children: <Widget>[
          CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: FutureBuilder<Set<DateTime>>(
                  future: _loadMarkedDays(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<Set<DateTime>> snapshot,
                      ) {
                        final Set<DateTime> marked =
                            snapshot.data ?? <DateTime>{};
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: MonthlyCalendar(
                            selectedDay: _selectedDay,
                            markedDays: marked,
                            onDaySelected: (DateTime day) {
                              setState(() => _selectedDay = day);
                              _loadForDay(day);
                            },
                          ),
                        );
                      },
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_tasks.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('No tasks on this date')),
                )
              else
                SliverList.separated(
                  itemCount: _tasks.length,
                  itemBuilder: (BuildContext context, int index) {
                    final Task task = _tasks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: TaskCard(
                        task: task,
                        onEdit: () async {
                          final Task? updated = await Navigator.of(context)
                              .push<Task>(
                                MaterialPageRoute<Task>(
                                  fullscreenDialog: true,
                                  builder: (BuildContext context) =>
                                      TaskFormScreen(
                                        repository: widget.repository,
                                        initial: task,
                                      ),
                                ),
                              );
                          if (updated != null) {
                            await _loadForDay(_selectedDay);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Task updated')),
                            );
                          }
                        },
                        onDelete: () async {
                          final bool? confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) => AlertDialog(
                              title: const Text('Delete task?'),
                              content: const Text(
                                'This action cannot be undone.',
                              ),
                              actions: <Widget>[
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            final Task deleted = task;
                            await widget.repository.delete(task.id);
                            await _loadForDay(_selectedDay);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Task deleted'),
                                action: SnackBarAction(
                                  label: 'Undo',
                                  onPressed: () async {
                                    await widget.repository.create(deleted);
                                    await _loadForDay(_selectedDay);
                                  },
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                ),
            ],
          ),
          if (_showSticky)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 2,
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.event, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _stickyDateText(),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Open calendar',
                        onPressed: _openCalendarSheet,
                        icon: const Icon(Icons.calendar_month_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settingsRepository,
    this.onStorageChanged,
  });

  final SettingsRepository settingsRepository;
  final Future<void> Function(String method)? onStorageChanged;

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

  Future<void> _openStorageSheet() async {
    await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.save_outlined),
                title: const Text('Shared Preferences'),
                subtitle: const Text('Store tasks as JSON (simpler)'),
                trailing: _settings.storageMethod == 'prefs'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, 'prefs'),
              ),
              const Divider(height: 0),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('SQLite (sqflite)'),
                subtitle: const Text('Store tasks in a table (advanced)'),
                trailing: _settings.storageMethod == 'sqlite'
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(context, 'sqlite'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).then((String? method) async {
      if (method == null || method == _settings.storageMethod) return;
      // Migrate and swap via callback
      if (widget.onStorageChanged != null) {
        await widget.onStorageChanged!(method);
      }
      final AppSettings updated = _settings.copyWith(storageMethod: method);
      await widget.settingsRepository.save(updated);
      if (!mounted) return;
      setState(() => _settings = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Storage set to ${method == 'prefs' ? 'Shared Preferences' : 'SQLite'}',
          ),
        ),
      );
    });
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
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: const Text('Storage'),
            subtitle: Text(
              _settings.storageMethod == 'sqlite'
                  ? 'SQLite (sqflite)'
                  : 'Shared Preferences',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openStorageSheet,
          ),
        ],
      ),
    );
  }
}
