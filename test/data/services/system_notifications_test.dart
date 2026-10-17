// SystemNotifications scheduling math (Friday summary, comeback reminder
// times) and that every call is a safe no-op without the platform plugin.

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/services/system_notifications.dart';

void main() {
  DateTime next(DateTime now) => SystemNotifications.nextFridayEvening(now);

  test('weekly summary lands on the coming Friday evening', () {
    // Tuesday 2026-10-20 -> Friday 2026-10-23 18:00.
    expect(next(DateTime(2026, 10, 20, 9)), DateTime(2026, 10, 23, 18));
  });

  test('Friday morning still gets the same evening', () {
    expect(next(DateTime(2026, 10, 23, 5)), DateTime(2026, 10, 23, 18));
  });

  test('late Friday moves to the next week', () {
    expect(next(DateTime(2026, 10, 23, 17)), DateTime(2026, 10, 30, 18));
    expect(next(DateTime(2026, 10, 23, 20)), DateTime(2026, 10, 30, 18));
  });

  test('Saturday points to the following Friday', () {
    expect(next(DateTime(2026, 10, 24, 10)), DateTime(2026, 10, 30, 18));
  });

  test('comeback reminders fire two and five days later at 20:30', () {
    final now = DateTime(2026, 12, 30, 9);
    expect(SystemNotifications.soonAt(now), DateTime(2027, 1, 1, 20, 30));
    expect(SystemNotifications.laterAt(now), DateTime(2027, 1, 4, 20, 30));
  });

  test('every call completes quietly without the plugin', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final service = SystemNotifications.instance;
    await service.present(eventKey: 'k', title: 't', body: 'b');
    await service.syncStreakReminder(enabled: true, streakCount: 3);
    await service.syncComebackReminders(enabled: true, soon: ('a', 'b'));
    await service.cancelAll();
    expect(await service.launchPayload(), isNull);
    expect(await service.requestPermission(), isFalse);
  });
}
