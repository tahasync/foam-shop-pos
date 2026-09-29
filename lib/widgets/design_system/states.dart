import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'app_button.dart';
import 'brand_mark.dart';
import 'glass_container.dart';

/// Error state, with a retry.
///
/// The design system shipped [EmptyState], [NoResults] and [LoadingScreen] but
/// **no error state**, which is the one a POS needs most: the difference
/// between "you have no sales" and "we could not load your sales" is the whole
/// difference between a calm screen and a cashier who thinks the shop is empty.
///
/// The gap was filled by hand instead: four screens each declared a
/// file-private `_ErrorBox`, and none of them had a retry button or told the
/// user anything more useful than a raw exception string. This is the shared
/// version, and it is deliberately part of the design system rather than another
/// private copy, so the next screen cannot reintroduce the gap.
///
/// A retry is optional because not every error is retryable — a permission
/// denial will fail identically forever, and offering a button that cannot work
/// is worse than saying plainly what went wrong.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  /// Short, human summary. Never a raw exception type.
  final String title;

  /// Optional second line with more detail.
  final String? message;

  /// When provided, renders a retry button. Omit for non-retryable errors.
  final VoidCallback? onRetry;

  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: ac.dangerFill,
            shape: BoxShape.circle,
            border: Border.all(color: ac.dangerSolid.withValues(alpha: 0.16)),
          ),
          child: Icon(
            Icons.cloud_off_rounded,
            size: AppIconSize.xxl - 6,
            color: ac.dangerSolid,
          ),
        ),
        SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.01,
            color: ac.ink,
          ),
        ),
        if (message != null && message!.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: ac.inkSoft,
              ),
            ),
          ),
        ],
        if (onRetry != null) ...[
          SizedBox(height: AppSpacing.lg),
          AppButton(
            label: retryLabel,
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.outline,
            onTap: onRetry,
          ),
        ],
      ],
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: content,
      ),
    );
  }
}

/// Empty state.
///
/// Previously this was a bare icon and two lines of text floating directly on
/// the page background, which made every empty screen look unfinished (the
/// "No outstanding baqaya!" and "No items added yet." panels in particular). It
/// is now a proper glass card with the icon in a tinted chip, so an empty state
/// reads as a deliberate, designed moment rather than a gap in the data.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.celebrate = false,
    this.tint,
    this.tintStrength = 1.0,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// Success framing (a "nothing outstanding" state) vs neutral.
  final bool celebrate;

  final Color? tint;
  final double tintStrength;

  /// Drops the card chrome for use *inside* an existing card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final fg = celebrate ? ac.saleFg : ac.inkSoft;
    final chipTint = tint ?? (celebrate ? ac.saleTint : ac.glassNested);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: chipTint,
            shape: BoxShape.circle,
            border: Border.all(color: fg.withValues(alpha: 0.16)),
          ),
          child: Icon(
            icon,
            size: AppIconSize.xxl - 6,
            color: celebrate ? fg : ac.inkFaint,
          ),
        ),
        SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.01,
            color: ac.ink,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ConstrainedBox(
          // Keeps the supporting line to a comfortable measure instead of
          // running edge-to-edge on a wide screen.
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: ac.inkFaint,
            ),
          ),
        ),
      ],
    );

    if (compact) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: content,
      );
    }

    return GlassContainer(
      level: AppGlassLevel.base,
      radius: AppRadii.xl,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxxl,
      ),
      tint: tint,
      tintStrength: tintStrength,
      child: Center(child: content),
    );
  }
}

/// No-results state for filtered lists.
class NoResults extends StatelessWidget {
  const NoResults({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon = Icons.search_off_rounded,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ac.glassNested,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: AppIconSize.lg, color: ac.inkFaint),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: ac.inkSoft,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: ac.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// Blocking loading state for the moments the app cannot render real content.
///
/// This exists because the post-sign-in path used to render a bare
/// `CircularProgressIndicator` on an empty `Scaffold`. On a cold start that
/// fetch of the shop profile from Firestore takes 15-25 seconds, and for that
/// whole window the user saw a blank white page with a small unstyled spinner.
/// That reads as a crashed or frozen app, so shopkeepers tapped the sign-in
/// button again and again - and repeated taps are exactly what trips the
/// 5-attempts-per-minute rate limiter in `AuthService`, turning a merely slow
/// load into a hard, misleading "too many attempts" failure.
///
/// The fix is to make the wait look deliberate: brand mark, an indeterminate
/// progress indicator, and a line that says what is happening. A wait the user
/// can read is a wait they will not fight.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({
    super.key,
    this.title = 'Loading',
    this.subtitle,
    this.showBrand = true,
  });

  /// What is being waited on, in the user's terms (e.g. "Setting up your shop").
  final String title;

  /// Optional reassurance line. Defaults to a generic "this can take a moment"
  /// only when [showBrand] is on; callers that pass no copy still get a clear
  /// title rather than a silent page.
  final String? subtitle;

  /// Set false for a nested, in-page wait where the brand mark would be noise.
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxxl,
            vertical: AppSpacing.xxxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showBrand) ...[
                const BrandMark(size: 56, iconSize: 26),
                const SizedBox(height: AppSpacing.xxl),
              ],
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: cs.primary,
                  strokeCap: StrokeCap.round,
                ),
              ),
              SizedBox(height: showBrand ? AppSpacing.xl : AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.01,
                  color: ac.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  // Keeps the supporting line to a comfortable measure instead
                  // of running edge-to-edge on a wide screen.
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: ac.inkFaint,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
