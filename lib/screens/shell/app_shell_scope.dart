// Shell-wide layout constants and the inherited scope that lets pages
// inside the shell switch the bottom-navigation tab.

import 'package:flutter/widgets.dart';

/// Space a tab keeps free at the bottom of its scroll content so the last
/// card can scroll clear of the floating navigation bar.
const double kFloatingNavClearance = 88;

/// Gap between neighboring cards on every tab, across and down, so all
/// screens share one rhythm.
const double kCardGap = 10;

/// Page indices of the shell tabs that other screens jump to.
class AppShellTabs {
  /// Home (dashboard) tab.
  static const int home = 0;

  /// Reports tab.
  static const int report = 1;

  /// Savings tab.
  static const int savings = 2;
}

/// Exposes the shell's tab switcher to every page below [AppShellScope].
class AppShellScope extends InheritedWidget {
  /// Switches the shell to the tab at the given page index.
  final ValueChanged<int> selectTab;

  /// Creates a [AppShellScope].
  const AppShellScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  /// Switches to tab [index] using the nearest [AppShellScope].
  ///
  /// No-op outside the shell (e.g. widget tests that pump a page alone).
  static void selectTabOf(BuildContext context, int index) {
    context.getInheritedWidgetOfExactType<AppShellScope>()?.selectTab(index);
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}
