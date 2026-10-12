import 'package:just_audio/just_audio.dart';
import 'package:spark/core/utils/dev_log.dart';

/// Enhanced audio playback service.
///
/// Plays a file through [AudioPlayer], ensuring compatibility across all
/// platforms, especially Android.
class AudioPlaybackService {
  final AudioPlayer _player;

  AudioPlaybackService(this._player);

  /// Play a file
  Future<void> playFile(String filePath) async {
    try {
      await _player.setFilePath(filePath);
      await _player.play();
    } catch (e) {
      devLog('Error playing file: $e');
      rethrow;
    }
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
  }

  /// Dispose and cleanup all resources
  Future<void> dispose() async {
    await _player.dispose();
  }

  /// Get audio player instance
  AudioPlayer get player => _player;
}

/// Factory for creating audio playback service
class AudioPlaybackServiceFactory {
  static AudioPlaybackService create() {
    final player = AudioPlayer();
    return AudioPlaybackService(player);
  }
}
