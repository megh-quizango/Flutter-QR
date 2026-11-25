import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings {
  const Settings({
    this.beep = true,
    this.vibrate = true,
    this.autoCopy = false,
    this.autoOpen = false,
    this.saveHistory = true,
    this.inAppBrowser = true,
    this.brandedShare = true,
    this.theme = ThemeMode.system,
  });

  final bool beep, vibrate, autoCopy, autoOpen, saveHistory, inAppBrowser;
  final bool brandedShare; // "Made with ScanLight" footer on shared codes
  final ThemeMode theme;

  /// Reads prefs; any bad value falls back to the default (NFR-6).
  factory Settings.load(SharedPreferences p) {
    bool b(String k, bool d) {
      try {
        return p.getBool(k) ?? d;
      } catch (_) {
        return d;
      }
    }

    ThemeMode t;
    try {
      t = ThemeMode.values.byName(p.getString('theme') ?? 'system');
    } catch (_) {
      t = ThemeMode.system;
    }
    return Settings(
      beep: b('beep', true),
      vibrate: b('vibrate', true),
      autoCopy: b('autoCopy', false),
      autoOpen: b('autoOpen', false),
      saveHistory: b('saveHistory', true),
      inAppBrowser: b('inAppBrowser', true),
      brandedShare: b('brandedShare', true),
      theme: t,
    );
  }
}

final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('overridden in main'),
);

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => Settings.load(ref.watch(prefsProvider));

  Future<void> setBool(String key, bool value) async {
    await ref.read(prefsProvider).setBool(key, value);
    state = Settings.load(ref.read(prefsProvider));
  }

  Future<void> setTheme(ThemeMode mode) async {
    await ref.read(prefsProvider).setString('theme', mode.name);
    state = Settings.load(ref.read(prefsProvider));
  }
}
