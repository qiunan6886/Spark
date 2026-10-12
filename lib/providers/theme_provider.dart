import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/spark_theme.dart';

/// The themes the user can pick in Settings.
///
/// [system] resolves to a light or dark palette from the platform brightness;
/// the other three pin a specific palette regardless of the platform.
enum SparkThemeChoice {
  system,
  obsidian,
  amoled,
  daylight;

  /// What to hand `MaterialApp`, so the Material brightness always agrees with
  /// the palette [resolveSparkPalette] picks.
  ThemeMode get themeMode => switch (this) {
    SparkThemeChoice.system => ThemeMode.system,
    SparkThemeChoice.obsidian || SparkThemeChoice.amoled => ThemeMode.dark,
    SparkThemeChoice.daylight => ThemeMode.light,
  };
}

/// Resolves a choice plus the platform brightness to a concrete palette.
SparkPalette resolveSparkPalette(
  SparkThemeChoice choice,
  Brightness platformBrightness,
) {
  return switch (choice) {
    SparkThemeChoice.system =>
      platformBrightness == Brightness.light ? sparkDaylight : sparkObsidian,
    SparkThemeChoice.obsidian => sparkObsidian,
    SparkThemeChoice.amoled => sparkAmoled,
    SparkThemeChoice.daylight => sparkDaylight,
  };
}

/// Persists the user's theme choice.
///
/// The stored value is read once in `main()` before `runApp`, so the first
/// frame is already painted in the right palette instead of flashing the
/// default dark theme at a light-theme user.
class ThemeChoiceController extends Notifier<SparkThemeChoice> {
  static const _prefsKey = 'spark.theme';

  static SparkThemeChoice _seeded = SparkThemeChoice.obsidian;

  @override
  SparkThemeChoice build() => _seeded;

  /// Reads the stored choice and seeds the provider's initial state.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    _seeded = SparkThemeChoice.values.firstWhere(
      (choice) => choice.name == stored,
      orElse: () => SparkThemeChoice.obsidian,
    );
  }

  Future<void> setChoice(SparkThemeChoice choice) async {
    if (state == choice) return;
    state = choice;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, choice.name);
  }
}

final themeChoiceProvider =
    NotifierProvider<ThemeChoiceController, SparkThemeChoice>(
      ThemeChoiceController.new,
    );
