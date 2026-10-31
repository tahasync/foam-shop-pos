import 'package:flutter/material.dart';
import '../utils/haptics.dart';
import '../theme/app_tokens.dart';
import 'dart:async';

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const ScaleButton(
      {super.key, required this.child, this.onTap, this.scale = 0.97});

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: AppMotion.fast, vsync: this);
    _anim =
        Tween<double>(begin: 1.0, end: widget.scale).animate(CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    _ctrl.duration = reduceMotion ? Duration.zero : AppMotion.fast;
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onTap != null && !reduceMotion) _ctrl.forward();
      },
      onTapUp: (_) {
        _ctrl.reverse();
      },
      onTap: widget.onTap == null
          ? null
          : () {
              final onTap = widget.onTap;
              if (onTap != null) {
                unawaited(AppHaptics.tap());
                onTap();
              }
            },
      onTapCancel: () => _ctrl.reverse(),
      child: reduceMotion
          ? widget.child
          : AnimatedBuilder(
              animation: _anim,
              builder: (_, child) =>
                  Transform.scale(scale: _anim.value, child: child),
              child: widget.child,
            ),
    );
  }
}
