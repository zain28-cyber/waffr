// Name and email shown on Profile. Not an account editor.

import 'package:flutter/foundation.dart';
import 'package:waffr/core/sync/auth_session.dart';
import 'package:waffr/core/prefs/app_prefs.dart';

/// The signed-in state, name and email the profile header shows.
class ProfileIdentity extends ChangeNotifier {
  ProfileIdentity._();

  /// The app-wide identity.
  static final ProfileIdentity instance = ProfileIdentity._();

  String _name = '';
  String _email = '';
  bool _loggedIn = false;
  bool _loaded = false;
  Future<void>? _loader;

  /// False until the first [reload] finishes; sign-in state is unknown before.
  bool get isLoaded => _loaded;

  /// Loads once if nothing has loaded yet; otherwise returns the last load.
  Future<void> ensureLoaded() => _loader ??= _load();

  /// Saved display name (may be empty).
  String get name => _name;

  /// Account email; empty for guests.
  String get email => _email;

  /// True while a session token is stored.
  bool get isLoggedIn => _loggedIn;

  /// The account name while signed in. The name saved from an account
  /// stays on the device after signing out, so a guest always reads «ضيف».
  String get displayName {
    if (!_loggedIn) return 'ضيف';
    final trimmed = _name.trim();
    return trimmed.isNotEmpty ? trimmed : 'مستخدم وفّر';
  }

  /// The email to show, or null for guests or when unknown.
  String? get displayEmail {
    if (!_loggedIn) return null;
    final trimmed = _email.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  /// Reads the state again (after sign-in, sign-out or edits).
  Future<void> reload() {
    _loader = _load();
    return _loader!;
  }

  /// Forgets everything (local data wipe).
  void reset() {
    _name = '';
    _email = '';
    _loggedIn = false;
    _loaded = false;
    _loader = null;
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await AppPrefs.instance;
    final loggedIn = await AuthSession.instance.isLoggedIn();
    final accountEmail = await AuthSession.instance.email() ?? '';
    final name = prefs.getString('user_name') ?? '';
    final email = loggedIn ? accountEmail : '';
    // Profile reloads on every visit; only rebuild listeners when something
    // actually changed.
    final changed =
        !_loaded || loggedIn != _loggedIn || name != _name || email != _email;
    _loggedIn = loggedIn;
    _name = name;
    _email = email;
    _loaded = true;
    if (changed) notifyListeners();
  }
}
