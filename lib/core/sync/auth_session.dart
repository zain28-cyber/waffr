// Auth session: JWT login/register against FastAPI /auth, plus last-sync stamp.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:waffr/data/services/backup_service.dart';
import 'package:waffr/data/models/registration_profile.dart';
import 'package:waffr/core/sync/api_config.dart';
import 'package:waffr/core/sync/auth_errors.dart';
import 'package:waffr/core/sync/profile_sync.dart';
import 'package:waffr/core/prefs/app_prefs.dart';
import 'package:waffr/core/security/data_key.dart';

export 'package:waffr/core/sync/auth_errors.dart';

/// Simple success/failure wrapper for login and register UI.
class AuthResult {
  /// True when the call succeeded.
  final bool ok;

  /// Arabic error text; empty on success.
  final String message;

  /// A success.
  const AuthResult.success() : ok = true, message = '';

  /// A failure with an Arabic [message].
  const AuthResult.failure(this.message) : ok = false;
}

/// Holds the Bearer token and account email. Server ownership always comes from
/// the token; guest mode has no token and never syncs. Switching accounts can
/// replace local data so one user's records do not bleed into another's.
class AuthSession {
  AuthSession._();

  /// The app-wide session.
  static final AuthSession instance = AuthSession._();

  /// Secure-storage key of the JWT (also its legacy prefs key).
  static const String tokenKey = 'waffer_sync_token';

  /// Prefs key of the server time of the last successful sync.
  static const String lastSyncKey = 'waffer_last_sync_at';

  /// Prefs key of the signed-in email.
  static const String accountEmailKey = 'waffer_account_email';

  /// Prefs key of the email whose data is on this device.
  static const String dataOwnerKey = 'waffer_data_owner_email';

  /// Prefs key where very old versions kept the password; always removed.
  static const String legacyPasswordKey = 'waffer_sync_password';

  static const Duration _timeout = Duration(seconds: 15);

  // v11 dropped EncryptedSharedPreferences; the default cipher storage is used.
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// True when a token is stored (it may still be expired).
  Future<bool> isLoggedIn() async {
    final value = await token();
    return value != null && value.isNotEmpty;
  }

  /// Signed-in API email, or null in guest mode.
  Future<String?> email() async {
    final prefs = await AppPrefs.instance;
    final stored = prefs.getString(accountEmailKey)?.trim() ?? '';
    if (stored.contains('@')) return stored.toLowerCase();
    return null;
  }

  /// Email whose local financial data currently lives on this device.
  Future<String?> dataOwnerEmail() async {
    final prefs = await AppPrefs.instance;
    final stored = prefs.getString(dataOwnerKey)?.trim() ?? '';
    if (stored.contains('@')) return stored.toLowerCase();
    return null;
  }

  /// The stored JWT, moving an old prefs copy into secure storage first.
  Future<String?> token() async {
    await _migrateLegacyToken();
    final value = (await _secure.read(key: tokenKey))?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Server time of the last successful sync, or null before the first.
  Future<DateTime?> lastSyncAt() async {
    final prefs = await AppPrefs.instance;
    return DateTime.tryParse(prefs.getString(lastSyncKey) ?? '')?.toUtc();
  }

  /// Stores the server time of a successful sync.
  Future<void> saveLastSyncAt(DateTime value) async {
    final prefs = await AppPrefs.instance;
    await prefs.setString(lastSyncKey, value.toUtc().toIso8601String());
  }

  /// Forgets the JWT.
  Future<void> clearToken() async {
    await _secure.delete(key: tokenKey);
    final prefs = await AppPrefs.instance;
    await prefs.remove(tokenKey);
  }

  /// Drop the API session and data key; local financial data and the
  /// data-owner stamp stay.
  Future<void> clearSession() async {
    await clearToken();
    await DataKeyStore.instance.clear();
    final prefs = await AppPrefs.instance;
    await prefs.remove(lastSyncKey);
    await prefs.remove(accountEmailKey);
    await prefs.remove(legacyPasswordKey);
  }

  /// Forgets whose data is on the device (after a wipe).
  Future<void> clearDataOwner() async {
    final prefs = await AppPrefs.instance;
    await prefs.remove(dataOwnerKey);
  }

  /// Return a live JWT, or null for guests / dead tokens. Never auto-registers.
  /// Only a 401 ends the session; a timeout, 429 or server error keeps the
  /// token so a slow or busy server does not sign the user out.
  Future<String?> ensureToken() async {
    final existing = await token();
    if (existing == null) return null;
    final reply = await _getMe(existing);
    if (reply.status == 401) {
      await clearToken();
      return null;
    }
    final me = reply.me;
    if (me == null) return existing;
    final address = me['email']?.toString().trim() ?? '';
    if (address.contains('@')) {
      final prefs = await AppPrefs.instance;
      await prefs.setString(accountEmailKey, address.toLowerCase());
    }
    return existing;
  }

  /// Signs in with email and password.
  Future<AuthResult> login({required String email, required String password}) {
    return _authenticate(
      path: '/auth/login',
      body: {'email': email.trim().toLowerCase(), 'password': password},
    );
  }

  /// Creates an account with the sign-up [profile].
  Future<AuthResult> register({
    required String email,
    required String password,
    required RegistrationProfile profile,
  }) {
    return _authenticate(
      path: '/auth/register',
      body: {
        'email': email.trim().toLowerCase(),
        'password': password,
        ...profile.toAuthBody(),
      },
    );
  }

  /// POST login or register, store the token, and bind the account locally.
  Future<AuthResult> _authenticate({
    required String path,
    required Map<String, dynamic> body,
  }) async {
    // Nothing to send without an email and a password.
    final address = body['email']?.toString() ?? '';
    final password = body['password']?.toString() ?? '';
    if (!_looksLikeEmail(address) || password.isEmpty) {
      return const AuthResult.failure('أدخل البريد وكلمة المرور');
    }

    try {
      // Log in or register; the reply carries the access token.
      final base = await ApiConfig.baseUrl();
      final response = await http
          .post(
            Uri.parse('$base$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeoutFor(base, local: _timeout));

      Object? decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode != 200) {
        return AuthResult.failure(
          describeAuthError(response.statusCode, decoded),
        );
      }

      if (decoded is! Map) {
        return const AuthResult.failure('تعذّر الاتصال بالخادم. حاول مرة أخرى');
      }
      final access = decoded['access_token']?.toString() ?? '';
      if (access.isEmpty) {
        return const AuthResult.failure('تعذّر الاتصال بالخادم. حاول مرة أخرى');
      }

      // Read the account, then open (or create) its data key with the
      // password, so synced text can be sealed.
      var me = await _fetchMe(access);
      if (me == null) {
        return const AuthResult.failure('تعذّر الاتصال بالخادم. حاول مرة أخرى');
      }
      final dataKey = await _unlockDataKey(access, password, me);
      if (dataKey == null) {
        return const AuthResult.failure(
          'تعذّر فتح بياناتك المشفّرة. حاول مرة أخرى',
        );
      }
      me = dataKey.me;
      final resolvedEmail = (me['email']?.toString() ?? address).toLowerCase();

      // Only now is anything stored on the device.
      await _bindAccount(
        email: resolvedEmail,
        token: access,
        profile: _mergedProfile(me, body),
      );
      await DataKeyStore.instance.save(dataKey.key);
      return const AuthResult.success();
    } catch (_) {
      return const AuthResult.failure(
        'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى',
      );
    }
  }

  /// Attach token + email; wipe local data when adopting a different owner.
  Future<void> _bindAccount({
    required String email,
    required String token,
    required Map<String, dynamic> profile,
  }) async {
    final owner = await dataOwnerEmail();
    final adopting = owner != email;
    if (owner != null && adopting) {
      await BackupService.instance.replaceLocalDataForAccountSwitch();
      final prefs = await AppPrefs.instance;
      await prefs.remove(lastSyncKey);
    }

    await _storeToken(token);

    final prefs = await AppPrefs.instance;
    await prefs.setString(accountEmailKey, email);
    await prefs.setString(dataOwnerKey, email);
    await prefs.setBool(BackupService.authChoiceKey, true);
    await prefs.setString('user_email', email);
    await prefs.remove(legacyPasswordKey);
    await prefs.remove(tokenKey);

    if (adopting) {
      await ProfileSync.adoptAccount(profile);
    } else {
      await ProfileSync.fillMissing(profile);
    }
  }

  /// Email a reset code. The server answers the same for unknown emails.
  Future<AuthResult> requestPasswordReset(String email) async {
    final address = email.trim().toLowerCase();
    if (!_looksLikeEmail(address)) {
      return const AuthResult.failure('أدخل بريداً إلكترونياً صالحاً');
    }
    final status = await _postJson('/auth/password/forgot', {'email': address});
    if (status == 200) return const AuthResult.success();
    if (status == 429) return const AuthResult.failure(tooManyAttemptsMessage);
    if (status == 503) {
      return const AuthResult.failure('تعذّر إرسال البريد الآن. حاول لاحقاً');
    }
    if (status == null) {
      return const AuthResult.failure(
        'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى',
      );
    }
    return const AuthResult.failure('أدخل بريداً إلكترونياً صالحاً');
  }

  /// Set a new password with the emailed code. The old data key cannot be
  /// opened without the old password, so the next sign-in makes a new one.
  Future<AuthResult> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final status = await _postJson('/auth/password/reset', {
      'email': email.trim().toLowerCase(),
      'code': code.trim(),
      'new_password': newPassword,
    });
    if (status == 200) {
      // Sign-in after this must push everything again under the new key.
      await clearSession();
      return const AuthResult.success();
    }
    if (status == 429) return const AuthResult.failure(tooManyAttemptsMessage);
    if (status == null) {
      return const AuthResult.failure(
        'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى',
      );
    }
    return const AuthResult.failure('الرمز غير صحيح أو انتهت صلاحيته');
  }

  /// Re-wrap the same data key with the new password, so nothing is lost.
  Future<AuthResult> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    // The change needs a live session and the current account.
    final token = await ensureToken();
    if (token == null) {
      return const AuthResult.failure('انتهت الجلسة. سجّل الدخول مجدداً');
    }
    final me = await _fetchMe(token);
    if (me == null) {
      return const AuthResult.failure(
        'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى',
      );
    }

    // Open the data key with the old password and wrap it with the new one.
    List<int>? key;
    WrappedDataKey? rewrapped;
    final wrapped = WrappedDataKey.fromJson(me['data_key']);
    if (wrapped != null) {
      key = await DataKeyStore.unwrap(currentPassword, wrapped);
      if (key == null) {
        return const AuthResult.failure('كلمة المرور الحالية غير صحيحة');
      }
      rewrapped = await DataKeyStore.wrap(key, newPassword);
    }

    try {
      // Send both passwords and the re-wrapped key in one request.
      final base = await ApiConfig.baseUrl();
      final response = await http
          .post(
            Uri.parse('$base/auth/password/change'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'current_password': currentPassword,
              'new_password': newPassword,
              'data_key': rewrapped?.toJson(),
            }),
          )
          .timeout(ApiConfig.timeoutFor(base, local: _timeout));
      if (response.statusCode == 400) {
        return const AuthResult.failure('كلمة المرور الحالية غير صحيحة');
      }
      if (response.statusCode == 429) {
        return const AuthResult.failure(tooManyAttemptsMessage);
      }
      if (response.statusCode != 200) {
        return const AuthResult.failure('تعذّر تغيير كلمة المرور. حاول لاحقاً');
      }
      final decoded = jsonDecode(response.body);
      final access = decoded is Map
          ? decoded['access_token']?.toString() ?? ''
          : '';
      if (access.isEmpty) {
        return const AuthResult.failure('تعذّر الاتصال بالخادم. حاول مرة أخرى');
      }
      // Other devices are signed out; this one keeps going on the new token.
      await _storeToken(access);
      if (key != null) await DataKeyStore.instance.save(key);
      return const AuthResult.success();
    } catch (_) {
      return const AuthResult.failure(
        'لا يوجد اتصال. تحقق من الشبكة وحاول مرة أخرى',
      );
    }
  }

  /// POST JSON without a token. Returns the status, or null when offline.
  Future<int?> _postJson(String path, Map<String, dynamic> body) async {
    try {
      final base = await ApiConfig.baseUrl();
      final response = await http
          .post(
            Uri.parse('$base$path'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeoutFor(base, local: _timeout));
      return response.statusCode;
    } catch (_) {
      return null;
    }
  }

  /// Delete the account and all its synced data on the server. Local data
  /// is left for the caller to clear.
  Future<AuthResult> deleteRemoteAccount() async {
    final token = await ensureToken();
    if (token == null) {
      return const AuthResult.failure(
        'انتهت الجلسة. سجّل الدخول مجدداً ثم احذف الحساب',
      );
    }
    try {
      final base = await ApiConfig.baseUrl();
      final response = await http
          .delete(
            Uri.parse('$base/auth/account'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(ApiConfig.timeoutFor(base, local: _timeout));
      if (response.statusCode != 204 && response.statusCode != 401) {
        return const AuthResult.failure(
          'تعذّر حذف الحساب من الخادم. حاول لاحقاً',
        );
      }
      return const AuthResult.success();
    } catch (_) {
      return const AuthResult.failure(
        'لا يوجد اتصال. حذف الحساب يحتاج إلى الإنترنت',
      );
    }
  }

  // Open the account's data key with the password, or create and upload one
  // on first sign-in. Returns the key and the latest /auth/me payload.
  Future<({List<int> key, Map<String, dynamic> me})?> _unlockDataKey(
    String token,
    String password,
    Map<String, dynamic> me,
  ) async {
    var wrapped = WrappedDataKey.fromJson(me['data_key']);
    if (wrapped == null) {
      final created = await DataKeyStore.create(password);
      final status = await _uploadDataKey(token, created.wrapped);
      if (status == 200) return (key: created.key, me: me);
      if (status != 409) return null;
      // Another device set the key first; use that one.
      final latest = await _fetchMe(token);
      if (latest == null) return null;
      me = latest;
      wrapped = WrappedDataKey.fromJson(me['data_key']);
      if (wrapped == null) return null;
    }
    final key = await DataKeyStore.unwrap(password, wrapped);
    return key == null ? null : (key: key, me: me);
  }

  Future<int?> _uploadDataKey(String token, WrappedDataKey wrapped) async {
    try {
      final base = await ApiConfig.baseUrl();
      final response = await http
          .put(
            Uri.parse('$base/auth/key'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(wrapped.toJson()),
          )
          .timeout(ApiConfig.timeoutFor(base, local: _timeout));
      return response.statusCode;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _mergedProfile(
    Map<String, dynamic>? me,
    Map<String, dynamic> body,
  ) {
    const fields = [
      'name',
      'gender',
      'birthdate',
      'country',
      'city',
      'street',
      'phone',
    ];
    final profile = <String, dynamic>{};
    for (final field in fields) {
      if (me != null && me.containsKey(field)) {
        profile[field] = me[field];
      } else if (body.containsKey(field)) {
        profile[field] = body[field];
      }
    }
    return profile;
  }

  Future<void> _storeToken(String value) async {
    await _secure.write(key: tokenKey, value: value);
  }

  // Move an old prefs-stored JWT into secure storage once.
  Future<void> _migrateLegacyToken() async {
    final prefs = await AppPrefs.instance;
    final legacy = prefs.getString(tokenKey)?.trim() ?? '';
    if (legacy.isEmpty) return;
    final current = (await _secure.read(key: tokenKey))?.trim() ?? '';
    if (current.isEmpty) {
      await _secure.write(key: tokenKey, value: legacy);
    }
    await prefs.remove(tokenKey);
    await prefs.remove(legacyPasswordKey);
  }

  // Validate the token with GET /auth/me and return the profile payload.
  Future<Map<String, dynamic>?> _fetchMe(String token) async {
    return (await _getMe(token)).me;
  }

  /// GET /auth/me. status is null when the request never got an answer.
  Future<({int? status, Map<String, dynamic>? me})> _getMe(String token) async {
    try {
      final base = await ApiConfig.baseUrl();
      final response = await http
          .get(
            Uri.parse('$base/auth/me'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(ApiConfig.timeoutFor(base, local: _timeout));
      final status = response.statusCode;
      if (status != 200) return (status: status, me: null);
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return (status: status, me: null);
      return (status: status, me: Map<String, dynamic>.from(decoded));
    } catch (_) {
      return (status: null, me: null);
    }
  }

  static bool _looksLikeEmail(String value) {
    final trimmed = value.trim();
    return trimmed.contains('@') && trimmed.contains('.');
  }
}
