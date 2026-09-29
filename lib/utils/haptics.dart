import 'package:flutter/services.dart';

/// Central vocabulary for haptic feedback.
///
/// Haptics are only worth having where they confirm something the screen
/// cannot: a completed action, a changed state, a rejected input. Firing them
/// on every tap trains the user to ignore them, so the rule here is that a
/// haptic accompanies an *outcome*, not an input.
///
/// The three levels map to what the user just learned:
///  - [tap]        a control responded (button press, chip toggle, selection)
///  - [success]    a meaningful record was committed (sale saved, receipt made)
///  - [error]      the input was refused or the action failed
///
/// Deliberately NOT fired for: scrolling, typing, passive loading, background
/// sync, list rebuilds, or notifications. Those are not user-initiated
/// confirmations and firing there is what makes haptics feel broken.
///
/// Every call here routes through Flutter's HapticFeedback, which respects the
/// system haptic setting and the user's accessibility choices - the app does
/// not talk to the vibrator directly and cannot override those preferences.
class AppHaptics {
  const AppHaptics._();

  /// Light confirmation for a control responding to a tap.
  static Future<void> tap() async {
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {
      // Haptics are a nicety, never a correctness requirement. A device with no
      // vibrator, or a platform channel that is not ready, must not turn a
      // successful sale into a failed one.
    }
  }

  /// Heavier confirmation for committing something important.
  static Future<void> success() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  /// Distinct, stronger feedback for a rejected input or a failed action.
  static Future<void> error() async {
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }
}
