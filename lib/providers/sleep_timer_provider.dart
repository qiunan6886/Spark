import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_provider.dart';

/// Sleep timer: pauses playback after a chosen delay.
///
/// Holds the time left rather than the end instant, so the UI can show a
/// countdown without needing the clock, and owns the ticker so nothing else has
/// to poll.
final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, Duration?>(
  SleepTimerNotifier.new,
);

class SleepTimerNotifier extends Notifier<Duration?> {
  Timer? _ticker;

  /// Presets offered in the picker.
  static const List<Duration> presets = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 45),
    Duration(minutes: 60),
    Duration(minutes: 90),
  ];

  @override
  Duration? build() {
    ref.onDispose(() => _ticker?.cancel());
    return null;
  }

  void start(Duration total) {
    _ticker?.cancel();
    state = total;

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = (state ?? Duration.zero) - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        cancel();
        // Pause rather than stop: the queue and position survive, so picking up
        // where you left off is one tap.
        ref.read(playerProvider.notifier).pause();
      } else {
        state = left;
      }
    });
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    state = null;
  }
}

/// `34:12` for the countdown chip.
String formatCountdown(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
