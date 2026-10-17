// Sheet content that comes and goes: SheetExpand (show or hide a section)
// and SheetSwap (cross-fade when the chosen option changes).

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_motion.dart';

/// Softly expands or collapses optional sheet content.
class SheetExpand extends StatelessWidget {
  /// Shows or hides [child].
  final bool visible;

  /// The optional content.
  final Widget child;

  /// Creates a [SheetExpand].
  const SheetExpand({super.key, required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppMotion.sizeOf(context, AppMotion.slow),
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, AppMotion.medium),
        switchInCurve: AppMotion.enter,
        switchOutCurve: AppMotion.exit,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        layoutBuilder: _keepOutgoing,
        child: visible
            ? KeyedSubtree(key: const ValueKey('sheet-expand-on'), child: child)
            : const SizedBox(width: double.infinity, key: ValueKey('off')),
      ),
    );
  }
}

/// Cross-fades sheet content when the active option changes.
class SheetSwap extends StatelessWidget {
  /// Changing it cross-fades to the new [child].
  final Object switchKey;

  /// The current content.
  final Widget child;

  /// Creates a [SheetSwap].
  const SheetSwap({super.key, required this.switchKey, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.medium),
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      layoutBuilder: _keepOutgoing,
      child: KeyedSubtree(key: ValueKey(switchKey), child: child),
    );
  }
}

// AnimatedSwitcher layout that keeps the outgoing child painted (so its
// fade-out plays) without letting it set the height; the incoming child
// decides the size.
Widget _keepOutgoing(Widget? current, List<Widget> previous) {
  return Stack(
    alignment: Alignment.topCenter,
    clipBehavior: Clip.none,
    children: [
      for (final child in previous)
        Positioned(top: 0, left: 0, right: 0, child: child),
      current ?? const SizedBox(width: double.infinity),
    ],
  );
}
