// Checks for the silent-fallback rule behind the audio diagnostics card.
//
//   flutter test test/audio_diagnostics_test.dart
//
// Direct USB can fall back to the Android mixer without any error the user can
// see, which is what made "is the DAC actually being used?" unanswerable from
// the settings screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/models/audio_output_diagnostics.dart';

AudioOutputDiagnostics _diag({
  required AudioEngineType selected,
  AudioEngineType? initialized,
  String? fallbackReason,
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
  usbInterfaceClaimed: true,
  usbStreamStable: true,
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

void main() {
  test('the requested engine in use is not a fallback', () {
    expect(
      audioPathFellBack(
        _diag(
          selected: AudioEngineType.usbDacExperimental,
          initialized: AudioEngineType.usbDacExperimental,
        ),
      ),
      isFalse,
    );
  });

  test('an Android engine where USB was asked for is a fallback', () {
    expect(
      audioPathFellBack(
        _diag(
          selected: AudioEngineType.usbDacExperimental,
          initialized: AudioEngineType.normalAndroid,
          fallbackReason: 'no USB DAC on the route',
        ),
      ),
      isTrue,
    );
  });

  test('nothing initialised yet is not a fallback', () {
    // Reporting this as a fallback would light the warning before playback has
    // even been attempted.
    expect(
      audioPathFellBack(
        _diag(selected: AudioEngineType.usbDacExperimental),
      ),
      isFalse,
    );
  });

  test('the Rust engine selected and initialised is not a fallback', () {
    expect(
      audioPathFellBack(
        _diag(
          selected: AudioEngineType.rustOboe,
          initialized: AudioEngineType.rustOboe,
        ),
      ),
      isFalse,
    );
  });
}
