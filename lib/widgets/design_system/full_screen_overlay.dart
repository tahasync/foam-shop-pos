import 'package:flutter/material.dart';
import '../../utils/animations.dart';
import 'design_system.dart';

/// Full-screen overlay scaffold (`.overlay`): a floating glass top bar with a
/// back button, title and optional actions, then a padded scroll body over the
/// animated liquid-glass backdrop.
///
/// Bug fixed here: the header used to be a `SafeArea`-wrapped strip whose
/// `AppIconButton` was given `size: 15`. That produced a 15px button wrapped in
/// a `blurRadius: 20` white glow which bled across the title, and on devices
/// reporting a zero top inset the row was painted straight into the status bar
/// so the title and the clock overlapped. The header is now [AppTopBar], which
/// owns the inset maths and a correctly sized back button.
class FullScreenOverlay extends StatelessWidget {
  const FullScreenOverlay({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.leading,
    this.scrollController,
  });

  final String title;
  final List<Widget>? actions;
  final Widget child;
  final Widget? leading;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      // `resizeToAvoidBottomInset` matters here: several of these screens host
      // amount inputs, and without it the keyboard covers the confirm button.
      resizeToAvoidBottomInset: true,
      body: GlassBackground(
        child: Column(
          children: [
            AppTopBar(
              title: title,
              leading: leading,
              actions: actions ?? const [],
              onBack: leading == null ? () => Navigator.maybePop(context) : null,
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.xs,
                  AppSpacing.gutter,
                  // Clear the home indicator / gesture bar.
                  MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pushes a [FullScreenOverlay] using the app's standard slide-up transition.
void pushOverlay(BuildContext context, Widget page) =>
    Navigator.push(context, slideUpRoute(page));