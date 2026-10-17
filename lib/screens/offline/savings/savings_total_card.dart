// Savings total card: everything saved so far, plus the compact action
// button used by the save / withdraw and plan shortcuts.

part of 'savings_screen.dart';

/// Lifetime savings balance shown beside the action buttons, or a hint
/// when nothing has been saved yet.
class _TotalSavingsCard extends StatelessWidget {
  final double total;

  const _TotalSavingsCard({required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'إجمالي المبالغ الموفرة',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: const ['Tajawal'],
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),

          const SizedBox(height: 4),

          if (total <= 0)
            Text(
              'وفّر أول مبلغ ليظهر هنا',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary.withValues(alpha: 0.65),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: RollingMoney(
                      value: total,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    currencyLabel,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Compact glass button used for save/withdraw and plan shortcuts, with an
/// optional leading widget before the label.
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget? leading;

  const _ActionButton({required this.label, required this.onTap, this.leading});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return GlassButton(
      onTap: onTap,
      colorType: GlassColorType.surface,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 6)],
              Text(
                label,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: const ['Tajawal'],
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
