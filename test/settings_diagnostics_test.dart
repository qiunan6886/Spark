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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:spark/features/settings/settings_screen.dart';
import 'package:spark/l10n/app_localizations.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/models/audio_output_diagnostics.dart';
import 'package:spark/providers/providers.dart';

AudioOutputDiagnostics _diag({
  required AudioEngineType selected,
  AudioEngineType? initialized,
  String? fallbackReason,
  String? engineNote,
  String routeType = 'usb',
  String routeLabel = 'FiiO',
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
  routeType: routeType,
  routeLabel: routeLabel,
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
  engineNote: engineNote,
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

  testWidgets('the USB DAC row does not show the phone as if it were a DAC', (
    tester,
  ) async {
    // The route label falls back to the device's product name, so this row used
    // to read "SM-S9280" -- the phone -- under a USB heading.
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.normalAndroid,
        initialized: AudioEngineType.normalAndroid,
        routeType: 'internal',
        routeLabel: 'SM-S9280',
      ),
    );

    expect(find.text('No USB DAC detected'), findsOneWidget);
  });

  testWidgets('the USB DAC row names the DAC when the route is USB', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.usbDacExperimental,
        initialized: AudioEngineType.usbDacExperimental,
        routeType: 'usb',
        routeLabel: 'DTC 480',
      ),
    );

    expect(find.text('DTC 480'), findsWidgets);
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

  testWidgets('a deliberate per-track override is not shown as a failure', (
    tester,
  ) async {
    // An uncached stream is played by the Android player on purpose. Showing
    // the same warning as a real fallback made a correctly applied output mode
    // look broken.
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.rustOboe,
        initialized: AudioEngineType.normalAndroid,
        engineNote: 'This track is streamed and not cached yet.',
      ),
    );

    expect(
      find.byIcon(LucideIcons.triangleAlert),
      findsNothing,
      reason: 'a deliberate override is not a failure',
    );
    expect(
      find.text('This track is streamed and not cached yet.'),
      findsOneWidget,
    );
  });

  testWidgets('a real fallback keeps the warning', (tester) async {
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.rustOboe,
        initialized: AudioEngineType.normalAndroid,
        fallbackReason: 'the Rust engine could not start',
        engineNote: 'some unrelated note',
      ),
    );

    expect(
      find.byIcon(LucideIcons.triangleAlert),
      findsWidgets,
      reason: 'a real fallback must keep the warning',
    );
    // The failure reason wins over the informational note.
    expect(find.text('the Rust engine could not start'), findsOneWidget);
    expect(find.text('some unrelated note'), findsNothing);
  });

  testWidgets('the pause-on-unplug behaviour is visible and on by default', (
    tester,
  ) async {
    // The behaviour existed but was unreachable from the UI, so it was impossible
    // to discover or change.
    await _pumpSettings(
      tester,
      _diag(
        selected: AudioEngineType.usbDacExperimental,
        initialized: AudioEngineType.usbDacExperimental,
      ),
    );

    expect(find.text('Pause when the DAC is unplugged'), findsOneWidget);
    final toggle = tester.widget<Switch>(find.byType(Switch));
    expect(toggle.value, isTrue);
  });
}
