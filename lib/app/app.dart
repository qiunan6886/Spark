import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/features/shell/spark_shell.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/providers/providers.dart';

class SparkApp extends ConsumerWidget {
  const SparkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // null means "follow the system locale"; the controller only ever returns
    // an explicit locale once the user has picked one.
    final locale = ref.watch(localeProvider);
    final choice = ref.watch(themeChoiceProvider);

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      // The Material brightness must match whichever palette the choice
      // resolves to, so "true black" gets a dark scheme and "light" a light one.
      theme: buildSparkTheme(sparkDaylight),
      darkTheme: buildSparkTheme(
        choice == SparkThemeChoice.amoled ? sparkAmoled : sparkObsidian,
      ),
      themeMode: choice.themeMode,
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: _PaletteScope(choice: choice, child: const SparkShell()),
    );
  }
}

/// Applies the resolved palette for the frame about to be built.
///
/// SparkColors is plain statics, so Flutter cannot rebuild widgets that read it
/// when the palette changes. Keying the subtree on the palette id forces the
/// whole tree to rebuild on a theme switch -- which is what a theme change
/// should do anyway -- without every call site having to take a BuildContext.
class _PaletteScope extends StatelessWidget {
  const _PaletteScope({required this.choice, required this.child});

  final SparkThemeChoice choice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = resolveSparkPalette(choice, Theme.of(context).brightness);
    SparkColors.apply(palette);
    return KeyedSubtree(
      key: ValueKey('spark-theme-${palette.id}'),
      child: child,
    );
  }
}
