# lib/core/sync

Account sign-in and cloud sync against the FastAPI backend (`backend/`,
deployed from `render.yaml`). Local prefs stay the source of truth; a failed
request never deletes or overwrites local rows. Guests have no token and never sync.

| File | Contents |
| --- | --- |
| `sync_service.dart` | `SyncService.instance`: `initialize()` (from `main`), `scheduleSync()` (3 s debounce), `syncNow(force:)` -> `SyncResult`, `isSyncing` notifier. Orchestrates one round trip. |
| `sync_request.dart` | `buildSyncRequest(lastSync:, everyRow:)`: the plain request from every store, plus `syncSettingsPayload()` and `tombstoneIdsIn()`. |
| `sync_codec.dart` | Fingerprints rows (`syncRowFingerprint`), drops unchanged ones, seals and JSON-encodes the request; decodes and opens the reply. `*InBackground` variants use `compute()`. |
| `sync_crypto.dart` | `privateSyncFields`, `sealSyncRequest`, `openSyncResponse`: which fields are encrypted with the `DataCipher`. |
| `sync_sent_rows.dart` | `SyncSentRows`: in-memory fingerprints of rows the server acknowledged this session. |
| `sync_apply.dart` | `applySyncResponse(body)`: merges the reply into every store and clears acknowledged tombstones. |
| `sync_mapper.dart` | Model <-> `/sync` JSON (`transactionToSync`, `goalFromSync`, ...), `collectionPayload`, `parseMoney`, default shopping-list ids. |
| `sync_merge.dart` | `mergeRemoteRecords<T>()`: generic last-write-wins merge used by the stores' `applyRemoteSync`. |
| `sync_tombstones.dart` | `SyncCollection`, `SyncTombstone`, `SyncTombstones.instance`: persisted log of offline deletes. |
| `sync_dirty.dart` | `SyncDirty.mark(settings:)` / `isDirty()` / `clear(ifRevision:)`: the "needs push" bit, with a revision counter. |
| `sync_pull_policy.dart` | `shouldSkipCleanPull()`: skips a clean pull repeated within 20 s. |
| `sync_clock.dart` | `syncNow()`, `deviceNow()`, `parseSyncDate`, `newerOrEqual`, `toSyncIso`: UTC helpers for LWW. |
| `auth_session.dart` | `AuthSession.instance`: login/register/reset/change password/delete account, JWT in secure storage, last-sync stamp, data-key unlock. Re-exports `auth_errors.dart`. |
| `auth_errors.dart` | `describeAuthError(status, body)`: Arabic messages for `/auth` failures. |
| `profile_sync.dart` | `ProfileSync`: profile prefs (name, address, theme, streak, ...) in the settings payload; `adoptAccount`, `fillMissing`, `apply`. |
| `api_config.dart` | `ApiConfig.baseUrl()` (prefs override `waffer_api_base_url`) and `timeoutFor()` (75 s for sleeping Render hosts). |

Flow: a store edit calls `SyncDirty.mark()` -> `SyncService.scheduleSync()` ->
`buildSyncRequest` -> `encodeSyncRequestInBackground` -> POST `/sync` ->
`decodeSyncResponseInBackground` -> `applySyncResponse` -> `SyncSentRows.remember`
and `SyncDirty.clear(ifRevision:)`. Lifecycle resume and reconnect also sync.

Conventions:

- Sync is incremental by content, not by clock: rows whose fingerprint matches
  the last acknowledged push are dropped in `sync_codec.dart`. Sign-in, a
  forced sync and the first sync after launch push every row.
- Sealing/encoding and decoding/opening run off the UI isolate via `compute()`.
- `SyncDirty.suppressed` is set while a reply is applied, so merging is not
  counted as a local edit. Only strictly newer remote rows replace local ones,
  and a newer local tombstone beats an incoming upsert.
