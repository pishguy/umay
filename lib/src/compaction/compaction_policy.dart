// compaction_policy.dart

/// Decides when to run compaction based on database size and garbage ratio.
///
/// - [maxDbSizeBytes]: minimum total DB file size to even consider compaction.
/// - [garbageRatioThreshold]: fraction of the DB that must be garbage
///   (i.e., (dbSize - liveDataSize) / dbSize) to trigger compaction.
class CompactionPolicy {
  final int maxDbSizeBytes;
  final double garbageRatioThreshold;

  CompactionPolicy({
    this.maxDbSizeBytes = 100 * 1024 * 1024, // 100MB
    this.garbageRatioThreshold = 0.3,
  });

  /// Decide whether compaction should run.
  ///
  /// [dbSize]       - total size of the DB file on disk, in bytes.
  /// [liveDataSize] - estimated size of live (non-deleted) data, in bytes.
  Future<bool> shouldCompact(int dbSize, int liveDataSize) async {
    if (dbSize <= 0) return false;

    // Don't compact small databases.
    if (dbSize < maxDbSizeBytes) return false;

    if (liveDataSize <= 0) {
      // Everything is garbage? In practice this is rare; let's compact.
      return true;
    }

    final garbageBytes = dbSize - liveDataSize;
    if (garbageBytes <= 0) return false;

    final garbageRatio = garbageBytes / dbSize;
    return garbageRatio > garbageRatioThreshold;
  }
}
