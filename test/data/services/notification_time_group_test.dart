// NotificationTimeGroup.from: today / yesterday / this week buckets and one
// section per earlier month, newest month first, with the year when needed.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/services/notification_time_group.dart';

AppNotification _at(DateTime when, String id) => AppNotification(
  id: id,
  type: NotificationType.goalReached,
  title: id,
  message: '',
  createdAt: when,
  eventKey: id,
);

void main() {
  // Thursday; the week started on Saturday 2026-10-17.
  final now = DateTime(2026, 10, 22, 15);

  test('an empty list has no groups', () {
    expect(NotificationTimeGroup.from(const [], now: now), isEmpty);
  });

  test('buckets by calendar day relative to now', () {
    final groups = NotificationTimeGroup.from([
      _at(DateTime(2026, 10, 22, 1), 'today'),
      _at(DateTime(2026, 10, 21, 23), 'yesterday'),
      _at(DateTime(2026, 10, 17), 'week'),
      _at(DateTime(2026, 10, 16), 'october'),
      _at(DateTime(2026, 9, 2), 'september'),
      _at(DateTime(2025, 12, 30), 'last-year'),
    ], now: now);

    expect(groups.map((g) => g.label), [
      'اليوم',
      'أمس',
      'هذا الأسبوع',
      'تشرين الأول',
      'أيلول',
      'كانون الأول 2025',
    ]);
    expect(groups.map((g) => g.items.single.id), [
      'today',
      'yesterday',
      'week',
      'october',
      'september',
      'last-year',
    ]);
  });

  test('yesterday before the week start still reads as yesterday', () {
    // Sunday: yesterday is Saturday, the first day of the week.
    final sunday = DateTime(2026, 10, 18, 9);
    final groups = NotificationTimeGroup.from([
      _at(DateTime(2026, 10, 17, 8), 'sat'),
      _at(DateTime(2026, 10, 16, 8), 'fri'),
    ], now: sunday);
    expect(groups.map((g) => g.label), ['أمس', 'تشرين الأول']);
  });

  test('items keep their order inside a group', () {
    final groups = NotificationTimeGroup.from([
      _at(DateTime(2026, 10, 22, 12), 'b'),
      _at(DateTime(2026, 10, 22, 9), 'a'),
    ], now: now);
    expect(groups.single.items.map((n) => n.id), ['b', 'a']);
  });
}
