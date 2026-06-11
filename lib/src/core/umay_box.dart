import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../compaction/compaction_policy.dart';
import '../compaction/compactor.dart';
import '../index/index_manager.dart';
import '../orm/soft_delete.dart';
import '../query/engine/query_engine.dart';
import '../query/linq_query_builder.dart';
import '../reactive/change_bus.dart';
import '../reactive/change_event.dart';
import '../serialization/serializer.dart';
import '../serialization/type_registry.dart';
import '../utils/lock.dart';
import 'box_index.dart';
import 'hint_codec.dart';
import 'index_snapshot.dart';
import 'record_codec.dart';
import 'storage_file.dart';

class UmayBox {
  final String name;
  final String _directory;

  late StorageFile _file;
  late StorageFile _hintFile;
  late BoxIndex _index;
  late final File _snapshotFile;

  final IndexManager indexManager = IndexManager();
  final CompactionPolicy _policy = CompactionPolicy();
  final ChangeBus _bus = ChangeBus();

  final AsyncLock _writeLock = AsyncLock();

  late final QueryEngine queryEngine;

  final Map<String, dynamic> relations = {};

  bool _isOpen = false;
  int _snapshotCounter = 0;
  bool _snapshotDirty = false;
  Timer? _backgroundCompactionTimer;

  UmayBox._(this.name, this._directory);

  // =============================================================
  // Open
  // =============================================================

  static Future<UmayBox> open(String name, {String? directory}) async {
    final dir = directory ?? '.';
    final box = UmayBox._(name, dir);
    box._file = StorageFile('$dir/$name.db');
    box._hintFile = StorageFile('$dir/$name.hint');
    box._snapshotFile = File('$dir/$name.idx');
    box._index = BoxIndex();

    await box._openFiles();

    final recovered = await box._recoverIndex();
    for (final entry in recovered.entries) {
      box._index.add(entry.key, entry.value);
    }

    box.queryEngine = QueryEngine(box, box.indexManager);
    box._isOpen = true;
    box._startBackgroundCompaction();

    return box;
  }

  // =============================================================
  // File Management
  // =============================================================

  Future<void> _openFiles() async {
    await _file.open();
    await _hintFile.open();
  }

  Future<void> _reopenFiles() async {
    await _file.close();
    await _hintFile.close();
    _file = StorageFile('$_directory/$name.db');
    _hintFile = StorageFile('$_directory/$name.hint');
    await _file.open();
    await _hintFile.open();
  }

  Future<void> rebuildIndexes() async {
    if (indexManager.secondaryIndexes.isEmpty &&
        indexManager.fuzzyIndexes.isEmpty &&
        indexManager.uniqueIndexes.isEmpty &&
        indexManager.compoundIndexes.isEmpty) {
      print('🔍 REBUILD: no indexes to rebuild');
      return;
    }

    print('🔍 REBUILD: rebuilding indexes for ${_index.offsets.length} records...');
    int count = 0;
    for (final entry in _index.offsets.entries) {
      try {
        final value = await _readValueAt(entry.value);
        if (value == null) continue;
        final map = _asMap(value);
        if (map != null) {
          indexManager.onPut(map, entry.key);
          count++;
        }
      } catch (_) {}
    }
    print('🔍 REBUILD: indexed $count records, fuzzy trigrams=${indexManager.fuzzyIndexes.values.fold(0, (s, i) => s + i.debugTrigramCount())}');
  }

  // =============================================================
  // Index Recovery
  //
  // ترتیب اولویت:
  //   1. Hint file (سریع‌ترین)
  //   2. Snapshot file (.idx)
  //   3. Full scan از log file (کندترین، ولی همیشه درست)
  // =============================================================

  Future<BoxIndex> _recoverIndex() async {
    // 1) Hint file
    try {
      final hint = File(_hintFile.path);
      if (await hint.exists() && await hint.length() > 0) {
        return await _loadIndexFromHint();
      }
    } catch (_) {}

    // 2) Snapshot
    try {
      final snapshot = await IndexSnapshot.load(_snapshotFile.path);
      if (snapshot != null) {
        return BoxIndex.fromMap(snapshot);
      }
    } catch (_) {}

    // 3) Full scan
    final rebuilt = await _buildIndex();
    await IndexSnapshot.save(_snapshotFile.path, rebuilt.offsets);
    return rebuilt;
  }

  ///         تا بفهمیم آیا tombstone هست یا نه.
  ///
  /// ❌ قدیمی: فقط key + offset رو از hint می‌خوند و بدون بررسی
  ///           tombstone بودن، به index اضافه می‌کرد
  ///           → key های delete شده زنده می‌شدن
  Future<BoxIndex> _loadIndexFromHint() async {
    final idx = BoxIndex();

    final file = File(_hintFile.path);
    if (!await file.exists()) return idx;

    final bytes = await file.readAsBytes();
    int pos = 0;

    while (pos + 4 <= bytes.length) {
      final keyLen = ByteData.sublistView(bytes, pos, pos + 4)
          .getInt32(0, Endian.big);

      if (keyLen < 0) break;

      final entrySize = 4 + keyLen + 8;
      if (pos + entrySize > bytes.length) break;

      final entryBytes =
      Uint8List.fromList(bytes.sublist(pos, pos + entrySize));
      final entry = HintCodec.decode(entryBytes);

      try {
        final headerBytes =
        await _file.readAt(entry.value, RecordCodec.headerSize);
        final header = RecordCodec.decodeHeader(headerBytes);

        if (header.deleted) {
          idx.remove(entry.key);
        } else {
          idx.add(entry.key, entry.value);
        }
      } catch (_) {
        // اگه header خراب بود، این entry رو skip کن
      }

      pos += entrySize;
    }

    return idx;
  }

  /// Full scan از log file — کندترین ولی همیشه درست.
  Future<BoxIndex> _buildIndex() async {
    final map = <String, int>{};

    int offset = 0;
    final size = await _file.length();

    while (offset < size) {
      try {
        final headerBytes =
        await _file.readAt(offset, RecordCodec.headerSize);
        final header = RecordCodec.decodeHeader(headerBytes);
        final totalLength = header.totalLength;

        if (offset + totalLength > size) break;

        final recordBytes = await _file.readAt(offset, totalLength);
        final record = RecordCodec.decodeWithCrc(recordBytes);

        final keyBytes = record['key'] as Uint8List;
        final key = String.fromCharCodes(keyBytes);

        if (record['deleted'] == true) {
          map.remove(key);
        } else {
          map[key] = offset;
        }

        offset += totalLength;
      } catch (_) {
        break;
      }
    }

    return BoxIndex.fromMap(map);
  }

  // =============================================================
  // Internal Read Helper
  // =============================================================

  /// مقدار ذخیره شده در offset رو می‌خونه و deserialize می‌کنه.
  Future<dynamic> _readValueAt(int offset) async {
    final headerBytes =
    await _file.readAt(offset, RecordCodec.headerSize);
    final header = RecordCodec.decodeHeader(headerBytes);

    final recordBytes = await _file.readAt(offset, header.totalLength);
    final record = RecordCodec.decodeWithCrc(recordBytes);

    if (record['deleted'] == true) return null;

    final valueBytes = record['value'] as Uint8List;
    return Serializer.deserialize(valueBytes);
  }

  // =============================================================
  // GET
  //
  // Read عملیات — lock لازم نداره چون:
  //   1. StorageFile دو handle جدا داره (read/write)
  //   2. Index فقط در write عوض میشه و atomic هست
  //   3. File read از یه offset ثابت همیشه safe هست
  // =============================================================

  Future<dynamic> getSync(String key) => get(key);

  Future<dynamic> get(String key) async {
    _ensureOpen();

    final offset = _index[key];
    if (offset == null) return null;

    return _readValueAt(offset);
  }


  Future<void> put(String key, Object value, [int? typeId]) async {
    _ensureOpen();

    return _writeLock.run(() async {
      final oldValue = await get(key);

      final resolvedTypeId =
          typeId ?? TypeRegistry.findTypeIdFor(value) ?? 0;
      final encodedValue = Serializer.serialize(value, resolvedTypeId);

      final record = RecordCodec.encode(
        deleted: false,
        key: Uint8List.fromList(key.codeUnits),
        value: encodedValue,
      );

      final offset = await _file.append(record);

      _index.add(key, offset);

      await _hintFile.append(HintCodec.encode(key, offset));

      _snapshotDirty = true;
      if (_snapshotCounter++ >= 5000) {
        await IndexSnapshot.save(_snapshotFile.path, _index.offsets);
        _snapshotCounter = 0;
      }

      final oldMap = _asMap(oldValue);
      final newMap = _asMap(value);
      if (oldMap != null) indexManager.onDelete(oldMap, key);
      if (newMap != null) indexManager.onPut(newMap, key);

      _bus.emit(ChangeEvent(
        key: key, type: ChangeType.put,
        oldValue: oldValue, newValue: value,
      ));
      queryEngine.invalidateAll();
      await _maybeCompact();
    });
  }

  Future<void> batchPut(List<MapEntry<String, Object>> entries) async {
    _ensureOpen();

    return _writeLock.run(() async {
      for (final entry in entries) {
        final key = entry.key;
        final value = entry.value;

        final oldValue = _index.containsKey(key) ? await get(key) : null;

        final resolvedTypeId =
            TypeRegistry.findTypeIdFor(value) ?? 0;
        final encodedValue = Serializer.serialize(value, resolvedTypeId);

        final record = RecordCodec.encode(
          deleted: false,
          key: Uint8List.fromList(key.codeUnits),
          value: encodedValue,
        );

        final offset = await _file.append(record);
        _index.add(key, offset);

        final hintEntry = HintCodec.encode(key, offset);
        await _hintFile.append(hintEntry);

        final oldMap = _asMap(oldValue);
        final newMap = _asMap(value);
        if (oldMap != null) indexManager.onDelete(oldMap, key);
        if (newMap != null) indexManager.onPut(newMap, key);
      }

      _snapshotDirty = true;

      for (final entry in entries) {
        _bus.emit(ChangeEvent(
          key: entry.key, type: ChangeType.put,
          oldValue: null, newValue: entry.value,
        ));
      }
      queryEngine.invalidateAll();
    });
  }

  // =============================================================
  // DELETE
  //
  // =============================================================

  Future<void> delete(String key) async {
    _ensureOpen();

    return _writeLock.run(() async {
      final obj = await get(key);
      if (obj == null) return;

      // اگه SoftDelete پیاده‌سازی کرده، soft delete کن
      if (obj is SoftDelete) {
        obj.markDeleted();
        // ✅ نکته: اینجا مستقیم _putInternal رو صدا بزن
        //          نه put() — چون ما الان داخل lock هستیم
        //          و put() هم lock می‌گیره → deadlock!
        await _putInternal(key, obj);
        return;
      }

      // اگه Map هست و deleted_at field داره، soft delete
      final map = _asMap(obj);
      if (map != null &&
          (map.containsKey('deleted_at') ||
              map.containsKey('deletedAt'))) {
        final field =
        map.containsKey('deleted_at') ? 'deleted_at' : 'deletedAt';
        map[field] = DateTime.now().toIso8601String();
        await _putInternal(key, map);
        return;
      }

      // Physical delete (tombstone)
      await _deletePhysical(key, obj);
    });
  }

  Future<void> batchDelete(List<String> keys) async {
    _ensureOpen();

    return _writeLock.run(() async {
      for (final key in keys) {
        final obj = await get(key);
        if (obj == null) continue;

        if (obj is SoftDelete) {
          obj.markDeleted();
          await _putInternal(key, obj);
          continue;
        }

        final map = _asMap(obj);
        if (map != null &&
            (map.containsKey('deleted_at') ||
                map.containsKey('deletedAt'))) {
          final field =
              map.containsKey('deleted_at') ? 'deleted_at' : 'deletedAt';
          map[field] = DateTime.now().toIso8601String();
          await _putInternal(key, map);
          continue;
        }

        final record = RecordCodec.encode(
          deleted: true,
          key: Uint8List.fromList(key.codeUnits),
          value: Uint8List(0),
        );
        final offset = await _file.append(record);
        _index.remove(key);

        final hintEntry = HintCodec.encode(key, offset);
        await _hintFile.append(hintEntry);

        final oldMap = _asMap(obj);
        if (oldMap != null) indexManager.onDelete(oldMap, key);

        _bus.emit(ChangeEvent(
          key: key, type: ChangeType.delete,
          oldValue: obj, newValue: null,
        ));
      }

      _snapshotDirty = true;
      queryEngine.invalidateAll();
    });
  }

  Future<void> _putInternal(String key, Object value,
      [int? typeId]) async {
    final oldValue = await get(key);

    final resolvedTypeId =
        typeId ?? TypeRegistry.findTypeIdFor(value) ?? 0;
    final encodedValue = Serializer.serialize(value, resolvedTypeId);

    final record = RecordCodec.encode(
      deleted: false,
      key: Uint8List.fromList(key.codeUnits),
      value: encodedValue,
    );

    final offset = await _file.append(record);

    _index.add(key, offset);

    final hintEntry = HintCodec.encode(key, offset);
    await _hintFile.append(hintEntry);

    _snapshotDirty = true;
    if (_snapshotCounter++ >= 5000) {
      await IndexSnapshot.save(_snapshotFile.path, _index.offsets);
      _snapshotCounter = 0;
    }

    final oldMap = _asMap(oldValue);
    final newMap = _asMap(value);

    if (oldMap != null) indexManager.onDelete(oldMap, key);
    if (newMap != null) indexManager.onPut(newMap, key);

    _bus.emit(ChangeEvent(
      key: key,
      type: ChangeType.put,
      oldValue: oldValue,
      newValue: value,
    ));

    queryEngine.invalidateAll();
  }

  /// Physical delete — tombstone رو append می‌کنه.
  /// فقط از داخل _writeLock.run() صدا زده میشه.
  Future<void> _deletePhysical(String key, dynamic oldValue) async {
    final record = RecordCodec.encode(
      deleted: true,
      key: Uint8List.fromList(key.codeUnits),
      value: Uint8List(0),
    );

    final offset = await _file.append(record);

    _index.remove(key);

    // Hint entry برای tombstone هم ثبت میشه
    // تا در recovery بفهمیم key حذف شده
    final hintEntry = HintCodec.encode(key, offset);
    await _hintFile.append(hintEntry);

    await IndexSnapshot.save(_snapshotFile.path, _index.offsets);

    // Secondary indexes
    final oldMap = _asMap(oldValue);
    if (oldMap != null) indexManager.onDelete(oldMap, key);

    _bus.emit(ChangeEvent(
      key: key,
      type: ChangeType.delete,
      oldValue: oldValue,
      newValue: null,
    ));

    queryEngine.invalidateAll();
  }

  // =============================================================
  // QUERY / SCAN
  // =============================================================

  /// LINQ-style query builder.
  LinqQueryBuilder<T> query<T>() => LinqQueryBuilder<T>(this);

  /// همه key های موجود در index.
  Iterable<String> indexKeys() => _index.offsets.keys;

  /// همه object ها رو برمی‌گردونه.
  Future<List<dynamic>> all() async {
    return getMany(_index.offsets.keys.toList());
  }

  /// Object هایی که predicate رو pass می‌کنن رو برمی‌گردونه.
  Future<List<dynamic>> scan(
      bool Function(dynamic obj) predicate,
      ) async {
    final results = <dynamic>[];
    for (final key in _index.offsets.keys) {
      final obj = await get(key);
      if (obj == null) continue;
      if (predicate(obj)) results.add(obj);
    }
    return results;
  }

  /// چندین key رو یکجا لود می‌کنه.
  Future<List<dynamic>> getMany(List<String> keys) async {
    _ensureOpen();

    final results = <dynamic>[];
    for (final key in keys) {
      final offset = _index[key];
      if (offset == null) continue;
      final obj = await _readValueAt(offset);
      if (obj != null) results.add(obj);
    }
    return results;
  }

  // =============================================================
  // COMPACTION
  // =============================================================

  Future<void> compact() async {
    _ensureOpen();

    return _writeLock.run(() async {
      final compactor = Compactor(
        _file.path,
        _snapshotFile.path,
        _hintFile.path,
      );

      final newIndex = await compactor.compact(_index);

      await _reopenFiles();
      _index.clear();
      newIndex.forEach(_index.add);

      queryEngine.invalidateAll();
    });
  }

  /// بررسی می‌کنه آیا compaction لازمه یا نه.
  /// اگه garbage ratio از threshold بیشتر بود، compact رو صدا می‌زنه.
  Future<void> _maybeCompact() async {
    final dbSize = await _file.length();

    int liveSize = 0;
    for (final offset in _index.offsets.values) {
      try {
        final headerBytes =
        await _file.readAt(offset, RecordCodec.headerSize);
        final header = RecordCodec.decodeHeader(headerBytes);
        liveSize += header.totalLength;
      } catch (_) {
        // اگه header خراب بود، skip کن
      }
    }

    if (await _policy.shouldCompact(dbSize, liveSize)) {
      // ✅ نکته: اینجا compact() رو بدون lock صدا نزن!
      //          compact() خودش lock می‌گیره.
      //          ولی _maybeCompact از داخل put() صدا زده میشه
      //          که خودش داخل lock هست → باید مستقیم _compactInternal بزنی
      await _compactInternal();
    }
  }

  /// Internal compact — بدون lock (چون caller داخل lock هست)
  Future<void> _compactInternal() async {
    final compactor = Compactor(
      _file.path,
      _snapshotFile.path,
      _hintFile.path,
    );

    final newIndex = await compactor.compact(_index);

    await _reopenFiles();

    _index.clear();
    newIndex.forEach(_index.add);

    queryEngine.invalidateAll();
  }

  /// هر ۱ دقیقه چک می‌کنه آیا compaction لازمه.
  void _startBackgroundCompaction() {
    _backgroundCompactionTimer =
        Timer.periodic(const Duration(minutes: 1), (_) async {
          try {
            //background compaction هم باید lock بگیره
            await _writeLock.run(() async {
              final dbSize = await _file.length();

              int liveSize = 0;
              for (final offset in _index.offsets.values) {
                try {
                  final headerBytes =
                  await _file.readAt(offset, RecordCodec.headerSize);
                  final header = RecordCodec.decodeHeader(headerBytes);
                  liveSize += header.totalLength;
                } catch (_) {}
              }

              if (await _policy.shouldCompact(dbSize, liveSize)) {
                await _compactInternal();
              }
            });
          } catch (_) {
            // Background compaction شکست خورد — بعداً retry میشه
          }
        });
  }

  // =============================================================
  // CLOSE
  // =============================================================

  Future<void> saveSnapshot() async {
    await IndexSnapshot.save(_snapshotFile.path, _index.offsets);
    _snapshotDirty = false;
  }

  Future<void> close() async {
    _backgroundCompactionTimer?.cancel();
    _backgroundCompactionTimer = null;

    if (_snapshotDirty) {
      await IndexSnapshot.save(_snapshotFile.path, _index.offsets);
    }
    await _file.close();
    await _hintFile.close();
    _bus.close();
    _isOpen = false;
  }

  void _ensureOpen() {
    if (!_isOpen) throw StateError('Box "$name" is not open');
  }

  // =============================================================
  // REACTIVE
  // =============================================================

  /// Stream تغییرات برای reactive watchers.
  Stream<ChangeEvent> watch() => _bus.stream;

  // =============================================================
  // HELPERS
  // =============================================================

  /// فیلد خاصی از یه object رو می‌خونه.
  /// هم Map و هم UmayModel رو handle می‌کنه.
  dynamic getField(dynamic obj, String field) {
    final map = _asMap(obj);
    return map?[field];
  }

  /// هر object رو به Map<String, dynamic> تبدیل می‌کنه.
  ///
  /// ترتیب اولویت:
  ///   1. اگه Map<String, dynamic> هست → مستقیم برگردون
  ///   2. اگه Map (با key غیر String) هست → تبدیل کن
  ///   3. اگه .toJson() داره → صدا بزن
  ///   4. اگه .toMap() داره → صدا بزن
  ///   5. null
  Map<String, dynamic>? _asMap(dynamic obj) {
    if (obj == null) return null;

    if (obj is Map<String, dynamic>) return obj;

    if (obj is Map) {
      return obj.map((k, v) => MapEntry(k.toString(), v));
    }

    try {
      final json = (obj as dynamic).toJson();
      if (json is Map<String, dynamic>) return json;
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}

    try {
      final map = (obj as dynamic).toMap();
      if (map is Map<String, dynamic>) return map;
      if (map is Map) {
        return map.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}

    return null;
  }
}