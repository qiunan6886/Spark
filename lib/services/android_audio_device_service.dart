import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:spark/services/uac2_service.dart';
import 'package:spark/core/utils/dev_log.dart';

class AndroidPlaybackDeviceInfo {
  const AndroidPlaybackDeviceInfo({
    required this.hasUsbDac,
    required this.hasAttachedUac2Device,
    required this.hasPermittedUsbAudioDevice,
    required this.manufacturer,
    required this.model,
    this.routeType,
    this.routeLabel,
  });

  /// Whether Android is **currently routing** output to a USB device.
  final bool hasUsbDac;

  /// Whether a USB audio device is **plugged in**. Not the same as [hasUsbDac]:
  /// the device can be attached while Android has not moved the route to it.
  final bool hasAttachedUac2Device;

  /// Whether an attached USB audio device is ours to use.
  ///
  /// Attached is not the same as usable -- `UsbManager.deviceList` includes
  /// devices the user has denied permission for.
  final bool hasPermittedUsbAudioDevice;

  final String manufacturer;
  final String model;
  final String? routeType;
  final String? routeLabel;

  bool get isUsbRoute => routeType == 'usb';
  bool get isInternalRoute => routeType == 'internal';
  bool get isWiredRoute => routeType == 'wired';
  bool get isBluetoothRoute => routeType == 'bluetooth';
  bool get isDockRoute => routeType == 'dock';

  /// Whether Android reports USB as the **current** output route.
  ///
  /// Deliberately identity-based: a route *label* or an attached DAC is not
  /// evidence that the USB route is active, so this must not match on
  /// [routeLabel] ([routeSummary]).
  bool get looksLikeUsbAudioRoute => isUsbRoute;

  bool get isLikelyDap {
    final haystack = '${manufacturer.toLowerCase()} ${model.toLowerCase()}';
    const dapKeywords = <String>[
      'fiio',
      'ibasso',
      'hiby',
      'shanling',
      'astell',
      'iriver',
      'cayin',
      'sony',
      'tempotec',
      'luxury',
      'luxuryprecision',
    ];
    return dapKeywords.any(haystack.contains);
  }

  bool get isXiaomiDevice {
    final haystack = '${manufacturer.toLowerCase()} ${model.toLowerCase()}';
    return haystack.contains('xiaomi') ||
        haystack.contains('redmi') ||
        haystack.contains('poco') ||
        haystack.contains('miui');
  }

  String get routeSummary => routeLabel ?? routeType ?? 'unknown';

  factory AndroidPlaybackDeviceInfo.fromMap(Map<Object?, Object?> raw) {
    return AndroidPlaybackDeviceInfo(
      hasUsbDac: raw['hasUsbDac'] == true,
      hasAttachedUac2Device: raw['hasAttachedUac2Device'] == true,
      hasPermittedUsbAudioDevice: raw['hasPermittedUsbAudioDevice'] == true,
      manufacturer: raw['manufacturer'] as String? ?? '',
      model: raw['model'] as String? ?? '',
      routeType: raw['routeType'] as String?,
      routeLabel: raw['routeLabel'] as String?,
    );
  }

  static const unknown = AndroidPlaybackDeviceInfo(
    hasUsbDac: false,
    hasAttachedUac2Device: false,
    hasPermittedUsbAudioDevice: false,
    manufacturer: '',
    model: '',
  );
}

class AndroidAudioDeviceService {
  AndroidAudioDeviceService._();

  static final AndroidAudioDeviceService instance =
      AndroidAudioDeviceService._();

  static const MethodChannel _channel = MethodChannel(
    'com.mossapps.spark/audio_device',
  );

  final ValueNotifier<AndroidPlaybackDeviceInfo> deviceInfoNotifier =
      ValueNotifier(AndroidPlaybackDeviceInfo.unknown);

  bool _channelConfigured = false;
  Future<void>? _initializeInFlight;
  Future<AndroidPlaybackDeviceInfo>? _refreshInFlight;

  Future<void> initialize() async {
    if (!Platform.isAndroid) return;

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

  Future<AndroidPlaybackDeviceInfo> refresh() async {
    if (!Platform.isAndroid) {
      return AndroidPlaybackDeviceInfo.unknown;
    }

    if (Uac2Service.instance.shouldFreezeAndroidDirectUsbSessionQueries) {
      return deviceInfoNotifier.value;
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _refreshInternal();
    _refreshInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  Future<void> _initializeInternal() async {
    if (!_channelConfigured) {
      _channelConfigured = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onPlaybackDevicesChanged') {
          devLog('[Engine] Audio device change detected');
          if (Uac2Service.instance.shouldFreezeAndroidDirectUsbSessionQueries) {
            return;
          }
          await refresh();
        }
      });
    }

    await refresh();
  }

  Future<AndroidPlaybackDeviceInfo> _refreshInternal() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'getPlaybackDeviceInfo',
      );
      final info = raw == null
          ? AndroidPlaybackDeviceInfo.unknown
          : AndroidPlaybackDeviceInfo.fromMap(raw);
      deviceInfoNotifier.value = info;
      return info;
    } catch (e) {
      devLog('AndroidAudioDeviceService.refresh failed: $e');
      deviceInfoNotifier.value = AndroidPlaybackDeviceInfo.unknown;
      return AndroidPlaybackDeviceInfo.unknown;
    }
  }
}
