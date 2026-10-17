// Sheet buttons: the round header button, the full-width save button and
// the quieter destructive action under it.

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/theme/app_palette.dart';
import 'package:waffr/widgets/containers/sheet_fields.dart';
import 'package:waffr/widgets/button/app_primary_button.dart';

/// Round icon button used in sheet headers (close / next).
class SheetCircleButton extends StatelessWidget {
  /// The icon.
  final IconData icon;

  /// Called on tap.
  final VoidCallback onTap;

  /// Creates a [SheetCircleButton].
  const SheetCircleButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final textPrimary = palette.textPrimary;

    return Material(
      color: sheetFieldColor(context),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 22,
            color: textPrimary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// Full-width primary save / confirm button at the bottom of a sheet.
class SheetSaveButton extends StatelessWidget {
  /// Button text.
  final String label;

  /// False greys the button out.
  final bool enabled;

  /// Called on tap while enabled.
  final VoidCallback onTap;

  /// Creates a [SheetSaveButton].
  const SheetSaveButton({
    super.key,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      label: label,
      onTap: onTap,
      enabled: enabled,
      icon: Icons.check_rounded,
    );
  }
}

/// Secondary "remove / delete" action under a sheet's main button. Every
/// sheet that deletes or clears something uses it, so removal always looks
/// the same and stays visually below the primary action.
class SheetDestructiveButton extends StatelessWidget {
  /// Button text.
  final String label;

  /// Called on tap; null disables it.
  final VoidCallback? onTap;

  /// Icon before the label.
  final IconData icon;

  /// Creates a [SheetDestructiveButton].
  const SheetDestructiveButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = Icons.delete_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.destructiveOf(context);
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon, size: 20, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontFamily: 'Outfit',
            fontFamilyFallback: const ['Tajawal'],
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
