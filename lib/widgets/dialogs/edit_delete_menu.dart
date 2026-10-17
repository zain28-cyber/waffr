// Small edit / delete popup anchored to a tile. Used by expense categories
// and shopping-list items so both long-press menus look the same.

import 'package:flutter/material.dart';
import 'package:waffr/core/theme/app_color.dart';
import 'package:waffr/core/theme/app_palette.dart';

/// What the user picked in the long-press menu.
enum EditDeleteAction {
  /// Edit the item.
  edit,

  /// Delete the item.
  delete,
}

/// Opens the menu over the widget at [anchorContext]. [allowEdit] hides the
/// edit row when only removal makes sense.
Future<EditDeleteAction?> showEditDeleteMenu(
  BuildContext context, {
  required BuildContext anchorContext,
  bool allowEdit = true,
}) async {
  final box = anchorContext.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;

  final origin = box.localToGlobal(Offset.zero);
  final size = box.size;
  final palette = AppPalette.of(context);
  final surface = palette.surface;
  final textPrimary = palette.textPrimary;
  final deleteColor = AppColors.destructiveOf(context);

  return showMenu<EditDeleteAction>(
    context: context,
    color: surface,
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    position: RelativeRect.fromLTRB(
      origin.dx,
      origin.dy - 8,
      origin.dx + size.width,
      origin.dy,
    ),
    items: [
      if (allowEdit)
        PopupMenuItem(
          value: EditDeleteAction.edit,
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.edit_rounded,
                size: 18,
                color: textPrimary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Text(
                'تعديل',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontFamilyFallback: const ['Tajawal'],
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ),
      PopupMenuItem(
        value: EditDeleteAction.delete,
        height: 44,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_rounded, size: 18, color: deleteColor),
            const SizedBox(width: 8),
            Text(
              'حذف',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontFamilyFallback: const ['Tajawal'],
                color: deleteColor,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
