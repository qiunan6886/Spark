import 'package:flutter/foundation.dart';
import 'package:spark/models/audio_engine_type.dart';

enum AudioPathManagement {
  androidManagedShared,
  androidManagedLowLatency,
  directUsbExperimental,
  alsaDirectDap,
  managedDirectExclusive,
}

@immutable
class AudioCapabilityFlags {
  const AudioCapabilityFlags({
    required this.supportsExclusiveUsbOwnership,
    required this.supportsDirectSampleRateSwitching,
    required this.supportsVerifiedBitPerfect,
    required this.supportsAndroidManagedHighResOnly,
    required this.supportsInternalDapPathOnly,
  });

  final bool supportsExclusiveUsbOwnership;
  final bool supportsDirectSampleRateSwitching;
  final bool supportsVerifiedBitPerfect;
  final bool supportsAndroidManagedHighResOnly;
  final bool supportsInternalDapPathOnly;
}

@immutable
class UrbTransportInfo {
  const UrbTransportInfo({
    this.activeAltSetting,
    this.activeEndpointAddress,
    this.activeSyncType,
    this.activeUsageType,
    this.activeRefresh,
    this.activeServiceIntervalUs,
    this.activeMaxPacketBytes,
    this.transportFormat,
    this.transportSubslot,
    this.transportBitResolution,
    this.bufferFillMs,
    this.bufferCapacityMs,
    this.bufferTargetMs,
    this.framesPerPacket,
    this.underrunCount,
    this.producerFrames,
    this.consumerFrames,
    this.driftMsFromTarget,
  });

  final int? activeAltSetting;
  final int? activeEndpointAddress;
  final String? activeSyncType;
  final String? activeUsageType;
  final int? activeRefresh;
  final int? activeServiceIntervalUs;
  final int? activeMaxPacketBytes;
  final String? transportFormat;
  final int? transportSubslot;
  final int? transportBitResolution;
  final int? bufferFillMs;
  final int? bufferCapacityMs;
  final int? bufferTargetMs;
  final int? framesPerPacket;
  final int? underrunCount;
  final int? producerFrames;
  final int? consumerFrames;
  final int? driftMsFromTarget;
}

@immutable
class AudioOutputDiagnostics {
  const AudioOutputDiagnostics({
    required this.selectedMode,
    required this.initializedMode,
    required this.detectedDap,
    required this.detectedDapBrand,
    required this.pathManagement,
    required this.outputStrategyLabel,
    required this.capabilityStateLabel,
    required this.backendDescription,
    required this.routeType,
    required this.routeLabel,
    required this.outputDeviceLabel,
    required this.isMixerManaged,
    required this.audioFocusHeld,
    required this.directUsbRegistered,
    required this.usbInterfaceClaimed,
    required this.usbStreamStable,
    required this.trackSampleRate,
    required this.requestedOutputSampleRate,
    required this.reportedOutputSampleRate,
    required this.resamplerActive,
    required this.passthroughAllowed,
    required this.activeOutputSignature,
    required this.verificationReason,
    required this.fallbackReason,
    this.engineNote,
    required this.capabilityFlags,
    this.urbTransport,
  });

  final AudioEngineType selectedMode;
  final AudioEngineType? initializedMode;
  final bool detectedDap;
  final String? detectedDapBrand;
  final AudioPathManagement pathManagement;
  final String outputStrategyLabel;
  final String capabilityStateLabel;
  final String backendDescription;
  final String routeType;
  final String routeLabel;
  final String outputDeviceLabel;
  final bool isMixerManaged;
  final bool audioFocusHeld;
  final bool directUsbRegistered;
  final bool usbInterfaceClaimed;
  final bool usbStreamStable;
  final int? trackSampleRate;
  final int? requestedOutputSampleRate;
  final int? reportedOutputSampleRate;
  final bool resamplerActive;
  final bool passthroughAllowed;
  final String? activeOutputSignature;
  final String? verificationReason;
  final String? fallbackReason;

  /// Why the engine differs from the requested one when that is deliberate for
  /// this track rather than a failure -- an uncached stream is played by the
  /// Android player on purpose.
  ///
  /// Kept apart from [fallbackReason] so the UI can say "expected" instead of
  /// raising an error on a mode setting that is working correctly.
  final String? engineNote;

  final AudioCapabilityFlags capabilityFlags;
  final UrbTransportInfo? urbTransport;
}

/// True when the audio path that actually initialised is not the one that was
/// requested -- i.e. a silent fallback.
///
/// Worth surfacing because a fallback used to be indistinguishable from success:
/// settings only ever showed the requested mode. A null `initializedMode` means
/// nothing has initialised yet, which is not a fallback.
bool audioPathFellBack(AudioOutputDiagnostics diagnostics) {
  final initialized = diagnostics.initializedMode;
  return initialized != null && initialized != diagnostics.selectedMode;
}
