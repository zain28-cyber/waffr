// Custom expense categories: local prefs, sync merge, and lookup hook for charts.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:waffr/data/models/custom_category_entry.dart';
import 'package:waffr/data/models/expense_categories.dart';
import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_dirty.dart';
import 'package:waffr/core/sync/sync_merge.dart';
import 'package:waffr/core/sync/sync_tombstones.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

export 'package:waffr/data/models/custom_category_entry.dart';

/// Owns custom categories in prefs and registers them with customCategoryLookup.
///
/// Built-in categories can be removed too. They are only hidden from the
/// pickers (the label list travels with settings sync), so old expenses keep
/// their label, icon and color. Removed custom categories are kept in a local
/// archive for the same reason.
class CategoryStore extends ChangeNotifier {
  CategoryStore._() {
    customCategoryLookup = findCustom;
  }

  /// The app-wide category store.
  static final CategoryStore instance = CategoryStore._();

  /// Prefs key of the oldest format: a list of labels.
  static const String itemsKey = 'custom_expense_categories';

  /// Prefs key of the current format: JSON entries.
  static const String itemsJsonKey = 'custom_expense_categories_v2';

  /// Prefs key of the removed built-in labels.
  static const String hiddenBuiltInsKey = 'hidden_builtin_categories';

  /// Prefs key of removed custom categories, kept for old expenses.
  static const String archivedKey = 'archived_expense_categories';

  final List<CustomCategoryEntry> _entries = [];
  final Set<String> _hiddenBuiltIns = {};
  final Map<String, CustomCategoryEntry> _archived = {};
  Future<void>? _loader;
  bool _loaded = false;

  /// True once loaded from prefs.
  bool get isLoaded => _loaded;

  /// The user's categories as drawable categories.
  List<ExpenseCategory> get customCategories => [
    for (final entry in _entries) entry.toCategory(),
  ];

  /// The user's categories as stored (for sync).
  List<CustomCategoryEntry> get entries => List.unmodifiable(_entries);

  /// Built-in labels the user removed, in catalog order (for settings sync).
  List<String> get hiddenBuiltIns => [
    for (final item in expenseCategories)
      if (_hiddenBuiltIns.contains(item.label)) item.label,
  ];

  /// Visible built-ins plus customs for pickers; excludes the "custom" tile.
  List<ExpenseCategory> get selectableCategories => [
    for (final item in expenseCategories)
      if (!_hiddenBuiltIns.contains(item.label)) item,
    ...customCategories,
  ];

  /// First category a new expense starts on.
  String get defaultLabel {
    final options = selectableCategories;
    return options.isEmpty ? fallbackCategory.label : options.first.label;
  }

  /// Loads from prefs once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Live custom categories first, then removed ones so history keeps its icon.
  ExpenseCategory? findCustom(String label) {
    for (final entry in _entries) {
      if (entry.label == label) return entry.toCategory();
    }
    return _archived[label]?.toCategory();
  }

  /// True for a live user-defined category.
  bool isCustom(String label) => _entries.any((entry) => entry.label == label);

  /// True for one of the built-in categories.
  bool isBuiltIn(String label) =>
      expenseCategories.any((item) => item.label == label);

  /// True when [label] shows in the pickers.
  bool isSelectable(String label) =>
      selectableCategories.any((item) => item.label == label);

  /// The saved icon slot of a custom category, else 0.
  int iconIndexOf(String label) {
    for (final entry in _entries) {
      if (entry.label == label) return entry.iconIndex;
    }
    return 0;
  }

  /// Arabic validation error, or null if the name can be used.
  String? validateName(String rawName, {String? ignoring}) {
    final name = rawName.trim();
    if (name.isEmpty) return 'أدخل اسماً للتصنيف';
    if (name == customCategoryActionLabel || name == fallbackCategory.label) {
      return 'هذا الاسم محجوز';
    }
    if (selectableCategories.any(
      (item) => item.label == name && item.label != ignoring,
    )) {
      return 'هذا التصنيف موجود مسبقاً';
    }
    // A removed built-in comes back through "add", not through a rename.
    if (ignoring != null && name != ignoring && isBuiltIn(name)) {
      return 'هذا التصنيف موجود مسبقاً';
    }
    return null;
  }

  /// Adds a category (or brings back a removed built-in of that name).
  /// Returns the saved label, or null when the name is not valid.
  Future<String?> addCustom(String rawName, {int iconIndex = 0}) async {
    await ensureLoaded();

    if (validateName(rawName) != null) return null;

    final name = rawName.trim();

    // Typing the name of a removed built-in brings that built-in back.
    if (_hiddenBuiltIns.remove(name)) {
      await _persistHidden();
      notifyListeners();
      return name;
    }

    _entries.add(
      CustomCategoryEntry(
        id: CustomCategoryEntry.newId(),
        label: name,
        iconIndex: clampCustomIconIndex(iconIndex),
        colorIndex: nextCustomColorIndex(
          _entries.map((entry) => entry.colorIndex).whereType<int>(),
        ),
        updatedAt: syncNow(),
      ),
    );
    await _persist();
    notifyListeners();
    return name;
  }

  /// Renames a custom category and may change its icon; the old name is
  /// archived so earlier expenses keep their look. Null when not valid.
  Future<String?> renameCustom(
    String oldLabel,
    String rawName, {
    int? iconIndex,
  }) async {
    await ensureLoaded();

    final index = _entries.indexWhere((entry) => entry.label == oldLabel);
    if (index < 0) return null;

    final error = validateName(rawName, ignoring: oldLabel);
    if (error != null) return null;

    final name = rawName.trim();
    _archive(_entries[index]);
    _entries[index] = _entries[index].copyWith(
      label: name,
      iconIndex: clampCustomIconIndex(iconIndex ?? _entries[index].iconIndex),
      updatedAt: syncNow(),
    );
    await _persist();
    notifyListeners();
    return name;
  }

  /// Removes the category and records a sync tombstone.
  Future<bool> removeCustom(String label) async {
    await ensureLoaded();

    final before = _entries.length;
    CustomCategoryEntry? removed;
    _entries.removeWhere((entry) {
      if (entry.label != label) return false;
      removed = entry;
      return true;
    });
    if (_entries.length == before || removed == null) return false;

    await SyncTombstones.instance.add(
      SyncCollection.expenseCategories,
      removed!.id,
    );
    _archive(removed!);
    await _persist();
    notifyListeners();
    return true;
  }

  /// Removes a built-in or custom category from the pickers. Expenses that
  /// already use it are not touched.
  Future<bool> removeCategory(String label) async {
    await ensureLoaded();
    if (isCustom(label)) return removeCustom(label);
    if (!isBuiltIn(label) || !_hiddenBuiltIns.add(label)) return false;
    await _persistHidden();
    notifyListeners();
    return true;
  }

  /// Settings sync: the remote list of removed built-ins replaces ours.
  Future<void> applyRemoteHidden(Object? raw) async {
    if (raw is! List) return;
    await ensureLoaded();
    final next = {
      for (final item in raw)
        if (isBuiltIn(item.toString())) item.toString(),
    };
    if (next.length == _hiddenBuiltIns.length &&
        next.containsAll(_hiddenBuiltIns)) {
      return;
    }
    _hiddenBuiltIns
      ..clear()
      ..addAll(next);
    await _persistHidden(markDirty: false);
    notifyListeners();
  }

  void _archive(CustomCategoryEntry entry) {
    _archived[entry.label] = entry;
  }

  /// Merges the server's categories, keeping locally assigned colors and
  /// archiving categories the merge removed.
  Future<void> applyRemoteSync({
    required List<Map<String, dynamic>> upserts,
    required List<SyncTombstone> deletes,
  }) async {
    await ensureLoaded();

    final previousColors = {
      for (final entry in _entries)
        if (entry.colorIndex != null) entry.id: entry.colorIndex!,
    };
    final previous = List<CustomCategoryEntry>.of(_entries);

    final changed = mergeRemoteRecords<CustomCategoryEntry>(
      items: _entries,
      upserts: [
        for (final raw in upserts)
          if (CustomCategoryEntry.fromSync(raw) != null)
            CustomCategoryEntry.fromSync(raw)!,
      ],
      deletes: deletes,
      collection: SyncCollection.expenseCategories,
      idOf: (item) => item.id,
      updatedOf: (item) => item.syncUpdatedAt,
    );

    for (var i = 0; i < _entries.length; i++) {
      final kept = previousColors[_entries[i].id];
      if (_entries[i].colorIndex == null && kept != null) {
        _entries[i] = _entries[i].copyWith(colorIndex: kept);
      }
    }
    final filled = _assignMissingColors();

    if (!changed && !filled) return;
    for (final entry in previous) {
      final live = _entries.any(
        (item) => item.id == entry.id && item.label == entry.label,
      );
      if (!live) _archive(entry);
    }
    await _persist();
    notifyListeners();
  }

  /// Drops memory so the next [ensureLoaded] re-reads prefs (tests, wipes).
  void resetCache() {
    _entries.clear();
    _hiddenBuiltIns.clear();
    _archived.clear();
    _loaded = false;
    _loader = null;
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    _hiddenBuiltIns
      ..clear()
      ..addAll(prefs.getStringList(hiddenBuiltInsKey) ?? const []);
    _archived.clear();
    for (final entry in _parseJson(prefs.getString(archivedKey) ?? '')) {
      _archived[entry.label] = entry;
    }
    // Read first: the migration paths of _readEntries fill _entries
    // themselves, so clearing before the await would keep both copies.
    final loaded = await _readEntries(prefs);
    _entries
      ..clear()
      ..addAll(loaded);
    if (_assignMissingColors()) {
      await _persist();
    }
    _loaded = true;
    notifyListeners();
  }

  // Gives each saved category its own palette slot when none was stored.
  bool _assignMissingColors() {
    var changed = false;
    for (var i = 0; i < _entries.length; i++) {
      if (_entries[i].colorIndex != null) continue;
      final used = _entries.map((entry) => entry.colorIndex).whereType<int>();
      _entries[i] = _entries[i].copyWith(
        colorIndex: nextCustomColorIndex(used),
      );
      changed = true;
    }
    return changed;
  }

  // Prefers v2 JSON; migrates the old string-list format when needed.
  Future<List<CustomCategoryEntry>> _readEntries(
    SharedPreferences prefs,
  ) async {
    final json = prefs.getString(itemsJsonKey);
    if (json != null && json.trim().isNotEmpty) {
      final parsed = _parseJson(json);
      if (parsed.isNotEmpty && !json.contains('"id"')) {
        _entries
          ..clear()
          ..addAll(parsed);
        await _persist();
      }
      return parsed;
    }

    final legacy = prefs.getStringList(itemsKey) ?? const [];
    final migrated = [
      for (final raw in legacy)
        if (raw.trim().isNotEmpty)
          CustomCategoryEntry(
            id: CustomCategoryEntry.legacyId(raw.trim()),
            label: raw.trim(),
            iconIndex: raw.hashCode.abs() % customCategoryIconChoices.length,
            updatedAt: syncNow(),
          ),
    ];
    if (migrated.isNotEmpty) {
      _entries
        ..clear()
        ..addAll(migrated);
      await _persist();
    }
    return migrated;
  }

  List<CustomCategoryEntry> _parseJson(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            CustomCategoryEntry.fromJson(item)
          else if (item is Map)
            CustomCategoryEntry.fromJson(Map<String, dynamic>.from(item)),
      ].where((entry) => entry.label.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _persist() async {
    final prefs = await AppPrefs.instance;
    await prefs.setString(
      itemsJsonKey,
      jsonEncode([for (final entry in _entries) entry.toJson()]),
    );
    await prefs.setString(
      archivedKey,
      jsonEncode([for (final entry in _archived.values) entry.toJson()]),
    );
    await SyncDirty.mark();
  }

  Future<void> _persistHidden({bool markDirty = true}) async {
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(hiddenBuiltInsKey, hiddenBuiltIns);
    if (markDirty) await SyncDirty.mark(settings: true);
  }
}
