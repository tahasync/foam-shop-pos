import 'package:flutter/material.dart';

// ── Durations & Curves ──
class AppAnim {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);

  static const Curve spring = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve fastOutSlowIn = Curves.fastOutSlowIn;
}

// ── Reusable page transitions ──
Route<T> fadeSlideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: page),
  transitionDuration: AppAnim.normal,
  reverseTransitionDuration: AppAnim.fast,
);

Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, a, __) => SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: a, curve: AppAnim.spring)),
    child: FadeTransition(opacity: a, child: page),
  ),
  transitionDuration: AppAnim.normal,
  reverseTransitionDuration: AppAnim.fast,
);

Route<T> scaleRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, a, __) => ScaleTransition(
    scale: Tween<double>(begin: 0.95, end: 1).animate(
      CurvedAnimation(parent: a, curve: AppAnim.spring),
    ),
    child: FadeTransition(opacity: a, child: page),
  ),
  transitionDuration: AppAnim.normal,
  reverseTransitionDuration: AppAnim.fast,
);

// ── Micro-interaction: scale-on-tap wrapper ──
class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const TapScale({super.key, required this.child, this.onTap, this.scale = 0.96});

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: AppAnim.fast, vsync: this);
    _anim = Tween<double>(begin: 1, end: widget.scale).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) => Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── Staggered list fade-in ──
class StaggerFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  const StaggerFadeIn({super.key, required this.index, required this.child});

  @override
  State<StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<StaggerFadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity, _transY;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: AppAnim.normal,
      vsync: this,
    );
    final delay = (widget.index * 40).clamp(0, 300);
    Future.delayed(Duration(milliseconds: delay), () { if (mounted) _ctrl.forward(); });
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
    _transY = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(parent: _ctrl, curve: AppAnim.spring),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: Offset(0, _transY.value), child: child),
      ),
      child: widget.child,
    );
  }
}

// ── Animated check mark for success states ──
class AnimatedCheck extends StatefulWidget {
  final double size;
  final Color color;
  const AnimatedCheck({super.key, this.size = 48, this.color = Colors.green});

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: AppAnim.slow, vsync: this);
    _scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.4, 1, curve: Curves.easeOut)),
    );
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 2)],
        ),
        child: Transform.scale(
          scale: _scale.value,
          child: CustomPaint(
            painter: _CheckPainter(progress: _checkProgress.value, color: Colors.white),
            size: Size(widget.size, widget.size),
          ),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(size.width * 0.25, size.height * 0.5)
      ..lineTo(size.width * 0.43, size.height * 0.68)
      ..lineTo(size.width * 0.75, size.height * 0.32);
    final metrics = path.computeMetrics();
    for (final m in metrics) {
      final trimmed = m.extractPath(0, m.length * progress);
      canvas.drawPath(trimmed, paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
