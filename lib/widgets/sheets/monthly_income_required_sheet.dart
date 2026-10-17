// Bottom sheet shown when the user tries to create a periodic savings plan
// without a monthly income set.
import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// Explains that monthly income must be set in settings, then dismisses.
Future<void> showMonthlyIncomeRequiredSheet(BuildContext context) {
  return showGlassSheet<void>(
    context: context,
    builder: (context) {
      final palette = AppPalette.of(context);
      final textSecondary = palette.textSecondary;

      return GlassSheetBody(
        children: [
          GlassSheetHeader(
            title: 'يلزم الدخل الشهري',
            subtitle: 'لا يمكن إنشاء الخطة الدورية الآن.',
          ),
          const SizedBox(height: 16),
          Text(
            'الخطة الدورية تُحسب من دخلك الشهري. افتح الإعدادات وحدّد «الدخل الشهري» أولاً، ثم أعد المحاولة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontFamilyFallback: ['Tajawal'],
              fontSize: 14,
              height: 1.7,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 22),
          SheetSaveButton(
            label: 'حسناً',
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ],
      );
    },
  );
}
