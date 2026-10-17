// Maps FastAPI auth HTTP errors into Arabic messages for login/register UI.

/// Shown when the server refuses for a while after too many attempts (429).
const String tooManyAttemptsMessage =
    'محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى';

/// An Arabic message for a failed `/auth` call with HTTP [status] and the
/// decoded JSON [body].
String describeAuthError(int status, Object? body) {
  final detail = _authDetail(body);
  if (status == 429) {
    return tooManyAttemptsMessage;
  }
  if (status == 401) {
    return 'البريد أو كلمة المرور غير صحيحة';
  }
  if (status == 400) {
    if (detail.contains('already registered')) {
      return 'هذا البريد مسجّل مسبقاً';
    }
    if (detail.contains('value is not a valid email') ||
        detail.contains('email')) {
      return 'أدخل بريداً إلكترونياً صالحاً';
    }
    return detail.isEmpty ? 'تعذّر إنشاء الحساب' : detail;
  }
  if (status == 422) {
    return 'أدخل بريداً إلكترونياً صالحاً';
  }
  return 'تعذّر الاتصال بالحساب. حاول مرة أخرى';
}

/// Pull FastAPI's `detail` string (or first validation msg) from the JSON body.
String _authDetail(Object? body) {
  if (body is! Map) return '';
  final detail = body['detail'];
  if (detail is String) return detail;
  if (detail is List && detail.isNotEmpty) {
    final first = detail.first;
    if (first is Map && first['msg'] != null) {
      return first['msg'].toString();
    }
    return first.toString();
  }
  return '';
}
