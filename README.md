<table>
<tr>
<td width="50%"><img src="6c708cc6-73a1-42a2-a557-f2a2478bbd0b.png" width="300" alt="UmayDB"></td>
<td width="50%" valign="middle">

## UmayDB

UmayDB is a lightweight embedded NoSQL database for Dart and Flutter, inspired by Laravel Eloquent ORM and Bitcask storage architecture.

</td>
</tr>
</table>

<div align="center">
  <a href="#en">English</a> | <a href="#fa">فارسی</a> | <a href="#az">Azərbaycanca</a>
</div>

---

<a name="en"></a>

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
  umay_db:
    git:
      url: https://github.com/pishguy/umay.git
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

---

<br>

<a name="fa"></a>

<div dir="rtl">

# UmayDB

یک دیتابیس NoSQL جاسازی‌شده، سبک و قدرتمند برای **Flutter** و **Dart**، با الهام از **Laravel Eloquent** و معماری **Bitcask**.

## ویژگی‌ها

- **ORM فعال (Active Record)** — مدل `UmayModel` به سبک Laravel با fillable، guarded، hidden، casts، accessors و mutators
- **ذخیره‌سازی پیوسته (Append-only Log)** — عملکرد بالا با فایل‌های `.db` / `.hint` / `.idx`
- **سازنده کوئری به سبک LINQ** — کوئری‌های نوع‌امن expressive با proxy objects
- **ایندکس‌های ثانویه** — ایندکس‌های B+Tree خودکار برای جستجوی سریع
- **ایندکس‌های ترکیبی** — ایندکس‌های چند فیلدی
- **ایندکس‌های یکتا** — اعمال یکتایی با B+Tree
- **کوئری‌های محدوده** — `gt`، `lt`، `gte`، `lte`، `between` با B+Tree
- **جستجوی فازی** — جستجوی فازی مبتنی بر Trigram با امتیاز Levenshtein
- **حذف نرم (Soft Deletes)** — mixin `SoftDeletes` با `trashed`، `restore()`، `withTrashed()` و `onlyTrashed()`
- **روابط (Relations)** — `HasMany`، `BelongsTo`، `HasOne`، `ManyToMany`، `MorphMany`، `MorphTo`
- **بارگذاری مشتاق (Eager Loading)** — بارگذاری روابط تو در تو با نقطه (`"posts.comments"`)
- **whereHas / withCount** — فیلتر بر اساس مدل‌های مرتبط، بارگذاری تعداد روابط
- **کوئری‌های reactive** — نتایج زنده با `watch()`
- **تراکنش‌های MVCC** — تراکنش‌های ایزوله با commit/rollback
- **فشرده‌سازی خودکار** — garbage collection در پس‌زمینه با سیاست قابل تنظیم
- **سیستم رویداد (Event System)** — رویدادهای چرخه حیات مدل: `creating`، `created`، `updating`، `updated`، `deleting`، `deleted`
- **روابط چندریختی (Polymorphic)** — `MorphMany` / `MorphTo` برای روابط چند مدلی
- **بهینه‌ساز کوئری** — انتخاب خودکار ایندکس: composite → single → range → full scan
- **کش (Caching)** — کش نتایج کوئری (تا ۵۰۰ ورودی)
- **عادی‌سازی متن فارسی** — تبدیل خودکار عربی به فارسی برای جستجوی فارسی
- **بدون وابستگی runtime** —純 Dart، فقط از `dart:io`، `dart:async`، `dart:collection`

---

## شروع کار

### اضافه کردن وابستگی

```yaml
dependencies:
  umay_db:
    git:
      url: https://github.com/pishguy/umay.git
```

### استفاده پایه

```dart
import 'package:umay_db/umay_db.dart';

final box = await UmayBox.open('users');

// درج
await box.put('user:1', {'name': 'Ali', 'email': 'ali@example.com', 'age': 30});

// خواندن
final user = await box.get('user:1');
print(user['name']); // Ali

// حذف
await box.delete('user:1');

// بستن
await box.close();
```

---

## مدل ORM

یک کلاس مدل که `UmayModel` را extends کند تعریف کنید:

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

### ثبت مدل

```dart
final box = await UmayBox.open('users');
UmayModel.register<User>(() => User(), box: box);
```

### عملیات CRUD

```dart
// ایجاد
final user = await UmayModel.create<User>({
  'name': 'Ali',
  'email': 'ali@example.com',
  'role': 'admin',
  'age': 28,
});

// جستجو
final found = await UmayModel.find<User>(userId);

// بروزرسانی
found!.setAttribute('age', 29);
await found.save();

// حذف
await found.delete();
```

---

## کوئری‌ها

### کوئری ساده

```dart
final results = await box.query<User>()
    .where((u) => (u as dynamic).role.eq('admin'))
    .orderBy((u) => (u as dynamic).name)
    .find();
```

### مقایسه‌ها

```dart
// eq, notEq, gt, lt, gte, lte
query.where((u) => (u as dynamic).age >= 18);

// contains, startsWith, endsWith
query.where((u) => (u as dynamic).name.contains('Ali'));

// IN
query.whereIn('role', ['admin', 'editor']);

// Between
query.whereBetween('age', 18, 65);

// بررسی null
query.whereNull('deleted_at');
```

### صفحه‌بندی و مرتب‌سازی

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

### جستجوی فازی

```dart
final results = await box.query<User>()
    .where((u) => (u as dynamic).name.fuzzy('عل'))
    .orderBy((u) => (u as dynamic).name)
    .find();
```

---

## حذف نرم (Soft Deletes)

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
await post!.delete();     // مقدار deleted_at را تنظیم می‌کند
print(post.isDeleted);    // true
await post.restore();     // مقدار deleted_at را پاک می‌کند

// کوئری معمولی — رکوردهای حذف نرم شده نشان داده نمی‌شوند
final posts = await box.query<Post>().find();

// همراه با حذف شده‌ها
final all = await box.query<Post>().withTrashed().find();

// فقط حذف شده‌ها
final trashed = await box.query<Post>().onlyTrashed().find();
```

---

## روابط (Relations)

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

### بارگذاری مشتاق (Eager Loading)

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

## معماری

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

## ذخیره‌سازی (Storage)

هر باکس دیتابیس از سه فایل تشکیل شده است:

| فایل      | توضیحات                            |
|-----------|-------------------------------------|
| `.db`     | لاگ پیوسته رکوردها (کلید + مقدار)   |
| `.hint`   | ایندکس کلید → offset برای بازیابی سریع |
| `.idx`    | snapshot دائمی از ایندکس             |

در زمان راه‌اندازی، باکس به ترتیب زیر بازیابی می‌شود:
1. خواندن snapshot `.idx` (سریع‌ترین)
2. خواندن فایل `.hint` برای ورودی‌های اخیر
3. اسکن کامل `.db` در صورت نیاز

فشرده‌سازی به صورت خودکار در پس‌زمینه اجرا می‌شود (هر ۶۰ ثانیه اگر نسبت garbage > 30%) یا به صورت دستی با `box.compact()`.

---

## کوئری‌ها و ایندکس‌ها

### انواع ایندکس

| ایندکس     | ساختار     | کاربرد                          |
|------------|------------|---------------------------------|
| Secondary  | HashMap    | جستجوی برابری O(1)              |
| Range      | B+Tree     | کوئری‌های محدوده (gt, lt, between) |
| Unique     | B+Tree     | اعمال یکتایی                    |
| Compound   | B+Tree     | کوئری‌های چند فیلدی             |
| Fuzzy      | Trigram map| جستجوی تقریبی متن               |

### استراتژی بهینه‌ساز کوئری

1. **ایندکس ترکیبی** — اگر همه فیلدها با یک ایندکس ترکیبی مطابقت داشته باشند
2. **برابری تکی** — سریع‌ترین (O(1) با HashMap)
3. **ایندکس محدوده** — اسکن محدوده B+Tree
4. **اسکن کامل** — اسکان خطی همه رکوردها (پیش‌فرض)

---

## رویدادها (Events)

```dart
UmayModel.events.on<User>(ModelEventType.created, (event) {
  print('کاربر ساخته شد: ${event.model?.getAttribute('name')}');
});
```

رویدادهای موجود: `creating`، `created`، `updating`، `updated`، `deleting`، `deleted`، `saving`، `saved`.

---

## تراکنش‌ها (MVCC)

```dart
final tm = TransactionManager(mvccStorage);

final tx = await tm.begin();
await mvccStorage.write('key', {'data': 'value'}, tx.id);
await tm.commit(tx.id);
// یا: await tm.rollback(tx.id);
```

---

## API Reference

### UmayBox

| متد                           | توضیحات                         |
|-------------------------------|----------------------------------|
| `UmayBox.open(name)`          | باز کردن یا ایجاد یک باکس        |
| `get(key)`                    | دریافت مقدار با کلید             |
| `put(key, value)`             | درج یا بروزرسانی                 |
| `delete(key)`                 | حذف با کلید                      |
| `all()`                       | دریافت همه رکوردها               |
| `query<T>()`                  | شروع یک کوئری                    |
| `batchPut(map)`               | درج گروهی                        |
| `batchDelete(keys)`           | حذف گروهی                        |
| `contains(key)`               | بررسی وجود کلید                  |
| `count()`                     | تعداد کل رکوردها                 |
| `compact()`                   | اجرای فشرده‌سازی                 |
| `watch()`                     | stream از ChangeEvents           |
| `watchKey(key)`               | stream برای یک کلید مشخص         |
| `close()`                     | بستن باکس                        |

### UmayModel

| متد                                 | توضیحات                         |
|-------------------------------------|----------------------------------|
| `UmayModel.register<T>()`           | ثبت مدل با باکس                  |
| `UmayModel.find<T>(id)`             | جستجو با ID                      |
| `UmayModel.create<T>(data)`         | ایجاد رکورد جدید                 |
| `UmayModel.query<T>()`              | شروع کوئری                       |
| `save()`                            | ذخیره تغییرات                    |
| `delete()`                          | حذف رکورد                        |
| `setAttribute(key, value)`          | تنظیم attribute                  |
| `getAttribute(key)`                 | دریافت attribute                 |
| `toMap()`                           | تبدیل به Map                     |
| `toJson()`                          | تبدیل به JSON                    |
| `isDirty()`                         | بررسی تغییرات ذخیره نشده         |
| `getDirty()`                        | دریافت attributeهای تغییر کرده   |
| `syncOriginal()`                    | ریست کردن ردیابی تغییرات         |

---

## مجوز (License)

MIT

</div>

---

<br>

<a name="az"></a>

# UmayDB

**UmayDB** — Dart və Flutter üçün yüngül, quraşdırılmış NoSQL verilənlər bazasıdır. **Laravel Eloquent** ORM və **Bitcask** saxlama arxitekturasından ilhamlanmışdır.

## Xüsusiyyətlər

- **Active Record ORM** — Laravel üslubunda `UmayModel` ilə fillable, guarded, hidden, casts, accessors, mutators
- **Append-only Log Storage** — `.db` / `.hint` / `.idx` faylları ilə yüksək performanslı jurnal
- **LINQ üslubunda Query Builder** — Proxy obyektləri ilə ifadəli tip-təhlükəsiz sorğular
- **İkinci dərəcəli indekslər** — Sürətli axtarış üçün avtomatik idarə olunan B+Tree indeksləri
- **Kompozit indekslər** — Çox sahəli indekslər
- **Unikal indekslər** — B+Tree ilə unikallığın təmin edilməsi
- **Range sorğuları** — B+Tree vasitəsilə `gt`, `lt`, `gte`, `lte`, `between`
- **Fuzzy axtarış** — Levenshtein ballaması ilə Trigram əsaslı fuzzy axtarış
- **Soft Deletes** — `SoftDeletes` mixini ilə `trashed`, `restore()`, `withTrashed()`, `onlyTrashed()`
- **Əlaqələr (Relations)** — `HasMany`, `BelongsTo`, `HasOne`, `ManyToMany`, `MorphMany`, `MorphTo`
- **Eager Loading** — Nöqtə notasiyası ilə iç-içə əlaqələrin yüklənməsi (`"posts.comments"`)
- **whereHas / withCount** — Əlaqəli modellərə görə filtrləmə, əlaqə saylarının yüklənməsi
- **Reaktiv sorğular** — `watch()` vasitəsilə canlı nəticələr
- **MVCC tranzaksiyaları** — commit/rollback ilə izolyasiya olunmuş tranzaksiyalar
- **Avtomatik kompaktlaşdırma** — Konfiqurasiya oluna bilən siyasətlə fon təmizləmə
- **Change Bus** — Reaktiv interfeyslər üçün `ChangeEvent` yayım axını
- **Event Sistemi** — Model həyat dövrü hadisələri: `creating`, `created`, `updating`, `updated`, `deleting`, `deleted`
- **Polimorfik əlaqələr** — Çox modelli əlaqələr üçün `MorphMany` / `MorphTo`
- **Sorğu optimallaşdırıcısı** — Avtomatik indeks seçimi: composite → single → range → full scan
- **Keş (Caching)** — Sorğu nəticələrinin keşi (500 girişə qədər)
- **Fars mətninin normallaşdırılması** — Fars axtarışı üçün ərəb→fars çevirmə
- **Sıfır runtime asılılığı** — Təmiz Dart, yalnız `dart:io`, `dart:async`, `dart:collection`

---

## Başlamaq

### Asılılığı əlavə edin

```yaml
dependencies:
  umay_db:
    git:
      url: https://github.com/pishguy/umay.git
```

### Əsas istifadə

```dart
import 'package:umay_db/umay_db.dart';

final box = await UmayBox.open('users');

// Əlavə et
await box.put('user:1', {'name': 'Ali', 'email': 'ali@example.com', 'age': 30});

// Oxu
final user = await box.get('user:1');
print(user['name']); // Ali

// Sil
await box.delete('user:1');

// Bağla
await box.close();
```

---

## ORM Model

`UmayModel`-i extends edən bir model sinifi təyin edin:

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

### Qeydiyyat

```dart
final box = await UmayBox.open('users');
UmayModel.register<User>(() => User(), box: box);
```

### CRUD əməliyyatları

```dart
// Yarat
final user = await UmayModel.create<User>({
  'name': 'Ali',
  'email': 'ali@example.com',
  'role': 'admin',
  'age': 28,
});

// Tap
final found = await UmayModel.find<User>(userId);

// Yenilə
found!.setAttribute('age', 29);
await found.save();

// Sil
await found.delete();
```

---

## Sorğular

### Sadə sorğu

```dart
final results = await box.query<User>()
    .where((u) => (u as dynamic).role.eq('admin'))
    .orderBy((u) => (u as dynamic).name)
    .find();
```

### Müqayisələr

```dart
// eq, notEq, gt, lt, gte, lte
query.where((u) => (u as dynamic).age >= 18);

// contains, startsWith, endsWith
query.where((u) => (u as dynamic).name.contains('Ali'));

// IN
query.whereIn('role', ['admin', 'editor']);

// Between
query.whereBetween('age', 18, 65);

// Null yoxlaması
query.whereNull('deleted_at');
```

### Səhifələmə və sıralama

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

### Fuzzy axtarış

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
await post!.delete();     // deleted_at təyin edir
print(post.isDeleted);    // true
await post.restore();     // deleted_at təmizləyir

// Adi sorğu — soft-deleted qeydlər göstərilmir
final posts = await box.query<Post>().find();

// Silinmişlər də daxil olmaqla
final all = await box.query<Post>().withTrashed().find();

// Yalnız silinmişlər
final trashed = await box.query<Post>().onlyTrashed().find();
```

---

## Əlaqələr (Relations)

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

### Eager Loading

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

## Arxitektura

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

## Saxlama (Storage)

Hər bir verilənlər bazası qutusu üç fayldan ibarətdir:

| Fayl     | Təsvir                            |
|----------|-----------------------------------|
| `.db`    | Append-only qeyd jurnalı (açar + dəyər) |
| `.hint`  | Sürətli bərpa üçün açar → offset indeksi |
| `.idx`   | İndeksin daimi snapshot-ı         |

Başlanğıcda qutu aşağıdakı ardıcıllıqla bərpa olunur:
1. `.idx` snapshot-ının oxunması (ən sürətli)
2. Son qeydlər üçün `.hint` faylının oxunması
3. Lazım olduqda `.db`-nin tam skani

Kompaktlaşdırma avtomatik olaraq fonda işləyir (hər 60 saniyədə zibil nisbəti > 30% olduqda) və ya əl ilə `box.compact()` vasitəsilə.

---

## Sorğular və İndekslər

### İndeks növləri

| İndeks      | Quruluş    | İstifadə                       |
|-------------|------------|--------------------------------|
| Secondary   | HashMap    | O(1) bərabərlik axtarışı       |
| Range       | B+Tree     | Range sorğuları (gt, lt, between) |
| Unique      | B+Tree     | Unikallığın təmin edilməsi     |
| Compound    | B+Tree     | Çox sahəli sorğular            |
| Fuzzy       | Trigram map| Təxmini mətn axtarışı          |

### Sorğu optimallaşdırıcı strategiyası

1. **Kompozit indeks** — bütün sahələr uyğun gəlirsə
2. **Tək bərabərlik** — ən sürətli (O(1) HashMap axtarışı)
3. **Range indeksi** — B+Tree range skani
4. **Tam skan** — bütün qeydlərin xətti skani (ehtiyat)

---

## Hadisələr (Events)

```dart
UmayModel.events.on<User>(ModelEventType.created, (event) {
  print('İstifadəçi yaradıldı: ${event.model?.getAttribute('name')}');
});
```

Mövcud hadisələr: `creating`, `created`, `updating`, `updated`, `deleting`, `deleted`, `saving`, `saved`.

---

## Tranzaksiyalar (MVCC)

```dart
final tm = TransactionManager(mvccStorage);

final tx = await tm.begin();
await mvccStorage.write('key', {'data': 'value'}, tx.id);
await tm.commit(tx.id);
// və ya: await tm.rollback(tx.id);
```

---

## Lisenziya

MIT

---

<br>
