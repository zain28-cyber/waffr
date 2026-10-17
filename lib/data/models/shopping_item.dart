// One shopping-list item as stored in prefs and synced to the server.

import 'dart:convert';

import 'package:waffr/core/sync/sync_clock.dart';
import 'package:waffr/core/sync/sync_mapper.dart';

/// One list row; [expenseId] links a purchased item to its ledger expense.
class ShoppingItem {
  /// Local id (also the sync client id).
  final String id;

  /// What to buy.
  final String name;

  /// When it was added; newest first.
  final DateTime createdAt;

  /// True once bought.
  final bool isPurchased;

  /// When it was bought.
  final DateTime? purchasedAt;

  /// The expense recorded for the purchase.
  final String? expenseId;

  /// Last change (UTC), for sync.
  final DateTime? updatedAt;

  /// A list item.
  const ShoppingItem({
    required this.id,
    required this.name,
    required this.createdAt,
    this.isPurchased = false,
    this.purchasedAt,
    this.expenseId,
    this.updatedAt,
  });

  /// Last change for sync, falling back to creation time.
  DateTime get syncUpdatedAt => (updatedAt ?? createdAt).toUtc();

  /// A copy with fields replaced; [clearPurchase] undoes a purchase and
  /// [touch] stamps [updatedAt] now.
  ShoppingItem copyWith({
    String? name,
    bool? isPurchased,
    DateTime? purchasedAt,
    String? expenseId,
    DateTime? updatedAt,
    bool clearPurchase = false,
    bool touch = true,
  }) {
    return ShoppingItem(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      isPurchased: clearPurchase ? false : (isPurchased ?? this.isPurchased),
      purchasedAt: clearPurchase ? null : (purchasedAt ?? this.purchasedAt),
      expenseId: clearPurchase ? null : (expenseId ?? this.expenseId),
      updatedAt: updatedAt ?? (touch ? DateTime.now().toUtc() : this.updatedAt),
    );
  }

  /// The /sync `shopping_items` row (always in the default list).
  Map<String, dynamic> toSyncJson() => {
    'client_id': id,
    'list_client_id': defaultShoppingListId,
    'name': name,
    'quantity': 1,
    'price': null,
    'is_purchased': isPurchased,
    'purchased_at': purchasedAt == null ? null : toSyncIso(purchasedAt),
    'expense_client_id': expenseId,
    'created_at': toSyncIso(createdAt),
    'updated_at': toSyncIso(syncUpdatedAt),
  };

  /// Reads a /sync row; null without id, name or creation time.
  static ShoppingItem? fromSync(Map<String, dynamic> raw) {
    final id = raw['client_id']?.toString().trim() ?? '';
    final name = raw['name']?.toString().trim() ?? '';
    final createdAt = parseEventLocal(raw['created_at'] ?? raw['createdAt']);
    if (id.isEmpty || name.isEmpty || createdAt == null) return null;
    return ShoppingItem(
      id: id,
      name: name,
      createdAt: createdAt,
      isPurchased: raw['is_purchased'] == true || raw['isPurchased'] == true,
      purchasedAt: parseEventLocal(raw['purchased_at'] ?? raw['purchasedAt']),
      expenseId: (raw['expense_client_id'] ?? raw['expenseId'])?.toString(),
      updatedAt: parseSyncDate(raw['updated_at'] ?? raw['updatedAt']),
    );
  }

  /// The prefs JSON string.
  String encode() => jsonEncode(<String, dynamic>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'isPurchased': isPurchased,
    'purchasedAt': purchasedAt?.toIso8601String(),
    'expenseId': expenseId,
    'updatedAt': syncUpdatedAt.toIso8601String(),
  });

  /// Reads a prefs JSON string; null when invalid.
  static ShoppingItem? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;

      final id = decoded['id']?.toString().trim() ?? '';
      final name = decoded['name']?.toString().trim() ?? '';
      final createdAt = DateTime.tryParse(
        decoded['createdAt']?.toString() ?? '',
      );

      if (id.isEmpty || name.isEmpty || createdAt == null) {
        return null;
      }

      return ShoppingItem(
        id: id,
        name: name,
        createdAt: createdAt.toLocal(),
        isPurchased: decoded['isPurchased'] == true,
        purchasedAt: DateTime.tryParse(decoded['purchasedAt']?.toString() ?? '')
            ?.toLocal(),
        expenseId: decoded['expenseId']?.toString(),
        updatedAt: DateTime.tryParse(decoded['updatedAt']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    }
  }
}
