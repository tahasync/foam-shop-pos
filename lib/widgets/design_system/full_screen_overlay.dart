import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/animations.dart';
import 'elevation.dart';

/// Full-screen overlay scaffold (`.overlay`): back button + title + optional
/// actions in the overlay bar, then a padded scroll body.
class FullScreenOverlay extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget child;
  final Widget? leading;

  const FullScreenOverlay({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ac = AppColors.of(context);
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(color: cs.surface, border: Border(bottom: BorderSide(color: ac.outline))),
            child: Row(
              children: [
                leading ??
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: appElevationShadows(context),
                        ),
                        foregroundDecoration: darkTopEdgeHighlight(context),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
                      ),
                    ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontFamilyFallback: ['serif'],
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pushes a [FullScreenOverlay] using the app's standard slide-up transition.
void pushOverlay(BuildContext context, Widget page) =>
    Navigator.push(context, slideUpRoute(page));
