// Reports and savings: the period selector pinned under the shell header,
// with the page scrolling beneath its glass.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/screens/shell/app_shell_scope.dart';
import 'package:waffr/widgets/containers/floating_glass.dart';

/// Period controls remain below the shell header while cards scroll beneath
/// their glass. The sliver reserves their initial space without duplicating
/// either the controls or the page's scrollable.
class PinnedPeriodScrollView extends StatelessWidget {
  /// Period names, in order.
  final List<String> options;

  /// The selected option.
  final String selected;

  /// Called with the tapped option.
  final ValueChanged<String> onSelected;

  /// The page content under the selector.
  final Widget child;

  /// Creates a [PinnedPeriodScrollView].
  const PinnedPeriodScrollView({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final height = FloatingPeriodSelector.heightOf(context);
    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _PeriodHeader(
            extent: height + 18 + kCardGap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, kCardGap),
              child: FloatingPeriodSelector(
                options: options,
                selected: selected,
                onSelected: onSelected,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, kFloatingNavClearance),
          sliver: SliverToBoxAdapter(child: child),
        ),
      ],
    );
  }
}

/// Sliver header that reserves the selector's height at the top.
class _PeriodHeader extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  _PeriodHeader({required this.extent, required this.child});

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;

  @override
  bool shouldRebuild(covariant _PeriodHeader oldDelegate) =>
      extent != oldDelegate.extent || child != oldDelegate.child;
}

/// A moving selection bubble on the same liquid-glass surface as navigation.
/// Wide layouts show every option; narrow/scaled layouts scroll horizontally
/// rather than truncating the period names or shrinking accessibility text.
class FloatingPeriodSelector extends StatefulWidget {
  /// Period names, in order.
  final List<String> options;

  /// The selected option.
  final String selected;

  /// Called with the tapped option.
  final ValueChanged<String> onSelected;

  /// Creates a [FloatingPeriodSelector].
  const FloatingPeriodSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  static const _style = TextStyle(
    fontFamily: 'Outfit',
    fontFamilyFallback: ['Tajawal'],
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  /// The selector height for the current text scale.
  static double heightOf(BuildContext context) =>
      math.max(56, MediaQuery.textScalerOf(context).scale(13) * 1.1 + 24);

  @override
  State<FloatingPeriodSelector> createState() => _FloatingPeriodSelectorState();
}

/// State of [FloatingPeriodSelector].
class _FloatingPeriodSelectorState extends State<FloatingPeriodSelector> {
  final _scroll = ScrollController();
  double _slot = 0;
  double _viewport = 0;
  bool _scheduled = false;
  bool _animateScroll = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _keepSelectionVisible();
  }

  @override
  void didUpdateWidget(covariant FloatingPeriodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        !listEquals(oldWidget.options, widget.options)) {
      _animateScroll = true;
      _keepSelectionVisible();
    }
  }

  // Only move the horizontal control, never the page's vertical position.
  // Layout/text-scale changes and programmatic selections can hide a choice.
  void _keepSelectionVisible() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || !_scroll.hasClients || widget.options.isEmpty) return;
      final index = widget.options
          .indexOf(widget.selected)
          .clamp(0, widget.options.length - 1);
      final target = (index * _slot - (_viewport - _slot) / 2).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      final duration = _animateScroll
          ? AppMotion.of(context, AppMotion.fast)
          : Duration.zero;
      _animateScroll = false;
      if (duration == Duration.zero) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: duration,
          curve: AppMotion.standard,
        );
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.options;
    final selected = widget.selected;
    if (options.isEmpty) return const SizedBox.shrink();
    final palette = AppPalette.of(context);
    final height = FloatingPeriodSelector.heightOf(context);
    final selectedIndex = options
        .indexOf(selected)
        .clamp(0, options.length - 1);
    return FloatingGlass(
      radius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final painter = TextPainter(
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
              );
              var minimumWidth = 48.0;
              for (final option in options) {
                painter
                  ..text = TextSpan(
                    text: option,
                    style: FloatingPeriodSelector._style,
                  )
                  ..layout();
                minimumWidth = math.max(minimumWidth, painter.width + 8);
              }
              painter.dispose();
              final slot = math.max(
                minimumWidth,
                constraints.maxWidth / options.length,
              );
              if (_slot != slot || _viewport != constraints.maxWidth) {
                _slot = slot;
                _viewport = constraints.maxWidth;
                _keepSelectionVisible();
              }
              return SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: slot * options.length,
                  child: Stack(
                    children: [
                      AnimatedPositionedDirectional(
                        duration: AppMotion.of(context, AppMotion.medium),
                        curve: AppMotion.standard,
                        start: selectedIndex * slot,
                        width: slot,
                        top: 0,
                        bottom: 0,
                        child: FloatingGlassHighlight(radius: (height - 8) / 2),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: Row(
                          children: [
                            for (final option in options)
                              SizedBox(
                                width: slot,
                                height: height - 8,
                                child: Semantics(
                                  button: true,
                                  selected: option == selected,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(
                                      height / 2,
                                    ),
                                    onTap: () => widget.onSelected(option),
                                    child: Center(
                                      child: AnimatedDefaultTextStyle(
                                        duration: AppMotion.of(
                                          context,
                                          AppMotion.fast,
                                        ),
                                        style: FloatingPeriodSelector._style
                                            .copyWith(
                                              color: option == selected
                                                  ? palette.accent
                                                  : palette.textPrimary,
                                            ),
                                        child: Text(option, maxLines: 1),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
