import 'package:flutter/material.dart';

class StitchedDivider extends StatelessWidget {
  final double thickness;
  final EdgeInsetsGeometry margin;

  const StitchedDivider({
    super.key,
    this.thickness = 2,
    this.margin = const EdgeInsets.symmetric(vertical: 18),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          width: constraints.maxWidth,
          height: thickness,
          child: CustomPaint(
            painter: _StitchPainter(
              color: cs.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _StitchPainter extends CustomPainter {
  final Color color;
  _StitchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 6.0;
    const gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, size.height / 2),
          Offset((x + dash).clamp(0, size.width), size.height / 2), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_StitchPainter old) => old.color != color;
}
