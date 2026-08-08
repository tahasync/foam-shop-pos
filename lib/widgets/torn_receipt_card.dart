import 'package:flutter/material.dart';

class TornReceiptCard extends StatelessWidget {
  final String label;
  final String amount;
  final List<SlipStat> stats;
  final Color gradientStart;
  final Color gradientEnd;
  final String? stubLeft;
  final String? stubRight;
  final Widget? trailing;
  final Widget? bottomAction;

  const TornReceiptCard({
    super.key,
    required this.label,
    required this.amount,
    this.stats = const [],
    required this.gradientStart,
    required this.gradientEnd,
    this.stubLeft,
    this.stubRight,
    this.trailing,
    this.bottomAction,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final surface2 = cs.surfaceContainerLow;
    final card = Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [gradientStart, gradientEnd]),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.account_balance_wallet_rounded, size: 15, color: Colors.white.withValues(alpha: 0.92)),
              const SizedBox(width: 6),
              Text(label.toUpperCase(),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.07,
                      color: Colors.white.withValues(alpha: 0.92))),
              if (trailing != null) ...[const Spacer(), trailing!],
            ]),
            const SizedBox(height: 5),
            Text(amount,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.01,
                    fontFeatures: const [FontFeature.tabularFigures()], color: Colors.white)),
            if (stats.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: stats.map((s) => Expanded(child: _statItem(s, context))).toList()),
            ],
          ]),
        ),
        SizedBox(
          height: 11,
          width: double.infinity,
          child: CustomPaint(painter: _TornEdgePainter(surface2: surface2, bgColor: cs.surface)),
        ),
        if (stubLeft != null || stubRight != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            decoration: BoxDecoration(
              color: surface2,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(stubLeft ?? '', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                  letterSpacing: 0.03, color: cs.onSurfaceVariant)),
              if (stubRight != null)
                Text(stubRight!, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()], color: cs.onSurfaceVariant)),
            ]),
          ),
        if (bottomAction != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: bottomAction,
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          elevation: 0,
          shadowColor: gradientStart.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          child: card,
        ),
      ),
    );
  }

  Widget _statItem(SlipStat s, BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.3)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.label, style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.85))),
        const SizedBox(height: 2),
        Text(s.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()], color: Colors.white)),
      ]),
    );
  }
}

class SlipStat {
  final String label;
  final String value;
  const SlipStat({required this.label, required this.value});
}

class _TornEdgePainter extends CustomPainter {
  final Color surface2;
  final Color bgColor;
  _TornEdgePainter({required this.surface2, required this.bgColor});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final paint = Paint()..color = surface2;
    const step = 14.0;
    final half = step / 2;
    final path = Path();
    path.moveTo(0, 11);
    for (double x = 0; x <= w; x += step) {
      path.lineTo(x, 0);
      path.lineTo((x + half).clamp(0, w), 11);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = bgColor);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_TornEdgePainter old) =>
      old.surface2 != surface2 || old.bgColor != bgColor;
}


