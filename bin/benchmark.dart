import 'dart:convert';
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
  final chart = _readBoolArg(args, 'chart');
  final json = _readBoolArg(args, 'json');

  final tempDir = await Directory.systemTemp.createTemp('umay_benchmark_');
  final results = <BenchmarkResult>[];

  stdout.writeln('Umay benchmark');
  stdout.writeln('records: $count');
  stdout.writeln('chunk size: $chunkSize');
  stdout.writeln('directory: ${tempDir.path}');
  stdout.writeln('');

  try {
    if (selectedCase == 'all' || selectedCase == 'create') {
      final r = await _benchmarkCreate(tempDir.path, count, chunkSize, progress);
      results.add(r);
    }

    if (selectedCase == 'all' || selectedCase == 'update') {
      final r = await _benchmarkUpdate(tempDir.path, count, chunkSize, progress);
      results.add(r);
    }

    if (selectedCase == 'all' || selectedCase == 'delete') {
      final r = await _benchmarkDelete(tempDir.path, count, chunkSize, progress);
      results.add(r);
    }
  } finally {
    await tempDir.delete(recursive: true);
  }

  if (chart && results.isNotEmpty) {
    final html = _generateChartHtml(results, count);
    final file = File('benchmark_${DateTime.now().millisecondsSinceEpoch}.html');
    await file.writeAsString(html);
    stdout.writeln('\nChart saved to: ${file.path}');
  }

  if (json && results.isNotEmpty) {
    final jsonStr = jsonEncode(results.map((r) => r.toJson()).toList());
    final file = File('benchmark_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(jsonStr);
    stdout.writeln('\nJSON saved to: ${file.path}');
  }
}

Future<BenchmarkResult> _benchmarkCreate(
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

  return _printResult(
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

Future<BenchmarkResult> _benchmarkUpdate(
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

  return _printResult(
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

Future<BenchmarkResult> _benchmarkDelete(
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

  return _printResult(
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

Future<BenchmarkResult> _printResult({
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
  final opsPerSecond = seconds == 0 ? 0.0 : count / seconds;
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

  return BenchmarkResult(
    name: name,
    count: count,
    openSeconds: _toSeconds(openElapsed),
    seedSeconds: _toSeconds(seedElapsed),
    operationSeconds: _toSeconds(operationElapsed),
    closeSeconds: _toSeconds(closeElapsed),
    totalSeconds: _toSeconds(totalElapsed),
    opsPerSecond: opsPerSecond,
    dbSize: dbSize,
    hintSize: hintSize,
    indexSize: indexSize,
    rss: ProcessInfo.currentRss,
  );
}

double _toSeconds(Duration d) =>
    d.inMicroseconds / Duration.microsecondsPerSecond;

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

String _generateChartHtml(List<BenchmarkResult> results, int count) {
  final labels = results.map((r) => r.name).toList();
  final opsData = results.map((r) => r.opsPerSecond.toStringAsFixed(1)).toList();
  final totalData = results.map((r) => r.totalSeconds.toStringAsFixed(3)).toList();
  final dbSizeData = results.map((r) => (r.dbSize / 1024 / 1024).toStringAsFixed(2)).toList();
  final openData = results.map((r) => r.openSeconds.toStringAsFixed(3)).toList();
  final operationData = results.map((r) => r.operationSeconds.toStringAsFixed(3)).toList();
  final closeData = results.map((r) => r.closeSeconds.toStringAsFixed(3)).toList();

  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>UmayDB Benchmark</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #e2e8f0; padding: 40px 20px; }
.container { max-width: 1100px; margin: 0 auto; }
h1 { font-size: 28px; margin-bottom: 8px; color: #fff; }
.subtitle { color: #94a3b8; margin-bottom: 32px; font-size: 14px; }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
.card { background: #1e293b; border-radius: 12px; padding: 24px; border: 1px solid #334155; }
.card.full { grid-column: 1 / -1; }
.card h2 { font-size: 16px; color: #94a3b8; margin-bottom: 16px; text-transform: uppercase; letter-spacing: 0.5px; }
.stats { display: flex; gap: 20px; flex-wrap: wrap; }
.stat { flex: 1; min-width: 120px; }
.stat-label { font-size: 12px; color: #64748b; }
.stat-value { font-size: 24px; font-weight: 700; color: #facc15; margin-top: 4px; }
canvas { max-height: 300px; }
@media (max-width: 768px) { .grid { grid-template-columns: 1fr; } }
</style>
</head>
<body>
<div class="container">
  <h1>UmayDB Benchmark</h1>
  <p class="subtitle">$count records &middot; ${DateTime.now().toString().split('.')[0]}</p>

  <div class="stats" style="margin-bottom: 20px;">
    ${results.map((r) => '''
    <div class="stat">
      <div class="stat-value" style="color: ${_colorFor(r.name)}">${r.opsPerSecond.toStringAsFixed(0)}</div>
      <div class="stat-label">${r.name} ops/sec</div>
    </div>
    ''').join()}
  </div>

  <div class="grid">
    <div class="card">
      <h2>Operations / Second</h2>
      <canvas id="opsChart"></canvas>
    </div>
    <div class="card">
      <h2>Total Time (seconds)</h2>
      <canvas id="timeChart"></canvas>
    </div>
    <div class="card">
      <h2>Time Breakdown</h2>
      <canvas id="breakdownChart"></canvas>
    </div>
    <div class="card">
      <h2>DB Size (MB)</h2>
      <canvas id="sizeChart"></canvas>
    </div>
  </div>
</div>

<script>
const labels = ${jsonEncode(labels)};

new Chart(document.getElementById('opsChart'), {
  type: 'bar',
  data: {
    labels,
    datasets: [{
      label: 'ops/sec',
      data: [${opsData.join(', ')}],
      backgroundColor: ['#3b82f6', '#facc15', '#ef4444'],
      borderRadius: 6,
    }]
  },
  options: { responsive: true, plugins: { legend: { display: false } },
    scales: { y: { beginAtZero: true, grid: { color: '#1e293b' } },
              x: { grid: { display: false } } } }
});

new Chart(document.getElementById('timeChart'), {
  type: 'bar',
  data: {
    labels,
    datasets: [{
      label: 'seconds',
      data: [${totalData.join(', ')}],
      backgroundColor: ['#3b82f6', '#facc15', '#ef4444'],
      borderRadius: 6,
    }]
  },
  options: { responsive: true, plugins: { legend: { display: false } },
    scales: { y: { beginAtZero: true, grid: { color: '#1e293b' } },
              x: { grid: { display: false } } } }
});

new Chart(document.getElementById('breakdownChart'), {
  type: 'bar',
  data: {
    labels,
    datasets: [
      { label: 'Open', data: [${openData.join(', ')}], backgroundColor: '#38bdf8' },
      { label: 'Operation', data: [${operationData.join(', ')}], backgroundColor: '#facc15' },
      { label: 'Close', data: [${closeData.join(', ')}], backgroundColor: '#a78bfa' },
    ]
  },
  options: { responsive: true, scales: { x: { stacked: true }, y: { stacked: true, beginAtZero: true, grid: { color: '#1e293b' } } } }
});

new Chart(document.getElementById('sizeChart'), {
  type: 'bar',
  data: {
    labels,
    datasets: [{
      label: 'DB Size (MB)',
      data: [${dbSizeData.join(', ')}],
      backgroundColor: ['#3b82f6', '#facc15', '#ef4444'],
      borderRadius: 6,
    }]
  },
  options: { responsive: true, plugins: { legend: { display: false } },
    scales: { y: { beginAtZero: true, grid: { color: '#1e293b' } },
              x: { grid: { display: false } } } }
});
</script>
</body>
</html>''';
}

String _colorFor(String name) {
  switch (name) {
    case 'create': return '#3b82f6';
    case 'update': return '#facc15';
    case 'delete': return '#ef4444';
    default: return '#94a3b8';
  }
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

class BenchmarkResult {
  final String name;
  final int count;
  final double openSeconds;
  final double seedSeconds;
  final double operationSeconds;
  final double closeSeconds;
  final double totalSeconds;
  final double opsPerSecond;
  final int dbSize;
  final int hintSize;
  final int indexSize;
  final int rss;

  const BenchmarkResult({
    required this.name,
    required this.count,
    required this.openSeconds,
    required this.seedSeconds,
    required this.operationSeconds,
    required this.closeSeconds,
    required this.totalSeconds,
    required this.opsPerSecond,
    required this.dbSize,
    required this.hintSize,
    required this.indexSize,
    required this.rss,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'count': count,
    'openSeconds': openSeconds,
    'seedSeconds': seedSeconds,
    'operationSeconds': operationSeconds,
    'closeSeconds': closeSeconds,
    'totalSeconds': totalSeconds,
    'opsPerSecond': opsPerSecond,
    'dbSize': dbSize,
    'hintSize': hintSize,
    'indexSize': indexSize,
    'rss': rss,
  };
}
