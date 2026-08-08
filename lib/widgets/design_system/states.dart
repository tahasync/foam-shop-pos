import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Empty state (`.empty`).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool celebrate;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.celebrate = false,
  });

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final color = celebrate ? ac.saleFg : ac.inkFaint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
      child: Column(
        children: [
          Icon(icon, size: 38, color: celebrate ? color : ac.inkFaint.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(title,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: celebrate ? ac.ink : ac.inkSoft)),
          const SizedBox(height: 3),
          Text(subtitle,
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: ac.inkFaint)),
        ],
      ),
    );
  }
}

/// No-results state for filtered lists.
class NoResults extends StatelessWidget {
  final String title;
  final String subtitle;
  const NoResults({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 30, color: ac.inkFaint.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ac.inkSoft)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(fontSize: 11, color: ac.inkFaint)),
        ],
      ),
    );
  }
}

/// Result-count caption for filtered lists.
class ResultCount extends StatelessWidget {
  final int count;
  const ResultCount({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Text('$count result${count == 1 ? '' : 's'}',
          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: ac.inkFaint)),
    );
  }
}
