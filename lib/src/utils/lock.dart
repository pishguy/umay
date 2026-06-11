import 'dart:async';

/// Mutex ساده بدون dependency خارجی.
/// عملیات async رو serial اجرا می‌کنه.
///
/// نحوه استفاده در UmayBox:
/// ```dart
/// final _lock = AsyncLock();
///
/// Future<void> put(String key, Object value) {
///   return _lock.run(() async {
///     // write logic
///   });
/// }
/// ```
class AsyncLock {
  Future<void> _last = Future.value();

  /// [fn] رو بعد از تموم شدن همه عملیات قبلی اجرا می‌کنه.
  Future<T> run<T>(Future<T> Function() fn) {
    final completer = Completer<T>();

    _last = _last.then((_) async {
      try {
        final result = await fn();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });

    return completer.future;
  }
}

/// ReadWriteLock — چند read همزمان مجاز، write انحصاری.
/// برای UmayBox که read بیشتر از write داره مناسب‌تره.
class ReadWriteLock {
  int _readers = 0;
  bool _writing = false;

  final List<Completer<void>> _writeQueue = [];
  final List<Completer<void>> _readQueue = [];

  Future<T> read<T>(Future<T> Function() fn) async {
    while (_writing) {
      final c = Completer<void>();
      _readQueue.add(c);
      await c.future;
    }
    _readers++;
    try {
      return await fn();
    } finally {
      _readers--;
      _notifyNextWriter();
    }
  }

  Future<T> write<T>(Future<T> Function() fn) async {
    while (_writing || _readers > 0) {
      final c = Completer<void>();
      _writeQueue.add(c);
      await c.future;
    }
    _writing = true;
    try {
      return await fn();
    } finally {
      _writing = false;
      // اول همه reader ها رو آزاد کن
      for (final c in List.of(_readQueue)) c.complete();
      _readQueue.clear();
      // بعد یه writer بعدی
      _notifyNextWriter();
    }
  }

  void _notifyNextWriter() {
    if (_readers == 0 && !_writing && _writeQueue.isNotEmpty) {
      _writeQueue.removeAt(0).complete();
    }
  }
}