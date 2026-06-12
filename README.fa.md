<table>
<tr>
<td width="50%"><img src="https://raw.githubusercontent.com/pishguy/umay/main/logo.png" width="300" alt="UmayDB"></td>
<td width="50%" valign="middle">

## UmayDB

یک دیتابیس NoSQL جاسازی‌شده، سبک و قدرتمند برای **Flutter** و **Dart**، با الهام از **Laravel Eloquent** و معماری **Bitcask**.

</td>
</tr>
</table>

<div align="center">
  <a href="README.md">English</a> | <strong>فارسی</strong> | <a href="README.az.md">Azərbaycanca</a>
</div>

---

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
  umay_db: ^1.1.1
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
