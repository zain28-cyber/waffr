// AppNotification: prefs JSON round trip, decode validation and defaults,
// copyWith read/touch rules, priorities per type and the shared thresholds.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/app_notification.dart';

void main() {
  AppNotification note({
    NotificationType type = NotificationType.goalReached,
    DateTime? updatedAt,
  }) => AppNotification(
    id: 'n1',
    type: type,
    title: 'عنوان',
    message: 'نص',
    createdAt: DateTime(2026, 5, 1, 9),
    eventKey: 'goalReached:g1',
    relatedId: 'g1',
    metadata: const {'goalName': 'سفر', 'percent': '100'},
    updatedAt: updatedAt,
  );

  test('encode / decode keeps every field', () {
    final decoded = AppNotification.decode(
      note(updatedAt: DateTime.utc(2026, 5, 2)).encode(),
    )!;
    expect(decoded.id, 'n1');
    expect(decoded.type, NotificationType.goalReached);
    expect(decoded.title, 'عنوان');
    expect(decoded.message, 'نص');
    expect(decoded.createdAt, DateTime(2026, 5, 1, 9));
    expect(decoded.eventKey, 'goalReached:g1');
    expect(decoded.relatedId, 'g1');
    expect(decoded.metadata, {'goalName': 'سفر', 'percent': '100'});
    expect(decoded.isRead, isFalse);
    expect(decoded.updatedAt, DateTime.utc(2026, 5, 2));
  });

  test('decode needs a title and an event key', () {
    expect(
      AppNotification.decode(jsonEncode({'title': ' ', 'eventKey': 'k'})),
      isNull,
    );
    expect(
      AppNotification.decode(jsonEncode({'title': 't', 'eventKey': ''})),
      isNull,
    );
    expect(AppNotification.decode('[]'), isNull);
    expect(AppNotification.decode('{'), isNull);
  });

  test('decode fills defaults and stringifies metadata', () {
    final decoded = AppNotification.decode(
      jsonEncode({
        'title': ' t ',
        'eventKey': 'k',
        'type': 'unknown',
        'isRead': 'yes',
        'relatedId': '  ',
        'metadata': {'a': 1, 'b': null, 'c': true},
      }),
    )!;
    expect(decoded.id, startsWith('n'));
    expect(decoded.title, 't');
    expect(decoded.message, '');
    expect(decoded.type, NotificationType.recurringPeriodCompleted);
    expect(decoded.isRead, isFalse, reason: 'only a real true counts');
    expect(decoded.relatedId, isNull);
    expect(decoded.metadata, {'a': '1', 'c': 'true'});
  });

  test('every type name survives a round trip', () {
    for (final type in NotificationType.values) {
      final decoded = AppNotification.decode(note(type: type).encode())!;
      expect(decoded.type, type);
    }
  });

  test('copyWith changes read state and stamps updatedAt by default', () {
    final original = note(updatedAt: DateTime.utc(2020));
    final before = DateTime.now().toUtc();

    final read = original.copyWith(isRead: true);
    expect(read.isRead, isTrue);
    expect(read.updatedAt!.isBefore(before), isFalse);
    expect(read.metadata, original.metadata);

    final quiet = original.copyWith(isRead: true, touch: false);
    expect(quiet.updatedAt, DateTime.utc(2020));

    final explicit = original.copyWith(updatedAt: DateTime.utc(2030));
    expect(explicit.updatedAt, DateTime.utc(2030));
    expect(explicit.isRead, isFalse);
  });

  test('syncUpdatedAt falls back to the creation time', () {
    expect(note().syncUpdatedAt, DateTime(2026, 5, 1, 9).toUtc());
    expect(
      note(updatedAt: DateTime.utc(2027)).syncUpdatedAt,
      DateTime.utc(2027),
    );
  });

  test('priority per type', () {
    const expected = {
      NotificationType.balanceWarning: NotificationPriority.warning,
      NotificationType.highSpending: NotificationPriority.important,
      NotificationType.largeExpense: NotificationPriority.important,
      NotificationType.goalReached: NotificationPriority.success,
      NotificationType.goalProgress: NotificationPriority.success,
      NotificationType.savingsTransferred: NotificationPriority.savings,
      NotificationType.recurringPeriodCompleted: NotificationPriority.info,
      NotificationType.recurringExpenseBlocked: NotificationPriority.warning,
      NotificationType.recurringExpenseApplied: NotificationPriority.info,
      NotificationType.recurringExpenseUpcoming: NotificationPriority.warning,
      NotificationType.recurringExpenseDue: NotificationPriority.important,
    };
    expect(expected.keys.toSet(), NotificationType.values.toSet());
    expected.forEach((type, priority) {
      expect(note(type: type).priority, priority, reason: type.name);
    });
  });

  test('thresholds do not overlap between spending and balance alerts', () {
    expect(NotificationThresholds.remainingPercents, [25, 10]);
    expect(NotificationThresholds.spendingPercents, [50]);
    expect(NotificationThresholds.goalPercents, [50, 75]);
    for (final spent in NotificationThresholds.spendingPercents) {
      for (final left in NotificationThresholds.remainingPercents) {
        expect(100 - spent, isNot(left));
      }
    }
  });

  test('new ids are unique and prefixed', () {
    final ids = {for (var i = 0; i < 20; i++) AppNotification.newId()};
    expect(ids, hasLength(20));
    expect(ids.every((id) => id.startsWith('n')), isTrue);
  });
}
