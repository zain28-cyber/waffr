// Privacy & security building blocks shared by the main screen and its
// detail pages: scaffold, colors, grouped rows, banners and info lines.

part of 'privacy_security_screen.dart';

/// Shared scaffold for privacy detail pages (header + scroll body).
class _PrivacyDetailScaffold extends StatelessWidget {
  final String title;
  final _PrivacyColors colors;
  final List<Widget> children;

  const _PrivacyDetailScaffold({
    required this.title,
    required this.colors,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: WaffrBackHeader(title: title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: children,
      ),
    );
  }
}

/// Light/dark color snapshot for privacy screens.
class _PrivacyColors {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;

  const _PrivacyColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
  });

  /// Reads the colors from the current [AppPalette].
  factory _PrivacyColors.of(BuildContext context) {
    final palette = AppPalette.of(context);
    return _PrivacyColors(
      background: palette.background,
      surface: palette.surface,
      textPrimary: palette.textPrimary,
      textSecondary: palette.textSecondary,
      accent: palette.accent,
    );
  }
}

/// Privacy settings rows stacked like the Settings screen: one card per row
/// with a 12px gap.
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}

/// Tappable privacy settings row with an optional status badge and trailing
/// widget; a wrapper over `AppListTile`.
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? status;
  final bool statusEmphasis;
  final bool showChevron;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    this.status,
    this.statusEmphasis = false,
    this.showChevron = true,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      icon: icon,
      title: title,
      status: status,
      statusOn: statusEmphasis,
      trailing: trailing,
      showChevron: showChevron,
      onTap: onTap,
    );
  }
}

/// Banner summarizing the current privacy/security status: a colored dot,
/// a title and a subtitle.
class _StatusBanner extends StatelessWidget {
  final _PrivacyColors colors;
  final bool emphasized;
  final String title;
  final String subtitle;

  const _StatusBanner({
    required this.colors,
    required this.emphasized,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = emphasized ? colors.accent : colors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
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

/// Intro icon + text block at the top of a detail page.
class _DetailLead extends StatelessWidget {
  final IconData icon;
  final _PrivacyColors colors;
  final String text;

  const _DetailLead({
    required this.icon,
    required this.colors,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: colors.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              text,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                fontFamily: 'Outfit',
                fontFamilyFallback: ['Tajawal'],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rounded card holding a column of [_InfoLine]s.
class _InfoGroup extends StatelessWidget {
  final _PrivacyColors colors;
  final List<Widget> children;

  const _InfoGroup({required this.colors, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }
}

/// Single info line inside an [_InfoGroup], with an optional divider below.
class _InfoLine extends StatelessWidget {
  final String label;
  final bool showDivider;

  const _InfoLine({required this.label, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final colors = _PrivacyColors.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13.5,
                    height: 1.45,
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 44,
            color: colors.textSecondary.withValues(alpha: 0.12),
          ),
      ],
    );
  }
}

/// Muted footnote under a detail section.
class _NoteText extends StatelessWidget {
  final _PrivacyColors colors;
  final String text;

  const _NoteText({required this.colors, required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 13.5,
        height: 1.55,
        fontFamily: 'Outfit',
        fontFamilyFallback: ['Tajawal'],
      ),
    );
  }
}
