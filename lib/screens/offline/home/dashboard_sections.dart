// Home card chrome shared by every dashboard section (part of
// dashboard.dart): the card frame, its title row and the empty state.

part of 'dashboard.dart';

/// Shared glass card shell used by the dashboard sections. Becomes a
/// tappable [GlassButton] when [onTap] is set.
class _SectionCard extends StatelessWidget {
  final String? title;
  final String? caption;
  final Widget child;
  final bool compact;

  /// Centers [child] in the leftover height; used in fixed-height rows.
  final bool centerChild;

  /// Opens the screen with the card's full details.
  final VoidCallback? onTap;

  const _SectionCard({
    required this.child,
    this.title,
    this.caption,
    this.compact = false,
    this.centerChild = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final padding = compact
        ? const EdgeInsets.fromLTRB(16, 15, 16, 16)
        : const EdgeInsets.fromLTRB(20, 18, 20, 20);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          _SectionTitle(title: title!, caption: caption, compact: compact),
          SizedBox(height: compact ? 14 : 16),
        ],
        if (centerChild) Expanded(child: Center(child: child)) else child,
      ],
    );

    if (onTap == null) {
      return GlassContainer(
        colorType: GlassColorType.surface,
        borderRadius: 28,
        padding: padding,
        child: content,
      );
    }

    return GlassButton(
      onTap: onTap!,
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: padding,
      child: content,
    );
  }
}

/// Card title with an optional caption beside it.
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? caption;
  final bool compact;

  const _SectionTitle({
    required this.title,
    this.caption,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;
    final textSecondary = palette.textSecondary;

    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Outfit',
        fontFamilyFallback: ['Tajawal'],
        fontSize: compact ? 14.5 : 16,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    );

    if (caption == null) return titleText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        titleText,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: compact ? 10.5 : 11,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashboard empty placeholder; a thin wrapper over [AppEmptyState].
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool compact;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(icon: icon, title: message, compact: compact);
  }
}
