// A user-defined expense category as stored in prefs and synced to the
// server: a stable id, a label, and palette slots for its icon and color.

import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/data/models/expense_categories.dart';

/// One user-defined category with a chosen icon and color slot.
class CustomCategoryEntry {
  /// Stable id, so a rename keeps the same synced row.
  final String id;

  /// The name shown on tiles and charts.
  final String label;

  /// Index into [customCategoryIconChoices].
  final int iconIndex;

  /// Index into [customCategoryColors]; null on rows from older versions.
  final int? colorIndex;

  /// Last local or remote change (UTC), for last-write-wins sync.
  final DateTime? updatedAt;

  /// A category entry.
  const CustomCategoryEntry({
    required this.id,
    required this.label,
    required this.iconIndex,
    this.colorIndex,
    this.updatedAt,
  });

  /// Last change for sync; rows without one count as the oldest possible.
  DateTime get syncUpdatedAt =>
      (updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();

  /// The category with this entry's icon and color.
  ExpenseCategory toCategory() =>
      customCategoryNamed(label, iconIndex: iconIndex, colorIndex: colorIndex);

  /// A copy with the given fields replaced.
  CustomCategoryEntry copyWith({
    String? label,
    int? iconIndex,
    int? colorIndex,
    DateTime? updatedAt,
  }) {
    return CustomCategoryEntry(
      id: id,
      label: label ?? this.label,
      iconIndex: iconIndex ?? this.iconIndex,
      colorIndex: colorIndex ?? this.colorIndex,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// The prefs JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'icon': iconIndex,
    if (colorIndex != null) 'color': colorIndex,
    'updatedAt': toSyncIso(syncUpdatedAt),
  };

  /// Reads prefs JSON. Rows from before ids existed get [legacyId].
  factory CustomCategoryEntry.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as String? ?? '').trim();
    final icon = json['icon'] ?? json['icon_index'] ?? json['iconIndex'];
    final iconIndex = icon is int
        ? icon
        : int.tryParse(icon?.toString() ?? '') ?? 0;
    final rawId = (json['id'] ?? json['client_id'])?.toString().trim() ?? '';
    return CustomCategoryEntry(
      id: rawId.isEmpty ? legacyId(label) : rawId,
      label: label,
      iconIndex: clampCustomIconIndex(iconIndex),
      colorIndex: _readColorIndex(json['color'] ?? json['color_index']),
      updatedAt:
          parseSyncDate(json['updatedAt'] ?? json['updated_at']) ?? syncNow(),
    );
  }

  /// Server payload → entry; null when label or client id is missing.
  static CustomCategoryEntry? fromSync(Map<String, dynamic> raw) {
    final label = raw['label']?.toString().trim() ?? '';
    final id = (raw['client_id'] ?? raw['id'])?.toString().trim() ?? '';
    if (label.isEmpty || id.isEmpty) return null;
    final icon = raw['icon_index'] ?? raw['iconIndex'] ?? raw['icon'];
    final iconIndex = icon is int
        ? icon
        : int.tryParse(icon?.toString() ?? '') ?? 0;
    return CustomCategoryEntry(
      id: id,
      label: label,
      iconIndex: clampCustomIconIndex(iconIndex),
      colorIndex: _readColorIndex(raw['color'] ?? raw['color_index']),
      updatedAt: parseSyncDate(raw['updated_at'] ?? raw['updatedAt']),
    );
  }

  /// Stable id for pre-v2 categories that only stored a label string.
  static String legacyId(String label) {
    var hash = 0;
    for (final unit in label.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return 'cat_$hash';
  }

  static int _seq = 0;

  /// A fresh id for a new category.
  static String newId() =>
      'cat_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // A stored color slot, clamped to the palette; null when absent.
  static int? _readColorIndex(Object? raw) {
    if (raw == null) return null;
    final index = raw is int ? raw : int.tryParse(raw.toString());
    if (index == null || customCategoryColors.isEmpty) return null;
    return clampCustomColorIndex(index);
  }
}
