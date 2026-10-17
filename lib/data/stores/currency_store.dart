// Persists which currencies are enabled and which one is active in the UI.

import 'package:flutter/foundation.dart';
import 'package:waffr/data/models/currency.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/sync/sync_dirty.dart';

export 'package:waffr/data/models/currency.dart';

/// Enabled list + active code. Removing a currency never deletes its ledger rows.
class CurrencyStore extends ChangeNotifier {
  CurrencyStore._();

  /// The app-wide currency store.
  static final CurrencyStore instance = CurrencyStore._();

  /// Prefs key of the enabled codes.
  static const String enabledKey = 'enabled_currencies';

  /// Prefs key of the active code.
  static const String activeKey = 'active_currency';

  final List<String> _enabled = [defaultCurrencyCode];
  String _activeCode = defaultCurrencyCode;

  Future<void>? _loader;
  bool _loaded = false;

  /// True once loaded from prefs.
  bool get isLoaded => _loaded;

  /// The active currency code.
  String get activeCode => _activeCode;

  /// The active currency.
  CurrencyInfo get active => Currencies.of(_activeCode);

  /// Symbol of the active currency.
  String get activeSymbol => active.symbol;

  /// Currencies shown in the balance carousel and amount pickers.
  List<CurrencyInfo> get enabledCurrencies {
    return [for (final code in _enabled) Currencies.of(code)];
  }

  /// Enabled codes, SYP first (for settings sync).
  List<String> get enabledCodes => List.unmodifiable(_enabled);

  /// Catalog entries not yet on the enabled list.
  List<CurrencyInfo> get availableToAdd {
    return [
      for (final item in Currencies.catalog)
        if (!_enabled.contains(item.code)) item,
    ];
  }

  /// True when [code] is on the enabled list.
  bool isEnabled(String code) => _enabled.contains(Currencies.normalize(code));

  /// Loads from prefs once; later calls return the same future.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Switches the active currency if it is already enabled.
  Future<void> setActive(String code) async {
    await ensureLoaded();

    final normalized = Currencies.normalize(code);
    if (!_enabled.contains(normalized)) {
      return;
    }
    if (_activeCode == normalized) {
      return;
    }

    _activeCode = normalized;
    await _persistActive();
    await SyncDirty.mark(settings: true);
    notifyListeners();
  }

  /// Replaces the enabled list and active code from a newer account sync.
  Future<void> applyRemote({List<dynamic>? enabled, String? active}) async {
    await ensureLoaded();
    if (enabled == null && (active == null || active.trim().isEmpty)) return;

    final beforeEnabled = List<String>.of(_enabled);
    final beforeActive = _activeCode;

    if (enabled != null) {
      _enabled
        ..clear()
        ..add(defaultCurrencyCode);
      for (final raw in enabled) {
        final code = Currencies.normalize(raw?.toString());
        if (code == defaultCurrencyCode) continue;
        if (!Currencies.isKnown(code)) continue;
        if (_enabled.contains(code)) continue;
        _enabled.add(code);
      }
    }

    final nextActive = Currencies.normalize(active ?? _activeCode);
    _activeCode = _enabled.contains(nextActive)
        ? nextActive
        : defaultCurrencyCode;
    // A sync usually echoes what this device already has; then there is
    // nothing to save and no reason to rebuild every screen.
    if (_activeCode == beforeActive && _sameOrder(_enabled, beforeEnabled)) {
      return;
    }
    await _persistEnabled();
    await _persistActive();
    notifyListeners();
  }

  /// Makes the next enabled currency active (wraps around).
  Future<void> selectNext() async {
    await ensureLoaded();
    if (_enabled.length < 2) return;

    final index = _enabled.indexOf(_activeCode);
    final next = (index < 0 ? 0 : index + 1) % _enabled.length;
    await setActive(_enabled[next]);
  }

  /// Makes the previous enabled currency active (wraps around).
  Future<void> selectPrevious() async {
    await ensureLoaded();
    if (_enabled.length < 2) return;

    final index = _enabled.indexOf(_activeCode);
    final previous =
        (index < 0 ? 0 : index - 1 + _enabled.length) % _enabled.length;
    await setActive(_enabled[previous]);
  }

  /// Adds a known non-SYP currency to the enabled list.
  Future<bool> addCurrency(String code) async {
    await ensureLoaded();

    final normalized = Currencies.normalize(code);
    if (normalized == defaultCurrencyCode) {
      return false;
    }
    if (!Currencies.isKnown(normalized) || _enabled.contains(normalized)) {
      return false;
    }

    _enabled.add(normalized);
    await _persistEnabled();
    await SyncDirty.mark(settings: true);
    notifyListeners();
    return true;
  }

  /// Drops a currency from the carousel without wiping its transactions.
  Future<bool> removeCurrency(String code) async {
    await ensureLoaded();

    final normalized = Currencies.normalize(code);
    if (normalized == defaultCurrencyCode) {
      return false;
    }
    if (!_enabled.contains(normalized)) {
      return false;
    }

    _enabled.remove(normalized);
    if (_activeCode == normalized) {
      _activeCode = defaultCurrencyCode;
      await _persistActive();
    }
    await _persistEnabled();
    await SyncDirty.mark(settings: true);
    notifyListeners();
    return true;
  }

  /// Drops memory so the next [ensureLoaded] re-reads prefs (tests, wipes).
  void resetCache() {
    _enabled
      ..clear()
      ..add(defaultCurrencyCode);
    _activeCode = defaultCurrencyCode;
    _loaded = false;
    _loader = null;
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    final stored = prefs.getStringList(enabledKey) ?? const [];

    _enabled
      ..clear()
      ..add(defaultCurrencyCode);

    for (final raw in stored) {
      final code = Currencies.normalize(raw);
      if (code == defaultCurrencyCode) continue;
      if (!Currencies.isKnown(code)) continue;
      if (_enabled.contains(code)) continue;
      _enabled.add(code);
    }

    final active = Currencies.normalize(prefs.getString(activeKey));
    _activeCode = _enabled.contains(active) ? active : defaultCurrencyCode;

    _loaded = true;
    notifyListeners();
  }

  Future<void> _persistEnabled() async {
    final prefs = await AppPrefs.instance;
    await prefs.setStringList(enabledKey, _enabled);
  }

  Future<void> _persistActive() async {
    final prefs = await AppPrefs.instance;
    await prefs.setString(activeKey, _activeCode);
  }

  static bool _sameOrder(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
