// Privacy policy style copy: what stays on-device vs what account fields are
// kept. Not linked from any screen at the moment (only the smoke test uses it).

import 'package:flutter/material.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Scrollable info sections about financial privacy and stored profile fields.
class PrivacyInfoScreen extends StatelessWidget {
  /// Creates a [PrivacyInfoScreen].
  const PrivacyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final bg = palette.background;

    final surface = palette.surface;

    final textPrimary = palette.textPrimary;

    final textSecondary = palette.textSecondary;

    final accent = palette.accent;

    return Scaffold(
      backgroundColor: bg,

      appBar: WaffrBackHeader(title: 'الخصوصية والبيانات'),

      body: ListView(
        padding: const EdgeInsets.all(20),

        children: [
          // One card per privacy topic.
          _InfoSection(
            icon: Icons.visibility_off_outlined,
            title: 'خصوصيتك المالية',
            description: 'وفّر لا يطّلع على بياناتك المالية ولا يقرأها ولا يشاركها مع أي جهة. رصيدك، أهدافك، تفاصيل مصروفاتك، ونشاط حسابك المالي تبقى خاصة بك وحدك على جهازك.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          _InfoSection(
            icon: Icons.badge_outlined,
            title: 'ما الذي يُحفظ عنك؟',
            description: 'نحفظ فقط معلومات حساب أساسية: الاسم، الجنس، العمر، والبريد الإلكتروني. الهدف منها الاحتفاظ بسجل المستخدم وفهم طبيعة المستخدمين بشكل عام، وليس متابعة سلوكك المالي أو الاطلاع على مصروفاتك.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          _InfoSection(
            icon: Icons.person_off_outlined,
            title: 'وضع الضيف',
            description: 'إذا كنت تستخدم التطبيق كضيف، فكل بياناتك تُحفظ على جهازك فقط. لا تُرسل إلى أي مكان ولا تُخزَّن على أي خادم خارجي.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          _InfoSection(
            icon: Icons.storage_rounded,
            title: 'تخزين البيانات',
            description: 'بياناتك المالية تُحفظ محلياً على جهازك. تسجيل الدخول يتم بالبريد وكلمة المرور، والمزامنة بين الأجهزة تتم عبر حساب وفّر.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          _InfoSection(
            icon: Icons.phone_android_rounded,
            title: 'التشغيل دون اتصال',
            description: 'عندما يعمل التطبيق دون اتصال بالإنترنت، تبقى جميع بياناتك على جهازك. لا يحتاج التطبيق إلى الإنترنت للعمل، وبياناتك محفوظة محلياً فقط.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          _InfoSection(
            icon: Icons.lock_outline_rounded,
            title: 'حماية الوصول',
            description: 'عند تفعيل «قفل التطبيق» تُحمى الوصول إلى التطبيق باستخدام مصادقة الجهاز (البصمة، التعرف على الوجه، رمز الجهاز، أو النمط). هذا يمنع أي شخص من فتح التطبيق دون إذنك.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),

          const SizedBox(height: 16),

          _InfoSection(
            icon: Icons.delete_outline_rounded,
            title: 'إعادة ضبط التطبيق',
            description: 'عند إعادة ضبط التطبيق من الإعدادات، يتم حذف جميع بياناتك المحلية بشكل دائم من جهازك: معلوماتك الشخصية، الرصيد، سجل المصروفات والدخل، أهداف التوفير، والإشعارات. هذا الإجراء لا يمكن التراجع عنه.',
            accent: accent,
            surface: surface,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 30),

          // Closing callout: data control and smart-feature consent.
          Container(
            padding: const EdgeInsets.all(18),

            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),

              border: Border.all(
                color: accent.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),

            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: accent, size: 28),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Text(
                        'بياناتك تحت سيطرتك الكاملة ولا تغادر جهازك.',

                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: accent, size: 28),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Text(
                        'أنت من يقرر أي بيانات يمكن استخدامها لميزات الذكاء الاصطناعي.',

                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                          fontFamily: 'Outfit',
                          fontFamilyFallback: ['Tajawal'],
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

/// Icon + title + body paragraph for one privacy info block.
class _InfoSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  final Color accent;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;

  const _InfoSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(icon, color: accent, size: 24),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,

                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                    fontFamily: 'Outfit',
                    fontFamilyFallback: ['Tajawal'],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            description,

            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: textSecondary,
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
            ),
          ),
        ],
      ),
    );
  }
}
