import 'package:extended_image/extended_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

class CacheBreakdown {
  const CacheBreakdown({
    required this.totalBytes,
    required this.imageBytes,
    required this.networkBytes,
    required this.systemBytes,
  });

  final int totalBytes;
  final int imageBytes;
  final int networkBytes;
  final int systemBytes;

  static const empty = CacheBreakdown(
    totalBytes: 0,
    imageBytes: 0,
    networkBytes: 0,
    systemBytes: 0,
  );

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var index = 0;
    var value = bytes.toDouble();
    while (value >= 1024 && index < suffixes.length - 1) {
      value /= 1024;
      index++;
    }
    return '${value.toStringAsFixed(index == 0 ? 0 : 2)} ${suffixes[index]}';
  }
}

class CacheService {
  static const MethodChannel _channel = MethodChannel('com.lurk/cache');

  static Future<CacheBreakdown> getCacheStats() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getCacheStats',
    );
    if (result == null) {
      throw PlatformException(code: 'CACHE_STATS_UNAVAILABLE');
    }
    return CacheBreakdown(
      totalBytes: (result['total'] as num?)?.toInt() ?? 0,
      imageBytes: (result['images'] as num?)?.toInt() ?? 0,
      networkBytes: (result['network'] as num?)?.toInt() ?? 0,
      systemBytes: (result['system'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<int?> clearCache() async {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      clearMemoryImageCache();
    } catch (error) {
      debugPrint('Failed to clear memory image cache: $error');
    }
    try {
      await clearDiskCachedImages();
    } catch (error) {
      debugPrint('Failed to clear extended_image disk cache: $error');
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'clearCache',
      );
      final cleared = result?['cleared'];
      return cleared is num ? cleared.toInt() : null;
    } catch (error) {
      debugPrint('Native cache clearing failed: $error');
      return null;
    }
  }

  static Future<bool> checkAndAutoClearCache(int thresholdMb) async {
    if (thresholdMb <= 0) return false;
    try {
      final stats = await getCacheStats();
      if (stats.totalBytes < thresholdMb * 1024 * 1024) return false;
      return await clearCache() != null;
    } catch (error) {
      debugPrint('Failed to check cache threshold: $error');
      return false;
    }
  }
}
