import 'package:flutter/foundation.dart';

@immutable
class AppSettings {
  final bool remindersEnabled;

  const AppSettings({this.remindersEnabled = true});

  AppSettings copyWith({bool? remindersEnabled}) {
    return AppSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }
}
