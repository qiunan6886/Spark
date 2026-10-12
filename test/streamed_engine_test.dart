// The rule that decides which audio engine a streamed track can use.
//
//   flutter test test/streamed_engine_test.dart
//
// This matters because the direct-USB path is the point of the app: an uncached
// stream must not be handed to an engine that expects a file, and a cached one
// must not be silently downgraded to the Android mixer. Both directions are
// regressions that would only show up on hardware with a DAC attached, which is
// exactly why the rule is pinned down here.
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/services/player_service.dart';

void main() {
  group('engineForStreamedSong', () {
    test('an uncached stream falls back to the Android player', () {
      expect(
        engineForStreamedSong(
          desired: AudioEngineType.usbDacExperimental,
          isCached: false,
        ),
        AudioEngineType.normalAndroid,
      );
      expect(
        engineForStreamedSong(
          desired: AudioEngineType.rustOboe,
          isCached: false,
        ),
        AudioEngineType.normalAndroid,
      );
    });

    test('a cached stream keeps the requested engine', () {
      // This is what makes a cached track eligible for direct USB.
      expect(
        engineForStreamedSong(
          desired: AudioEngineType.usbDacExperimental,
          isCached: true,
        ),
        AudioEngineType.usbDacExperimental,
      );
      expect(
        engineForStreamedSong(desired: AudioEngineType.rustOboe, isCached: true),
        AudioEngineType.rustOboe,
      );
    });

    test('the Android player stays the Android player either way', () {
      for (final cached in [true, false]) {
        expect(
          engineForStreamedSong(
            desired: AudioEngineType.normalAndroid,
            isCached: cached,
          ),
          AudioEngineType.normalAndroid,
        );
      }
    });
  });

  group('canUseDirectUsbEngine', () {
    test('an attached, permitted DAC is enough even before the route moves', () {
      // The regression this guards: the rule used to require Android to already
      // be routing to the DAC. A plugged-in DAC whose route has not switched is
      // exactly when direct USB matters, and it used to fall back silently.
      expect(
        canUseDirectUsbEngine(
          hasUsbRoute: false,
          hasDacAttached: true,
          hasDacPermission: true,
        ),
        isTrue,
      );
    });

    test('an attached DAC we may not claim is not enough', () {
      // UsbManager.deviceList includes devices the user denied. Choosing the
      // direct engine for one would fail after the fact instead of falling back.
      expect(
        canUseDirectUsbEngine(
          hasUsbRoute: false,
          hasDacAttached: true,
          hasDacPermission: false,
        ),
        isFalse,
      );
    });

    test('Android already routing to the DAC is enough on its own', () {
      // Android only routes to a device the app may use, so no separate
      // permission check is needed here.
      expect(
        canUseDirectUsbEngine(
          hasUsbRoute: true,
          hasDacAttached: false,
          hasDacPermission: false,
        ),
        isTrue,
      );
    });

    test('no USB audio device at all means no direct path', () {
      expect(
        canUseDirectUsbEngine(
          hasUsbRoute: false,
          hasDacAttached: false,
          hasDacPermission: false,
        ),
        isFalse,
      );
    });
  });
}
