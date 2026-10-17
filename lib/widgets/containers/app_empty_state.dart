// The one "nothing here yet" block: muted icon, short title, optional hint.
// Lists, cards and sheets all use it so empty screens look the same.
import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// The shared empty-state block.
class AppEmptyState extends StatelessWidget {
  /// Muted icon on top.
  final IconData icon;

  /// Short title.
  final String title;

  /// Optional hint under the title.
  final String? message;

  /// Smaller variant for dashboard cards.
  final bool compact;

  /// Creates a [AppEmptyState].
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 12 : 28,
        horizontal: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 30 : 40,
            color: textSecondary.withValues(alpha: 0.55),
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: compact ? 12.5 : 14.5,
              fontWeight: FontWeight.w700,
              color: textPrimary.withValues(alpha: 0.75),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                fontSize: compact ? 11 : 12.5,
                height: 1.5,
                color: textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
