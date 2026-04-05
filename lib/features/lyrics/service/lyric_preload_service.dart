import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/models/lyric_model.dart';
import 'lyric_cache_service.dart';
import 'lyric_service.dart';

/// 歌词预加载服务
/// 
/// 负责歌词的预加载管理，包括：
/// - 播放列表歌曲歌词预加载
/// - 智能预加载策略
/// - 预加载队列管理
/// - 内存缓存管理
class LyricPreloadService {
  /// 单例实例
  static LyricPreloadService? _instance;
  
  /// 缓存服务
  final LyricCacheService _cacheService;
  
  /// 歌词服务
  final LyricService _lyricService;
  
  /// 预加载队列
  final List<LyricPreloadTask> _preloadQueue = [];
  
  /// 正在预加载的任务
  final Set<String> _loadingKeys = {};
  
  /// 已预加载的歌词缓存
  final Map<String, LyricData> _preloadedLyrics = {};
  
  /// 最大内存缓存数量
  int _maxCacheSize = 50;
  
  /// 预加载线程数
  int _preloadThreads = 3;
  
  /// 是否启用
  bool _enabled = true;
  
  /// 运行中的预加载任务
  final List<Future<void>> _runningTasks = [];
  
  /// 内存缓存的最大条目数
  static const int kDefaultMaxCacheSize = 50;
  
  /// 预加载线程数
  static const int kDefaultPreloadThreads = 3;

  /// 获取单例实例
  static LyricPreloadService get instance {
    _instance ??= LyricPreloadService._(LyricCacheService.instance, LyricService());
    return _instance!;
  }

  LyricPreloadService._(this._cacheService, this._lyricService);

  /// 初始化服务
  Future<void> initialize() async {
    await _cacheService.initialize();
    
    if (kDebugMode) {
      print('✅ 歌词预加载服务初始化完成');
      print('📊 预加载线程: $_preloadThreads');
      print('📦 内存缓存上限: $_maxCacheSize');
    }
  }

  /// 设置是否启用
  set enabled(bool value) => _enabled = value;

  /// 获取启用状态
  bool get isEnabled => _enabled;

  /// 设置最大缓存大小
  set maxCacheSize(int value) {
    _maxCacheSize = value.clamp(10, 200);
    _trimMemoryCache();
  }

  /// 获取最大缓存大小
  int get maxCacheSize => _maxCacheSize;

  /// 设置预加载线程数
  set preloadThreads(int value) {
    _preloadThreads = value.clamp(1, 5);
  }

  /// 获取预加载线程数
  int get preloadThreads => _preloadThreads;

  /// 预加载歌词
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [language] 语言标识（可选）
  /// [priority] 优先级（越高越优先）
  Future<LyricData?> preloadLyric({
    required String title,
    required String artist,
    String? language,
    int priority = 0,
  }) async {
    if (!_enabled) return null;
    
    final key = _generateKey(title, artist, language);
    
    // 检查是否已预加载
    if (_preloadedLyrics.containsKey(key)) {
      return _preloadedLyrics[key];
    }
    
    // 检查是否正在加载
    if (_loadingKeys.contains(key)) {
      return null;
    }
    
    // 添加到队列
    final task = LyricPreloadTask(
      title: title,
      artist: artist,
      language: language,
      priority: priority,
      key: key,
    );
    
    // 按优先级插入队列
    _insertTaskByPriority(task);
    
    // 触发预加载
    _processQueue();
    
    return null;
  }

  /// 批量预加载歌词
  /// 
  /// [tracks] 歌曲列表
  /// [startIndex] 开始索引
  /// [count] 预加载数量
  Future<void> preloadTrackList({
    required List<PreloadTrack> tracks,
    int startIndex = 0,
    int count = 10,
  }) async {
    if (!_enabled || tracks.isEmpty) return;
    
    // 计算预加载范围
    final endIndex = (startIndex + count).clamp(0, tracks.length);
    
    for (int i = startIndex; i < endIndex; i++) {
      final track = tracks[i];
      
      // 跳过本地已有的歌词
      if (track.localLyric != null) continue;
      
      await preloadLyric(
        title: track.title,
        artist: track.artist,
        language: track.language,
        priority: i - startIndex, // 越接近当前播放位置的优先级越高
      );
    }
  }

  /// 预加载下一首歌曲的歌词
  Future<void> preloadNextLyric({
    required List<PreloadTrack> playlist,
    required int currentIndex,
  }) async {
    if (!_enabled || playlist.isEmpty) return;
    
    final nextIndex = currentIndex + 1;
    if (nextIndex >= playlist.length) return;
    
    final nextTrack = playlist[nextIndex];
    
    await preloadLyric(
      title: nextTrack.title,
      artist: nextTrack.artist,
      language: nextTrack.language,
      priority: 100,
    );
  }

  /// 预加载上一首歌曲的歌词
  Future<void> preloadPreviousLyric({
    required List<PreloadTrack> playlist,
    required int currentIndex,
  }) async {
    if (!_enabled || playlist.isEmpty) return;
    
    final prevIndex = currentIndex - 1;
    if (prevIndex < 0) return;
    
    final prevTrack = playlist[prevIndex];
    
    await preloadLyric(
      title: prevTrack.title,
      artist: prevTrack.artist,
      language: prevTrack.language,
      priority: 100,
    );
  }

  /// 获取预加载的歌词
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [language] 语言标识
  LyricData? getPreloadedLyric({
    required String title,
    required String artist,
    String? language,
  }) {
    final key = _generateKey(title, artist, language);
    return _preloadedLyrics[key];
  }

  /// 检查歌词是否已预加载
  bool isLyricPreloaded({
    required String title,
    required String artist,
    String? language,
  }) {
    final key = _generateKey(title, artist, language);
    return _preloadedLyrics.containsKey(key);
  }

  /// 清除指定预加载
  Future<void> clearPreloadedLyric({
    required String title,
    required String artist,
    String? language,
  }) async {
    final key = _generateKey(title, artist, language);
    _preloadedLyrics.remove(key);
  }

  /// 清除所有预加载
  Future<void> clearAllPreloaded() async {
    _preloadedLyrics.clear();
    _preloadQueue.clear();
    _runningTasks.clear();
    
    if (kDebugMode) {
      print('🗑️ 已清除所有预加载歌词');
    }
  }

  /// 获取预加载统计
  PreloadStats getStats() {
    return PreloadStats(
      queuedCount: _preloadQueue.length,
      loadedCount: _preloadedLyrics.length,
      loadingCount: _loadingKeys.length,
      maxCacheSize: _maxCacheSize,
    );
  }

  /// 按优先级插入任务到队列
  void _insertTaskByPriority(LyricPreloadTask task) {
    // 移除已有的相同任务
    _preloadQueue.removeWhere((t) => t.key == task.key);
    
    // 找到正确的插入位置
    int insertIndex = _preloadQueue.length;
    for (int i = 0; i < _preloadQueue.length; i++) {
      if (_preloadQueue[i].priority < task.priority) {
        insertIndex = i;
        break;
      }
    }
    
    _preloadQueue.insert(insertIndex, task);
  }

  /// 处理预加载队列
  void _processQueue() {
    // 限制并发数
    while (_loadingKeys.length < _preloadThreads && _preloadQueue.isNotEmpty) {
      final task = _preloadQueue.removeAt(0);
      _executePreload(task);
    }
  }

  /// 执行预加载任务
  Future<void> _executePreload(LyricPreloadTask task) async {
    _loadingKeys.add(task.key);
    
    final completer = Completer<void>();
    _runningTasks.add(completer.future);
    
    try {
      // 1. 尝试从缓存加载
      String? lrcContent = await _cacheService.getCachedLyric(
        title: task.title,
        artist: task.artist,
        language: task.language,
      );
      
      // 2. 如果缓存没有，从网络加载
      if (lrcContent == null) {
        lrcContent = await _fetchLyricFromNetwork(task);
        
        // 3. 保存到缓存
        if (lrcContent != null) {
          await _cacheService.cacheLyric(
            title: task.title,
            artist: task.artist,
            lrcContent: lrcContent,
            language: task.language,
          );
        }
      }
      
      // 4. 解析歌词
      if (lrcContent != null) {
        final lyricData = LyricParser.parse(lrcContent);
        
        if (!lyricData.isEmpty) {
          // 5. 保存到内存缓存
          _preloadedLyrics[task.key] = lyricData;
          
          // 6. 清理过多缓存
          _trimMemoryCache();
          
          if (kDebugMode) {
            print('✅ 歌词预加载完成: ${task.title} - ${task.artist}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 歌词预加载失败: ${task.title} - ${task.artist}: $e');
      }
    } finally {
      _loadingKeys.remove(task.key);
      _runningTasks.remove(completer.future);
      completer.complete();
    }
  }

  /// 从网络获取歌词
  Future<String?> _fetchLyricFromNetwork(LyricPreloadTask task) async {
    // 预留接口：可以从 QQ 音乐、网易云等 API 获取
    // 这里暂时返回 null，让外部服务实现
    return null;
  }

  /// 清理过多内存缓存
  void _trimMemoryCache() {
    if (_preloadedLyrics.length <= _maxCacheSize) return;
    
    // 按访问频率清理
    final entries = _preloadedLyrics.entries.toList();
    entries.sort((a, b) => a.key.compareTo(b.key));
    
    while (_preloadedLyrics.length > _maxCacheSize) {
      _preloadedLyrics.remove(entries.first.key);
      entries.removeAt(0);
    }
  }

  /// 生成缓存键
  String _generateKey(String title, String artist, String? language) {
    final key = '${title}_${artist}'.toLowerCase();
    return language != null ? '${key}_$language' : key;
  }

  /// 等待所有任务完成
  Future<void> waitForAllTasks() async {
    await Future.wait(_runningTasks);
  }
}

/// 歌词预加载任务
class LyricPreloadTask {
  /// 歌曲标题
  final String title;
  
  /// 艺术家
  final String artist;
  
  /// 语言标识
  final String? language;
  
  /// 优先级
  final int priority;
  
  /// 缓存键
  final String key;
  
  /// 创建时间
  final DateTime createdAt;

  LyricPreloadTask({
    required this.title,
    required this.artist,
    this.language,
    this.priority = 0,
    required this.key,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// 预加载轨道数据
class PreloadTrack {
  /// 歌曲标题
  final String title;
  
  /// 艺术家
  final String artist;
  
  /// 语言标识
  final String? language;
  
  /// 本地歌词（如果有）
  final String? localLyric;

  PreloadTrack({
    required this.title,
    required this.artist,
    this.language,
    this.localLyric,
  });
}

/// 预加载统计信息
class PreloadStats {
  /// 队列中的任务数
  final int queuedCount;
  
  /// 已加载的歌词数
  final int loadedCount;
  
  /// 正在加载的任务数
  final int loadingCount;
  
  /// 最大缓存大小
  final int maxCacheSize;

  PreloadStats({
    required this.queuedCount,
    required this.loadedCount,
    required this.loadingCount,
    required this.maxCacheSize,
  });
}
