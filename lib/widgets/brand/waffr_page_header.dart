// Shared top app bar for the shell and settings-style screens.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Fixed-height page header with optional scroll-elevation shadow.
class WaffrPageHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Header height without the status bar.
  static const double height = 68;

  /// Title widget (usually text or the logo).
  final Widget title;

  /// Optional widget at the start (back arrow).
  final Widget? leading;

  /// Space kept for [leading].
  final double leadingWidth;

  /// Center the title instead of starting it after [leading].
  final bool centerTitle;

  /// When true the header casts its scroll shadow.
  final ValueListenable<bool>? elevated;

  /// Pad for the status bar.
  final bool applySafeArea;

  /// Creates a [WaffrPageHeader].
  const WaffrPageHeader({
    super.key,
    required this.title,
    this.leading,
    this.leadingWidth = 48,
    this.centerTitle = false,
    this.elevated,
    this.applySafeArea = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    if (elevated == null) {
      return _HeaderChrome(
        title: title,
        leading: leading,
        leadingWidth: leadingWidth,
        centerTitle: centerTitle,
        elevated: false,
        applySafeArea: applySafeArea,
      );
    }

    return ValueListenableBuilder<bool>(
      valueListenable: elevated!,
      builder: (context, isElevated, _) {
        return _HeaderChrome(
          title: title,
          leading: leading,
          leadingWidth: leadingWidth,
          centerTitle: centerTitle,
          elevated: isElevated,
          applySafeArea: applySafeArea,
        );
      },
    );
  }
}

/// Header of every pushed screen: back arrow and centered title. Use this
/// instead of building a [WaffrPageHeader] by hand so all screens match.
class WaffrBackHeader extends StatelessWidget implements PreferredSizeWidget {
  /// Centered title text.
  final String title;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;

  /// False disables the back arrow (e.g. while a request is running).
  final bool enabled;

  /// False hides the back arrow on the first screen of a flow.
  final bool showBack;

  /// When true the header casts its scroll shadow.
  final ValueListenable<bool>? elevated;

  /// Pad for the status bar.
  final bool applySafeArea;

  /// Creates a [WaffrBackHeader].
  const WaffrBackHeader({
    super.key,
    required this.title,
    this.onBack,
    this.enabled = true,
    this.showBack = true,
    this.elevated,
    this.applySafeArea = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(WaffrPageHeader.height);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;

    return WaffrPageHeader(
      centerTitle: true,
      elevated: elevated,
      applySafeArea: applySafeArea,
      leading: showBack
          ? IconButton(
              tooltip: 'رجوع',
              icon: Icon(Icons.arrow_forward_ios_rounded, color: textPrimary),
              onPressed: enabled
                  ? (onBack ?? () => Navigator.of(context).maybePop())
                  : null,
            )
          : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}

/// Gradient bar chrome, shadow, and title/leading layout.
class _HeaderChrome extends StatelessWidget {
  final Widget title;
  final Widget? leading;
  final double leadingWidth;
  final bool centerTitle;
  final bool elevated;
  final bool applySafeArea;

  const _HeaderChrome({
    required this.title,
    required this.leading,
    required this.leadingWidth,
    required this.centerTitle,
    required this.elevated,
    required this.applySafeArea,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final surface = palette.surface;

    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.fast),
      curve: AppMotion.soft,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            surface,
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.03 : 0.05),
              surface,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: elevated ? 0.10 : 0.05),
            blurRadius: elevated ? 16 : 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          bottom: BorderSide(
            color: accent.withValues(alpha: elevated ? 0.18 : 0.08),
            width: 1,
          ),
        ),
      ),
      child: applySafeArea ? SafeArea(bottom: false, child: _bar) : _bar,
    );
  }

  Widget get _bar {
    return SizedBox(
      height: WaffrPageHeader.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SizedBox(width: leadingWidth, child: leading),
            Expanded(
              child: centerTitle
                  ? Center(child: title)
                  : Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: title,
                      ),
                    ),
            ),
            if (centerTitle) SizedBox(width: leadingWidth),
          ],
        ),
      ),
    );
  }
}
