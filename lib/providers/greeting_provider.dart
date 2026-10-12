import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How many greetings the ARB files define.
///
/// Must match the `greeting0` .. `greeting{n-1}` keys in app_en.arb and
/// app_zh.arb.
const int kGreetingCount = 10;

/// Rotates the greeting shown at the top of the home screen.
///
/// Seeded from the clock so two launches in the same hour differ, then advanced
/// on a timer so the screen does not say the same thing all day.
class GreetingNotifier extends Notifier<int> {
  static const Duration _rotateEvery = Duration(minutes: 2);

  Timer? _timer;

  @override
  int build() {
    final now = DateTime.now();
    var index = (now.hour * 7 + now.minute ~/ 5) % kGreetingCount;

    _timer = Timer.periodic(_rotateEvery, (_) {
      index = (index + 1) % kGreetingCount;
      state = index;
    });
    ref.onDispose(() => _timer?.cancel());

    return index;
  }

  /// Advances immediately, so tapping the greeting changes it.
  void next() => state = (state + 1) % kGreetingCount;
}

final greetingProvider = NotifierProvider<GreetingNotifier, int>(
  GreetingNotifier.new,
);
