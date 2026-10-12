import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:spark/models/audio_engine_type.dart';
import 'package:spark/services/android_audio_device_service.dart';
import 'package:spark/services/uac2_preferences_service.dart';
import 'package:spark/services/uac2_service.dart';
import 'package:spark/src/rust/api/audio_api.dart' as rust_audio;
import 'package:spark/core/utils/dev_log.dart';

typedef AudioSessionSwitchHandler = Future<void> Function({
  required AudioEngineType? from,
  required AudioEngineType to,
  required bool initializeNewEngine,
  required String reason,
});
typedef AudioSessionPlaybackActiveReader = bool Function();

/// The engine to use once no external USB device is in play.
///
/// The user's output mode is authoritative here. This decision used to be made
/// by a "does the device advertise a hi-res internal route?" check that ran
/// *before* the preference was consulted, and every recent flagship advertises
/// one -- so picking "Android shared", "Hi-res (Oboe)" or "USB DAC direct"
/// all resolved to the same engine and the setting looked broken.
///
/// The exclusive internal path is reserved for a confirmed DAP ([isConfirmedDap]).
/// Reporting a >48k internal route is not evidence of one, and taking that path
/// on an ordinary phone bypasses the Android mixer for no reason.
AudioEngineType resolveInternalEngine({
  required AudioEnginePreference preference,
  required bool isConfirmedDap,
  required bool dapBitPerfectEnabled,
}) {
  if (isConfirmedDap) {
    return dapBitPerfectEnabled
        ? AudioEngineType.dapInternalHighRes
        : AudioEngineType.rustOboe;
  }

  return preference == AudioEnginePreference.rustOboe
      ? AudioEngineType.rustOboe
      : AudioEngineType.normalAndroid;
}

class AudioSessionManager {
  AudioSessionManager({
    AndroidAudioDeviceService? deviceService,
    Uac2PreferencesService? preferencesService,
    Uac2Service? uac2Service,
    required AudioSessionSwitchHandler onSwitchEngine,
    required AudioSessionPlaybackActiveReader isPlaybackActive,
  }) : _deviceService = deviceService ?? AndroidAudioDeviceService.instance,
       _preferencesService = preferencesService ?? Uac2PreferencesService(),
       _uac2Service = uac2Service ?? Uac2Service.instance,
       _onSwitchEngine = onSwitchEngine,
       _isPlaybackActive = isPlaybackActive;

  final AndroidAudioDeviceService _deviceService;
  final Uac2PreferencesService _preferencesService;
  final Uac2Service _uac2Service;
  final AudioSessionSwitchHandler _onSwitchEngine;
  final AudioSessionPlaybackActiveReader _isPlaybackActive;

  final ValueNotifier<AudioEngineType> selectedModeNotifier = ValueNotifier(
    AudioEngineType.normalAndroid,
  );
  final ValueNotifier<AudioEngineType?> initializedModeNotifier = ValueNotifier(
    null,
  );
  final ValueNotifier<String?> fallbackReasonNotifier = ValueNotifier(null);

  /// Why the engine in use is not the requested one, when that is a deliberate
  /// choice for this track rather than a failure.
  ///
  /// Distinct from [fallbackReason]: an uncached stream is played by the Android
  /// player on purpose (neither the Rust engine nor direct USB can open an
  /// `https://` URL), and presenting that as an error made a working mode
  /// setting look broken.
  final ValueNotifier<String?> trackEngineNoteNotifier = ValueNotifier(null);
  final ValueNotifier<rust_audio.AudioCapabilityInfo> capabilityInfoNotifier =
      ValueNotifier(
        const rust_audio.AudioCapabilityInfo(
          capabilities: [rust_audio.AudioCapabilityType.standard],
          routeType: 'unknown',
          routeLabel: null,
          maxSampleRate: null,
        ),
      );

  bool _initialized = false;
  Future<void>? _initializeInFlight;
  Future<void>? _routeSyncInFlight;
  VoidCallback? _deviceInfoListener;
  final Map<String, String> _exclusiveUnavailableUsbDeviceReasons =
      <String, String>{};

  AudioEngineType get selectedMode => selectedModeNotifier.value;
  AudioEngineType? get initializedMode => initializedModeNotifier.value;
  String? get fallbackReason => fallbackReasonNotifier.value;

  void _debugLog(String message) {
    devLog(message);
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final inFlight = _initializeInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _initializeInternal();
    _initializeInFlight = future;
    try {
      await future;
    } finally {
      _initializeInFlight = null;
    }
  }

  Future<void> switchMode(
    AudioEngineType mode, {
    bool initializeNewEngine = false,
    String reason = 'manual switch',
  }) async {
    final previousInitialized = initializedMode;
    final selectedChanged = selectedMode != mode;
    final needsInitialization =
        initializeNewEngine && previousInitialized != mode;
    final needsDisposal =
        previousInitialized != null && previousInitialized != mode;

    selectedModeNotifier.value = mode;

    if (!selectedChanged && !needsInitialization && !needsDisposal) {
      return;
    }

    _debugLog(
      '[Session] Switching from ${previousInitialized?.logLabel ?? 'none'} '
      'to ${mode.logLabel} '
      '(${initializeNewEngine ? 'initialize' : 'lazy'}) because $reason',
    );

    if (needsDisposal || needsInitialization) {
      await _onSwitchEngine(
        from: previousInitialized,
        to: mode,
        initializeNewEngine: initializeNewEngine,
        reason: reason,
      );
    }

    initializedModeNotifier.value = initializeNewEngine
        ? mode
        : (previousInitialized == mode ? previousInitialized : null);
  }

  Future<AudioEngineType> resolvePreferredMode({bool refresh = false}) async {
    await initialize();
    return _resolvePreferredMode(refresh: refresh);
  }

  Future<void> recordFallback({
    required AudioEngineType requestedMode,
    required AudioEngineType fallbackMode,
    required String reason,
  }) async {
    fallbackReasonNotifier.value =
        '${requestedMode.logLabel} -> ${fallbackMode.logLabel}: $reason';
    if (selectedMode != fallbackMode) {
      selectedModeNotifier.value = fallbackMode;
    }
    _debugLog('[Session] Fallback: ${fallbackReasonNotifier.value}');
  }

  /// Records a deliberate, non-failure reason for the engine in use.
  void noteTrackEngineOverride(String? note) {
    if (trackEngineNoteNotifier.value == note) return;
    trackEngineNoteNotifier.value = note;
  }

  Future<void> suppressExperimentalUsbForCurrentDevice({
    required String reason,
  }) async {
    final info = await _deviceService.refresh();
    final deviceKey = _currentUsbExperimentalDeviceKey(info);
    if (deviceKey == null) {
      return;
    }

    _exclusiveUnavailableUsbDeviceReasons[deviceKey] = reason;
    if (selectedMode == AudioEngineType.usbDacExperimental) {
      await recordFallback(
        requestedMode: AudioEngineType.usbDacExperimental,
        fallbackMode: AudioEngineType.normalAndroid,
        reason: reason,
      );
      selectedModeNotifier.value = AudioEngineType.normalAndroid;
    }
    _debugLog(
      '[Session] Marking USB_DAC_EXPERIMENTAL unavailable for the current '
      'DAC this session: $reason',
    );
  }

  void clearFallbackReason() {
    if (fallbackReasonNotifier.value != null) {
      fallbackReasonNotifier.value = null;
    }
  }

  Future<void> setHiFiModeEnabled(bool enabled) async {
    await _preferencesService.setHiFiModeEnabled(enabled);
    await _syncRouteSelection(
      reason: enabled ? 'HiFi Mode enabled' : 'HiFi Mode disabled',
    );
  }

  Future<bool> isHiFiModeEnabled() {
    return _preferencesService.getHiFiModeEnabled();
  }

  Future<void> _initializeInternal() async {
    await _preferencesService.initializeDeveloperModeCache();
    await _preferencesService.initializeKillIsochronousUsbOnQuitCache();
    await _preferencesService.initialize432HzTuningCache();
    await _preferencesService.initializeBtFlagsCache();
    await _deviceService.initialize();
    selectedModeNotifier.value = await _resolvePreferredMode();

    _deviceInfoListener ??= () {
      unawaited(_syncRouteSelection(reason: 'audio route change'));
    };
    _deviceService.deviceInfoNotifier.addListener(_deviceInfoListener!);
    _initialized = true;
  }

  Future<void> syncRouteSelection({required String reason}) async {
    await _syncRouteSelection(reason: reason);
  }

  Future<void> _syncRouteSelection({required String reason}) async {
    final inFlight = _routeSyncInFlight;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _syncRouteSelectionInternal(reason: reason);
    _routeSyncInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_routeSyncInFlight, future)) {
        _routeSyncInFlight = null;
      }
    }
  }

  Future<void> _syncRouteSelectionInternal({required String reason}) async {
    final desired = await _resolvePreferredMode(refresh: true);
    if (selectedMode == desired) {
      return;
    }

    selectedModeNotifier.value = desired;
    if (_isPlaybackActive() && initializedMode != desired) {
      _debugLog(
        '[Session] Route changed to ${desired.logLabel}; '
        'new engine will attach on the next playback request ($reason)',
      );
    }
  }

  Future<AudioEngineType> _resolvePreferredMode({bool refresh = false}) async {
    final freezeDirectUsbSessionQueries =
        _uac2Service.shouldFreezeAndroidDirectUsbSessionQueries;
    final info = refresh && !freezeDirectUsbSessionQueries
        ? await _deviceService.refresh()
        : _deviceService.deviceInfoNotifier.value;
    final bitPerfectEnabled = await _preferencesService.getBitPerfectEnabled();
    final dapBitPerfectEnabled = await _preferencesService
        .getDapBitPerfectEnabled();
    final audioEnginePreference = await _preferencesService
        .getAudioEnginePreference();
    final capabilityInfo = await _uac2Service.getAndroidAudioCapabilityInfo();
    final dapInfo = await _detectedAndroidDapInfo();
    capabilityInfoNotifier.value = capabilityInfo;
    final capabilityReportsUsb = capabilityInfo.capabilities.contains(
      rust_audio.AudioCapabilityType.usbDac,
    );
    final looksLikeUsbAudioRoute = info.looksLikeUsbAudioRoute;

    _debugLog(
      '[Session] Resolve inputs: route=${info.routeLabel ?? info.routeType ?? 'unknown'} '
      'attachedUac2=${info.hasAttachedUac2Device} audioManagerUsb=${info.hasUsbDac} '
      'capabilityUsb=$capabilityReportsUsb routeLooksUsb=$looksLikeUsbAudioRoute '
      'isBt=${info.isBluetoothRoute} btLowLatency=${Uac2PreferencesService.isBtLowLatencyModeSync} '
      'btHiResDirect=${Uac2PreferencesService.isBtHiResDirectSync} '
      'bitPerfect=$bitPerfectEnabled dapBitPerfect=$dapBitPerfectEnabled '
      'enginePref=$audioEnginePreference '
      'caps=${capabilityInfo.capabilities.map((c) => c.name).toList()} '
      'detectedDap=${dapInfo.brand ?? 'none'}',
    );

    if (info.isBluetoothRoute) {
      // ponytail: dapInternalHighRes is never used on BT (level loss + 5-10s
      // dropouts on A2DP); both output-mode toggles use the stable shared
      // Rust Oboe stream. Codec quality stays driven by codec prefs.
      final outputModeReason = Uac2PreferencesService.isBtLowLatencyModeSync
          ? 'Low-latency mode'
          : Uac2PreferencesService.isBtHiResDirectSync
          ? 'Hi-Res Direct'
          : null;
      if (outputModeReason != null) {
        _debugLog(
          '[Session] Selected RUST_OBOE for Bluetooth because '
          '$outputModeReason is enabled '
          '(${info.routeLabel ?? info.routeType ?? 'unknown'})',
        );
        return AudioEngineType.rustOboe;
      }
      _debugLog(
        '[Session] Keeping NORMAL_ANDROID for Bluetooth '
        '(${info.routeLabel ?? info.routeType ?? 'unknown'})',
      );
      return AudioEngineType.normalAndroid;
    }

    if (info.hasAttachedUac2Device ||
        info.hasUsbDac ||
        capabilityReportsUsb ||
        looksLikeUsbAudioRoute) {
      if (audioEnginePreference == AudioEnginePreference.rustOboe) {
        _debugLog(
          '[Session] Selected RUST_OBOE because an external USB DAC is '
          'attached and the user prefers the Rust Android-managed engine '
          '(${info.routeLabel ?? info.routeType ?? 'unknown'}; '
          'attachedUac2=${info.hasAttachedUac2Device}; '
          'audioManagerUsb=${info.hasUsbDac}; '
          'capabilityUsb=$capabilityReportsUsb; '
          'routeLooksUsb=$looksLikeUsbAudioRoute)',
        );
        return AudioEngineType.rustOboe;
      }

      if (audioEnginePreference != AudioEnginePreference.isochronousUsb) {
        _debugLog(
          '[Session] Keeping NORMAL_ANDROID because an external USB DAC is '
          'attached but the user prefers the default Android engine '
          '(${info.routeLabel ?? info.routeType ?? 'unknown'}; '
          'attachedUac2=${info.hasAttachedUac2Device}; '
          'audioManagerUsb=${info.hasUsbDac}; '
          'capabilityUsb=$capabilityReportsUsb; '
          'routeLooksUsb=$looksLikeUsbAudioRoute)',
        );
        return AudioEngineType.normalAndroid;
      }

      // ponytail: bit-perfect (USB) off no longer forces the stuttering HAL
      // path. We keep the direct-USB driver and run the DSP chain over it —
      // the only click-free route on the Pixel USB audio HAL. bit-perfect on
      // => Passthrough; off => Dsp (decided in engine.rs direct-USB block).
      final suppressedReason = _suppressedReasonForCurrentUsbDevice(info);
      if (suppressedReason != null) {
        _debugLog(
          '[Session] Keeping NORMAL_ANDROID because USB_DAC_EXPERIMENTAL is '
          'unavailable for the current DAC this session ($suppressedReason)',
        );
        return AudioEngineType.normalAndroid;
      }
      _debugLog(
        '[Session] Selected USB_DAC_EXPERIMENTAL because an external USB DAC '
        'is attached (${info.routeLabel ?? info.routeType ?? 'unknown'}; '
        'attachedUac2=${info.hasAttachedUac2Device}; '
        'audioManagerUsb=${info.hasUsbDac}; '
        'capabilityUsb=$capabilityReportsUsb; '
        'routeLooksUsb=$looksLikeUsbAudioRoute)',
      );
      return AudioEngineType.usbDacExperimental;
    }

    // Only a *confirmed* DAP gets the exclusive internal path.
    //
    // This used to also fire on any device that merely advertised a >48k
    // internal route, which every recent flagship does -- and because the block
    // returned before the preference was consulted, all three output modes
    // resolved to the same engine and switching between them did nothing.
    final resolved = resolveInternalEngine(
      preference: audioEnginePreference,
      isConfirmedDap: dapInfo.detected,
      dapBitPerfectEnabled: dapBitPerfectEnabled,
    );
    _debugLog(
      '[Session] Selected ${resolved.logLabel} for the internal route '
      '(enginePref=$audioEnginePreference detectedDap=${dapInfo.brand ?? 'none'} '
      'dapBitPerfect=$dapBitPerfectEnabled '
      'route=${info.routeLabel ?? info.routeType ?? 'unknown'} '
      'hiResCapability=${capabilityInfo.capabilities.any((c) => c.name == 'hiResInternal')})',
    );
    return resolved;
  }

  Future<({bool detected, String? brand})> _detectedAndroidDapInfo() async {
    final debugState = await _uac2Service.getAndroidPlaybackDebugState();
    final rustState = _mapValue(debugState?['rustAudioState']);
    final deviceProfile = _mapValue(rustState?['device_profile']);
    final kind = _mapValue(deviceProfile?['kind']);
    final brand = kind?['Dap'];
    return (
      detected: brand is String && brand.isNotEmpty,
      brand: brand is String ? brand : null,
    );
  }

  Map<String, dynamic>? _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  String? _suppressedReasonForCurrentUsbDevice(AndroidPlaybackDeviceInfo info) {
    final deviceKey = _currentUsbExperimentalDeviceKey(info);
    if (deviceKey == null) {
      return null;
    }
    return _exclusiveUnavailableUsbDeviceReasons[deviceKey];
  }

  String? _currentUsbExperimentalDeviceKey(AndroidPlaybackDeviceInfo info) {
    if (!(info.hasAttachedUac2Device ||
        info.hasUsbDac ||
        info.looksLikeUsbAudioRoute)) {
      return null;
    }

    final device = _uac2Service.currentDeviceStatus?.device;
    final vendorId = device?.vendorId ?? 0;
    final productId = device?.productId ?? 0;
    if (vendorId != 0 || productId != 0) {
      return 'vid:$vendorId|pid:$productId';
    }

    final productName = _normalizeUsbIdentityToken(device?.productName);
    final manufacturer = _normalizeUsbIdentityToken(device?.manufacturer);
    if (productName.isNotEmpty || manufacturer.isNotEmpty) {
      return 'name:$productName|mfg:$manufacturer';
    }

    final routeSummary = _normalizeUsbIdentityToken(info.routeSummary);
    if (routeSummary.isNotEmpty) {
      return 'route:$routeSummary';
    }

    return null;
  }

  String _normalizeUsbIdentityToken(String? raw) {
    if (raw == null) {
      return '';
    }

    return raw
        .trim()
        .toLowerCase()
        .replaceFirst(RegExp(r'^usb[- ]audio\s*-\s*'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  void dispose() {
    final listener = _deviceInfoListener;
    if (listener != null) {
      _deviceService.deviceInfoNotifier.removeListener(listener);
    }
    _deviceInfoListener = null;
    selectedModeNotifier.dispose();
    initializedModeNotifier.dispose();
    fallbackReasonNotifier.dispose();
    capabilityInfoNotifier.dispose();
  }
}
