import 'package:study_planner_app/src/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:study_planner_app/src/features/settings/domain/entities/app_settings.dart';
import 'package:study_planner_app/src/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryPrefs implements SettingsRepository {
  SettingsRepositoryPrefs(this._ds);

  final SettingsLocalDataSourcePrefs _ds;

  @override
  Future<AppSettings> load() => _ds.load();

  @override
  Future<void> save(AppSettings settings) => _ds.save(settings);
}
