import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// CUSTOM CROSSED RIFLES ICON
// -----------------------------------------------------------------------------
class CrossedRiflesIcon extends StatelessWidget {
  final Color color;
  final double size;

  const CrossedRiflesIcon({
    super.key,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CrossedRiflesPainter(color: color),
      ),
    );
  }
}

class _CrossedRiflesPainter extends CustomPainter {
  final Color color;

  _CrossedRiflesPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Draw first rifle (diagonal: top-left to bottom-right)
    canvas.drawLine(Offset(w * 0.15, h * 0.15), Offset(w * 0.85, h * 0.85), paint);
    // Draw thicker stock (bottom-right area of the diagonal)
    final stockPaint = Paint()
      ..color = color
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.65, h * 0.65), Offset(w * 0.85, h * 0.85), stockPaint);
    // Scope (small rectangle in middle)
    canvas.drawRect(
      Rect.fromCenter(center: Offset(w * 0.43, h * 0.43), width: w * 0.12, height: h * 0.08),
      Paint()..color = color..style = PaintingStyle.fill,
    );

    // Draw second rifle (diagonal: top-right to bottom-left)
    canvas.drawLine(Offset(w * 0.85, h * 0.15), Offset(w * 0.15, h * 0.85), paint);
    // Draw thicker stock (bottom-left area of the diagonal)
    canvas.drawLine(Offset(w * 0.35, h * 0.65), Offset(w * 0.15, h * 0.85), stockPaint);
    // Scope (small rectangle in middle)
    canvas.drawRect(
      Rect.fromCenter(center: Offset(w * 0.57, h * 0.43), width: w * 0.12, height: h * 0.08),
      Paint()..color = color..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
