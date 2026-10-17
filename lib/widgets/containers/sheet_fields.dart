// Sheet form parts: field labels with optional (i) help, text fields,
// choice chips, option rows, and the shared field fill color.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/theme/app_motion.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/core/utils/app_feedback.dart';

/// Small label above a field; can mark the field optional and host a trailing action.
class SheetFieldLabel extends StatelessWidget {
  /// Label text.
  final String text;

  /// Appends "(اختياري)".
  final bool optional;

  /// Trailing widget, e.g. a [SheetInfoButton].
  final Widget? action;

  /// Creates a [SheetFieldLabel].
  const SheetFieldLabel({
    super.key,
    required this.text,
    this.optional = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textSecondary = palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: textSecondary,
            ),
          ),

          if (optional)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Text(
                ' (اختياري)',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: ['Tajawal'],
                  fontSize: 11,
                  color: textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ),
          if (action != null) ...[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

/// Small (i) button next to a field label; opens a short explanation.
/// Every inline help in the app uses this so they look and behave the same.
class SheetInfoButton extends StatelessWidget {
  /// Dialog title.
  final String title;

  /// Dialog text.
  final String message;

  /// Creates a [SheetInfoButton].
  const SheetInfoButton({
    super.key,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;

    return Semantics(
      button: true,
      label: 'شرح: $title',
      child: InkResponse(
        radius: 18,
        onTap: () => showAppInfoDialog(context, title: title, message: message),
        child: SizedBox(
          width: 22,
          height: 22,
          child: Icon(Icons.info_outline_rounded, size: 18, color: accent),
        ),
      ),
    );
  }
}

/// Tappable row inside a sheet: icon, label, optional hint. Used for lists of
/// choices (e.g. photo source) so every option row looks the same.
class SheetOptionTile extends StatelessWidget {
  /// Row icon.
  final IconData icon;

  /// Row title.
  final String label;

  /// Optional second line.
  final String? hint;

  /// Called on tap.
  final VoidCallback onTap;

  /// Paints the row red.
  final bool destructive;

  /// Creates a [SheetOptionTile].
  const SheetOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.hint,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final accent = palette.accent;
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;
    final destructiveColor = AppColors.destructiveOf(context);
    final tint = destructive ? destructiveColor : accent;

    return Material(
      color: sheetFieldColor(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tint.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 20, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: destructive ? destructiveColor : textPrimary,
                      ),
                    ),
                    if (hint != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        hint!,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optional single-line text field styled like other sheet inputs.
class SheetTextField extends StatelessWidget {
  /// Holds the text.
  final TextEditingController controller;

  /// Placeholder.
  final String hint;

  /// False makes it read-only.
  final bool enabled;

  /// Keyboard to show.
  final TextInputType? keyboardType;

  /// Input filters.
  final List<TextInputFormatter>? inputFormatters;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Creates a [SheetTextField].
  const SheetTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textAlign: TextAlign.right,
      cursorColor: textPrimary,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: ['Tajawal'],
        fontSize: 15,
        color: enabled ? textPrimary : textSecondary.withValues(alpha: 0.55),
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: sheetFieldColor(context),
        hintText: hint,
        hintStyle: TextStyle(
          fontFamily: 'Outfit',
          fontFamilyFallback: ['Tajawal'],
          fontSize: 14,
          color: textSecondary.withValues(alpha: 0.7),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

/// Segmented choice row (same pattern as expense payment-method chips).
class SheetChoiceChips extends StatelessWidget {
  /// Choice labels.
  final List<String> options;

  /// The selected label.
  final String selected;

  /// Called with the tapped label.
  final ValueChanged<String> onSelected;

  /// False ignores taps.
  final bool enabled;

  /// Creates a [SheetChoiceChips].
  const SheetChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final accent = palette.accent;
    final textPrimary = palette.textPrimary;

    if (options.isEmpty) return const SizedBox.shrink();

    final selectedIndex = options
        .indexOf(selected)
        .clamp(0, options.length - 1);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Container(
        decoration: BoxDecoration(
          color: sheetFieldColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / options.length;

            return Stack(
              children: [
                AnimatedPositionedDirectional(
                  duration: AppMotion.of(context, AppMotion.medium),
                  curve: AppMotion.enter,
                  start: selectedIndex * itemWidth,
                  width: itemWidth,
                  top: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: accent, width: 1.4),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final option in options)
                      Expanded(
                        child: GestureDetector(
                          onTap: enabled ? () => onSelected(option) : null,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 4,
                            ),
                            child: AnimatedDefaultTextStyle(
                              duration: AppMotion.of(context, AppMotion.fast),
                              curve: AppMotion.soft,
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontFamilyFallback: ['Tajawal'],
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                                color: option == selected
                                    ? accent
                                    : textPrimary,
                              ),
                              child: Text(
                                option,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shared fill for sheet inputs: app background blended with a touch of accent.
Color sheetFieldColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final palette = AppPalette.of(context);

  final base = palette.background;
  final accent = palette.accent;

  return Color.alphaBlend(accent.withValues(alpha: isDark ? 0.10 : 0.07), base);
}
