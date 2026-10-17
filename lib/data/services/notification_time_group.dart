// Groups the notification list into today, yesterday, this week, and one
// section per earlier month.

import 'package:waffr/data/models/app_notification.dart';
import 'package:waffr/data/models/calendar_period.dart';

/// Groups notifications into today / yesterday / this week / month buckets.
class NotificationTimeGroup {
  /// Section title ("اليوم", a month name...).
  final String label;

  /// The section's notifications, newest first.
  final List<AppNotification> items;

  /// A section.
  const NotificationTimeGroup({required this.label, required this.items});

  /// Buckets by calendar day relative to [now] (Arabic section labels).
  static List<NotificationTimeGroup> from(
    List<AppNotification> notifications, {
    DateTime? now,
  }) {
    if (notifications.isEmpty) return const [];

    final moment = now ?? DateTime.now();
    final today = DateTime(moment.year, moment.month, moment.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = CalendarPeriod.weekStart(today);

    final todayItems = <AppNotification>[];
    final yesterdayItems = <AppNotification>[];
    final weekItems = <AppNotification>[];
    final older = <String, List<AppNotification>>{};

    for (final item in notifications) {
      final day = DateTime(
        item.createdAt.year,
        item.createdAt.month,
        item.createdAt.day,
      );

      if (day == today) {
        todayItems.add(item);
      } else if (day == yesterday) {
        yesterdayItems.add(item);
      } else if (!day.isBefore(weekStart) && day.isBefore(yesterday)) {
        weekItems.add(item);
      } else {
        final key = '${day.year}-${day.month.toString().padLeft(2, '0')}';
        older.putIfAbsent(key, () => []).add(item);
      }
    }

    final groups = <NotificationTimeGroup>[];
    if (todayItems.isNotEmpty) {
      groups.add(NotificationTimeGroup(label: 'اليوم', items: todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      groups.add(NotificationTimeGroup(label: 'أمس', items: yesterdayItems));
    }
    if (weekItems.isNotEmpty) {
      groups.add(NotificationTimeGroup(label: 'هذا الأسبوع', items: weekItems));
    }

    final monthKeys = older.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final key in monthKeys) {
      final parts = key.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final label = year == today.year
          ? CalendarPeriod.monthName(month)
          : '${CalendarPeriod.monthName(month)} $year';
      groups.add(NotificationTimeGroup(label: label, items: older[key]!));
    }

    return groups;
  }
}
