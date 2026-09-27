import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_tokens.dart';
import 'glass_container.dart';

/// Search field — a true glass pill.
///
/// Bug fixed here: the `TextField` inherited the global `InputDecorationTheme`,
/// which filled it with an almost-opaque white slab at a *different* radius to
/// the surrounding glass. That produced the "white rectangle floating inside a
/// rounded field" you saw on Inventory, New Sale, Khata and Customer Recovery.
/// The fix has two halves and both are needed:
///   1. the theme fill is now translucent (see `app_theme.dart`), and
///   2. this widget explicitly opts out of *any* fill and border, so a future
///      theme change can never reintroduce the slab.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.hintText = 'Search\u2026',
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Fired after the built-in clear button empties the field, so callers reset
  /// their filter state in one place instead of duplicating the logic.
  final VoidCallback? onClear;

  final String hintText;
  final bool autofocus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);

    // Rebuild on each keystroke so the clear button can appear and disappear.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller ?? _kEmptyController,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;
        return GlassContainer(
          radius: AppRadii.pill,
          level: AppGlassLevel.raised,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: SizedBox(
            // The whole control meets the 48dp minimum target.
            height: AppHit.min,
            child: Row(
              children: [
                Icon(Icons.search_rounded,
                    size: AppIconSize.sm, color: ac.inkFaint),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    enabled: enabled,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: ac.ink,
                    ),
                    cursorColor: ac.primary,
                    cursorRadius: const Radius.circular(2),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: ac.inkFaint,
                      ),
                      // Opt out of the theme fill *and* border entirely — the
                      // glass pill *is* the field.
                      filled: false,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (hasText) ...[
                  const SizedBox(width: AppSpacing.sm),
                  _ClearButton(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      controller?.clear();
                      onChanged?.call('');
                      onClear?.call();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A stand-in notifier for when no controller is supplied, so
/// `ValueListenableBuilder` always has something to listen to.
final TextEditingValue _kEmpty = TextEditingValue.empty;
final ValueNotifier<TextEditingValue> _kEmptyController =
    ValueNotifier<TextEditingValue>(_kEmpty);

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      // The row is already 48px tall, so the vertical target is satisfied; this
      // padding brings the horizontal extent over the 44px minimum too.
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: ac.saleTint, shape: BoxShape.circle),
          child: Icon(Icons.close_rounded,
              size: AppIconSize.xs - 2, color: ac.saleFg),
        ),
      ),
    );
  }
}

/// Form field — a visible label above a glass input.
///
/// Two pro-rules are enforced here that the previous version ignored:
///  * the label is **always** rendered (never placeholder-only), and
///  * errors, if any, are rendered *next to the field that caused them*,
///    never only at the top of the form.
class AppField extends StatelessWidget {
  const AppField({
    super.key,
    required this.label,
    this.controller,
    this.hintText,
    this.initialValue,
    this.keyboardType = TextInputType.text,
    this.readOnly = false,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
    this.errorText,
    this.helperText,
    this.semanticLabel,
    this.textCapitalization = TextCapitalization.sentences,
    this.focusNode,
  });

  final String label;
  final TextEditingController? controller;
  final String? hintText;
  final String? initialValue;
  final TextInputType keyboardType;
  final bool readOnly;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;

  /// Rendered directly beneath the field, in the error colour.
  final String? errorText;

  /// Rendered directly beneath the field when there is no error.
  final String? helperText;

  /// Screen-reader name. Defaults to the visible label.
  final String? semanticLabel;
  final TextCapitalization textCapitalization;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final ac = AppColors.of(context);
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ac.inkSoft,
                letterSpacing: 0.03,
              ),
            ),
          ),
          Semantics(
            textField: true,
            label: semanticLabel ?? label,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: readOnly,
              maxLines: maxLines,
              onChanged: onChanged,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: ac.ink,
              ),
              cursorColor: ac.primary,
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: ac.inkFaint,
                ),
                isDense: true,
                // Errors stay attached to their field.
                errorText: errorText,
                helperText: hasError ? null : helperText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
