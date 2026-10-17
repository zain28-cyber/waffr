// Country list with calling codes, opened from the profile form. Rows follow
// the currency list under the amount field: name, with the code at the end.

import 'package:flutter/material.dart';
import 'package:waffr/widgets/containers/app_empty_state.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/data/models/country.dart';
import 'package:waffr/widgets/containers/glass_sheet.dart';

/// Opens the searchable country list and returns the picked country, or
/// null when dismissed. [selected] is highlighted.
Future<CountryInfo?> showCountryPickerSheet(
  BuildContext context, {
  CountryInfo? selected,
}) {
  return showGlassSheet<CountryInfo>(
    context: context,
    heightFactor: 0.85,
    builder: (context) => _CountryPickerSheet(selected: selected),
  );
}

/// Sheet body: header with a search field above the filtered country list.
class _CountryPickerSheet extends StatefulWidget {
  final CountryInfo? selected;

  const _CountryPickerSheet({this.selected});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

/// State of [_CountryPickerSheet]. Owns the search controller; the list is
/// re-filtered with [Countries.search] on every keystroke.
class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = Countries.search(_search.text);

    return GlassSheetFixedBody(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GlassSheetHeader(
            title: 'الدولة',
            subtitle: 'اختر دولتك. يظهر رمز الاتصال بجانب رقم الهاتف.',
          ),
          const SizedBox(height: 14),
          SheetTextField(
            controller: _search,
            hint: 'ابحث باسم الدولة أو رمز الاتصال',
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      body: results.isEmpty
          ? const AppEmptyState(
              icon: Icons.search_off_rounded,
              title: 'لا توجد دولة بهذا الاسم',
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                return _CountryTile(
                  country: item,
                  selected: item.iso == widget.selected?.iso,
                  onTap: () => Navigator.of(context).pop(item),
                );
              },
            ),
    );
  }
}

/// One country row: check mark when selected, Arabic name, calling code.
class _CountryTile extends StatelessWidget {
  final CountryInfo country;
  final bool selected;
  final VoidCallback onTap;

  const _CountryTile({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = selected ? palette.accent : palette.textPrimary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Row(
              children: [
                if (selected) ...[
                  Icon(Icons.check_rounded, size: 18, color: palette.accent),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    country.arabicName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Tajawal'],
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  country.dialLabel,
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontFamilyFallback: const ['Tajawal'],
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: selected ? palette.accent : palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
