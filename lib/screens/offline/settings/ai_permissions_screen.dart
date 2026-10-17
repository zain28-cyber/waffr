// Smart analysis settings: a shortcut to the full analysis, switches for the
// smart features, and a note on where the analysis runs.

import 'package:flutter/material.dart';
import 'package:waffr/core/insights/smart/smart_insight.dart';
import 'package:waffr/data/services/smart_settings.dart';
import 'package:waffr/screens/offline/smart/smart_analysis_screen.dart';
import 'package:waffr/widgets/brand/waffr_page_header.dart';
import 'package:waffr/widgets/containers/app_list_tile.dart';
import 'package:waffr/widgets/containers/glass.dart';
import 'package:waffr/widgets/smart/smart_glow.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Smart analysis settings page, opened from settings. Reads and writes
/// [SmartSettings] (smart alerts, auto-categorize).
class AIPermissionsScreen extends StatefulWidget {
  /// Creates a [AIPermissionsScreen].
  const AIPermissionsScreen({super.key});

  @override
  State<AIPermissionsScreen> createState() => _AIPermissionsScreenState();
}

/// State of [AIPermissionsScreen]. Rebuilds from [SmartSettings] changes.
class _AIPermissionsScreenState extends State<AIPermissionsScreen> {
  final SmartSettings _settings = SmartSettings.instance;

  @override
  void initState() {
    super.initState();
    _settings.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final background = palette.background;
    final accent = palette.accent;
    final textSecondary = palette.textSecondary;

    return Scaffold(
      backgroundColor: background,
      appBar: WaffrBackHeader(title: 'التحليل الذكي'),
      body: AnimatedBuilder(
        animation: _settings,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              // Shortcut to the full smart analysis.
              AppListTile(
                icon: Icons.auto_awesome,
                leading: const SmartSpark(size: 32),
                title: 'افتح التحليل الشامل',
                subtitle: 'ملاحظات واقتراحات عن مصاريفك وتوفيرك وعاداتك',
                onTap: () => openSmartAnalysis(context, InsightScope.profile),
              ),
              const SizedBox(height: 22),
              const AppSectionTitle(title: 'الميزات'),
              // Feature switches.
              AppListTile(
                icon: Icons.notifications_active_outlined,
                leading: const SmartGradientIcon(
                  Icons.notifications_active_outlined,
                ),
                title: 'تنبيهات ذكية',
                subtitle:
                    'تنبيه قبل نفاد الرصيد، وتذكيرات قصيرة إن غبت عن التطبيق',
                showChevron: false,
                trailing: Switch(
                  value: _settings.alerts,
                  activeThumbColor: accent,
                  onChanged: _settings.setAlerts,
                ),
                onTap: () => _settings.setAlerts(!_settings.alerts),
              ),
              const SizedBox(height: 10),
              AppListTile(
                icon: Icons.category_outlined,
                leading: const SmartGradientIcon(Icons.category_outlined),
                title: 'تصنيف تلقائي للمصروف',
                subtitle: 'يقترح التصنيف من الملاحظة التي تكتبها',
                showChevron: false,
                trailing: Switch(
                  value: _settings.categorize,
                  activeThumbColor: accent,
                  onChanged: _settings.setCategorize,
                ),
                onTap: () => _settings.setCategorize(!_settings.categorize),
              ),
              const SizedBox(height: 22),
              // On-device privacy note.
              const AppSectionTitle(title: 'الخصوصية'),
              GlassContainer(
                colorType: GlassColorType.surface,
                borderRadius: 22,
                padding: const EdgeInsets.all(16),
                child: Text(
                  'كل التحليل يتم على جهازك. لا تُرسَل مصاريفك أو ملاحظاتك '
                  'إلى أي خادم لتحليلها، ويعمل التحليل بدون إنترنت وفي وضع الضيف.',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 13,
                    height: 1.6,
                    color: textSecondary,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
