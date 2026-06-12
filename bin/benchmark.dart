import 'dart:io';

import 'package:umay_db/umay_db.dart';

const _defaultCount = 1000000;
const _defaultChunkSize = 10000;

Future<void> main(List<String> args) async {
  TypeRegistry.registerAdapter(MapAdapter());

  final count = _readIntArg(args, 'count') ?? _defaultCount;
  final chunkSize = _readIntArg(args, 'chunk-size') ?? _defaultChunkSize;
  final selectedCase = _readStringArg(args, 'case') ?? 'all';
  final progress = _readBoolArg(args, 'progress');

  final tempDir = await Directory.systemTemp.createTemp('umay_benchmark_');

  stdout.writeln('Umay benchmark');
  stdout.writeln('records: $count');
  stdout.writeln('chunk size: $chunkSize');
  stdout.writeln('directory: ${tempDir.path}');
  stdout.writeln('');

  try {
    if (selectedCase == 'all' || selectedCase == 'create') {
      await _benchmarkCreate(tempDir.path, count, chunkSize, progress);
    }

    if (selectedCase == 'all' || selectedCase == 'update') {
      await _benchmarkUpdate(tempDir.path, count, chunkSize, progress);
    }

    if (selectedCase == 'all' || selectedCase == 'delete') {
      await _benchmarkDelete(tempDir.path, count, chunkSize, progress);
    }
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<void> _benchmarkCreate(
  String directory,
  int count,
  int chunkSize,
  bool progress,
) async {
  await _deleteBoxFiles(directory, 'create');
  final openWatch = Stopwatch()..start();
  final box = await UmayBox.open('create', directory: directory);
  openWatch.stop();

  final operationWatch = Stopwatch()..start();
  await _batchPutRecords(
    box: box,
    name: 'create',
    count: count,
    chunkSize: chunkSize,
    progress: progress,
    valueBuilder: _record,
  );
  operationWatch.stop();

  final closeWatch = Stopwatch()..start();
  await box.close();
  closeWatch.stop();

  await _printResult(
    name: 'create',
    directory: directory,
    boxName: 'create',
    count: count,
    openElapsed: openWatch.elapsed,
    seedElapsed: Duration.zero,
    operationElapsed: operationWatch.elapsed,
    closeElapsed: closeWatch.elapsed,
  );
}

Future<void> _benchmarkUpdate(
  String directory,
  int count,
  int chunkSize,
  bool progress,
) async {
  await _deleteBoxFiles(directory, 'update');
  final openWatch = Stopwatch()..start();
  final box = await UmayBox.open('update', directory: directory);
  openWatch.stop();

  final seedWatch = Stopwatch()..start();
  await _seed(box, count, chunkSize, progress);
  seedWatch.stop();

  final operationWatch = Stopwatch()..start();
  await _batchPutRecords(
    box: box,
    name: 'update',
    count: count,
    chunkSize: chunkSize,
    progress: progress,
    valueBuilder: (i) => {
      ..._record(i),
      'updated': true,
      'version': 2,
    },
  );
  operationWatch.stop();

  final closeWatch = Stopwatch()..start();
  await box.close();
  closeWatch.stop();

  await _printResult(
    name: 'update',
    directory: directory,
    boxName: 'update',
    count: count,
    openElapsed: openWatch.elapsed,
    seedElapsed: seedWatch.elapsed,
    operationElapsed: operationWatch.elapsed,
    closeElapsed: closeWatch.elapsed,
  );
}

Future<void> _benchmarkDelete(
  String directory,
  int count,
  int chunkSize,
  bool progress,
) async {
  await _deleteBoxFiles(directory, 'delete');
  final openWatch = Stopwatch()..start();
  final box = await UmayBox.open('delete', directory: directory);
  openWatch.stop();

  final seedWatch = Stopwatch()..start();
  await _seed(box, count, chunkSize, progress);
  seedWatch.stop();

  final operationWatch = Stopwatch()..start();
  await _batchDeleteRecords(
    box: box,
    name: 'delete',
    count: count,
    chunkSize: chunkSize,
    progress: progress,
  );
  operationWatch.stop();

  final closeWatch = Stopwatch()..start();
  await box.close();
  closeWatch.stop();

  await _printResult(
    name: 'delete',
    directory: directory,
    boxName: 'delete',
    count: count,
    openElapsed: openWatch.elapsed,
    seedElapsed: seedWatch.elapsed,
    operationElapsed: operationWatch.elapsed,
    closeElapsed: closeWatch.elapsed,
  );
}

Future<void> _seed(
  UmayBox box,
  int count,
  int chunkSize,
  bool progress,
) async {
  await _batchPutRecords(
    box: box,
    name: 'seed',
    count: count,
    chunkSize: chunkSize,
    progress: progress,
    valueBuilder: _record,
  );
}

Future<void> _batchPutRecords({
  required UmayBox box,
  required String name,
  required int count,
  required int chunkSize,
  required bool progress,
  required Map<String, dynamic> Function(int index) valueBuilder,
}) async {
  for (var start = 0; start < count; start += chunkSize) {
    final end = start + chunkSize > count ? count : start + chunkSize;
    final chunkWatch = Stopwatch()..start();
    await box.batchPut([
      for (var i = start; i < end; i++)
        MapEntry('record:$i', valueBuilder(i)),
    ]);
    chunkWatch.stop();
    if (progress) {
      _printProgress(name, end, count, end - start, chunkWatch.elapsed);
    }
  }
}

Future<void> _batchDeleteRecords({
  required UmayBox box,
  required String name,
  required int count,
  required int chunkSize,
  required bool progress,
}) async {
  for (var start = 0; start < count; start += chunkSize) {
    final end = start + chunkSize > count ? count : start + chunkSize;
    final chunkWatch = Stopwatch()..start();
    await box.batchDelete([
      for (var i = start; i < end; i++) 'record:$i',
    ]);
    chunkWatch.stop();
    if (progress) {
      _printProgress(name, end, count, end - start, chunkWatch.elapsed);
    }
  }
}

Map<String, dynamic> _record(int index) {
  return {
    'id': index,
    'name': 'Record $index',
    'email': 'record$index@example.com',
    'active': index.isEven,
    'score': index % 1000,
  };
}

Future<void> _printResult({
  required String name,
  required String directory,
  required String boxName,
  required int count,
  required Duration openElapsed,
  required Duration seedElapsed,
  required Duration operationElapsed,
  required Duration closeElapsed,
}) async {
  final totalElapsed =
      openElapsed + seedElapsed + operationElapsed + closeElapsed;
  final seconds =
      operationElapsed.inMicroseconds / Duration.microsecondsPerSecond;
  final opsPerSecond = seconds == 0 ? 0 : count / seconds;
  final dbSize = await _fileLength('$directory/$boxName.db');
  final hintSize = await _fileLength('$directory/$boxName.hint');
  final indexSize = await _fileLength('$directory/$boxName.idx');

  stdout.writeln('$name:');
  stdout.writeln('  records: $count');
  stdout.writeln('  open: ${_formatDuration(openElapsed)}');
  if (seedElapsed > Duration.zero) {
    stdout.writeln('  seed: ${_formatDuration(seedElapsed)}');
  }
  stdout.writeln('  operation: ${_formatDuration(operationElapsed)}');
  stdout.writeln('  close: ${_formatDuration(closeElapsed)}');
  stdout.writeln('  total: ${_formatDuration(totalElapsed)}');
  stdout.writeln('  ops/sec: ${opsPerSecond.toStringAsFixed(2)}');
  stdout.writeln('  db size: ${_formatBytes(dbSize)}');
  stdout.writeln('  hint size: ${_formatBytes(hintSize)}');
  stdout.writeln('  index size: ${_formatBytes(indexSize)}');
  stdout.writeln('  rss: ${_formatBytes(ProcessInfo.currentRss)}');
  stdout.writeln('');
}

void _printProgress(
  String name,
  int done,
  int total,
  int chunkCount,
  Duration elapsed,
) {
  final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  final opsPerSecond = seconds == 0 ? 0 : chunkCount / seconds;
  final percent = total == 0 ? 100 : (done * 100 / total);

  stdout.writeln(
    '$name progress: $done/$total '
    '(${percent.toStringAsFixed(1)}%) '
    '${opsPerSecond.toStringAsFixed(2)} ops/sec',
  );
}

String _formatDuration(Duration duration) {
  final seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;
  return '${seconds.toStringAsFixed(3)}s';
}

String _formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;

  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }

  return '${value.toStringAsFixed(unit == 0 ? 0 : 2)} ${units[unit]}';
}

Future<int> _fileLength(String path) async {
  final file = File(path);
  if (!await file.exists()) return 0;
  return file.length();
}

Future<void> _deleteBoxFiles(String directory, String name) async {
  for (final extension in ['db', 'hint', 'idx']) {
    final file = File('$directory/$name.$extension');
    if (await file.exists()) {
      await file.delete();
    }
  }
}

int? _readIntArg(List<String> args, String name) {
  final value = _readStringArg(args, name);
  if (value == null) return null;
  return int.tryParse(value);
}

String? _readStringArg(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) {
      return arg.substring(prefix.length);
    }
  }
  return null;
}

bool _readBoolArg(List<String> args, String name) {
  final value = _readStringArg(args, name);
  if (value != null) {
    return value == 'true' || value == '1' || value == 'yes';
  }
  return args.contains('--$name');
}
