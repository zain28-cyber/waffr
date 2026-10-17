// Expense history PDF: the background-built document has day tables and
// totals.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:waffr/data/models/transaction.dart';
import 'package:waffr/screens/offline/report/expense_history_share.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a non-empty Arabic PDF with day tables and totals', () async {
    final bytes = await buildExpenseHistoryPdfBytes([
      WaffrTransaction(
        id: 'e1',
        type: TransactionType.expense,
        amount: 1500,
        category: 'طعام',
        paymentMethod: 'نقداً',
        note: 'غداء مع العائلة',
        dateTime: DateTime(2026, 9, 30, 14, 5),
      ),
      WaffrTransaction(
        id: 'e2',
        type: TransactionType.expense,
        amount: 40000,
        category: 'فواتير',
        paymentMethod: 'نقداً',
        sourceId: 'recurring:r1_0:202609300900',
        dateTime: DateTime(2026, 9, 30, 9),
      ),
      WaffrTransaction(
        id: 'e3',
        type: TransactionType.expense,
        amount: 20,
        currencyCode: 'USD',
        category: 'صحة',
        dateTime: DateTime(2026, 9, 28, 18, 30),
      ),
    ]);

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    final file = File('${Directory.systemTemp.path}/waffr-expenses-test.pdf');
    await file.writeAsBytes(bytes, flush: true);
    expect(await file.exists(), isTrue);
    expect(await file.length(), bytes.length);
    addTearDown(() => file.delete());
  });
}
