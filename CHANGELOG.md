## 1.1.1

- Fix undefined `_calculateLiveDataSize` method — replaced with `_rebuildRecordLengthMetrics`

## 1.1.0

- Batch write optimization: `batchPut` and `batchDelete` now batch all disk and hint writes via `StorageFile.appendAll()`
- Cached DB size metrics (`_dbDataSize`, `_liveDataSize`) for O(1) compaction decisions instead of file scanning
- Record length tracking (`_recordLengths` map) to avoid header re-reads during updates/deletes
- Configurable snapshot write interval (`_snapshotWriteInterval` = 100K ops)
- `hasIndexes` getter on `IndexManager`, `hasListeners` getter on `ChangeBus` for efficient old-value skipping
- `StorageFile.appendAll()` for single-disk-write batch appending
- Add benchmark tool (`bin/benchmark.dart`) with create/update/delete cases
- Add test suite (`test/umay_box_test.dart`) covering recovery, batch consistency, and update semantics
- Add `test` dev dependency

## 1.0.2

- Rename logo image to logo.png
- Update install instructions to pub.dev package
- Add Persian and Azerbaijani README

## 1.0.1

- Initial pub.dev release
- Add CHANGELOG.md
- Add LICENSE
- Prepare package metadata for publishing

- Initial release
- Active Record ORM with fillable, guarded, hidden, casts, accessors, mutators
- Append-only log storage (`.db` / `.hint` / `.idx`)
- LINQ-style type-safe query builder
- Secondary, compound, unique, range, and fuzzy indexes (B+Tree)
- Soft Deletes (SoftDeletes mixin)
- Relations: HasMany, BelongsTo, HasOne, ManyToMany, MorphMany, MorphTo
- Eager loading with dot-notation
- Reactive queries via `watch()` streams
- MVCC transactions with commit/rollback
- Auto compaction with configurable policy
- Model lifecycle events
- Query optimizer with automatic index selection
- Persian/Arabic text normalization
- Zero runtime dependencies
