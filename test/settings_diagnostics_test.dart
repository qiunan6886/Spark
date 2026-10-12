// The audio diagnostics card in Settings.
//
//   flutter test test/settings_diagnostics_test.dart
//
// The card exists because a silent fallback from direct USB to the Android mixer
// was indistinguishable from success: the rest of the Audio section only ever
// showed the *requested* mode.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/features/settings/settings_screen.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/models/audio_output_diagnostics.dart';
import 'package:spark/providers/providers.dart';

AudioOutputDiagnostics _diag({
  required AudioEngineType selected,
  AudioEngineType? initialized,
  String? fallbackReason,
  bool usbInterfaceClaimed = true,
  bool usbStreamStable = true,
}) => AudioOutputDiagnostics(
  selectedMode: selected,
  initializedMode: initialized,
  detectedDap: false,
  detectedDapBrand: null,
  pathManagement: AudioPathManagement.directUsbExperimental,
  outputStrategyLabel: 'direct',
  capabilityStateLabel: 'ok',
  backendDescription: 'usb',
  routeType: 'usb',
  routeLabel: 'USB',
  outputDeviceLabel: 'FiiO',
  isMixerManaged: false,
  audioFocusHeld: true,
  directUsbRegistered: true,
  usbInterfaceClaimed: usbInterfaceClaimed,
  usbStreamStable: usbStreamStable,
  trackSampleRate: 48000,
  requestedOutputSampleRate: 48000,
  reportedOutputSampleRate: 48000,
  resamplerActive: false,
  passthroughAllowed: true,
  activeOutputSignature: null,
  verificationReason: null,
  fallbackReason: fallbackReason,
  capabilityFlags: const AudioCapabilityFlags(
    supportsExclusiveUsbOwnership: true,
    supportsDirectSampleRateSwitching: true,
    supportsVerifiedBitPerfect: true,
    supportsAndroidManagedHighResOnly: false,
    supportsInternalDapPathOnly: false,
  ),
);

Future<void> _pumpSettings(
  WidgetTester tester,
  AudioOutputDiagnostics diagnostics,
) async {
  // Tall enough that the whole Audio section is laid out without scrolling.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [audioOutputDiagnosticsProvider.overrideWithValue(diagnostics)],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('names both the requested engine and the one actually running', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.usbDacExperimental,
        initialized: AudioEngineType.usbDacExperimental,
      ),
    );

    expect(find.text('Requested'), findsOneWidget);
    expect(find.text('Actually using'), findsOneWidget);
    // Direct USB on both sides: no fallback to report.
    expect(find.text('USB DAC (direct)'), findsWidgets);
    expect(find.text('Fallback reason'), findsNothing);
  });

  testWidgets('a fallback is shown as such, with its reason', (tester) async {
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.usbDacExperimental,
        initialized: AudioEngineType.normalAndroid,
        fallbackReason: 'no USB audio device attached',
      ),
    );

    // Both engines appear, so the disagreement is visible rather than implied.
    expect(find.text('USB DAC (direct)'), findsWidgets);
    expect(find.text('Android shared'), findsWidgets);
    expect(find.text('no USB audio device attached'), findsOneWidget);
  });

  testWidgets('reports whether the interface is claimed', (tester) async {
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.usbDacExperimental,
        initialized: AudioEngineType.usbDacExperimental,
        usbInterfaceClaimed: false,
        usbStreamStable: false,
      ),
    );

    expect(find.text('not claimed'), findsOneWidget);
    expect(find.text('unstable'), findsOneWidget);
  });

  testWidgets('nothing initialised yet is not presented as a fallback', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _diag(selected: AudioEngineType.usbDacExperimental),
    );

    expect(find.text('Requested'), findsOneWidget);
    // The warning must not fire before playback has been attempted.
    expect(find.text('Fallback reason'), findsNothing);
  });
}
