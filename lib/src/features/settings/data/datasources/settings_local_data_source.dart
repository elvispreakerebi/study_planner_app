import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:study_planner_app/src/core/storage/storage_keys.dart';
import 'package:study_planner_app/src/features/settings/domain/entities/app_settings.dart';

class SettingsLocalDataSourcePrefs {
  SettingsLocalDataSourcePrefs(this._prefs);

  final SharedPreferences _prefs;

  Future<AppSettings> load() async {
    final String? raw = _prefs.getString(StorageKeys.settings);
    if (raw == null || raw.isEmpty) {
      return const AppSettings();
    }
    final Map<String, dynamic> map = json.decode(raw) as Map<String, dynamic>;
    return AppSettings(
      remindersEnabled: map['remindersEnabled'] as bool? ?? true,
    );
  }

  Future<void> save(AppSettings settings) async {
    final Map<String, dynamic> map = <String, dynamic>{
      'remindersEnabled': settings.remindersEnabled,
    };
    await _prefs.setString(StorageKeys.settings, json.encode(map));
  }
}
