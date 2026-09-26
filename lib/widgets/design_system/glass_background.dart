import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Animated liquid-glass background: three slowly drifting color orbs behind
/// the app content. Orbs are painted as radial gradients (no blur filter) and
/// animated with pure transforms, so they stay cheap to render in both themes.
class GlassBackground extends StatelessWidget {
  final Widget child;
  /// When true the background paints transparent (lets the scaffold color
  /// show through on key screens) while still providing the orbs.
  final bool transparent;

  const GlassBackground({
    super.key,
    required this.child,
    this.transparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Container(
            color: transparent
                ? Colors.transparent
                : (isDark ? const Color(0xFF0E0D15) : const Color(0xFFF7F4F2)),
          ),
        ),
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _Orb(
                color: ac.orb1,
                size: 460,
                start: const Offset(-120, -140),
                drift: const Offset(70, 55),
                duration: const Duration(seconds: 21),
              ),
              _Orb(
                color: ac.orb2,
                size: 400,
                start: const Offset(0, 0),
                drift: const Offset(-60, 70),
                duration: const Duration(seconds: 27),
                anchor: const Alignment(1.1, 1.15),
              ),
              _Orb(
                color: ac.orb3,
                size: 340,
                start: const Offset(-60, 120),
                drift: const Offset(80, -60),
                duration: const Duration(seconds: 23),
                anchor: const Alignment(0.35, 1.25),
              ),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Convenience scaffold: `GlassBackground` behind an optional [SafeArea].
class GlassScaffold extends StatelessWidget {
  final Widget child;
  final bool safeTop;
  final bool safeBottom;

  const GlassScaffold({
    super.key,
    required this.child,
    this.safeTop = true,
    this.safeBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GlassBackground(
        child: SafeArea(
          top: safeTop,
          bottom: safeBottom,
          child: child,
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final Offset start;
  final Offset drift;
  final Duration duration;
  final Alignment anchor;

  const _Orb({
    required this.color,
    required this.size,
    required this.start,
    required this.drift,
    required this.duration,
    this.anchor = Alignment.topLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: anchor,
      child: _DriftingOrb(
        color: color,
        size: size,
        start: start,
        drift: drift,
        duration: duration,
      ),
    );
  }
}

class _DriftingOrb extends StatefulWidget {
  final Color color;
  final double size;
  final Offset start;
  final Offset drift;
  final Duration duration;

  const _DriftingOrb({
    required this.color,
    required this.size,
    required this.start,
    required this.drift,
    required this.duration,
  });

  @override
  State<_DriftingOrb> createState() => _DriftingOrbState();
}

class _DriftingOrbState extends State<_DriftingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              widget.color.withValues(alpha: 0.65),
              widget.color.withValues(alpha: 0.22),
              widget.color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
      builder: (context, orb) {
        final t = _controller.value * 2 * math.pi;
        final dx = widget.drift.dx * math.sin(t);
        final dy = widget.drift.dy * math.sin(t * 0.8 + 1.2);
        return Transform.translate(
          offset: widget.start + Offset(dx, dy),
          child: orb,
        );
      },
    );
  }
}