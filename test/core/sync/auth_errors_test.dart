// describeAuthError: Arabic messages for FastAPI /auth failures by status
// code and `detail` shape.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/core/sync/auth_errors.dart';

void main() {
  test('maps register and login API errors to Arabic copy', () {
    expect(
      describeAuthError(401, {'detail': 'Invalid email or password'}),
      'البريد أو كلمة المرور غير صحيحة',
    );
    expect(
      describeAuthError(400, {'detail': 'Email already registered'}),
      'هذا البريد مسجّل مسبقاً',
    );
    expect(
      describeAuthError(422, {
        'detail': [
          {'msg': 'value is not a valid email address'},
        ],
      }),
      'أدخل بريداً إلكترونياً صالحاً',
    );
    expect(
      describeAuthError(429, {'detail': 'Too many requests'}),
      tooManyAttemptsMessage,
    );
  });

  test('400 details: duplicate, email problems, others passed through', () {
    expect(
      describeAuthError(400, {'detail': 'invalid email'}),
      'أدخل بريداً إلكترونياً صالحاً',
    );
    expect(
      describeAuthError(400, {'detail': 'Weak password'}),
      'Weak password',
    );
    expect(describeAuthError(400, null), 'تعذّر إنشاء الحساب');
    expect(
      describeAuthError(400, {
        'detail': [
          {'msg': 'value is not a valid email address'},
        ],
      }),
      'أدخل بريداً إلكترونياً صالحاً',
    );
    expect(
      describeAuthError(400, {
        'detail': ['Email already registered'],
      }),
      'هذا البريد مسجّل مسبقاً',
      reason: 'a list entry without msg is stringified',
    );
  });

  test('401, 422 and 429 ignore the body', () {
    expect(describeAuthError(401, 'junk'), 'البريد أو كلمة المرور غير صحيحة');
    expect(describeAuthError(422, null), 'أدخل بريداً إلكترونياً صالحاً');
    expect(describeAuthError(429, null), tooManyAttemptsMessage);
  });

  test('anything else is a connection message', () {
    expect(
      describeAuthError(500, {'detail': 'boom'}),
      'تعذّر الاتصال بالحساب. حاول مرة أخرى',
    );
    expect(describeAuthError(0, null), 'تعذّر الاتصال بالحساب. حاول مرة أخرى');
    expect(
      describeAuthError(400, {'detail': <Object>[]}),
      'تعذّر إنشاء الحساب',
    );
  });
}
