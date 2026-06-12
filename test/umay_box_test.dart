import 'dart:io';

import 'package:test/test.dart';
import 'package:umay_db/umay_db.dart';

void main() {
  setUpAll(() {
    TypeRegistry.registerAdapter(MapAdapter());
  });

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('umay_box_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('writes and reads many records without losing index entries', () async {
    final box = await UmayBox.open('records', directory: tempDir.path);

    const count = 10000;
    for (var i = 0; i < count; i++) {
      await box.put('user:$i', {
        'id': i,
        'name': 'User $i',
        'active': i.isEven,
      });
    }

    expect(box.indexKeys().length, count);
    expect(await box.get('user:0'), {
      'id': 0,
      'name': 'User 0',
      'active': true,
    });
    expect(await box.get('user:9999'), {
      'id': 9999,
      'name': 'User 9999',
      'active': false,
    });

    await box.close();
  });

  test('updates replace the live value and survive reopen', () async {
    var box = await UmayBox.open('records', directory: tempDir.path);

    await box.put('user:1', {'id': 1, 'name': 'Before'});
    await box.put('user:1', {'id': 1, 'name': 'After'});
    await box.close();

    box = await UmayBox.open('records', directory: tempDir.path);

    expect(box.indexKeys().toList(), ['user:1']);
    expect(await box.get('user:1'), {'id': 1, 'name': 'After'});

    await box.close();
  });

  test('physical deletes stay deleted after reopen', () async {
    var box = await UmayBox.open('records', directory: tempDir.path);

    await box.put('keep', {'id': 1});
    await box.put('delete', {'id': 2});
    await box.delete('delete');
    await box.close();

    box = await UmayBox.open('records', directory: tempDir.path);

    expect(await box.get('keep'), {'id': 1});
    expect(await box.get('delete'), isNull);
    expect(box.indexKeys().toList(), ['keep']);

    await box.close();
  });

  test('batchPut and batchDelete keep reads and recovery consistent', () async {
    var box = await UmayBox.open('records', directory: tempDir.path);

    await box.batchPut(List.generate(
      1000,
      (i) => MapEntry('item:$i', {'id': i, 'group': i % 10}),
    ));
    await box.batchDelete(['item:1', 'item:3', 'item:5']);
    await box.close();

    box = await UmayBox.open('records', directory: tempDir.path);

    expect(box.indexKeys().length, 997);
    expect(await box.get('item:0'), {'id': 0, 'group': 0});
    expect(await box.get('item:1'), isNull);
    expect(await box.get('item:5'), isNull);
    expect(await box.get('item:999'), {'id': 999, 'group': 9});

    await box.close();
  });
}
