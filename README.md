<table>
<tr>
<td width="50%"><img src="https://raw.githubusercontent.com/pishguy/umay/main/logo.png" width="300" alt="UmayDB"></td>
<td width="50%" valign="middle">

## UmayDB

UmayDB is a lightweight embedded NoSQL database for Dart and Flutter, inspired by Laravel Eloquent ORM and Bitcask storage architecture.

</td>
</tr>
</table>

<div align="center">
  <strong>English</strong> | <a href="README.fa.md">فارسی</a> | <a href="README.az.md">Azərbaycanca</a>
</div>

---

**UmayDB** is a lightweight embedded NoSQL database for Dart and Flutter, inspired by Laravel Eloquent ORM and Bitcask storage architecture.

## Features

- **Active Record ORM** — Laravel-style `UmayModel` with fillable, guarded, hidden, casts, accessors, mutators
- **Append-only Log Storage** — High-performance write-ahead log backed by `.db` / `.hint` / `.idx` files
- **LINQ-style Query Builder** — Expressive type-safe queries with proxy objects
- **Secondary Indexes** — Auto-managed B+Tree indexes for fast lookups
- **Compound Indexes** — Multi-field composite indexes
- **Unique Indexes** — Enforce uniqueness with B+Tree
- **Range Queries** — `gt`, `lt`, `gte`, `lte`, `between` via B+Tree range scans
- **Fuzzy Search** — Trigram-based fuzzy search with Levenshtein scoring
- **Soft Deletes** — `SoftDeletes` mixin with `trashed`, `restore()`, `withTrashed()`, `onlyTrashed()`
- **Relations** — `HasMany`, `BelongsTo`, `HasOne`, `ManyToMany`, `MorphMany`, `MorphTo`
- **Eager Loading** — Nested relation loading with dot-notation (`"posts.comments"`)
- **whereHas / withCount** — Filter by related models, load relationship counts
- **Reactive Queries** — Live-updating query results via `watch()` streams
- **MVCC Transactions** — Snapshot-isolated transactions with commit/rollback
- **Auto Compaction** — Background garbage collection with configurable policy
- **Change Bus** — Broadcast stream of `ChangeEvent` for reactive UIs
- **Event System** — Model lifecycle events: `creating`, `created`, `updating`, `updated`, `deleting`, `deleted`
- **Polymorphic Relations** — `MorphMany` / `MorphTo` for multi-model relationships
- **Query Optimizer** — Automatic index selection: composite → single → range → full scan
- **Caching** — Query result cache (up to 500 entries)
- **Persian Text Normalization** — Built-in Arabic→Persian normalization for Farsi search
- **Zero Runtime Dependencies** — Pure Dart, only uses `dart:io`, `dart:async`, `dart:collection`

---

## Getting Started

### Add dependency

```yaml
dependencies:
  umay_db: ^1.0.1
```

### Basic usage

```dart
import 'package:umay_db/umay_db.dart';

final box = await UmayBox.open('users');

// Insert
await box.put('user:1', {'name': 'Alice', 'email': 'alice@example.com', 'age': 30});

// Read
final user = await box.get('user:1');
print(user['name']); // Alice

// Delete
await box.delete('user:1');

// Close
await box.close();
```

---

## ORM Model

Define a model class extending `UmayModel`:

```dart
class User extends UmayModel with IndexableModel {
  @override
  List<String> get indexed => ['email', 'role'];

  @override
  List<String> get fuzzyIndexed => ['name'];

  @override
  List<String> get fillable => ['name', 'email', 'role', 'age', 'is_active'];

  @override
  List<String> get hidden => ['password'];

  @override
  Map<String, String> get casts => {
    'age': 'int',
    'is_active': 'bool',
  };

  @override
  Map<String, dynamic Function(dynamic)> get mutators => {
    'email': (v) => v?.toString().toLowerCase().trim(),
    'name': (v) => v?.toString().trim(),
  };

  @override
  Map<String, dynamic Function(dynamic)> get accessors => {
    'label': (_) => '${getAttribute('name')} [${getAttribute('role')}]',
  };

  String? get name => getAttribute('name');
  String? get email => getAttribute('email');
  String? get role => getAttribute('role');
  int? get age => getAttribute('age');
  bool get isActive => getAttribute('is_active') ?? false;
}
```

### Registration

```dart
final box = await UmayBox.open('users');
UmayModel.register<User>(() => User(), box: box);
```

### CRUD

```dart
// Create
final user = await UmayModel.create<User>({
  'name': 'Alice',
  'email': 'alice@example.com',
  'role': 'admin',
  'age': 28,
});

// Find
final found = await UmayModel.find<User>(userId);

// Update
found!.setAttribute('age', 29);
await found.save();

// Delete
await found.delete();
```

---

## Queries

### Simple queries

```dart
final results = await box.query<User>()
  .where((u) => (u as dynamic).role.eq('admin'))
  .orderBy((u) => (u as dynamic).name)
  .find();
```

### Comparisons

```dart
// eq, notEq, gt, lt, gte, lte
query.where((u) => (u as dynamic).age >= 18);

// contains, startsWith, endsWith
query.where((u) => (u as dynamic).name.contains('Ali'));

// IN
query.whereIn('role', ['admin', 'editor']);

// Between
query.whereBetween('age', 18, 65);

// Null checks
query.whereNull('deleted_at');
```

### Pagination & sorting

```dart
final page = await box.query<User>()
  .orderBy((u) => (u as dynamic).name)
  .limit(20)
  .offset(0)
  .find();

final total = await box.query<User>().count();
final first = await box.query<User>().orderBy((u) => (u as dynamic).age).first();
final paginated = await box.query<User>().paginate(page: 1, perPage: 20);
```

### Fuzzy search

```dart
final results = await box.query<User>()
  .where((u) => (u as dynamic).name.fuzzy('عل'))
  .orderBy((u) => (u as dynamic).name)
  .find();
```

---

## Soft Deletes

```dart
class Post extends UmayModel with SoftDeletes, IndexableModel {
  @override
  List<String> get indexed => ['user_id', 'status'];

  @override
  List<String> get fillable => ['title', 'body', 'user_id', 'status'];
}
```

```dart
final post = await UmayModel.find<Post>(postId);
await post!.delete();     // sets deleted_at
print(post.isDeleted);    // true
await post.restore();     // clears deleted_at

// Query normally — soft-deleted records are excluded
final posts = await box.query<Post>().find();

// Include trashed
final all = await box.query<Post>().withTrashed().find();

// Only trashed
final trashed = await box.query<Post>().onlyTrashed().find();
```

---

## Relations

### HasMany

```dart
box.relations['posts'] = HasMany<Map<String, dynamic>, Map<String, dynamic>>(
  usersBox, postsBox, 'user_id', (user) => user['id'],
);

final alicePosts = await hasManyRel.loadOne(aliceMap);
```

### BelongsTo

```dart
box.relations['user'] = BelongsTo<Map<String, dynamic>, Map<String, dynamic>>(
  postsBox, usersBox, (post) => post['user_id'],
);

final author = await belongsRel.loadOne(postMap);
```

### ManyToMany

```dart
final pivot = PivotTable();

box.relations['tags'] = ManyToMany<Map<String, dynamic>, Map<String, dynamic>>(
  postsBox, tagsBox, pivot, (post) => post['id'],
);

pivot.attach(postId, tagId);
pivot.detach(postId, tagId);

final tags = await manyRel.loadOne(postMap);
final postIds = pivot.getReverse(tagId);
```

### Eager loading

```dart
final users = await box.query<User>()
  .withRelation('posts')
  .withRelation('posts.comments')
  .find();
```

### whereHas / withCount

```dart
final users = await box.query<User>()
  .whereHas('posts', (q) => q.where('status', eq: 'published'))
  .withCount('posts')
  .find();

print(users.first.getAttribute('posts_count'));
```

---

## Polymorphic Relations

```dart
// MorphMap — register your polymorphic targets
MorphMap.register('post', postsBox);
MorphMap.register('video', videosBox);

box.relations['comments'] = MorphMany<...>(
  commentsBox, 'commentable_type', 'commentable_id', (post) => post['id'],
);
```

---

## Reactive Queries

```dart
final stream = box.query<User>()
  .orderBy((u) => (u as dynamic).name)
  .watch();

final subscription = stream.listen((users) {
  // Called on every insert/update/delete
  setState(() => _users = users);
});
```

### Watch a single key

```dart
final stream = box.watchKey('user:1');
```

---

## Annotations (for code generation)

```dart
@UmayCollection('users')
class User {
  @UmayField(index: true, unique: true)
  String email = '';

  @UmayField(fuzzy: true)
  String name = '';

  @RelHasMany(Post, foreignKey: 'user_id')
  late List<Post> posts;
}
```

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   UmayBox                         │
│  ┌──────────┐  ┌───────────┐  ┌──────────────┐  │
│  │ CRUD API │  │ Query API │  │ Reactive API │  │
│  └────┬─────┘  └─────┬─────┘  └──────┬───────┘  │
│       │              │               │           │
│  ┌────▼──────────────▼───────────────▼───────┐   │
│  │           IndexManager                     │   │
│  │  ┌──────┐ ┌────────┐ ┌──────┐ ┌────────┐ │   │
│  │  │ Sec. │ │ Fuzzy  │ │Uniq. │ │Comp.   │ │   │
│  │  │Index │ │ Index  │ │Index │ │Index   │ │   │
│  │  └──┬───┘ └───┬────┘ └──┬───┘ └───┬────┘ │   │
│  │     └─────────┴─────────┴──────────┘      │   │
│  └────────────────────────────────────────────┘   │
│                         │                         │
│  ┌──────────────────────▼────────────────────┐    │
│  │              Storage Layer                 │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────────┐  │    │
│  │  │ .db log │ │ .hint   │ │ .idx snap   │  │    │
│  │  └─────────┘ └─────────┘ └─────────────┘  │    │
│  └────────────────────────────────────────────┘    │
│                         │                         │
│  ┌──────────────────────▼────────────────────┐    │
│  │            Compaction Engine               │    │
│  └────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────┘
```

---

## Storage

Each database box consists of three files:

| File     | Description                            |
|----------|----------------------------------------|
| `.db`    | Append-only record log (key + value)   |
| `.hint`  | Key → offset index for fast recovery   |
| `.idx`   | Persistent snapshot of the index       |

On startup, the box recovers in order:
1. Read `.idx` snapshot (fastest)
2. Read `.hint` file for recent entries
3. Full scan of `.db` as fallback

Compaction runs automatically in the background (every 60 seconds when garbage ratio > 30%) or manually via `box.compact()`.

---

## Queries & Indexes

### Index types

| Index       | Structure   | Use case                       |
|-------------|-------------|--------------------------------|
| Secondary   | HashMap     | O(1) equality lookups          |
| Range       | B+Tree      | Range queries (gt, lt, between)|
| Unique      | B+Tree      | Uniqueness enforcement         |
| Compound    | B+Tree      | Multi-field queries            |
| Fuzzy       | Trigram map | Approximate text search        |

### Query optimizer strategy

1. **Composite index** — if all fields match a compound index
2. **Single equality** — fastest (O(1) HashMap lookup)
3. **Range index** — B+Tree range scan
4. **Full scan** — linear scan over all records (fallback)

---

## Events

```dart
UmayModel.events.on<User>(ModelEventType.created, (event) {
  print('User created: ${event.model?.getAttribute('name')}');
});
```

Available events: `creating`, `created`, `updating`, `updated`, `deleting`, `deleted`, `saving`, `saved`.

---

## Transactions (MVCC)

```dart
final tm = TransactionManager(mvccStorage);

final tx = await tm.begin();
await mvccStorage.write('key', {'data': 'value'}, tx.id);
await tm.commit(tx.id);
// or: await tm.rollback(tx.id);
```

---

## Migration

```dart
final engine = MigrationEngine(box);
final diffs = engine.detectChanges(definition);
```

---

## API Reference

### UmayBox

| Method                     | Description                     |
|----------------------------|---------------------------------|
| `UmayBox.open(name)`       | Open or create a box            |
| `get(key)`                 | Get value by key                |
| `put(key, value)`          | Insert or update                |
| `delete(key)`              | Delete by key                   |
| `all()`                    | Get all records                 |
| `query<T>()`               | Start a query                   |
| `batchPut(map)`            | Batch insert                    |
| `batchDelete(keys)`        | Batch delete                    |
| `contains(key)`            | Check key existence             |
| `count()`                  | Total record count              |
| `compact()`                | Run compaction                  |
| `watch()`                  | Stream of ChangeEvents          |
| `watchKey(key)`            | Stream for a specific key       |
| `close()`                  | Close the box                   |

### UmayModel

| Method                            | Description                     |
|-----------------------------------|---------------------------------|
| `UmayModel.register<T>()`         | Register model with box         |
| `UmayModel.find<T>(id)`           | Find by ID                      |
| `UmayModel.create<T>(data)`       | Create new record               |
| `UmayModel.query<T>()`            | Start query                     |
| `save()`                          | Persist changes                 |
| `delete()`                        | Delete record                   |
| `setAttribute(key, value)`        | Set attribute                   |
| `getAttribute(key)`               | Get attribute                   |
| `toMap()`                         | Serialize to map                |
| `toJson()`                        | Serialize to JSON               |
| `isDirty()`                       | Check for unsaved changes       |
| `getDirty()`                      | Get changed attributes          |
| `syncOriginal()`                  | Reset dirty tracking            |

---

## License

MIT
