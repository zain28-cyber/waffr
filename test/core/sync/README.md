# test/core/sync

Sync without the network: building the push body from the stores
(`sync_request`), fingerprint filtering and sealing (`sync_codec`,
`sync_sent_rows`, `sync_crypto`), model mapping (`sync_mapper`),
last-write-wins merging (`sync_merge`), applying a reply to every store
(`sync_apply`), the delete log (`sync_tombstones`), the dirty flag
(`sync_dirty`), timestamps (`sync_clock`), the pull cooldown
(`sync_pull_policy`), profile settings (`profile_sync`), the API base URL
(`api_config`) and auth error messages (`auth_errors`).

`SyncService` and `AuthSession` HTTP calls are not tested here.

```
flutter test --no-pub test/core/sync
```
