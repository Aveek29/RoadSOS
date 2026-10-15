import 'dart:math';
import 'package:flutter/material.dart';

class QRCodePainter extends CustomPainter {
  final String data;
  final Color color;

  QRCodePainter({
    required this.data,
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // We'll draw a 21x21 grid (QR Code Version 1)
    const int gridSize = 21;
    final double cellSize = size.width / gridSize;

    // Deterministic random generator based on hash of input data string
    final random = Random(data.hashCode);

    // Draw finder patterns at: top-left, top-right, bottom-left
    _drawFinderPattern(canvas, 0, 0, cellSize, paint);
    _drawFinderPattern(canvas, gridSize - 7, 0, cellSize, paint);
    _drawFinderPattern(canvas, 0, gridSize - 7, cellSize, paint);

    // Draw timing patterns (alternating modules between finder patterns)
    for (int i = 7; i < gridSize - 7; i++) {
      if (i % 2 == 0) {
        canvas.drawRect(Rect.fromLTWH(i * cellSize, 6 * cellSize, cellSize, cellSize), paint);
        canvas.drawRect(Rect.fromLTWH(6 * cellSize, i * cellSize, cellSize, cellSize), paint);
      }
    }

    // Draw random data modules, avoiding the finder areas (first 8x8 columns/rows)
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Skip Finder Pattern Top-Left
        if (r < 8 && c < 8) continue;
        // Skip Finder Pattern Top-Right
        if (r < 8 && c >= gridSize - 8) continue;
        // Skip Finder Pattern Bottom-Left
        if (r >= gridSize - 8 && c < 8) continue;
        // Skip Timing Pattern tracks
        if (r == 6 || c == 6) continue;

        // Draw data module pseudo-randomly based on string seed
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellSize, r * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, int col, int row, double cellSize, Paint paint) {
    // 7x7 outer square
    canvas.drawRect(
      Rect.fromLTWH(col * cellSize, row * cellSize, 7 * cellSize, 7 * cellSize),
      paint,
    );
    // 5x5 inner transparent cut-out (drawn by background color)

    // Wait, blending clear might clear the whole canvas to transparent if layer is not isolated.
    // Instead of BlendMode.clear, we draw with the opposite color (e.g. background of the card: charcoal or black)
    // To make it blend on any background, we can draw explicit black/white rings.
    // Let's draw with background color: transparent ring can be achieved by drawing the black/white layers directly:
    // Actually, finder pattern is: 7x7 outer square, 5x5 white square, 3x3 black square (relative to dark/light theme).
    // Let's draw with theme background color or draw transparent layers. Let's use the opposite color.
    // Let's draw the white (inverse) ring:
    final inversePaint = Paint()
      ..color = color == Colors.white ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH((col + 1) * cellSize, (row + 1) * cellSize, 5 * cellSize, 5 * cellSize),
      inversePaint,
    );

    // 3x3 inner square
    canvas.drawRect(
      Rect.fromLTWH((col + 2) * cellSize, (row + 2) * cellSize, 3 * cellSize, 3 * cellSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class QRCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color color;

  const QRCodeWidget({
    super.key,
    required this.data,
    this.size = 140.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.transparent,
      child: CustomPaint(
        painter: QRCodePainter(data: data, color: color),
      ),
    );
  }
}
