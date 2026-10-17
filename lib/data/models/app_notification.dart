// In-app notification model, types, priorities, and prefs serialization.

import 'dart:convert';

/// What happened that produced the notification.
enum NotificationType {
  /// The balance fell below a remaining-percent threshold.
  balanceWarning,

  /// Spending in the cycle passed a percent of the cycle's budget.
  highSpending,

  /// A savings goal was completed.
  goalReached,

  /// A goal passed a progress threshold (50%, 75%).
  goalProgress,

  /// Money was moved to savings automatically.
  savingsTransferred,

  /// A weekly or monthly income period ended.
  recurringPeriodCompleted,

  /// One expense was much larger than usual.
  largeExpense,

  /// A recurring bill could not be charged (low balance).
  recurringExpenseBlocked,

  /// A recurring bill was charged.
  recurringExpenseApplied,

  /// A bill due soon is larger than the balance.
  recurringExpenseUpcoming,

  /// A bill waits for the user to approve it.
  recurringExpenseDue,
}

/// Light visual weight for list styling (no extra theme colors).
enum NotificationPriority {
  /// Needs attention.
  warning,

  /// Worth reading soon.
  important,

  /// Good news.
  success,

  /// About savings.
  savings,

  /// Plain information.
  info,
}

/// Shared percent / size cutoffs for generators across the app. Spending and
/// remaining-balance cutoffs do not overlap, so one drop never sends two alerts.
class NotificationThresholds {
  /// Balance-left levels (percent of the cycle) that warn once each.
  static const List<int> remainingPercents = [25, 10];

  /// Spent levels (percent of the cycle) that warn once each.
  static const List<int> spendingPercents = [50];

  /// Goal progress levels that celebrate once each.
  static const List<int> goalPercents = [50, 75];

  /// An expense this many times the average counts as large.
  static const double largeExpenseMultiplier = 2.0;

  /// Expenses needed before "large" can be judged.
  static const int minExpensesForLarge = 4;
}

/// One notification as stored in SharedPreferences.
class AppNotification {
  /// Local id (also the sync client id).
  final String id;

  /// What happened.
  final NotificationType type;

  /// Bold first line.
  final String title;

  /// Body text.
  final String message;

  /// When it was written.
  final DateTime createdAt;

  /// False until opened or marked read.
  final bool isRead;

  /// Identifies the event, so it is never written twice.
  final String eventKey;

  /// Goal, bill or expense it is about, if any.
  final String? relatedId;

  /// Extra values (e.g. goal name); sealed when synced.
  final Map<String, String> metadata;

  /// Last change (UTC), for last-write-wins sync.
  final DateTime? updatedAt;

  /// A notification.
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.eventKey,
    this.isRead = false,
    this.relatedId,
    this.metadata = const {},
    this.updatedAt,
  });

  /// Last change for sync, falling back to creation time.
  DateTime get syncUpdatedAt => (updatedAt ?? createdAt).toUtc();

  /// How the list styles it.
  NotificationPriority get priority => switch (type) {
    NotificationType.balanceWarning => NotificationPriority.warning,
    NotificationType.highSpending => NotificationPriority.important,
    NotificationType.largeExpense => NotificationPriority.important,
    NotificationType.goalReached => NotificationPriority.success,
    NotificationType.goalProgress => NotificationPriority.success,
    NotificationType.savingsTransferred => NotificationPriority.savings,
    NotificationType.recurringPeriodCompleted => NotificationPriority.info,
    NotificationType.recurringExpenseBlocked => NotificationPriority.warning,
    NotificationType.recurringExpenseApplied => NotificationPriority.info,
    NotificationType.recurringExpenseUpcoming => NotificationPriority.warning,
    NotificationType.recurringExpenseDue => NotificationPriority.important,
  };

  /// A copy with read state changed; [touch] stamps [updatedAt] now.
  AppNotification copyWith({
    bool? isRead,
    DateTime? updatedAt,
    bool touch = true,
  }) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      createdAt: createdAt,
      eventKey: eventKey,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
      metadata: metadata,
      updatedAt: updatedAt ?? (touch ? DateTime.now().toUtc() : this.updatedAt),
    );
  }

  /// The prefs JSON shape.
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'isRead': isRead,
    'eventKey': eventKey,
    'relatedId': relatedId,
    'metadata': metadata,
    'updatedAt': syncUpdatedAt.toIso8601String(),
  };

  /// [toJson] as a string.
  String encode() => jsonEncode(toJson());

  /// Prefs decode; requires non-empty title and eventKey.
  static AppNotification? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final title = decoded['title']?.toString().trim() ?? '';
      final message = decoded['message']?.toString().trim() ?? '';
      final eventKey = decoded['eventKey']?.toString().trim() ?? '';
      if (title.isEmpty || eventKey.isEmpty) return null;

      final metadata = <String, String>{};
      final rawMeta = decoded['metadata'];
      if (rawMeta is Map) {
        rawMeta.forEach((key, value) {
          if (value == null) return;
          metadata[key.toString()] = value.toString();
        });
      }

      return AppNotification(
        id: decoded['id']?.toString() ?? newId(),
        type: _parseType(decoded['type']?.toString()),
        title: title,
        message: message,
        createdAt:
            (DateTime.tryParse(decoded['createdAt']?.toString() ?? '') ??
                    DateTime.now())
                .toLocal(),
        isRead: decoded['isRead'] == true,
        eventKey: eventKey,
        relatedId: _text(decoded['relatedId']),
        metadata: metadata,
        updatedAt: DateTime.tryParse(decoded['updatedAt']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  static int _seq = 0;

  /// A fresh local id.
  static String newId() =>
      'n${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  static NotificationType _parseType(String? raw) {
    return switch (raw) {
      'balanceWarning' => NotificationType.balanceWarning,
      'highSpending' => NotificationType.highSpending,
      'goalReached' => NotificationType.goalReached,
      'goalProgress' => NotificationType.goalProgress,
      'savingsTransferred' => NotificationType.savingsTransferred,
      'recurringPeriodCompleted' => NotificationType.recurringPeriodCompleted,
      'largeExpense' => NotificationType.largeExpense,
      'recurringExpenseBlocked' => NotificationType.recurringExpenseBlocked,
      'recurringExpenseApplied' => NotificationType.recurringExpenseApplied,
      'recurringExpenseUpcoming' => NotificationType.recurringExpenseUpcoming,
      'recurringExpenseDue' => NotificationType.recurringExpenseDue,
      _ => NotificationType.recurringPeriodCompleted,
    };
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
