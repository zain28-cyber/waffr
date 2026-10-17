// Money and date/time formatting helpers for the financial UI.

import 'package:intl/intl.dart';
import 'package:waffr/data/stores/currency_store.dart';

/// Fixed Syrian pound label used where rates are shown online.
const String sypCurrencyLabel = 'ل.س';

/// Symbol for the currently active currency in the UI.
String get currencyLabel => CurrencyStore.instance.activeSymbol;

/// Symbol of the currency [code] (SYP when null).
String currencyLabelFor(String? code) => Currencies.symbolOf(code);

final NumberFormat _moneyFormat = NumberFormat('#,##0', 'en');

/// A whole amount with thousands separators and 0-9 digits ("1,500").
String formatMoney(num value) => _moneyFormat.format(value.round());

/// Manual DD/MM/YYYY with Latin digits so DateFormat locale data is not required.
String formatDate(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year}';
}

/// "HH:mm" in the device zone.
String formatTime(DateTime date) {
  final local = date.toLocal();
  return '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
