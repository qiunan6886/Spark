import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark/app/app.dart';
import 'package:spark/core/utils/dev_log.dart';
import 'package:spark/data/database.dart';
import 'package:spark/providers/theme_provider.dart';
import 'package:spark/services/player_service.dart';
import 'package:spark/src/rust/api/logging.dart';
import 'package:spark/src/rust/frb_generated.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Order matters: the bridge must be live before anything touches the Rust
  // audio engine, and the database must be open before repositories are read.
  await RustLib.init();
  _subscribeRustLogs();
  await Database.init();

  // Read the saved theme before the first frame so a light-theme user does not
  // see a dark flash on launch.
  await ThemeChoiceController.load();

  runApp(const ProviderScope(child: SparkApp()));

  // Playback restore is deliberately post-first-frame so a slow probe never
  // delays the UI. It only re-arms the previous session's engine and track.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_bootstrapPlayback());
  });
}

void _subscribeRustLogs() {
  registerLogSink().listen(
    (msg) => devLog('[rust] $msg'),
    onError: (Object e) => devLog('rust log stream error: $e'),
  );
}

Future<void> _bootstrapPlayback() async {
  final player = PlayerService();
  try {
    await player.restorePlaybackModes();
    await player.prepareForAppLaunch();
    await player.restoreLastPlayed();
  } catch (e) {
    devLog('Playback bootstrap failed: $e');
  }
}
