import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/cache_entry.dart';

/// URL缓存服务
/// 用于缓存音乐播放URL，避免重复请求，提升用户体验
class UrlCacheService {
  static const String _cachePrefix = 'music_url_cache_';
  static const int _defaultTtlMinutes = 10;
  static const int _maxCacheItems = 1000;

  final SharedPreferences _prefs;

  /// 缓存统计信息
  int _hitCount = 0;
  int _missCount = 0;

  UrlCacheService(this._prefs);

  /// 生成缓存KEY
  /// 格式: music_url_cache_{musicId}_{quality}_{platform}
  String _getCacheKey(String musicId, String quality, String platform) {
    return '$_cachePrefix${musicId}_${quality}_$platform';
  }

  /// 获取缓存URL
  /// 返回：CacheEntry? 缓存条目，如果不存在或过期返回null
  CacheEntry? get(String musicId, String quality, String platform) {
    try {
      final key = _getCacheKey(musicId, quality, platform);
      final cached = _prefs.getString(key);
      
      if (cached == null) {
        _missCount++;
        if (kDebugMode) {
          print('💔 缓存未命中: $musicId ($quality) from $platform');
        }
        return null;
      }

      final json = jsonDecode(cached) as Map<String, dynamic>;
      final entry = CacheEntry.fromJson(json);

      // 检查是否过期
      if (entry.isExpired(_defaultTtlMinutes)) {
        if (kDebugMode) {
          print('⏰ 缓存已过期: $musicId ($quality) age: ${entry.ageMinutes} minutes');
        }
        // 异步删除过期缓存
        _prefs.remove(key);
        _missCount++;
        return null;
      }

      _hitCount++;
      if (kDebugMode) {
        print('✅ 缓存命中: $musicId ($quality) from $platform, age: ${entry.ageMinutes} minutes');
      }

      return entry;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 读取缓存失败: $e');
      }
      _missCount++;
      return null;
    }
  }

  /// 缓存URL
  Future<void> set(
    String musicId,
    String quality,
    String platform,
    String url, {
    int? fileSize,
  }) async {
    try {
      final key = _getCacheKey(musicId, quality, platform);
      final entry = CacheEntry(
        url: url,
        createdAt: DateTime.now(),
        platform: platform,
        quality: quality,
        fileSize: fileSize,
      );

      await _prefs.setString(key, jsonEncode(entry.toJson()));

      if (kDebugMode) {
        print('💾 缓存已保存: $musicId ($quality) from $platform');
      }

      // 检查缓存条数，超出则清理最旧的
      _cleanupIfNeeded();
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存缓存失败: $e');
      }
    }
  }

  /// 清理过期或超限的缓存
  Future<void> _cleanupIfNeeded() async {
    try {
      final keys = _prefs.getKeys()
          .where((k) => k.toString().startsWith(_cachePrefix))
          .toList();

      if (keys.length <= _maxCacheItems) {
        return;
      }

      // 获取所有缓存条目
      final entries = <String, CacheEntry>{};
      for (final key in keys) {
        final cached = _prefs.getString(key);
        if (cached != null) {
          try {
            final json = jsonDecode(cached) as Map<String, dynamic>;
            entries[key] = CacheEntry.fromJson(json);
          } catch (_) {
            await _prefs.remove(key);
          }
        }
      }

      // 按创建时间排序（旧到新）
      final sortedKeys = entries.keys.toList()
        ..sort((a, b) {
          final timeA = entries[a]!.createdAt;
          final timeB = entries[b]!.createdAt;
          return timeA.compareTo(timeB);
        });

      // 删除最旧的10%
      final toDelete = sortedKeys.take((sortedKeys.length * 0.1).ceil());
      for (final key in toDelete) {
        await _prefs.remove(key);
      }

      if (kDebugMode) {
        print('🧹 清理缓存: 删除${toDelete.length}条旧条目');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清理缓存失败: $e');
      }
    }
  }

  /// 删除指定缓存
  Future<void> remove(String musicId, String quality, String platform) async {
    try {
      final key = _getCacheKey(musicId, quality, platform);
      await _prefs.remove(key);
      if (kDebugMode) {
        print('🗑️ 已删除缓存: $musicId ($quality) from $platform');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 删除缓存失败: $e');
      }
    }
  }

  /// 清空所有URL缓存
  Future<void> clear() async {
    try {
      final keys = _prefs.getKeys()
          .where((k) => k.toString().startsWith(_cachePrefix))
          .toList();

      for (final key in keys) {
        await _prefs.remove(key);
      }

      _hitCount = 0;
      _missCount = 0;

      if (kDebugMode) {
        print('🧹 已清空所有URL缓存，共${keys.length}条');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清空缓存失败: $e');
      }
    }
  }

  /// 清理过期缓存
  Future<int> cleanExpired() async {
    try {
      final keys = _prefs.getKeys()
          .where((k) => k.toString().startsWith(_cachePrefix))
          .toList();

      int cleanedCount = 0;
      for (final key in keys) {
        final cached = _prefs.getString(key);
        if (cached != null) {
          try {
            final json = jsonDecode(cached) as Map<String, dynamic>;
            final entry = CacheEntry.fromJson(json);
            
            if (entry.isExpired(_defaultTtlMinutes)) {
              await _prefs.remove(key);
              cleanedCount++;
            }
          } catch (_) {
            await _prefs.remove(key);
            cleanedCount++;
          }
        }
      }

      if (kDebugMode && cleanedCount > 0) {
        print('🧹 清理过期缓存: 删除$cleanedCount条');
      }

      return cleanedCount;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 清理过期缓存失败: $e');
      }
      return 0;
    }
  }

  /// 获取缓存统计
  Future<Map<String, dynamic>> getStats() async {
    try {
      final keys = _prefs.getKeys()
          .where((k) => k.toString().startsWith(_cachePrefix))
          .toList();

      int totalSize = 0;
      int expiredCount = 0;
      
      for (final key in keys) {
        final value = _prefs.getString(key);
        if (value != null) {
          totalSize += value.length;
          
          // 检查是否过期
          try {
            final json = jsonDecode(value) as Map<String, dynamic>;
            final entry = CacheEntry.fromJson(json);
            if (entry.isExpired(_defaultTtlMinutes)) {
              expiredCount++;
            }
          } catch (_) {}
        }
      }

      // 计算命中率
      final totalRequests = _hitCount + _missCount;
      final hitRate = totalRequests > 0 
          ? ((_hitCount / totalRequests) * 100).toStringAsFixed(2) 
          : '0.00';

      return {
        'count': keys.length,
        'expiredCount': expiredCount,
        'sizeKB': (totalSize / 1024).toStringAsFixed(2),
        'hitCount': _hitCount,
        'missCount': _missCount,
        'hitRate': '$hitRate%',
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取缓存统计失败: $e');
      }
      return {
        'count': 0,
        'expiredCount': 0,
        'sizeKB': '0',
        'hitCount': 0,
        'missCount': 0,
        'hitRate': '0.00%',
      };
    }
  }

  /// 重置统计计数
  void resetStats() {
    _hitCount = 0;
    _missCount = 0;
    if (kDebugMode) {
      print('📊 缓存统计已重置');
    }
  }
}
