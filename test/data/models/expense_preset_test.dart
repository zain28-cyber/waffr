// ExpensePreset model: prefs and /sync round trips, validation and clamping
// in the shared reader, total, and duplicate detection (sameDetailsAs).

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/expense_preset.dart';
import 'package:waffr/data/models/recurring_expense.dart';

ExpensePreset _preset({
  String id = 'p1',
  double amount = 100,
  int multiplier = 1,
  bool recurring = false,
  RecurringUnit unit = RecurringUnit.month,
  int intervalCount = 1,
  String? note,
}) => ExpensePreset(
  id: id,
  amount: amount,
  multiplier: multiplier,
  category: 'طعام',
  paymentMethod: 'نقداً',
  note: note,
  recurring: recurring,
  unit: unit,
  intervalCount: intervalCount,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  test('total multiplies the typed amount', () {
    expect(_preset(amount: 250, multiplier: 4).total, 1000);
  });

  test('sync JSON uses snake case and string amounts', () {
    final json = _preset(amount: 12.5).toSyncJson();
    expect(json['client_id'], 'p1');
    expect(json['amount'], '12.5');
    expect(json['currency_code'], 'SYP');
    expect(json['payment_method'], 'نقداً');
    expect(json['interval_count'], 1);
    expect(json['created_at'], DateTime(2026, 1, 1).toUtc().toIso8601String());
  });

  test('readers reject missing id, category or positive amount', () {
    expect(ExpensePreset.fromSync({'client_id': 'x', 'amount': '5'}), isNull);
    expect(ExpensePreset.fromSync({'category': 'طعام', 'amount': '5'}), isNull);
    expect(
      ExpensePreset.fromSync({
        'client_id': 'x',
        'category': 'طعام',
        'amount': 'abc',
      }),
      isNull,
    );
    expect(ExpensePreset.decode('[]'), isNull);
    expect(ExpensePreset.decode('nope'), isNull);
  });

  test('multiplier and interval are clamped; unknown units are months', () {
    final preset = ExpensePreset.fromSync({
      'client_id': 'x',
      'category': 'طعام',
      'amount': 3,
      'multiplier': 50,
      'interval_count': '0',
      'unit': 'year',
      'note': '  ',
      'recurring': 'true',
    })!;
    expect(preset.multiplier, 10);
    expect(preset.intervalCount, 1);
    expect(preset.unit, RecurringUnit.month);
    expect(preset.note, isNull);
    expect(preset.recurring, isFalse, reason: 'only a real true counts');
    expect(preset.paymentMethod, '');
    expect(preset.updatedAt, isNull);
  });

  test('camel case keys are accepted by the sync reader', () {
    final preset = ExpensePreset.fromSync({
      'id': 'x',
      'category': 'طعام',
      'amount': 3,
      'currencyCode': 'usd',
      'paymentMethod': 'بطاقة',
      'intervalCount': 3,
      'unit': 'day',
      'recurring': true,
    })!;
    expect(preset.currencyCode, 'USD');
    expect(preset.paymentMethod, 'بطاقة');
    expect(preset.intervalCount, 3);
    expect(preset.unit, RecurringUnit.day);
  });

  test(
    'sameDetailsAs ignores ids and only compares the schedule when recurring',
    () {
      expect(_preset().sameDetailsAs(_preset(id: 'other')), isTrue);
      expect(_preset().sameDetailsAs(_preset(amount: 101)), isFalse);
      expect(_preset().sameDetailsAs(_preset(multiplier: 2)), isFalse);
      expect(
        _preset(note: '').sameDetailsAs(_preset()),
        isTrue,
        reason: 'empty and missing notes are the same',
      );
      expect(
        _preset(unit: RecurringUnit.day).sameDetailsAs(_preset()),
        isTrue,
        reason: 'the unit does not matter for a one-off preset',
      );
      expect(
        _preset(
          recurring: true,
          unit: RecurringUnit.day,
        ).sameDetailsAs(_preset(recurring: true)),
        isFalse,
      );
      expect(_preset(recurring: true).sameDetailsAs(_preset()), isFalse);
    },
  );

  test('syncUpdatedAt falls back to creation time', () {
    expect(_preset().syncUpdatedAt, DateTime(2026, 1, 1).toUtc());
  });

  test('new ids are unique', () {
    expect({for (var i = 0; i < 10; i++) ExpensePreset.newId()}, hasLength(10));
  });
}
