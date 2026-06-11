<table>
<tr>
<td width="50%"><img src="https://raw.githubusercontent.com/pishguy/umay/main/logo.png" width="300" alt="UmayDB"></td>
<td width="50%" valign="middle">

## UmayDB

**UmayDB** — Dart və Flutter üçün yüngül, quraşdırılmış NoSQL verilənlər bazasıdır. **Laravel Eloquent** ORM və **Bitcask** saxlama arxitekturasından ilhamlanmışdır.

</td>
</tr>
</table>

<div align="center">
  <a href="README.md">English</a> | <a href="README.fa.md">فارسی</a> | <strong>Azərbaycanca</strong>
</div>

---

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
  umay_db: ^1.0.1
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

## API Reference

### UmayBox

| Metod                          | Təsvir                           |
|--------------------------------|----------------------------------|
| `UmayBox.open(name)`           | Qutunu aç və ya yarat            |
| `get(key)`                     | Açar ilə dəyəri əldə et          |
| `put(key, value)`              | Əlavə et və ya yenilə            |
| `delete(key)`                  | Açar ilə sil                     |
| `all()`                        | Bütün qeydləri əldə et           |
| `query<T>()`                   | Sorğuya başla                    |
| `batchPut(map)`                | Toplu əlavə                      |
| `batchDelete(keys)`            | Toplu sil                        |
| `contains(key)`                | Açarın mövcudluğunu yoxla        |
| `count()`                      | Ümumi qeyd sayı                  |
| `compact()`                    | Kompaktlaşdırma                  |
| `watch()`                      | ChangeEvents axını               |
| `watchKey(key)`                | Müəyyən açar üçün axın           |
| `close()`                      | Qutunu bağla                     |

### UmayModel

| Metod                                | Təsvir                           |
|--------------------------------------|----------------------------------|
| `UmayModel.register<T>()`            | Modeli qutu ilə qeydiyyatdan keçir |
| `UmayModel.find<T>(id)`              | ID ilə axtar                     |
| `UmayModel.create<T>(data)`          | Yeni qeyd yarat                  |
| `UmayModel.query<T>()`               | Sorğuya başla                    |
| `save()`                             | Dəyişiklikləri yadda saxla       |
| `delete()`                           | Qeydi sil                        |
| `setAttribute(key, value)`           | Atributu təyin et                |
| `getAttribute(key)`                  | Atributu əldə et                 |
| `toMap()`                            | Map-ə çevir                      |
| `toJson()`                           | JSON-a çevir                     |
| `isDirty()`                          | Saxlanılmamış dəyişiklikləri yoxla |
| `getDirty()`                         | Dəyişdirilmiş atributları əldə et |
| `syncOriginal()`                     | Dəyişiklik izləməni sıfırla      |

---

## Lisenziya

MIT
