// Online tab cards that need no state of their own: the sign-in gate and
// the nearby places shortcuts.

part of 'online_screen.dart';

/// Translucent cover over the blurred online cards for guests, with a
/// sign-in action.
class _SignInGate extends StatelessWidget {
  final VoidCallback onLogin;

  const _SignInGate({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return ClipRect(
      child: SizedBox.expand(
        child: ColoredBox(
          color: colors.background.withValues(alpha: 0.55),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: GlassContainer(
                colorType: GlassColorType.surface,
                tintOpacity: 1,
                borderRadius: 28,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  // Globe badge, message, then the sign-in button.
                  children: [
                    Center(
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: colors.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.public_rounded,
                          size: 28,
                          color: colors.accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'سجّل الدخول لاستخدام الميزات التي تحتاج إلى الإنترنت.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontFamilyFallback: const ['Tajawal'],
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassButton(
                      onTap: onLogin,
                      colorType: GlassColorType.accent,
                      tintOpacity: 1,
                      borderRadius: 20,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Text(
                        'تسجيل الدخول',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: const ['Tajawal'],
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid of nearby-place categories that launch Google Maps searches.
class _NearbyPlacesCard extends StatelessWidget {
  final ValueChanged<NearbyPlaceCategory> onOpen;

  const _NearbyPlacesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final colors = AppPalette.of(context);

    return GlassContainer(
      colorType: GlassColorType.surface,
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'مواقع قريبة',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          // Two-column grid; each tile reports its category to [onOpen].
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: nearbyPlaceCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 3.1,
            ),
            itemBuilder: (context, index) {
              final category = nearbyPlaceCategories[index];
              return GlassButton(
                onTap: () => onOpen(category),
                colorType: GlassColorType.background,
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Icon(category.icon, size: 18, color: colors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        category.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
