import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Custom painter for creating a dot pattern background
class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    
    final double dotSize = 3.0;
    final double spacing = 20.0;
    
    // Create a staggered dot pattern
    for (double y = 0; y < size.height + spacing; y += spacing) {
      // Convert to bool first, then use a ternary operator to get a double value
      final bool isOddRow = ((y / spacing).round() % 2 == 1);
      final double startX = isOddRow ? spacing / 2 : 0.0;
      
      for (double x = startX; x < size.width + spacing; x += spacing) {
        canvas.drawCircle(
          Offset(x, y),
          dotSize,
          paint
        );
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// Custom painter for creating a hexagonal pattern background
class HexagonPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final double hexSize = 20.0;  // Smaller hexagons
    final double hexWidth = hexSize * math.sqrt(3);
    final double hexHeight = hexSize * 2;
    final double verticalSpacing = hexHeight * 0.75;

    for (double y = -hexHeight; y < size.height + hexHeight; y += verticalSpacing) {
      final bool isOddRow = ((y / verticalSpacing).round() % 2 == 1);
      final double startX = isOddRow ? hexWidth / 2 : 0;

      for (double x = startX - hexWidth; x < size.width + hexWidth; x += hexWidth) {
        _drawHexagon(canvas, Offset(x, y), hexSize, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi) / 3;
      final x = center.dx + size * math.cos(angle);
      final y = center.dy + size * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 