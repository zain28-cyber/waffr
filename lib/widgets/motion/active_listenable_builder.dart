// A ListenableBuilder that stops listening while its tab is hidden.

import 'package:flutter/widgets.dart';

/// Store-driven content that sleeps with a retained tab's [TickerMode].
///
/// Hidden pages retain their widget state without rebuilding financial
/// summaries on every store notification. Reactivation reads the latest
/// state immediately; notifications themselves are never buffered.
class ActiveListenableBuilder extends StatefulWidget {
  /// Rebuilds on its notifications while the page is active.
  final Listenable listenable;

  /// Builds the content.
  final TransitionBuilder builder;

  /// Passed to [builder] unchanged.
  final Widget? child;

  /// Creates a [ActiveListenableBuilder].
  const ActiveListenableBuilder({
    super.key,
    required this.listenable,
    required this.builder,
    this.child,
  });

  @override
  State<ActiveListenableBuilder> createState() =>
      _ActiveListenableBuilderState();
}

/// State of [ActiveListenableBuilder].
class _ActiveListenableBuilderState extends State<ActiveListenableBuilder> {
  bool _listening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TickerMode.valuesOf(context).enabled;
    if (active == _listening) return;
    if (active) {
      widget.listenable.addListener(_changed);
    } else {
      widget.listenable.removeListener(_changed);
    }
    _listening = active;
  }

  @override
  void didUpdateWidget(covariant ActiveListenableBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_listening && oldWidget.listenable != widget.listenable) {
      oldWidget.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    if (_listening) widget.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.child);
}
