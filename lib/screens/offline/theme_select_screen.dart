// First-launch theme picker with live light and dark home-screen previews.

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/widgets/brand/waffr_logo.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';
import 'package:waffr/core/theme/app_motion.dart';

/// First-launch light/dark picker before entering the app. Each choice shows
/// a small preview of the home screen in that theme; picking one switches the
/// app theme live so the whole screen follows it.
class ThemeSelectScreen extends StatefulWidget {
  /// Applies (and persists, in `main.dart`) the chosen theme mode.
  final void Function(ThemeMode mode) onThemeChanged;

  /// Leaves the screen; the gate marks first launch as done.
  final VoidCallback onContinue;

  /// Creates a [ThemeSelectScreen].
  const ThemeSelectScreen({
    super.key,
    required this.onThemeChanged,
    required this.onContinue,
  });

  @override
  State<ThemeSelectScreen> createState() => _ThemeSelectScreenState();
}

/// State of [ThemeSelectScreen]. Starts from the platform brightness.
class _ThemeSelectScreenState extends State<ThemeSelectScreen> {
  /// Currently selected option.
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  /// Selects an option and applies it live.
  void _select(bool dark) {
    if (dark == _isDark) return;
    setState(() => _isDark = dark);
    widget.onThemeChanged(dark ? ThemeMode.dark : ThemeMode.light);
  }

  /// Applies the selection (even if untouched) and continues.
  void _continue() {
    widget.onThemeChanged(_isDark ? ThemeMode.dark : ThemeMode.light);
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              child: Column(
                children: [
                  // Logo, title and subtitle.
                  const Spacer(flex: 2),
                  const WaffrLogo(size: 64),
                  const SizedBox(height: 20),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'اختر مظهر '),
                        TextSpan(
                          text: 'وفّر',
                          style: TextStyle(
                            color: colors.accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 30,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'يمكنك تغييره لاحقاً من الإعدادات',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  // Light and dark preview cards side by side.
                  Row(
                    children: [
                      Expanded(
                        child: _ThemeOption(
                          label: 'فاتح',
                          icon: Icons.light_mode_rounded,
                          preview: AppPalette.light,
                          selected: !_isDark,
                          onTap: () => _select(false),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _ThemeOption(
                          label: 'داكن',
                          icon: Icons.dark_mode_rounded,
                          preview: AppPalette.dark,
                          selected: _isDark,
                          onTap: () => _select(true),
                        ),
                      ),
                    ],
                  ),
                  // Continue button pinned to the bottom.
                  const Spacer(flex: 2),
                  AppPrimaryButton(label: 'متابعة', onTap: _continue),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A selectable card: a mini home screen in [preview] colors, with its name
/// and a check mark under it.
class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final AppPalette preview;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.preview,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);
    const duration = Duration(milliseconds: 250);

    return Semantics(
      button: true,
      selected: selected,
      label: 'المظهر ال$label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: selected ? 1 : 0.96,
          duration: duration,
          curve: AppMotion.enter,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.enter,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: selected
                    ? colors.accent
                    : colors.textPrimary.withValues(alpha: 0.08),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (selected ? colors.accent : Colors.black).withValues(
                    alpha: selected ? 0.18 : 0.06,
                  ),
                  blurRadius: selected ? 18 : 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            // Preview, then icon, name and check mark.
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 0.66,
                  child: _MiniHome(colors: preview),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(width: 6),
                    Icon(
                      icon,
                      size: 20,
                      color: selected ? colors.accent : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    _CheckMark(selected: selected, colors: colors),
                    const SizedBox(width: 4),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round check mark that fills with the accent when [selected].
class _CheckMark extends StatelessWidget {
  final bool selected;
  final AppPalette colors;

  const _CheckMark({required this.selected, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? colors.accent : Colors.transparent,
        border: Border.all(
          color: selected
              ? colors.accent
              : colors.textSecondary.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check_rounded, size: 14, color: colors.onAccent)
          : null,
    );
  }
}

/// A sketch of the home screen: header, balance card with its bar, a few
/// rows and the bottom bar, drawn with the given theme's colors.
class _MiniHome extends StatelessWidget {
  final AppPalette colors;

  const _MiniHome({required this.colors});

  @override
  Widget build(BuildContext context) {
    final line = colors.textPrimary.withValues(alpha: 0.12);
    final border = Border.all(
      color: colors.textPrimary.withValues(alpha: 0.08),
    );

    // Rounded bar at a fraction of the available width.
    Widget bar(double widthFactor, double height, Color color) {
      return FractionallySizedBox(
        widthFactor: widthFactor,
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      );
    }

    // List row: icon dot plus a text bar.
    Widget row(double widthFactor) {
      return Padding(
        padding: const EdgeInsets.only(top: 7),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: colors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: bar(widthFactor, 5, line)),
          ],
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: border,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: avatar dot and title bar.
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(child: bar(0.55, 6, colors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          // Balance card: label, amount, and progress bar.
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                bar(0.4, 4, colors.textSecondary.withValues(alpha: 0.5)),
                const SizedBox(height: 6),
                bar(0.7, 9, colors.accent),
                const SizedBox(height: 9),
                Container(
                  height: 5,
                  alignment: AlignmentDirectional.centerStart,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: bar(0.68, 5, colors.accent),
                ),
              ],
            ),
          ),
          // A few list rows, then the bottom bar.
          const SizedBox(height: 4),
          row(0.8),
          row(0.6),
          row(0.7),
          const Spacer(),
          Container(
            height: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(18),
              border: border,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == 0 ? colors.accent : line,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
