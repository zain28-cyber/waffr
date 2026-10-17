// Shared bottom-sheet toolkit: open a glass sheet, lay out its body, and reuse
// the same field / chrome helpers so new sheets look and behave the same.
//
// The modal barrier is a flat dim ([kSheetBarrierColor]), not a BackdropFilter
// blur — live blur behind the sheet was too expensive. The sheet itself is a
// translucent GlassContainer fill, same performance choice as glass cards.
//
// The field, amount, transition and button pieces live in the sheet_*.dart
// files next to this one and are re-exported here, so one import gives a
// sheet everything.

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/containers/sheet_buttons.dart';
import 'package:waffr/widgets/motion/motion.dart';

export 'package:waffr/widgets/containers/sheet_amount_field.dart';
export 'package:waffr/widgets/containers/sheet_buttons.dart';
export 'package:waffr/widgets/containers/sheet_fields.dart';
export 'package:waffr/widgets/containers/sheet_transitions.dart';

/// Modal barrier tint. Dims the page behind the sheet without blurring it.
const Color kSheetBarrierColor = Color.fromARGB(114, 0, 0, 0);

/// Opens a transparent modal bottom sheet wrapped in [_GlassSheetShell].
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double? heightFactor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: kSheetBarrierColor,
    elevation: 0,
    sheetAnimationStyle: AppMotion.reduced(context)
        ? AnimationStyle.noAnimation
        : null,
    // The content is built once (inside a Builder child) so keyboard frames
    // only re-pad the sheet instead of rebuilding the whole form.
    builder: (context) => _GlassSheetShell(
      heightFactor: heightFactor,
      child: Builder(builder: builder),
    ),
  );
}

/// Positions the sheet above the keyboard and optionally pins its height.
class _GlassSheetShell extends StatelessWidget {
  final Widget child;
  final double? heightFactor;

  const _GlassSheetShell({required this.child, this.heightFactor});

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final maxSheetHeight = (screenHeight - keyboard - 28).clamp(
      220.0,
      screenHeight,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: heightFactor == null
          ? ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: child,
            )
          : SizedBox(
              height: (screenHeight * heightFactor!).clamp(
                220.0,
                maxSheetHeight,
              ),
              child: child,
            ),
    );
  }
}

/// Fixed-height layout: pinned header, scrollable [body] below.
class GlassSheetFixedBody extends StatelessWidget {
  /// Pinned top part.
  final Widget header;

  /// Scrollable part under the header.
  final Widget body;

  /// Creates a [GlassSheetFixedBody].
  const GlassSheetFixedBody({
    super.key,
    required this.header,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: GlassContainer(
        colorType: GlassColorType.surface,
        tintOpacity: 1,
        radius: const BorderRadius.vertical(top: Radius.circular(34)),
        padding: EdgeInsets.zero,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: header,
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// Default sheet shell: large top corners and a single scrollable column.
class GlassSheetBody extends StatelessWidget {
  /// Sheet content, top to bottom (entrances are staggered).
  final List<Widget> children;

  /// Space around the content.
  final EdgeInsetsGeometry padding;

  /// Creates a [GlassSheetBody].
  const GlassSheetBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 20),
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      colorType: GlassColorType.surface,
      tintOpacity: 1,
      radius: const BorderRadius.vertical(top: Radius.circular(34)),
      padding: EdgeInsets.zero,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: padding,
          child: AnimatedSize(
            duration: AppMotion.sizeOf(context, AppMotion.slow),
            curve: AppMotion.enter,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.none,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: staggered(children, offset: 12),
            ),
          ),
        ),
      ),
    );
  }
}

/// Drag handle, title, subtitle, close, and optional next control.
class GlassSheetHeader extends StatelessWidget {
  /// Sheet title.
  final String title;

  /// One line under the title.
  final String subtitle;

  /// Shows a "next" arrow that calls this; null hides it.
  final VoidCallback? onNext;

  /// Creates a [GlassSheetHeader].
  const GlassSheetHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final accent = palette.accent;
    final textSecondary = palette.textSecondary;

    return Column(
      children: [
        Container(
          width: 42,
          height: 5,
          decoration: BoxDecoration(
            color: textSecondary.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 18),
        // Full width so the close / next buttons stay at the sheet edges even
        // when the title is short.
        SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 52),
                child: Column(
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: ['Tajawal'],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: ['Tajawal'],
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                child: SheetCircleButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ),
              if (onNext != null)
                Positioned(
                  right: 0,
                  child: SheetCircleButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: onNext!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
