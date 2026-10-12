import 'package:flutter/material.dart';

/// A favourite heart: outlined when off, solid when on.
///
/// Lucide ships outline icons only, so a genuinely filled heart has to be
/// drawn. Keeping it in one widget means every favourite control in the app
/// (hero card, now playing, mini player) fills identically.
class SparkHeart extends StatelessWidget {
  const SparkHeart({
    super.key,
    required this.filled,
    required this.color,
    this.size = 22,
  });

  final bool filled;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _HeartPainter(filled: filled, color: color),
      ),
    );
  }
}

class _HeartPainter extends CustomPainter {
  _HeartPainter({required this.filled, required this.color});

  final bool filled;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Two lobes meeting at a centre notch, falling to a point at the bottom.
    final path = Path()
      ..moveTo(w * 0.5, h * 0.88)
      ..cubicTo(w * 0.10, h * 0.62, w * 0.01, h * 0.40, w * 0.18, h * 0.21)
      ..cubicTo(w * 0.33, h * 0.05, w * 0.46, h * 0.16, w * 0.5, h * 0.29)
      ..cubicTo(w * 0.54, h * 0.16, w * 0.67, h * 0.05, w * 0.82, h * 0.21)
      ..cubicTo(w * 0.99, h * 0.40, w * 0.90, h * 0.62, w * 0.5, h * 0.88)
      ..close();

    if (filled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      );
      return;
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.085
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_HeartPainter oldDelegate) =>
      oldDelegate.filled != filled || oldDelegate.color != color;
}
