// Turns the /sync request into the body that goes over the wire, and the
// reply back into a map, off the UI isolate.
//
// Sealing private text is pure-Dart AES-GCM, one call per field, and the
// payload can hold thousands of rows. Encoding, sealing, decoding and
// opening therefore run in a background isolate through `compute` (an
// `Isolate.run` on phones; inline on the web, which has no isolates).
//
// The request side also drops rows the server already has: each row's
// fingerprint is compared with the one this device last pushed successfully
// (see SyncSentRows). That comparison never looks at a clock, so it stays
// correct when the phone's time differs from the server's.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:waffr/core/security/data_key.dart';
import 'package:waffr/core/sync/sync_crypto.dart';

/// Per collection, row `client_id` → fingerprint of the row as pushed.
typedef SyncRowPrints = Map<String, Map<String, String>>;

/// Collections whose upserts may be skipped when unchanged. The shopping
/// list row is left out: it is one tiny row stamped with "now" every time.
const List<String> fingerprintedSyncCollections = [
  'transactions',
  'savings_goals',
  'savings_transfers',
  'shopping_items',
  'recurring_expenses',
  'notifications',
  'expense_categories',
  'expense_presets',
];

/// A stable fingerprint of one plain (unsealed) row.
///
/// Rows are built by the same mapper every time, so their keys come in the
/// same order and the JSON text is stable. The text length plus two
/// independent 32-bit hashes make an accidental match practically
/// impossible, and none of it depends on per-process hash seeds.
String syncRowFingerprint(Map row) {
  final text = jsonEncode(row);
  var fnv = 0x811c9dc5;
  var djb = 5381;
  for (final unit in text.codeUnits) {
    fnv = ((fnv ^ unit) * 0x01000193) & 0xFFFFFFFF;
    djb = ((djb * 33) + unit) & 0xFFFFFFFF;
  }
  return '${text.length}:${fnv.toRadixString(36)}:${djb.toRadixString(36)}';
}

/// Input for [encodeSyncRequest].
class SyncRequestJob {
  /// Bundles everything the background isolate needs.
  const SyncRequestJob({
    required this.payload,
    required this.keyBytes,
    this.known,
  });

  /// The plain request, as built from the stores. It is changed in place.
  final Map<String, dynamic> payload;

  /// The data key, so the isolate can build its own [DataCipher].
  final Uint8List keyBytes;

  /// Fingerprints the server already acknowledged. Null sends every row.
  final SyncRowPrints? known;
}

/// Output of [encodeSyncRequest].
class EncodedSyncRequest {
  /// The JSON [body] and the fingerprints of the rows it carries.
  const EncodedSyncRequest(this.body, this.sent);

  /// Sealed request JSON, ready to POST.
  final String body;

  /// Fingerprints of the upserts in [body], to remember once it succeeds.
  final SyncRowPrints sent;
}

/// Drops unchanged rows, fingerprints the rest, seals private text and
/// encodes the request. Pure function of [job]; safe to run in an isolate.
Future<EncodedSyncRequest> encodeSyncRequest(SyncRequestJob job) async {
  final sent = <String, Map<String, String>>{};

  for (final collection in fingerprintedSyncCollections) {
    final section = job.payload[collection];
    if (section is! Map) continue;
    final upserts = section['upserts'];
    if (upserts is! List) continue;

    // A row deleted and then saved again under the same id must go out with
    // its tombstone, even when it looks exactly like the last push.
    final known = job.known?[collection];
    final deleted = _deletedIds(section['deletes']);
    final kept = <Object?>[];
    final prints = <String, String>{};
    for (final row in upserts) {
      if (row is! Map) continue;
      final id = row['client_id']?.toString();
      final print = syncRowFingerprint(row);
      final unchanged =
          known != null &&
          id != null &&
          !deleted.contains(id) &&
          known[id] == print;
      if (unchanged) continue;
      kept.add(row);
      if (id != null) prints[id] = print;
    }
    section['upserts'] = kept;
    sent[collection] = prints;
  }

  // Fingerprints are taken first: sealing adds a random nonce per field.
  await sealSyncRequest(job.payload, DataCipher(job.keyBytes));
  return EncodedSyncRequest(jsonEncode(job.payload), sent);
}

/// [encodeSyncRequest] in a background isolate.
Future<EncodedSyncRequest> encodeSyncRequestInBackground(SyncRequestJob job) {
  return compute(encodeSyncRequest, job, debugLabel: 'encode sync request');
}

/// Output of [decodeSyncResponse].
class DecodedSyncResponse {
  /// The opened [body] (null when the reply was not a JSON object).
  const DecodedSyncResponse(this.body, {this.sawPlaintext = false});

  /// The reply with private text opened, or null when it was not an object.
  final Map<String, dynamic>? body;

  /// True when the server still held some text unencrypted.
  final bool sawPlaintext;
}

/// Decodes the reply JSON and opens its sealed text. Throws on malformed
/// JSON, like `jsonDecode`.
Future<DecodedSyncResponse> decodeSyncResponse(
  ({String body, Uint8List keyBytes}) job,
) async {
  final decoded = jsonDecode(job.body);
  if (decoded is! Map) return const DecodedSyncResponse(null);
  final body = Map<String, dynamic>.from(decoded);
  final sawPlaintext = await openSyncResponse(body, DataCipher(job.keyBytes));
  return DecodedSyncResponse(body, sawPlaintext: sawPlaintext);
}

/// [decodeSyncResponse] in a background isolate.
Future<DecodedSyncResponse> decodeSyncResponseInBackground(
  String body,
  Uint8List keyBytes,
) {
  return compute(decodeSyncResponse, (
    body: body,
    keyBytes: keyBytes,
  ), debugLabel: 'decode sync response');
}

Set<String> _deletedIds(Object? deletes) {
  if (deletes is! List) return const {};
  return {
    for (final item in deletes)
      if (item is Map && item['client_id'] != null)
        item['client_id'].toString(),
  };
}
