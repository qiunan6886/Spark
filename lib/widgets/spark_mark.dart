import 'package:flutter/material.dart';

import '../app/theme/spark_theme.dart';

/// The Spark mark: a four-point sparkle.
///
/// Drawn rather than shipped as an asset, so it stays crisp at any size, needs
/// no per-density variants, and follows the active theme's accent colour.
///
/// This replaces the gradient circle that used to sit at the top-left of the
/// home screen. That circle was a placeholder for an account avatar, but Spark
/// has no accounts -- so it read as a login button that did nothing. A brand
/// mark is what the space is actually for.
class SparkMark extends StatelessWidget {
  const SparkMark({
    super.key,
    this.size = 40,
    this.color,
    this.background,
    this.radius,
  });

  final double size;
  final Color? color;

  /// Fill behind the mark. Null leaves it transparent.
  final Color? background;

  /// Corner radius of [background]; defaults to a squircle-ish 28%.
  final double? radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SparkMarkPainter(
          color: color ?? SparkColors.accent,
          background: background,
          radius: radius ?? size * 0.28,
        ),
      ),
    );
  }
}

class _SparkMarkPainter extends CustomPainter {
  _SparkMarkPainter({
    required this.color,
    required this.background,
    required this.radius,
  });

  final Color color;
  final Color? background;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (background != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        Paint()..color = background!,
      );
    }

    final centre = rect.center;
    // Leave a margin so the sharp tips are not clipped by the rounded box.
    final r = size.shortestSide * 0.36;

    canvas.drawPath(
      _sparklePath(centre, r, waist: 0.13),
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  /// A four-point sparkle with sharp tips.
  ///
  /// Straight-sided polygons read as a plus sign; the concave sides are what
  /// make it a spark, so each side is a cubic pulled toward the centre by
  /// [waist] (fraction of [r]).
  Path _sparklePath(Offset c, double r, {required double waist}) {
    final top = Offset(c.dx, c.dy - r);
    final right = Offset(c.dx + r, c.dy);
    final bottom = Offset(c.dx, c.dy + r);
    final left = Offset(c.dx - r, c.dy);
    final w = waist * r;

    final path = Path()..moveTo(top.dx, top.dy);
    path.cubicTo(c.dx + w, c.dy - w, c.dx + w, c.dy - w, right.dx, right.dy);
    path.cubicTo(c.dx + w, c.dy + w, c.dx + w, c.dy + w, bottom.dx, bottom.dy);
    path.cubicTo(c.dx - w, c.dy + w, c.dx - w, c.dy + w, left.dx, left.dy);
    path.cubicTo(c.dx - w, c.dy - w, c.dx - w, c.dy - w, top.dx, top.dy);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(_SparkMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.background != background ||
      oldDelegate.radius != radius;
}
