import 'dart:io';

import 'package:umay_db/umay_db.dart';

Future<void> main(List<String> args) async {
  TypeRegistry.registerAdapter(MapAdapter());

  final dir = await Directory.systemTemp.createTemp('umay_example_');

  try {
    await basicCrud(dir.path);
    await queryBuilder(dir.path);
  } finally {
    await dir.delete(recursive: true);
  }
}

Future<void> basicCrud(String directory) async {
  print('=== Basic CRUD ===');

  final box = await UmayBox.open('users', directory: directory);

  await box.put('user:1', {
    'name': 'Alice',
    'email': 'alice@example.com',
    'age': 30,
  });

  final user = await box.get('user:1');
  print('  get: $user');

  await box.batchPut([
    MapEntry('user:2', {'name': 'Bob', 'email': 'bob@example.com', 'age': 25}),
    MapEntry('user:3', {
      'name': 'Charlie',
      'email': 'charlie@example.com',
      'age': 35,
    }),
  ]);

  final all = await box.all();
  print('  all (${all.length} records): '
      '${all.map((e) => e['name']).toList()}');

  await box.put('user:1', {
    'name': 'Alice Updated',
    'email': 'alice@example.com',
    'age': 31,
  });

  await box.delete('user:2');
  final remaining = await box.all();
  print('  after delete (${remaining.length} records)');

  await box.close();
  print('');
}

Future<void> queryBuilder(String directory) async {
  print('=== Query Builder ===');

  final box = await UmayBox.open('products', directory: directory);

  await box.batchPut([
    MapEntry('p:1', {'name': 'Laptop', 'price': 1200, 'inStock': true}),
    MapEntry('p:2', {'name': 'Mouse', 'price': 25, 'inStock': true}),
    MapEntry('p:3', {'name': 'Keyboard', 'price': 75, 'inStock': false}),
    MapEntry('p:4', {'name': 'Monitor', 'price': 400, 'inStock': true}),
  ]);

  final results = await box.query()
      .where((p) => p.price > 100)
      .orderBy((p) => p.price)
      .find();

  print('  products > \$100: ${results.map((r) => r['name']).toList()}');

  final inStock = await box.scan((obj) => obj['inStock'] == true);
  print('  in stock: ${inStock.length} products');

  await box.close();
  print('');
}
