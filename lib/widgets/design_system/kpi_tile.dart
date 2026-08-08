import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../initial_avatar.dart' show InitialAvatar;
import 'foam_card.dart';

/// A KPI tile matching `.kpi` in the mockup: tinted icon chip, uppercase label,
/// Fraunces value and a faint sub-label.
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final Color? valueColor;
  final bool foam;
  final bool span2;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.tint,
    required this.iconColor,
    this.valueColor,
    this.foam = true,
    this.span2 = false,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 15, color: iconColor),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ac.inkSoft)),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTheme.display(context, size: 21, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(sub, style: TextStyle(fontSize: 10.5, color: ac.inkFaint)),
      ],
    );

    final tile = Container(
      constraints: const BoxConstraints(minHeight: 104),
      child: content,
    );

    return span2 ? FoamCard(foam: foam, padding: const EdgeInsets.all(15), child: tile)
        : FoamCard(foam: foam, padding: const EdgeInsets.all(15), child: tile);
  }
}

/// A horizontal tile that renders an avatar on the left, label + value pair on
/// the right (used for supplier rows and khata-style list items).
class RowAvatar extends StatelessWidget {
  final String initials;
  final Color background;
  final Color foreground;
  final double size;

  const RowAvatar({
    super.key,
    required this.initials,
    required this.background,
    required this.foreground,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.31),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.34,
          ),
        ),
      ),
    );
  }
}

/// Simple initials avatar using the shared [InitialAvatar] widget.
class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  const InitialsAvatar({super.key, required this.name, this.size = 42});

  @override
  Widget build(BuildContext context) {
    return InitialAvatar(
      name: name,
      size: size,
      borderRadius: size * 0.31,
      fontSize: size * 0.34,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
    );
  }
}
