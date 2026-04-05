import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/models/lyric_model.dart';
import 'lyric_service.dart';

/// 歌词缓存服务
/// 
/// 负责歌词的本地缓存管理，包括：
/// - 歌词文件存储
/// - 缓存索引管理
/// - 缓存清理
/// - 多语言歌词支持
class LyricCacheService {
  /// 单例实例
  static LyricCacheService? _instance;
  
  /// 缓存目录
  Directory? _cacheDir;
  
  /// 索引文件路径
  File? _indexFile;
  
  /// 缓存索引
  LyricCacheIndex _index = LyricCacheIndex();
  
  /// 是否初始化
  bool _initialized = false;

  /// 获取单例实例
  static LyricCacheService get instance {
    _instance ??= LyricCacheService._();
    return _instance!;
  }

  LyricCacheService._();

  /// 初始化缓存服务
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // 获取应用文档目录
      final appDir = await getApplicationDocumentsDirectory();
      
      // 创建歌词缓存目录
      _cacheDir = Directory(path.join(appDir.path, 'lyrics_cache'));
      if (!await _cacheDir!.exists()) {
        await _cacheDir!.create(recursive: true);
      }
      
      // 创建索引文件
      _indexFile = File(path.join(_cacheDir!.path, 'cache_index.json'));
      
      // 加载索引
      if (await _indexFile!.exists()) {
        try {
          final content = await _indexFile!.readAsString();
          _index = LyricCacheIndex.fromJson(jsonDecode(content));
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 歌词缓存索引加载失败，使用新索引: $e');
          }
          _index = LyricCacheIndex();
        }
      }
      
      _initialized = true;
      
      if (kDebugMode) {
        print('✅ 歌词缓存服务初始化完成');
        print('📁 缓存目录: ${_cacheDir!.path}');
        print('📊 缓存索引: ${_index.entries.length} 条');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 歌词缓存服务初始化失败: $e');
      }
    }
  }

  /// 获取缓存目录
  Future<Directory> getCacheDirectory() async {
    if (_cacheDir == null) {
      await initialize();
    }
    return _cacheDir!;
  }

  /// 生成缓存键
  /// 
  /// 基于歌曲信息生成唯一的缓存键
  String _generateCacheKey(String title, String artist, {String? language}) {
    final key = '${title}_${artist}'.toLowerCase().replaceAll(RegExp(r'[^\w]'), '_');
    return language != null ? '${key}_$language' : key;
  }

  /// 获取缓存文件路径
  Future<File> _getCacheFile(String cacheKey) async {
    final dir = await getCacheDirectory();
    return File(path.join(dir.path, '$cacheKey.lrc'));
  }

  /// 保存歌词到缓存
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [lrcContent] LRC 歌词内容
  /// [language] 语言标识（可选，用于多语言支持）
  /// [metadata] 附加元数据
  Future<LyricCacheEntry?> cacheLyric({
    required String title,
    required String artist,
    required String lrcContent,
    String? language,
    Map<String, dynamic>? metadata,
  }) async {
    if (!await _isInitialized()) return null;
    
    try {
      final cacheKey = _generateCacheKey(title, artist, language: language);
      final cacheFile = await _getCacheFile(cacheKey);
      
      // 保存歌词文件
      await cacheFile.writeAsString(lrcContent, flush: true);
      
      // 更新索引
      final entry = LyricCacheEntry(
        cacheKey: cacheKey,
        title: title,
        artist: artist,
        language: language,
        cachedAt: DateTime.now(),
        fileSize: lrcContent.length,
        metadata: metadata,
      );
      
      _index.addEntry(entry);
      await _saveIndex();
      
      if (kDebugMode) {
        print('✅ 歌词已缓存: $title - $artist${language != null ? ' [$language]' : ''}');
      }
      
      return entry;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 歌词缓存失败: $e');
      }
      return null;
    }
  }

  /// 从缓存获取歌词
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [language] 语言标识（可选）
  Future<String?> getCachedLyric({
    required String title,
    required String artist,
    String? language,
  }) async {
    if (!await _isInitialized()) return null;
    
    try {
      final cacheKey = _generateCacheKey(title, artist, language: language);
      
      // 检查索引
      final entry = _index.getEntry(cacheKey);
      if (entry == null) {
        if (kDebugMode) {
          print('🔍 歌词缓存未命中: $title - $artist');
        }
        return null;
      }
      
      // 读取缓存文件
      final cacheFile = await _getCacheFile(cacheKey);
      if (!await cacheFile.exists()) {
        _index.removeEntry(cacheKey);
        await _saveIndex();
        return null;
      }
      
      final content = await cacheFile.readAsString();
      
      // 更新访问时间
      entry.lastAccessedAt = DateTime.now();
      entry.accessCount++;
      await _saveIndex();
      
      if (kDebugMode) {
        print('✅ 歌词缓存命中: $title - $artist${language != null ? ' [$language]' : ''}');
      }
      
      return content;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 读取缓存失败: $e');
      }
      return null;
    }
  }

  /// 检查歌词是否已缓存
  Future<bool> isLyricCached({
    required String title,
    required String artist,
    String? language,
  }) async {
    if (!await _isInitialized()) return false;
    
    final cacheKey = _generateCacheKey(title, artist, language: language);
    return _index.hasEntry(cacheKey);
  }

  /// 获取已缓存的语言列表
  Future<List<String?>> getCachedLanguages({
    required String title,
    required String artist,
  }) async {
    if (!await _isInitialized()) return [];
    
    // 生成不带语言的键作为基础
    final baseKey = _generateCacheKey(title, artist);
    
    // 查找所有相关的缓存条目
    return _index.entries
        .where((e) => e.cacheKey.startsWith(baseKey))
        .map((e) => e.language)
        .toList();
  }

  /// 删除歌词缓存
  Future<bool> removeCachedLyric({
    required String title,
    required String artist,
    String? language,
  }) async {
    if (!await _isInitialized()) return false;
    
    try {
      final cacheKey = _generateCacheKey(title, artist, language: language);
      
      // 删除缓存文件
      final cacheFile = await _getCacheFile(cacheKey);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
      
      // 从索引中移除
      _index.removeEntry(cacheKey);
      await _saveIndex();
      
      if (kDebugMode) {
        print('🗑️ 歌词缓存已删除: $title - $artist');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 删除缓存失败: $e');
      }
      return false;
    }
  }

  /// 清理过期缓存
  /// 
  /// [maxAge] 最大缓存时间
  /// [maxCount] 最大缓存数量
  Future<int> cleanExpiredCache({
    Duration? maxAge,
    int? maxCount,
  }) async {
    if (!await _isInitialized()) return 0;
    
    int removedCount = 0;
    
    // 按时间清理
    if (maxAge != null) {
      final cutoffTime = DateTime.now().subtract(maxAge);
      final expiredKeys = <String>[];
      
      for (final entry in _index.entries) {
        if (entry.cachedAt.isBefore(cutoffTime)) {
          expiredKeys.add(entry.cacheKey);
        }
      }
      
      for (final key in expiredKeys) {
        await _deleteCacheFile(key);
        _index.removeEntry(key);
        removedCount++;
      }
    }
    
    // 按数量清理（保留最近访问的）
    if (maxCount != null && _index.entries.length > maxCount) {
      // 按最后访问时间排序
      final sortedEntries = List<LyricCacheEntry>.from(_index.entries)
        ..sort((a, b) => b.lastAccessedAt.compareTo(a.lastAccessedAt));
      
      // 删除超出数量的旧缓存
      for (int i = maxCount; i < sortedEntries.length; i++) {
        await _deleteCacheFile(sortedEntries[i].cacheKey);
        _index.removeEntry(sortedEntries[i].cacheKey);
        removedCount++;
      }
    }
    
    if (removedCount > 0) {
      await _saveIndex();
      if (kDebugMode) {
        print('🧹 已清理 $removedCount 条过期缓存');
      }
    }
    
    return removedCount;
  }

  /// 删除缓存文件
  Future<void> _deleteCacheFile(String cacheKey) async {
    try {
      final cacheFile = await _getCacheFile(cacheKey);
      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 删除缓存文件失败: $cacheKey');
      }
    }
  }

  /// 获取缓存统计信息
  Future<LyricCacheStats> getCacheStats() async {
    if (!await _isInitialized()) {
      return LyricCacheStats.empty();
    }
    
    final dir = await getCacheDirectory();
    int totalSize = 0;
    
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.lrc')) {
        totalSize += await entity.length();
      }
    }
    
    return LyricCacheStats(
      totalCount: _index.entries.length,
      totalSize: totalSize,
      oldestCache: _index.entries.isEmpty 
          ? null 
          : _index.entries.map((e) => e.cachedAt).reduce((a, b) => a.isBefore(b) ? a : b),
      newestCache: _index.entries.isEmpty 
          ? null 
          : _index.entries.map((e) => e.cachedAt).reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }

  /// 清除所有缓存
  Future<int> clearAllCache() async {
    if (!await _isInitialized()) return 0;
    
    int count = _index.entries.length;
    
    // 删除所有缓存文件
    final dir = await getCacheDirectory();
    await for (final entity in dir.list()) {
      if (entity is File && entity.path.endsWith('.lrc')) {
        await entity.delete();
      }
    }
    
    // 重置索引
    _index = LyricCacheIndex();
    await _saveIndex();
    
    if (kDebugMode) {
      print('🗑️ 已清除所有歌词缓存 ($count 条)');
    }
    
    return count;
  }

  /// 保存索引
  Future<void> _saveIndex() async {
    if (_indexFile == null) return;
    
    try {
      final content = jsonEncode(_index.toJson());
      await _indexFile!.writeAsString(content, flush: true);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存缓存索引失败: $e');
      }
    }
  }

  /// 检查是否已初始化
  Future<bool> _isInitialized() async {
    if (!_initialized) {
      await initialize();
    }
    return _initialized;
  }
}

/// 歌词缓存索引
class LyricCacheIndex {
  /// 缓存条目列表
  final List<LyricCacheEntry> entries;
  
  /// 索引版本
  final int version;

  LyricCacheIndex({
    List<LyricCacheEntry>? entries,
    this.version = 1,
  }) : entries = entries ?? [];

  /// 添加缓存条目
  void addEntry(LyricCacheEntry entry) {
    // 移除已存在的相同键
    entries.removeWhere((e) => e.cacheKey == entry.cacheKey);
    entries.add(entry);
  }

  /// 获取缓存条目
  LyricCacheEntry? getEntry(String cacheKey) {
    try {
      return entries.firstWhere((e) => e.cacheKey == cacheKey);
    } catch (e) {
      return null;
    }
  }

  /// 检查是否包含键
  bool hasEntry(String cacheKey) {
    return entries.any((e) => e.cacheKey == cacheKey);
  }

  /// 移除缓存条目
  void removeEntry(String cacheKey) {
    entries.removeWhere((e) => e.cacheKey == cacheKey);
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'version': version,
    'entries': entries.map((e) => e.toJson()).toList(),
  };

  /// 从 JSON 创建
  factory LyricCacheIndex.fromJson(Map<String, dynamic> json) {
    return LyricCacheIndex(
      version: json['version'] ?? 1,
      entries: (json['entries'] as List?)
          ?.map((e) => LyricCacheEntry.fromJson(e))
          .toList() ?? [],
    );
  }
}

/// 歌词缓存条目
class LyricCacheEntry {
  /// 缓存键
  final String cacheKey;
  
  /// 歌曲标题
  final String title;
  
  /// 艺术家
  final String artist;
  
  /// 语言标识
  final String? language;
  
  /// 缓存时间
  final DateTime cachedAt;
  
  /// 最后访问时间
  DateTime lastAccessedAt;
  
  /// 访问次数
  int accessCount;
  
  /// 文件大小
  final int fileSize;
  
  /// 附加元数据
  final Map<String, dynamic>? metadata;

  LyricCacheEntry({
    required this.cacheKey,
    required this.title,
    required this.artist,
    this.language,
    required this.cachedAt,
    DateTime? lastAccessedAt,
    this.accessCount = 0,
    required this.fileSize,
    this.metadata,
  }) : lastAccessedAt = lastAccessedAt ?? cachedAt;

  /// 转换为 JSON
  Map<String, dynamic> toJson() => {
    'cacheKey': cacheKey,
    'title': title,
    'artist': artist,
    'language': language,
    'cachedAt': cachedAt.toIso8601String(),
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'accessCount': accessCount,
    'fileSize': fileSize,
    'metadata': metadata,
  };

  /// 从 JSON 创建
  factory LyricCacheEntry.fromJson(Map<String, dynamic> json) {
    return LyricCacheEntry(
      cacheKey: json['cacheKey'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      language: json['language'],
      cachedAt: DateTime.parse(json['cachedAt']),
      lastAccessedAt: DateTime.parse(json['lastAccessedAt'] ?? json['cachedAt']),
      accessCount: json['accessCount'] ?? 0,
      fileSize: json['fileSize'] ?? 0,
      metadata: json['metadata'],
    );
  }
}

/// 歌词缓存统计信息
class LyricCacheStats {
  /// 总数量
  final int totalCount;
  
  /// 总大小 (字节)
  final int totalSize;
  
  /// 最老的缓存时间
  final DateTime? oldestCache;
  
  /// 最新的缓存时间
  final DateTime? newestCache;

  LyricCacheStats({
    required this.totalCount,
    required this.totalSize,
    this.oldestCache,
    this.newestCache,
  });

  /// 获取格式化的大小
  String get formattedSize {
    if (totalSize < 1024) {
      return '$totalSize B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 创建空统计
  factory LyricCacheStats.empty() => LyricCacheStats(
    totalCount: 0,
    totalSize: 0,
    oldestCache: null,
    newestCache: null,
  );
}
