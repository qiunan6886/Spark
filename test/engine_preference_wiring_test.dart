// Guards the wiring between the output-mode picker and the audio engine.
//
//   flutter test test/engine_preference_wiring_test.dart
//
// This is a source-level check on purpose. The bug was not in a value or a
// calculation -- it was that the settings screen saved the preference through
// the low-level preferences service, which only stores the string. The engine
// selection lives in PlayerService.setAudioEnginePreference, which additionally
// triggers a route re-sync; without that, `selectedMode` is never recomputed and
// all three output modes behave identically. There is no widget-level assertion
// that catches "the write went to the wrong object", so the call itself is
// pinned down here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the output-mode picker applies the mode through PlayerService', () {
    final source = File(
      'lib/features/settings/settings_screen.dart',
    ).readAsStringSync();

    expect(
      source.contains('playerServiceProvider).setAudioEnginePreference'),
      isTrue,
      reason:
          'the picker must apply the mode through PlayerService, which also '
          're-syncs the audio route',
    );

    expect(
      source.contains('uac2PreferencesServiceProvider).setAudioEnginePreference'),
      isFalse,
      reason:
          'writing the preference directly stores the string but never '
          'recomputes selectedMode, so the engine keeps its previous value and '
          'switching modes does nothing',
    );
  });

  test('PlayerService.setAudioEnginePreference re-syncs the route', () {
    // The re-sync is the part that actually applies the change; if it is ever
    // dropped the picker goes back to being decorative.
    final source = File('lib/services/player_service.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<void> setAudioEnginePreference(',
    );
    expect(start, isNot(-1));

    final body = source.substring(start, start + 500);
    expect(body.contains('_preferencesService.setAudioEnginePreference'), isTrue);
    expect(body.contains('syncRouteSelection'), isTrue);
  });
}
