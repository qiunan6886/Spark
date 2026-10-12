import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/app/theme/spark_theme.dart';
import 'package:spark/core/l10n/l10n_context.dart';
import 'package:spark/features/library/add_music_folder.dart';
import 'package:spark/features/library/downloads_pane.dart' show formatBytes;
import 'package:spark/features/settings/cache_settings_screen.dart';
import 'package:spark/models/album_color_mode.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/models/audio_output_diagnostics.dart';
import 'package:spark/providers/providers.dart';
import 'package:spark/services/uac2_preferences_service.dart';

/// Settings, deliberately tiny: audio output, language, about.
///
/// Flick had 26 settings screens, most of them for re-arranging the UI. Spark
/// keeps only what changes how the app sounds, what language it speaks, and what
/// version it is.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final diagnostics = ref.watch(audioOutputDiagnosticsProvider);
    final bitPerfect = ref.watch(uac2BitPerfectIndicatorProvider);
    final folders = ref.watch(musicFoldersProvider).value ?? const [];
    final isScanning = ref.watch(isScanningProvider);
    final preference =
        ref.watch(audioEnginePreferenceProvider).value ??
        AudioEnginePreference.exoPlayer;
    // Watched in build, not read inside the picker callback: uac2DevicesProvider
    // is a FutureProvider, so a `read` at tap time can still be unresolved and
    // would grey out the USB option with a DAC plugged in.
    final hasDac = ref.watch(uac2DevicesProvider).value?.isNotEmpty ?? false;
    final themeChoice = ref.watch(themeChoiceProvider);
    final colorMode = ref.watch(albumColorModeProvider);
    final jamendoClientId = ref.watch(jamendoClientIdProvider);

    return Scaffold(
      backgroundColor: SparkColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 140),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpacing.page,
                12,
                SparkSpacing.page,
                20,
              ),
              child: Text(
                l10n.navSettings,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: SparkColors.textPrimary,
                ),
              ),
            ),
            _SectionLabel(text: 'LIBRARY'),
            _Card(
              children: [
                _NavRow(
                  icon: LucideIcons.folderPlus,
                  title: l10n.musicFolders,
                  value: '${folders.length}',
                  onTap: () => runAddMusicFolder(context, ref),
                ),
                const _Divider(),
                _NavRow(
                  icon: LucideIcons.refreshCw,
                  title: l10n.rescanLibrary,
                  value: isScanning ? l10n.libraryScanning : '',
                  onTap: isScanning ? null : () => _rescan(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: 'AUDIO'),
            _Card(
              children: [
                // The engine preference is what actually enables direct USB: the
                // session manager deliberately keeps Android shared output while
                // the preference is exoPlayer, even with a DAC attached. Without
                // this control there is no way to reach the bit-perfect path.
                _NavRow(
                  icon: LucideIcons.slidersHorizontal,
                  title: l10n.outputMode,
                  value: _outputModeLabel(context, preference),
                  onTap: () =>
                      _pickOutputMode(context, ref, preference, hasDac),
                ),
                const _Divider(),
                _ValueRow(
                  icon: bitPerfect
                      ? LucideIcons.zap
                      : LucideIcons.audioLines,
                  title: l10n.settingsAudio,
                  value: _outputLabel(context, diagnostics?.outputStrategyLabel),
                  subtitle: diagnostics == null
                      ? null
                      : '${diagnostics.outputDeviceLabel}'
                            '${diagnostics.isMixerManaged ? ' · shared' : ' · direct'}',
                  accent: bitPerfect,
                ),
                const _Divider(),
                _ValueRow(
                  icon: LucideIcons.usb,
                  title: 'USB DAC',
                  // Only the DAC's own name when the route really is USB. The
                  // route label falls back to the device's product name, so this
                  // row used to read "SM-S9280" -- the phone -- under a USB
                  // heading, which looked like a connected but unnamed DAC.
                  value: diagnostics?.isUsbRoute == true
                      ? (diagnostics?.routeLabel ?? '—')
                      : l10n.outputUsbDirectUnavailable,
                  subtitle: diagnostics?.isUsbRoute == true
                      ? null
                      : diagnostics?.routeLabel,
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Whether direct USB actually engaged used to be invisible: the
            // card above shows the *requested* mode, so a silent fallback to
            // Android looked identical to success.
            _SectionLabel(text: l10n.settingsAudioDiagnostics),
            _AudioDiagnosticsCard(diagnostics: diagnostics),
            const SizedBox(height: 20),
            _SectionLabel(text: 'APPEARANCE'),
            _Card(
              children: [
                _NavRow(
                  icon: LucideIcons.palette,
                  title: l10n.theme,
                  value: _themeLabel(context, themeChoice),
                  onTap: () => _pickTheme(context, ref, themeChoice),
                ),
                const _Divider(),
                _NavRow(
                  icon: LucideIcons.paintbrush,
                  title: l10n.albumColorMode,
                  value: _albumColorLabel(context, colorMode),
                  onTap: () => _pickAlbumColorMode(context, ref, colorMode),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: 'LANGUAGE'),
            _Card(
              children: [
                _NavRow(
                  icon: LucideIcons.languages,
                  title: l10n.settingsLanguage,
                  value: _localeLabel(context, ref),
                  onTap: () => _pickLanguage(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: 'ONLINE'),
            _Card(
              children: [
                _NavRow(
                  icon: LucideIcons.cloud,
                  title: l10n.jamendoClientId,
                  value: jamendoClientId.trim().isEmpty
                      ? l10n.jamendoClientIdEmpty
                      : jamendoClientId,
                  onTap: () => _editJamendoClientId(context, ref),
                ),
                _NavRow(
                  icon: LucideIcons.hardDrive,
                  title: l10n.cacheSettings,
                  value: l10n.cacheUsage(formatBytes(ref.watch(cacheSizeProvider))),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CacheSettingsScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SectionLabel(text: 'ABOUT'),
            _Card(
              children: [
                _NavRow(
                  icon: LucideIcons.info,
                  title: l10n.settingsAbout,
                  value: '0.1.0',
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _outputLabel(BuildContext context, String? strategy) {
    if (strategy == null || strategy.isEmpty) {
      return context.l10n.outputUsbDirectUnavailable;
    }
    return strategy;
  }

  static String _localeLabel(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    if (locale == null) return l10n.languageSystem;
    return locale.languageCode == 'zh'
        ? l10n.languageChinese
        : l10n.languageEnglish;
  }

  /// Rescans every registered folder via the shared helper.
  static void _rescan(BuildContext context, WidgetRef ref) {
    unawaited(rescanLibrary(context, ref));
  }

  /// Edits the Jamendo Client ID.
  ///
  /// Editable rather than hardcoded because the ID belongs to whoever registered
  /// the app at devportal.jamendo.com. Clearing it switches the Jamendo section
  /// off without affecting Audius.
  static Future<void> _editJamendoClientId(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(
      text: ref.read(jamendoClientIdProvider),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SparkColors.surface,
        title: Text(
          l10n.jamendoClientId,
          style: TextStyle(color: SparkColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(color: SparkColors.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.jamendoClientId,
                hintStyle: TextStyle(color: SparkColors.textTertiary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.jamendoClientIdHint,
              style: TextStyle(fontSize: 12, color: SparkColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              l10n.cancel,
              style: TextStyle(color: SparkColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(
              l10n.save,
              style: TextStyle(color: SparkColors.accent),
            ),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) return;
    await ref.read(jamendoClientIdProvider.notifier).setClientId(result);
  }

  static Future<void> _showAbout(BuildContext context) async {
    final l10n = context.l10n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: SparkColors.surface,
        title: Text(
          l10n.appTitle,
          style: TextStyle(color: SparkColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AboutLine(label: l10n.aboutVersion, value: '0.1.0'),
            const SizedBox(height: 10),
            _AboutLine(label: l10n.aboutEngine, value: 'Rust + Flutter'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'OK',
              style: TextStyle(color: SparkColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  static String _outputModeLabel(
    BuildContext context,
    AudioEnginePreference preference,
  ) {
    final l10n = context.l10n;
    return switch (preference) {
      AudioEnginePreference.isochronousUsb => l10n.outputModeUsb,
      AudioEnginePreference.rustOboe => l10n.outputModeOboe,
      AudioEnginePreference.exoPlayer => l10n.outputModeAndroid,
    };
  }

  /// Picks the output engine.
  ///
  /// "USB DAC direct" is offered even with no DAC attached (greyed out with an
  /// explanation) so the option is discoverable before plugging one in.
  static Future<void> _pickOutputMode(
    BuildContext context,
    WidgetRef ref,
    AudioEnginePreference current,
    bool hasDac,
  ) async {
    final l10n = context.l10n;

    final choice = await showModalBottomSheet<AudioEnginePreference>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SparkColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.outputMode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _ModeOption(
              label: l10n.outputModeAndroid,
              hint: l10n.outputModeAndroidHint,
              selected: current == AudioEnginePreference.exoPlayer,
              onTap: () =>
                  Navigator.pop(sheetContext, AudioEnginePreference.exoPlayer),
            ),
            _ModeOption(
              label: l10n.outputModeOboe,
              hint: l10n.outputModeOboeHint,
              selected: current == AudioEnginePreference.rustOboe,
              onTap: () =>
                  Navigator.pop(sheetContext, AudioEnginePreference.rustOboe),
            ),
            _ModeOption(
              label: l10n.outputModeUsb,
              hint: hasDac ? l10n.outputModeUsbHint : l10n.outputModeUsbNeedsDac,
              selected: current == AudioEnginePreference.isochronousUsb,
              enabled: hasDac,
              onTap: hasDac
                  ? () => Navigator.pop(
                      sheetContext,
                      AudioEnginePreference.isochronousUsb,
                    )
                  : null,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null) return;
    // Through PlayerService, NOT the preferences service.
    //
    // Saving the value on its own changes nothing: `selectedMode` -- the engine
    // playback actually uses -- is only recomputed at startup and on audio route
    // changes. PlayerService.setAudioEnginePreference also triggers a route
    // re-sync, which is what recomputes it. Calling the preferences service
    // directly here meant all three modes behaved identically: the picker label
    // moved, the engine did not.
    await ref.read(playerServiceProvider).setAudioEnginePreference(choice);
    ref.invalidate(audioEnginePreferenceProvider);
  }

  static String _albumColorLabel(BuildContext context, AlbumColorMode mode) {
    final l10n = context.l10n;
    return switch (mode) {
      AlbumColorMode.off => l10n.albumColorOff,
      AlbumColorMode.subtle => l10n.albumColorSubtle,
      AlbumColorMode.moderate => l10n.albumColorModerate,
      AlbumColorMode.vibrant => l10n.albumColorVibrant,
    };
  }

  /// Picks how strongly cover art tints the hero card.
  static Future<void> _pickAlbumColorMode(
    BuildContext context,
    WidgetRef ref,
    AlbumColorMode current,
  ) async {
    final l10n = context.l10n;

    final choice = await showModalBottomSheet<AlbumColorMode>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SparkColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.albumColorMode,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _ModeOption(
              label: l10n.albumColorOff,
              hint: l10n.albumColorOffHint,
              selected: current == AlbumColorMode.off,
              onTap: () => Navigator.pop(sheetContext, AlbumColorMode.off),
            ),
            _ModeOption(
              label: l10n.albumColorSubtle,
              hint: l10n.albumColorSubtleHint,
              selected: current == AlbumColorMode.subtle,
              onTap: () => Navigator.pop(sheetContext, AlbumColorMode.subtle),
            ),
            _ModeOption(
              label: l10n.albumColorModerate,
              hint: l10n.albumColorModerateHint,
              selected: current == AlbumColorMode.moderate,
              onTap: () =>
                  Navigator.pop(sheetContext, AlbumColorMode.moderate),
            ),
            _ModeOption(
              label: l10n.albumColorVibrant,
              hint: l10n.albumColorVibrantHint,
              selected: current == AlbumColorMode.vibrant,
              onTap: () => Navigator.pop(sheetContext, AlbumColorMode.vibrant),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null) return;
    await ref.read(albumColorModeProvider.notifier).setMode(choice);
  }

  static String _themeLabel(BuildContext context, SparkThemeChoice choice) {
    final l10n = context.l10n;
    return switch (choice) {
      SparkThemeChoice.system => l10n.themeSystem,
      SparkThemeChoice.obsidian => l10n.themeDark,
      SparkThemeChoice.amoled => l10n.themeAmoled,
      SparkThemeChoice.daylight => l10n.themeLight,
    };
  }

  /// Picks a theme.
  ///
  /// Each row carries a swatch of the palette it applies, so the choice is
  /// legible without switching back and forth to compare.
  static Future<void> _pickTheme(
    BuildContext context,
    WidgetRef ref,
    SparkThemeChoice current,
  ) async {
    final l10n = context.l10n;
    final systemPalette = resolveSparkPalette(
      SparkThemeChoice.system,
      MediaQuery.platformBrightnessOf(context),
    );

    final choice = await showModalBottomSheet<SparkThemeChoice>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SparkColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.theme,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _ThemeOption(
              palette: systemPalette,
              label: l10n.themeSystem,
              hint: l10n.themeSystemHint,
              selected: current == SparkThemeChoice.system,
              onTap: () =>
                  Navigator.pop(sheetContext, SparkThemeChoice.system),
            ),
            _ThemeOption(
              palette: sparkObsidian,
              label: l10n.themeDark,
              hint: l10n.themeDarkHint,
              selected: current == SparkThemeChoice.obsidian,
              onTap: () =>
                  Navigator.pop(sheetContext, SparkThemeChoice.obsidian),
            ),
            _ThemeOption(
              palette: sparkAmoled,
              label: l10n.themeAmoled,
              hint: l10n.themeAmoledHint,
              selected: current == SparkThemeChoice.amoled,
              onTap: () =>
                  Navigator.pop(sheetContext, SparkThemeChoice.amoled),
            ),
            _ThemeOption(
              palette: sparkDaylight,
              label: l10n.themeLight,
              hint: l10n.themeLightHint,
              selected: current == SparkThemeChoice.daylight,
              onTap: () =>
                  Navigator.pop(sheetContext, SparkThemeChoice.daylight),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null) return;
    await ref.read(themeChoiceProvider.notifier).setChoice(choice);
  }

  static Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final current = ref.read(localeProvider);

    await showModalBottomSheet<String>(
      context: context,
      backgroundColor: SparkColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: SparkColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.settingsLanguage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: SparkColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              label: l10n.languageSystem,
              selected: current == null,
              onTap: () => Navigator.pop(sheetContext, 'system'),
            ),
            _LanguageOption(
              label: l10n.languageEnglish,
              selected: current?.languageCode == 'en',
              onTap: () => Navigator.pop(sheetContext, 'en'),
            ),
            _LanguageOption(
              label: l10n.languageChinese,
              selected: current?.languageCode == 'zh',
              onTap: () => Navigator.pop(sheetContext, 'zh'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ).then((choice) {
      if (choice == null) return;
      final controller = ref.read(localeProvider.notifier);
      switch (choice) {
        case 'en':
          controller.setLocale(const Locale('en'));
        case 'zh':
          controller.setLocale(const Locale('zh'));
        default:
          controller.setLocale(null);
      }
    });
  }
}

/// One theme row, with a swatch previewing the palette it applies.
class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.palette,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final SparkPalette palette;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.border),
        ),
        child: Center(
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: selected ? SparkColors.accent : SparkColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        hint,
        style: TextStyle(fontSize: 12, color: SparkColors.textSecondary),
      ),
      trailing: selected
          ? Icon(LucideIcons.check, size: 18, color: SparkColors.accent)
          : null,
    );
  }
}

/// One row in the output-mode sheet.
///
/// `enabled: false` greys the row out and shows the hint as the reason, instead
/// of leaving a tappable option that silently does nothing.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.hint,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tint = !enabled
        ? SparkColors.textTertiary
        : (selected ? SparkColors.accent : SparkColors.textPrimary);
    return ListTile(
      enabled: enabled,
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: tint,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      subtitle: Text(
        hint,
        style: TextStyle(fontSize: 12, color: SparkColors.textSecondary),
      ),
      trailing: selected
          ? Icon(LucideIcons.check, size: 18, color: SparkColors.accent)
          : null,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(
        label,
        style: TextStyle(
          color: selected ? SparkColors.accent : SparkColors.textPrimary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: selected
          ? Icon(LucideIcons.check, size: 18, color: SparkColors.accent)
          : null,
    );
  }
}

/// One label/value line inside the About dialog.
class _AboutLine extends StatelessWidget {
  const _AboutLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: SparkColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SparkColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SparkSpacing.page + 4, 0, 0, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
          color: SparkColors.textTertiary,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: SparkSpacing.page),
      decoration: BoxDecoration(
        color: SparkColors.surface,
        borderRadius: BorderRadius.circular(SparkRadius.card),
        border: Border.all(color: SparkColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 56, color: SparkColors.border);
}

/// What the audio path is *actually* doing, as opposed to what was requested.
///
/// Direct USB can fall back to the Android mixer for several reasons -- no DAC
/// on the route, the interface could not be claimed, the stream never stabilised.
/// The card above only ever showed the requested mode, so a fallback was
/// indistinguishable from success.
class _AudioDiagnosticsCard extends StatelessWidget {
  const _AudioDiagnosticsCard({required this.diagnostics});

  final AudioOutputDiagnostics? diagnostics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = diagnostics;

    if (d == null) {
      return _Card(
        children: [
          _ValueRow(
            icon: LucideIcons.activity,
            title: l10n.diagActualEngine,
            value: '—',
          ),
        ],
      );
    }

    final initialized = d.initializedMode;
    final fellBack = audioPathFellBack(d);
    // A deliberate per-track override (an uncached stream) is not a fault, so it
    // must not raise the same warning as a real fallback.
    final note = d.engineNote;
    final isNoteworthy = fellBack && d.fallbackReason == null;

    return _Card(
      children: [
        _ValueRow(
          icon: LucideIcons.slidersHorizontal,
          title: l10n.diagRequestedEngine,
          value: _engineTypeLabel(context, d.selectedMode),
        ),
        const _Divider(),
        _ValueRow(
          icon: fellBack
              ? (isNoteworthy ? LucideIcons.info : LucideIcons.triangleAlert)
              : LucideIcons.circleCheck,
          title: l10n.diagActualEngine,
          value: initialized == null
              ? '—'
              : _engineTypeLabel(context, initialized),
          subtitle: fellBack ? (d.fallbackReason ?? note) : null,
          accent: !fellBack,
        ),
        const _Divider(),
        _ValueRow(
          icon: LucideIcons.usb,
          title: l10n.diagUsbInterface,
          value: d.usbInterfaceClaimed ? l10n.diagClaimed : l10n.diagUnclaimed,
          subtitle: d.usbStreamStable ? l10n.diagStable : l10n.diagUnstable,
        ),
        if (d.fallbackReason != null && !fellBack) ...[
          const _Divider(),
          _ValueRow(
            icon: LucideIcons.info,
            title: l10n.diagFallbackReason,
            value: d.fallbackReason!,
          ),
        ],
      ],
    );
  }
}

String _engineTypeLabel(BuildContext context, AudioEngineType type) {
  final l10n = context.l10n;
  return switch (type) {
    AudioEngineType.normalAndroid => l10n.outputNormalAndroid,
    AudioEngineType.rustOboe => l10n.outputModeOboe,
    AudioEngineType.usbDacExperimental => l10n.outputUsbDirect,
    // Distinct from rustOboe on purpose: they used to share a label, so the two
    // were indistinguishable in the diagnostics and any difference between the
    // requested and actual engine was invisible.
    AudioEngineType.dapInternalHighRes => l10n.outputModeDapExclusive,
  };
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.icon,
    required this.title,
    required this.value,
    this.subtitle,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: accent ? SparkColors.accent : SparkColors.textSecondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: SparkColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: accent
                        ? SparkColors.accent
                        : SparkColors.textSecondary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: SparkColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: SparkColors.textSecondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: SparkColors.textPrimary,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                color: SparkColors.textSecondary,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: SparkColors.textTertiary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
