// Shared motion tokens: one tempo and one set of curves for the whole app.
// Widgets use these names instead of raw `Curves` and `Duration`s, so the
// feel of the app is tuned in one place.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Duration and curve tokens, plus reduced-motion helpers.
///
/// Durations go from quick feedback (press, highlight) up to emphasized
/// entrances. Curves pair an entering ease-out with an exiting ease-in.
class AppMotion {
  AppMotion._();

  /// Instant feedback: a highlight or a color change.
  static const Duration instant = Duration(milliseconds: 100);

  /// Small changes: presses, chips, switches.
  static const Duration fast = Duration(milliseconds: 200);

  /// The default for most transitions.
  static const Duration medium = Duration(milliseconds: 280);

  /// Larger surfaces: cards expanding, pages of a pager.
  static const Duration slow = Duration(milliseconds: 360);

  /// Entrances that should be noticed: dialogs, first reveals.
  static const Duration emphasized = Duration(milliseconds: 450);

  /// Rolling numbers (balances, totals) need longer to read as counting.
  static const Duration countUp = Duration(milliseconds: 650);

  /// Something arriving: fast start, gentle stop.
  static const Curve enter = Curves.easeOutCubic;

  /// Something leaving: gentle start, fast finish.
  static const Curve exit = Curves.easeInCubic;

  /// Moving from one place to another on screen.
  static const Curve standard = Curves.easeInOutCubic;

  /// A pop that goes a little past its end and settles: badges, dots,
  /// a released button.
  static const Curve overshoot = Curves.easeOutBack;

  /// A lighter ease-out for presses and small progress changes.
  static const Curve soft = Curves.easeOut;

  /// The lighter ease-in that pairs with [soft] when something hides.
  static const Curve softExit = Curves.easeIn;

  /// True when the device asks for reduced motion (accessibility setting).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Repeating effects should only run on the visible, motion-enabled page.
  static bool enabled(BuildContext context) =>
      !reduced(context) && TickerMode.valuesOf(context).enabled;

  /// [duration], or zero when the device asks for reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;

  /// The "no animation" duration for [AnimatedSize]. Duration.zero makes it
  /// finish inside its own layout and re-dirty itself, which the framework
  /// rejects, so it gets one microsecond instead.
  static const Duration instantSize = Duration(microseconds: 1);

  /// Like [of] for [AnimatedSize]: [instantSize] under reduced motion.
  static Duration sizeOf(BuildContext context, Duration duration) =>
      reduced(context) ? instantSize : duration;
}

/// Page steps for period pagers (reports, savings) that honor reduced
/// motion: a jump instead of a slide.
extension AppMotionPaging on PageController {
  /// Moves one page forward, sliding with [AppMotion.medium] unless the
  /// device asks for reduced motion.
  void nextPageFor(BuildContext context) => _step(context, 1);

  /// Moves one page back, like [nextPageFor].
  void previousPageFor(BuildContext context) => _step(context, -1);

  void _step(BuildContext context, int delta) {
    if (!hasClients) return;
    final target = (page ?? initialPage.toDouble()).round() + delta;
    final duration = AppMotion.of(context, AppMotion.medium);
    if (duration == Duration.zero) {
      jumpToPage(target);
    } else {
      animateToPage(target, duration: duration, curve: AppMotion.enter);
    }
  }
}

/// Haptic cues, named by intent so screens don't pick raw feedback types.
class AppHaptics {
  AppHaptics._();

  /// Moving between options: tabs, segments, pickers.
  static void selection() => HapticFeedback.selectionClick();

  /// A save or other completed action.
  static void success() => HapticFeedback.lightImpact();

  /// A blocked action or a destructive one.
  static void warning() => HapticFeedback.mediumImpact();
}

/// Wraps a page transition so reduced motion shows the new page in place.
class ReducedMotionPageTransitionsBuilder extends PageTransitionsBuilder {
  /// The transition used when motion is allowed.
  final PageTransitionsBuilder base;

  /// Wraps [base].
  const ReducedMotionPageTransitionsBuilder(this.base);

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      base.delegatedTransition;

  @override
  Duration get transitionDuration => base.transitionDuration;

  @override
  Duration get reverseTransitionDuration => base.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    return base.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
