// Translucent "glass" card surface. Uses a tinted fill only — no BackdropFilter —
// so scrolling stays smooth; glass is a translucent color, not a live blur.
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Which palette token tints the glass fill.
enum GlassColorType {
  /// The brand accent.
  accent,

  /// The page background.
  background,

  /// The card surface.
  surface,

  /// The main text color.
  textPrimary,

  /// The secondary text color.
  textSecondary,
}

/// Rounded translucent card with a liquid-glass sheen and rim and a soft
/// shadow.
///
/// Intentionally skips [BackdropFilter]: blurring whatever sits behind every
/// card caused scroll jank. The look comes from a translucent palette fill.
class GlassContainer extends StatelessWidget {
  /// Card content.
  final Widget child;

  /// Fixed width, if any.
  final double? width;

  /// Fixed height, if any.
  final double? height;

  /// Space inside the card.
  final EdgeInsetsGeometry padding;

  /// Space outside the card.
  final EdgeInsetsGeometry margin;

  /// Corner radius (all corners).
  final double borderRadius;

  /// Uneven corners when a circular [borderRadius] is not enough (e.g. sheets).
  final BorderRadius? radius;

  /// Which theme color tints the glass.
  final GlassColorType colorType;

  /// How strongly the glass is tinted, 0..1.
  final double tintOpacity;

  /// Creates a [GlassContainer].
  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.borderRadius = 20,
    this.radius,
    this.colorType = GlassColorType.accent,
    this.tintOpacity = 0.8,
  });

  /// Maps [colorType] to the matching token on the active palette.
  Color _resolveColor(AppPalette palette) {
    switch (colorType) {
      case GlassColorType.accent:
        return palette.accent;
      case GlassColorType.background:
        return palette.background;
      case GlassColorType.surface:
        return palette.surface;
      case GlassColorType.textPrimary:
        return palette.textPrimary;
      case GlassColorType.textSecondary:
        return palette.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color baseColor = _resolveColor(palette);
    final BorderRadius shape = radius ?? BorderRadius.circular(borderRadius);

    // Accent fills get a stronger shine so buttons read as glossy.
    final strong = colorType == GlassColorType.accent;
    final card = CustomPaint(
      foregroundPainter: LiquidGlassPainter(
        radius: shape,
        isDark: isDark,
        strong: strong,
      ),
      child: Container(
        width: width,
        height: height,
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: liquidGlassFill(
            baseColor.withValues(alpha: tintOpacity.clamp(0.0, 1.0)),
            isDark: isDark,
            strong: strong,
          ),
          borderRadius: shape,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: child,
      ),
    );

    if (margin == EdgeInsets.zero) return card;
    return Padding(padding: margin, child: card);
  }
}

/// Fill for a glass surface: [base] with a soft light sheen from the top
/// corner. It sits under the content, so text and charts keep their color.
/// [sheen] overrides the default white strength for see-through surfaces.
LinearGradient liquidGlassFill(
  Color base, {
  required bool isDark,
  bool strong = false,
  double? sheen,
}) {
  sheen ??= strong ? 0.2 : (isDark ? 0.045 : 0.6);
  return LinearGradient(
    begin: Alignment.topLeft,
    end: const Alignment(0.2, 0.4),
    colors: [
      Color.alphaBlend(Colors.white.withValues(alpha: sheen), base),
      base,
    ],
  );
}

/// The rim of a "liquid glass" surface, drawn over its edge: bright on top
/// and fading toward the bottom, like light caught on the edge of glass.
/// Pure gradients, no blur, so it costs about as much as a border.
class LiquidGlassPainter extends CustomPainter {
  /// Shape of the surface.
  final BorderRadius radius;

  /// Dark-theme rim colors.
  final bool isDark;

  /// A brighter rim for floating chrome.
  final bool strong;

  /// Creates a [LiquidGlassPainter].
  const LiquidGlassPainter({
    required this.radius,
    required this.isDark,
    this.strong = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = radius.toRRect(rect).deflate(0.5);

    final rimTop = strong ? 0.45 : (isDark ? 0.14 : 0.95);
    final rimBottom = isDark ? 0.03 : 0.0;
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: rimTop),
            Colors.white.withValues(alpha: rimBottom),
          ],
        ).createShader(rect),
    );

    // A faint dark line under the rim keeps light cards from melting into
    // a light background.
    if (!isDark && !strong) {
      canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.0),
              Colors.black.withValues(alpha: 0.07),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant LiquidGlassPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.isDark != isDark ||
      oldDelegate.strong != strong;
}
