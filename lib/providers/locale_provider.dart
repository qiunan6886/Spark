import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language choice.
///
/// `null` means "follow the system", which is the default: with no stored
/// choice the app hands Flutter no explicit locale and the platform decides.
/// Spark ships English and Simplified Chinese only.
class LocaleController extends Notifier<Locale?> {
  static const _prefsKey = 'spark.locale';

  @override
  Locale? build() {
    _restore();
    return null;
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == null || stored.isEmpty) return;
    if (!_supported.contains(stored)) return;
    if (!ref.mounted) return;
    state = Locale(stored);
  }

  /// Pass `null` to go back to following the system locale.
  Future<void> setLocale(Locale? locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
  }

  static const _supported = {'en', 'zh'};
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);
