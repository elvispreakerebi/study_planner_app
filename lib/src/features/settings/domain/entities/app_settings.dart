import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  final bool remindersEnabled;
  final String storageMethod; // 'prefs' or 'sqlite'

  const AppSettings({
    this.remindersEnabled = true,
    this.storageMethod = 'prefs',
  });

  AppSettings copyWith({bool? remindersEnabled, String? storageMethod}) {
    return AppSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      storageMethod: storageMethod ?? this.storageMethod,
    );
  }
}
