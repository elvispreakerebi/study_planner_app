# Study Planner App

A Flutter app that helps students plan and track study tasks. It includes task management, a monthly calendar with sticky date header, reminder surfacing, local persistence (Shared Preferences or SQLite), and a simple settings page to toggle reminders and switch storage backends at runtime.

## Features

- Today tab: View tasks due today; add, edit, delete with undo
- Calendar tab: Scrollable month view with markers; sticky header shows active date; select a date to view tasks
- Task creation/editing: Custom-styled form with date+time picker in a single step and optional reminder offsets (1 hour/day)
- Reminders: On app resume/open, due reminders surface once per session (if enabled)
- Settings: Toggle reminders; choose storage backend (Shared Preferences JSON or SQLite) with live migration and hot-swap

## Project Structure

```
lib/
  main.dart                          # App shell, tab nav, repo bootstrapping, storage migration
  src/
    app/                             # (future routing/theme space)
    core/
      storage/storage_keys.dart      # Preference keys
      utils/date_time_utils.dart     # Date utilities (if needed)
    features/
      tasks/
        domain/
          entities/task.dart         # Task entity (immutable)
          repositories/task_repository.dart
        data/
          models/task_model.dart     # JSON encode/decode for prefs
          datasources/task_local_data_source.dart
          repositories/
            task_repository_prefs.dart
            task_repository_sqlite.dart
        presentation/
          screens/task_form_screen.dart
          widgets/task_card.dart
      calendar/
        presentation/widgets/monthly_calendar.dart
      settings/
        domain/
          entities/app_settings.dart
          repositories/settings_repository.dart
        data/
          datasources/settings_local_data_source.dart
          repositories/settings_repository_prefs.dart
```

## Architecture Overview

- UI (presentation) is kept separate from domain (entities, interfaces) and data (datasources/repositories).
- The app shell (`main.dart`) composes the `TaskRepository` and `SettingsRepository`, wires tabs, and orchestrates storage switching.
- Storage is abstracted behind the `TaskRepository` interface. Two implementations:
  - `TaskRepositoryPrefs`: stores tasks as JSON in Shared Preferences
  - `TaskRepositorySqlite`: stores tasks in SQLite via `sqflite`
- Settings are stored via `SettingsRepositoryPrefs` (Shared Preferences).

## Storage Switching & Migration

- The current storage method is saved in `AppSettings.storageMethod` (`prefs` or `sqlite`).
- On Settings → Storage row, a sheet lets the user pick between Shared Preferences or SQLite.
- When a new method is chosen:
  1. The app migrates by reading all tasks from the active repo and writing them to the destination repo (idempotent by id).
  2. The new method is persisted and the app swaps the active repository in-memory without requiring restart.

## Data Model

`Task` fields:
- id: String (UUID)
- title: String (required)
- description: String? (optional)
- dueDate: DateTime (required; date and time)
- notifyOneHourBefore: bool
- notifyOneDayBefore: bool
- isCompleted: bool
- createdAt: DateTime
- updatedAt: DateTime

`AppSettings` fields:
- remindersEnabled: bool
- storageMethod: String (`prefs` or `sqlite`)

## UI Details

- Task card: Title and "Due at {date • time}"; one-line truncated description; bottom action row with "See more" (if truncated) on the left and edit/delete on the right (16px gap). The details bottom sheet shows full content and actions.
- Calendar view: Top monthly calendar (scrolls with the list). A sticky header appears only after the calendar is scrolled off, showing the active date and a calendar icon to open a calendar sheet.
- Task form: Custom-labeled fields, 20px spacing between inputs, 28px spacing before the primary button. Due uses a single-step bottom-sheet picker (date+time). Validation errors appear only after the first submit.

## Reminders

- If reminders are enabled, when the app resumes/opens Today, the app surfaces a single reminder dialog per session showing tasks whose reminder thresholds have passed (1h/1d before due). The dialog is shown at most once per session, and tasks are deduplicated.

## Accessibility & UX Notes

- Visible focus states on interactive controls; large tap targets.
- Labels above inputs with clear error messages; no reliance on color alone.
- Description truncation provides an explicit "See more" affordance.
- Calendar sticky header provides a quick affordance to reopen the calendar when scrolled.

## How to Run

1. Ensure Flutter SDK is installed.
2. From the project root:

```
flutter pub get
flutter run
```

## Running Tests

```
flutter test
```

The included smoke test boots the app and ensures the Today tab renders.

## Design Choices & Rationale

- Feature-first structure keeps related domain/data/presentation code together and scales well as features grow.
- Repository abstraction enables runtime storage switching and facilitates testing.
- Sticky header is rendered as a lightweight overlay toggled by scroll offset; it avoids layout jitter and remains performant.
- Single-step date+time picker reduces friction compared to two-step flows.

## Extensibility

- Add state management (e.g., Riverpod) to centralize state, if complexity grows.
- Add real local notifications (`flutter_local_notifications`) and background scheduling.
- Add task completion toggle and filtering/sorting.
- Add i18n strings using `intl` and ARB files.

## Key Files with Commentary

- `lib/main.dart`: App shell, navigation, repository bootstrapping, storage migration, sticky header logic.
- `lib/src/features/tasks/domain/entities/task.dart`: Self-documenting immutable entity with copyWith; equality/hashCode implemented.
- `lib/src/features/tasks/presentation/screens/task_form_screen.dart`: Form UX, validation scheduling, combined picker, and edit mode.
- `lib/src/features/tasks/presentation/widgets/task_card.dart`: Task card layout, truncation and details sheet logic.
- `lib/src/features/tasks/data/repositories/task_repository_sqlite.dart`: SQLite schema and row mapping.

## License

This project is for educational purposes.
