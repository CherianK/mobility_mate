import 'package:flutter/material.dart';

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