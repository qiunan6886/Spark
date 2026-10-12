// The rule that picks an engine when no external USB device is in play.
//
//   flutter test test/internal_engine_test.dart
//
// The bug this pins down: the decision used to be made by a "does the device
// advertise a hi-res internal route?" check that ran before the user's output
// mode was consulted. Every recent flagship advertises one, so all three modes
// -- Android shared, Hi-res (Oboe), USB DAC direct -- resolved to the same
// engine and switching between them changed nothing.
import 'package:flutter_test/flutter_test.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/services/audio_session_manager.dart';
import 'package:spark/services/uac2_preferences_service.dart';

void main() {
  group('on a phone that is not a DAP', () {
    test('Android shared really means the Android player', () {
      expect(
        resolveInternalEngine(
          preference: AudioEnginePreference.exoPlayer,
          isConfirmedDap: false,
          dapBitPerfectEnabled: true,
        ),
        AudioEngineType.normalAndroid,
      );
    });

    test('Hi-res (Oboe) selects the Rust stream', () {
      expect(
        resolveInternalEngine(
          preference: AudioEnginePreference.rustOboe,
          isConfirmedDap: false,
          dapBitPerfectEnabled: true,
        ),
        AudioEngineType.rustOboe,
      );
    });

    test('the exclusive DAP path is never taken', () {
      // Reporting a >48k internal route is not evidence of a DAP; taking the
      // exclusive path on an ordinary phone bypasses the Android mixer for no
      // reason.
      for (final preference in AudioEnginePreference.values) {
        expect(
          resolveInternalEngine(
            preference: preference,
            isConfirmedDap: false,
            dapBitPerfectEnabled: true,
          ),
          isNot(AudioEngineType.dapInternalHighRes),
          reason: '$preference must not select the DAP-exclusive path',
        );
      }
    });

    test('the three modes do not all collapse to one engine', () {
      AudioEngineType resolve(AudioEnginePreference p) => resolveInternalEngine(
        preference: p,
        isConfirmedDap: false,
        dapBitPerfectEnabled: true,
      );

      expect(resolve(AudioEnginePreference.exoPlayer), isNot(resolve(AudioEnginePreference.rustOboe)));
    });
  });

  group('on a confirmed DAP', () {
    test('bit-perfect enabled takes the exclusive internal path', () {
      expect(
        resolveInternalEngine(
          preference: AudioEnginePreference.exoPlayer,
          isConfirmedDap: true,
          dapBitPerfectEnabled: true,
        ),
        AudioEngineType.dapInternalHighRes,
      );
    });

    test('bit-perfect disabled keeps the shared Rust stream', () {
      expect(
        resolveInternalEngine(
          preference: AudioEnginePreference.exoPlayer,
          isConfirmedDap: true,
          dapBitPerfectEnabled: false,
        ),
        AudioEngineType.rustOboe,
      );
    });
  });
}
