import 'package:flutter/material.dart';

import '../../models/album_color_mode.dart';

/// Colour derivations that let a surface pick up the hue of its cover art.
///
/// Two rules keep this safe everywhere:
///   * gradients stay LIGHT, because the hero card always draws near-black text
///     and icons on top of them;
///   * the hero button stays DARK, because it always draws the lime accent on
///     top of itself.
///
/// So the source colour is only allowed to steer hue and saturation -- never
/// lightness. That is what stops a dark cover from producing an unreadable card.

/// Saturation band that reads as "coloured" without turning muddy.
const double _minSaturation = 0.34;
const double _maxSaturation = 0.72;

/// Lightness of the three gradient stops. Kept high for legibility.
const double _stopLightnessA = 0.70;
const double _stopLightnessB = 0.76;
const double _stopLightnessC = 0.68;

HSLColor _steer(Color source, {double hueShift = 0, required double lightness}) {
  final hsl = HSLColor.fromColor(source);
  return HSLColor.fromAHSL(
    1,
    (hsl.hue + hueShift) % 360,
    hsl.saturation.clamp(_minSaturation, _maxSaturation),
    lightness,
  );
}

/// Gradient for the "curated" hero card.
///
/// Falls back to the designed gradient when there is no cover, or when the user
/// has turned cover-art colouring off.
LinearGradient heroGradientFor(Color? dominant, AlbumColorMode mode) {
  final base = SparkHeroGradient.defaultGradient;
  if (dominant == null || mode == AlbumColorMode.off) return base;

  final blend = mode.backgroundBlend * 3.2;
  final tinted = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      _steer(dominant, hueShift: -26, lightness: _stopLightnessA).toColor(),
      _steer(dominant, lightness: _stopLightnessB).toColor(),
      _steer(dominant, hueShift: 32, lightness: _stopLightnessC).toColor(),
    ],
  );

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.lerp(base.colors[0], tinted.colors[0], blend)!,
      Color.lerp(base.colors[1], tinted.colors[1], blend)!,
      Color.lerp(base.colors[2], tinted.colors[2], blend)!,
    ],
  );
}

/// Background of the round play button on the hero card.
///
/// Stays very dark so the lime glyph keeps its contrast, but picks up a hint of
/// the cover's hue.
Color heroButtonColorFor(Color? dominant, AlbumColorMode mode) {
  const base = Color(0xFF14101C);
  if (dominant == null || mode == AlbumColorMode.off) return base;
  return Color.lerp(base, dominant, mode.accentBlend * 0.55)!;
}

/// Holder for the designed gradient so this file has one source for the
/// fallback, independent of the active theme palette.
abstract final class SparkHeroGradient {
  static const LinearGradient defaultGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB98BE8), Color(0xFFE28CC8), Color(0xFF8FB6F0)],
  );
}
