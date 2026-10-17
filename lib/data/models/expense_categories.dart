// Built-in expense categories, custom-icon palette, and label → category lookup.

import 'package:flutter/material.dart';

/// A category's label, icon and chart colors.
class ExpenseCategory {
  /// Name stored on expenses and shown on tiles.
  final String label;

  /// Tile and list icon.
  final IconData icon;

  /// Chart color on the light theme.
  final Color color;

  /// Chart color on the dark theme: the same hue, a little lighter.
  final Color darkColor;

  /// A category.
  const ExpenseCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.darkColor,
  });
}

/// Grid order for "add expense". Chart colors are an earthy set that sits
/// with the app's green: terracotta, teal, berry, ochre, leaf green, violet
/// and sky blue. Each hue has its own lightness so neighbouring slices stay
/// apart, also for color-blind readers.
const List<ExpenseCategory> expenseCategories = [
  ExpenseCategory(
    label: 'طعام',
    icon: Icons.lunch_dining_outlined,
    color: Color(0xFFDD8461),
    darkColor: Color(0xFFF19773),
  ),
  ExpenseCategory(
    label: 'مواصلات',
    icon: Icons.directions_bus_outlined,
    color: Color(0xFF00828D),
    darkColor: Color(0xFF289DA9),
  ),
  ExpenseCategory(
    label: 'تسوق',
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFFAC5371),
    darkColor: Color(0xFFCA6E8C),
  ),
  ExpenseCategory(
    label: 'فواتير',
    icon: Icons.receipt_long_outlined,
    color: Color(0xFFDBB155),
    darkColor: Color(0xFFE8C773),
  ),
  ExpenseCategory(
    label: 'صحة',
    icon: Icons.favorite_border_rounded,
    color: Color(0xFF4E8841),
    darkColor: Color(0xFF518B44),
  ),
  ExpenseCategory(
    label: 'ترفيه',
    icon: Icons.sports_esports_outlined,
    color: Color(0xFF6A57A4),
    darkColor: Color(0xFF8371C1),
  ),
  ExpenseCategory(
    label: 'تعليم',
    icon: Icons.school_outlined,
    color: Color(0xFF7CAFE8),
    darkColor: Color(0xFF88BCF6),
  ),
];

/// Label of the "add your own" tile.
const String customCategoryActionLabel = 'مخصص';

/// The "add your own" tile at the end of the grid.
const ExpenseCategory customCategoryAction = ExpenseCategory(
  label: customCategoryActionLabel,
  icon: Icons.add_rounded,
  color: Color(0xFF9A9388),
  darkColor: Color(0xFFA39D91),
);

/// Expenses with no category, or «أخرى».
const ExpenseCategory fallbackCategory = ExpenseCategory(
  label: 'أخرى',
  icon: Icons.more_horiz_rounded,
  color: Color(0xFF9A9388),
  darkColor: Color(0xFFA39D91),
);

/// Payment methods; the first is the default.
const List<String> paymentMethods = ['نقداً', 'بطاقة'];

/// Icons users can pick when creating a custom category.
const List<IconData> customCategoryIconChoices = [
  Icons.restaurant_outlined,
  Icons.lunch_dining_outlined,
  Icons.local_cafe_outlined,
  Icons.local_grocery_store_outlined,
  Icons.directions_bus_outlined,
  Icons.directions_car_outlined,
  Icons.local_taxi_outlined,
  Icons.two_wheeler_outlined,
  Icons.local_gas_station_outlined,
  Icons.flight_outlined,
  Icons.shopping_bag_outlined,
  Icons.shopping_cart_outlined,
  Icons.checkroom_outlined,
  Icons.home_outlined,
  Icons.water_drop_outlined,
  Icons.lightbulb_outline_rounded,
  Icons.receipt_long_outlined,
  Icons.wifi_outlined,
  Icons.phone_android_outlined,
  Icons.tv_outlined,
  Icons.local_hospital_outlined,
  Icons.local_pharmacy_outlined,
  Icons.school_outlined,
  Icons.menu_book_outlined,
  Icons.work_outline_rounded,
  Icons.sports_soccer_outlined,
  Icons.sports_outlined,
  Icons.fitness_center_outlined,
  Icons.sports_esports_outlined,
  Icons.movie_outlined,
  Icons.account_balance_wallet_outlined,
  Icons.credit_card_outlined,
  Icons.savings_outlined,
  Icons.child_care_outlined,
  Icons.pets_outlined,
  Icons.card_giftcard_outlined,
  Icons.content_cut_outlined,
  Icons.build_outlined,
  Icons.celebration_outlined,
];

/// Chart slices for added categories: more hues from the same earthy
/// family. Saved categories keep their slot index, so the order is fixed.
const List<Color> customCategoryColors = [
  Color(0xFF848D42),
  Color(0xFFA24B36),
  Color(0xFF4EA4CA),
  Color(0xFFD48490),
  Color(0xFF41A083),
  Color(0xFF6D4177),
  Color(0xFFC9A471),
  Color(0xFF596DB2),
  Color(0xFFDD766F),
  Color(0xFF4C682E),
  Color(0xFFAD98D5),
  Color(0xFF57B6B6),
];

/// [customCategoryColors] for the dark theme, slot for slot.
const List<Color> customCategoryDarkColors = [
  Color(0xFF90994E),
  Color(0xFFBC634D),
  Color(0xFF5BB0D7),
  Color(0xFFE2909C),
  Color(0xFF4FAC8F),
  Color(0xFF855890),
  Color(0xFFD6B17D),
  Color(0xFF6F85CC),
  Color(0xFFEB827B),
  Color(0xFF637F45),
  Color(0xFFBAA4E2),
  Color(0xFF64C3C3),
];

/// Wired by CategoryStore so charts/reports resolve saved custom icons.
ExpenseCategory? Function(String label)? customCategoryLookup;

/// [index] kept inside [customCategoryIconChoices].
int clampCustomIconIndex(int index) {
  if (customCategoryIconChoices.isEmpty) return 0;
  return index.clamp(0, customCategoryIconChoices.length - 1).toInt();
}

/// [index] kept inside [customCategoryColors].
int clampCustomColorIndex(int index) {
  if (customCategoryColors.isEmpty) return 0;
  return index.clamp(0, customCategoryColors.length - 1).toInt();
}

/// First palette slot not already taken; wraps only after every color is used.
int nextCustomColorIndex(Iterable<int> used) {
  final taken = used.toSet();
  for (var i = 0; i < customCategoryColors.length; i++) {
    if (!taken.contains(i)) return i;
  }
  return taken.length % customCategoryColors.length;
}

/// Builds a custom category. [colorIndex] keeps a saved color; otherwise the
/// label hash picks one from the added-category palette.
ExpenseCategory customCategoryNamed(
  String label, {
  int? iconIndex,
  int? colorIndex,
}) {
  final hash = label.hashCode.abs();
  final resolvedIcon = iconIndex == null
      ? hash % customCategoryIconChoices.length
      : clampCustomIconIndex(iconIndex);
  final resolvedColor = colorIndex == null
      ? hash % customCategoryColors.length
      : clampCustomColorIndex(colorIndex);

  return ExpenseCategory(
    label: label,
    icon: customCategoryIconChoices[resolvedIcon],
    color: customCategoryColors[resolvedColor],
    darkColor: customCategoryDarkColors[resolvedColor],
  );
}

/// Built-in first, then custom lookup, otherwise a hashed custom row.
ExpenseCategory categoryFor(String? label) {
  if (label == null || label.isEmpty) return fallbackCategory;

  for (final item in expenseCategories) {
    if (item.label == label) return item;
  }

  if (label == fallbackCategory.label) return fallbackCategory;

  final custom = customCategoryLookup?.call(label);
  if (custom != null) return custom;

  return customCategoryNamed(label);
}

/// The chart color of [label] for the current theme.
Color categoryChartColor(BuildContext context, String? label) {
  final category = categoryFor(label);
  return Theme.of(context).brightness == Brightness.dark
      ? category.darkColor
      : category.color;
}
