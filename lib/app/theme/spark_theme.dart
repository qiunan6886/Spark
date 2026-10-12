import 'package:flutter/material.dart';

/// A complete colour set for one theme.
///
/// Every theme is described by one of these, so adding a theme means adding a
/// palette here and an entry in [SparkThemeChoice] -- no widget has to know
/// which theme is active.
@immutable
class SparkPalette {
  const SparkPalette({
    required this.id,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.accent,
    required this.onAccent,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.border,
    required this.heroGradient,
    required this.headerGlow,
  });

  /// Stable identifier, also used as a widget key so a theme switch forces the
  /// tree to rebuild (the colours are read through plain statics, which Flutter
  /// cannot observe on its own).
  final String id;

  final Brightness brightness;

  /// The page canvas.
  final Color background;

  /// Cards, list rows, the mini player.
  final Color surface;

  /// A step above [surface] for pressed states and unselected chips.
  final Color surfaceHigh;

  /// The single accent: lime. Kept identical across themes so the brand reads
  /// the same everywhere; it always carries [onAccent] content on top.
  final Color accent;

  /// Text/icons on top of [accent].
  final Color onAccent;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  final Color border;

  /// Gradient stops for the "curated" hero card.
  final LinearGradient heroGradient;

  /// Backdrop wash behind the home header. Its outer stop fades to
  /// [background], so it has to be defined per palette.
  final RadialGradient headerGlow;
}

const _accent = Color(0xFFD8F14E);
const _onAccent = Color(0xFF0A0A0F);

/// The reference design: a near-black canvas with one loud lime accent.
const sparkObsidian = SparkPalette(
  id: 'obsidian',
  brightness: Brightness.dark,
  background: Color(0xFF08080C),
  surface: Color(0xFF15151B),
  surfaceHigh: Color(0xFF1E1E26),
  accent: _accent,
  onAccent: _onAccent,
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFF9C9CA8),
  textTertiary: Color(0xFF6B6B78),
  border: Color(0xFF26262F),
  heroGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB98BE8), Color(0xFFE28CC8), Color(0xFF8FB6F0)],
  ),
  headerGlow: RadialGradient(
    center: Alignment(-0.7, -0.9),
    radius: 1.4,
    colors: [Color(0x33B98BE8), Color(0x0008080C)],
  ),
);

/// True black, for OLED panels where lit pixels cost battery and grey blacks
/// are visible in a dark room.
const sparkAmoled = SparkPalette(
  id: 'amoled',
  brightness: Brightness.dark,
  background: Color(0xFF000000),
  surface: Color(0xFF0B0B0E),
  surfaceHigh: Color(0xFF16161A),
  accent: _accent,
  onAccent: _onAccent,
  textPrimary: Color(0xFFFFFFFF),
  textSecondary: Color(0xFF9A9AA6),
  textTertiary: Color(0xFF6A6A76),
  border: Color(0xFF1F1F26),
  heroGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB98BE8), Color(0xFFE28CC8), Color(0xFF8FB6F0)],
  ),
  headerGlow: RadialGradient(
    center: Alignment(-0.7, -0.9),
    radius: 1.4,
    colors: [Color(0x33B98BE8), Color(0x00000000)],
  ),
);

/// Daylight: light surfaces for bright rooms.
const sparkDaylight = SparkPalette(
  id: 'daylight',
  brightness: Brightness.light,
  background: Color(0xFFF3F3F7),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFE8E8EF),
  accent: _accent,
  onAccent: _onAccent,
  textPrimary: Color(0xFF14141A),
  textSecondary: Color(0xFF5C5C6A),
  textTertiary: Color(0xFF8C8C9A),
  border: Color(0xFFE1E1EA),
  heroGradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC9A6F0), Color(0xFFEFA9D8), Color(0xFFA8C6F5)],
  ),
  headerGlow: RadialGradient(
    center: Alignment(-0.7, -0.9),
    radius: 1.4,
    colors: [Color(0x40B98BE8), Color(0x00F3F3F7)],
  ),
);

/// Design tokens for Spark.
///
/// These stay plain statics rather than a `ThemeExtension` so the ~150 call
/// sites keep reading `SparkColors.accent`. The price is that they can no
/// longer be `const`, and that Flutter cannot observe a palette change on its
/// own -- [SparkApp] rebuilds the tree with a new key when the palette changes.
abstract final class SparkColors {
  static SparkPalette _active = sparkObsidian;

  /// The palette currently in effect.
  static SparkPalette get active => _active;

  /// Switches the active palette. Called once per build by the app root, before
  /// any descendant builds.
  static void apply(SparkPalette palette) {
    _active = palette;
  }

  static Brightness get brightness => _active.brightness;

  /// True for the dark palettes. Shorthand for the many places that pick a
  /// shadow strength or an overlay alpha from the theme.
  static bool get isDark => _active.brightness == Brightness.dark;

  static Color get background => _active.background;
  static Color get surface => _active.surface;
  static Color get surfaceHigh => _active.surfaceHigh;
  static Color get accent => _active.accent;
  static Color get onAccent => _active.onAccent;
  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textTertiary => _active.textTertiary;
  static Color get border => _active.border;
  static LinearGradient get heroGradient => _active.heroGradient;
  static RadialGradient get headerGlow => _active.headerGlow;
}

abstract final class SparkRadius {
  static const card = 20.0;
  static const hero = 24.0;
  static const pill = 999.0;
}

abstract final class SparkSpacing {
  static const page = 20.0;
  static const gap = 12.0;
  static const section = 28.0;
}

ThemeData buildSparkTheme(SparkPalette palette) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: palette.brightness,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        secondary: palette.accent,
        onSecondary: palette.onAccent,
        surface: palette.surface,
        onSurface: palette.textPrimary,
        error: const Color(0xFFFF5A5A),
        onError: Colors.white,
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: palette.brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    splashFactory: InkSparkle.splashFactory,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceHigh,
      contentTextStyle: TextStyle(color: palette.textPrimary),
      behavior: SnackBarBehavior.floating,
      // Lifts the banner clear of the bottom nav bar and the floating mini
      // player; floating snack bars otherwise sit on top of both and swallow
      // taps meant for the tab bar.
      insetPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 96),
    ),
    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 1,
      space: 1,
    ),
  );
}
