import 'package:flutter/material.dart';

class InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final double borderRadius;
  final double fontSize;

  const InitialAvatar({
    super.key,
    required this.name,
    required this.backgroundColor,
    required this.foregroundColor,
    this.size = 44,
    this.borderRadius = 999,
    this.fontSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    final initial = (name.isNotEmpty ? name[0] : '?').toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
          color: foregroundColor,
        ),
      ),
    );
  }
}
