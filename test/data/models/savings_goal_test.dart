// SavingsGoal: prefs round trip and validation, duration presets and cycle
// counts, cyclesFor, copyWith touch rules and the decode defaults.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/savings_goal.dart';
import 'package:waffr/data/models/transaction.dart';

void main() {
  SavingsGoal goal({int? durationCount, DateTime? updatedAt}) => SavingsGoal(
    id: 'g1',
    name: 'سفر',
    targetAmount: 1200,
    currencyCode: 'EUR',
    createdAt: DateTime(2026, 1, 1, 8),
    duration: GoalDurationPreset.sixMonths,
    completedAt: DateTime(2026, 6, 1),
    completedAmount: 1250,
    allocatePercent: 10,
    allocateAmount: 200,
    deductFrequency: RecurringFrequency.weekly,
    isPeriodic: true,
    durationCount: durationCount,
    priority: 2,
    updatedAt: updatedAt,
  );

  test('encode / decode keeps every field', () {
    final decoded = SavingsGoal.decode(
      goal(durationCount: 26, updatedAt: DateTime.utc(2026, 6, 2)).encode(),
    )!;
    expect(decoded.id, 'g1');
    expect(decoded.name, 'سفر');
    expect(decoded.targetAmount, 1200);
    expect(decoded.currencyCode, 'EUR');
    expect(decoded.createdAt, DateTime(2026, 1, 1, 8));
    expect(decoded.duration, GoalDurationPreset.sixMonths);
    expect(decoded.completedAt, DateTime(2026, 6, 1));
    expect(decoded.completedAmount, 1250);
    expect(decoded.allocatePercent, 10);
    expect(decoded.allocateAmount, 200);
    expect(decoded.deductFrequency, RecurringFrequency.weekly);
    expect(decoded.isPeriodic, isTrue);
    expect(decoded.durationCount, 26);
    expect(decoded.priority, 2);
    expect(decoded.isCompleted, isTrue);
    expect(decoded.updatedAt, DateTime.utc(2026, 6, 2));
  });

  test('decode rejects missing name or non-positive target', () {
    expect(
      SavingsGoal.decode(jsonEncode({'name': 'x', 'targetAmount': 0})),
      isNull,
    );
    expect(
      SavingsGoal.decode(jsonEncode({'name': ' ', 'targetAmount': 5})),
      isNull,
    );
    expect(SavingsGoal.decode('[]'), isNull);
    expect(SavingsGoal.decode('{'), isNull);
  });

  test('decode defaults', () {
    final plain = SavingsGoal.decode(
      jsonEncode({'name': 'x', 'targetAmount': 5, 'duration': 'decade'}),
    )!;
    expect(plain.id, startsWith('g'));
    expect(plain.duration, GoalDurationPreset.month);
    expect(plain.currencyCode, 'SYP');
    expect(plain.priority, 0);
    expect(plain.isCompleted, isFalse);
    expect(
      plain.deductFrequency,
      RecurringFrequency.none,
      reason: 'a stored non-periodic goal without a cadence reads as none',
    );

    final periodic = SavingsGoal.decode(
      jsonEncode({'name': 'x', 'targetAmount': 5, 'isPeriodic': true}),
    )!;
    expect(periodic.deductFrequency, RecurringFrequency.monthly);
  });

  test('a goal built in code defaults to a monthly cadence', () {
    final fresh = SavingsGoal(
      id: 'a',
      name: 'b',
      targetAmount: 1,
      createdAt: DateTime(2026),
      duration: GoalDurationPreset.month,
    );
    expect(fresh.deductFrequency, RecurringFrequency.monthly);
    expect(fresh.syncUpdatedAt, DateTime(2026).toUtc());
  });

  test('cyclesFor prefers an explicit positive count', () {
    expect(goal(durationCount: 9).cyclesFor(RecurringFrequency.monthly), 9);
    expect(goal(durationCount: 0).cyclesFor(RecurringFrequency.monthly), 6);
    expect(goal().cyclesFor(RecurringFrequency.weekly), 26);
  });

  test('cycle counts per preset and cadence', () {
    const monthly = {
      GoalDurationPreset.week: 1,
      GoalDurationPreset.month: 1,
      GoalDurationPreset.threeMonths: 3,
      GoalDurationPreset.sixMonths: 6,
      GoalDurationPreset.year: 12,
    };
    const weekly = {
      GoalDurationPreset.week: 1,
      GoalDurationPreset.month: 4,
      GoalDurationPreset.threeMonths: 13,
      GoalDurationPreset.sixMonths: 26,
      GoalDurationPreset.year: 52,
    };
    monthly.forEach((preset, count) {
      expect(preset.cycleCount(RecurringFrequency.monthly), count);
      expect(preset.cycleCount(RecurringFrequency.none), count);
    });
    weekly.forEach((preset, count) {
      expect(preset.cycleCount(RecurringFrequency.weekly), count);
    });
  });

  test('fromCount maps a cycle count back to the nearest preset', () {
    expect(GoalDurationPresetLabel.fromCount(1), GoalDurationPreset.month);
    expect(
      GoalDurationPresetLabel.fromCount(3),
      GoalDurationPreset.threeMonths,
    );
    expect(GoalDurationPresetLabel.fromCount(5), GoalDurationPreset.sixMonths);
    expect(GoalDurationPresetLabel.fromCount(7), GoalDurationPreset.year);

    GoalDurationPreset weekly(int count) => GoalDurationPresetLabel.fromCount(
      count,
      frequency: RecurringFrequency.weekly,
    );
    expect(weekly(1), GoalDurationPreset.week);
    expect(weekly(4), GoalDurationPreset.month);
    expect(weekly(13), GoalDurationPreset.threeMonths);
    expect(weekly(26), GoalDurationPreset.sixMonths);
    expect(weekly(52), GoalDurationPreset.year);
  });

  test('labels', () {
    expect(GoalDurationPreset.week.label, 'أسبوع');
    expect(GoalDurationPreset.year.label, 'سنة');
  });

  test('copyWith keeps fields and only touches when asked', () {
    final original = goal(updatedAt: DateTime.utc(2020));
    final reordered = original.copyWith(priority: 7);
    expect(reordered.priority, 7);
    expect(reordered.name, 'سفر');
    expect(reordered.updatedAt, DateTime.utc(2020), reason: 'no touch');

    final before = DateTime.now().toUtc();
    final touched = original.copyWith(allocateAmount: 5, touch: true);
    expect(touched.allocateAmount, 5);
    expect(touched.updatedAt!.isBefore(before), isFalse);
  });

  test('ids made back to back never collide', () {
    final ids = {for (var i = 0; i < 1000; i++) SavingsGoal.newId()};
    expect(ids, hasLength(1000));
  });
}
