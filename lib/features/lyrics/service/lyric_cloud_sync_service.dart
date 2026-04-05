import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../data/models/lyric_model.dart';
import 'lyric_cache_service.dart';

/// 歌词云同步服务
/// 
/// 负责歌词数据的云端同步，包括：
/// - 用户歌词库同步
/// - 收藏歌词同步
/// - 歌词编辑历史同步
/// - 多设备歌词同步
class LyricCloudSyncService {
  /// 单例实例
  static LyricCloudSyncService? _instance;
  
  /// 缓存服务
  final LyricCacheService _cacheService;
  
  /// 同步服务器地址
  String _serverUrl = '';
  
  /// 用户认证令牌
  String? _authToken;
  
  /// 用户 ID
  String? _userId;
  
  /// 同步状态
  SyncState _syncState = SyncState.idle;
  
  /// 最后同步时间
  DateTime? _lastSyncTime;
  
  /// 本地待同步队列
  final List<LyricSyncItem> _pendingSyncQueue = [];
  
  /// 同步冲突解决策略
  SyncConflictStrategy _conflictStrategy = SyncConflictStrategy.serverWins;
  
  /// HTTP 客户端
  final http.Client _httpClient = http.Client();

  /// 获取单例实例
  static LyricCloudSyncService get instance {
    _instance ??= LyricCloudSyncService._(LyricCacheService.instance);
    return _instance!;
  }

  LyricCloudSyncService._(this._cacheService);

  /// 初始化服务
  Future<void> initialize() async {
    await _cacheService.initialize();
    
    if (kDebugMode) {
      print('✅ 歌词云同步服务初始化完成');
      print('🔗 服务器: ${_serverUrl.isEmpty ? "未配置" : _serverUrl}');
    }
  }

  /// 获取同步状态
  SyncState get syncState => _syncState;

  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 是否已登录
  bool get isLoggedIn => _authToken != null && _userId != null;

  /// 设置服务器地址
  set serverUrl(String url) {
    _serverUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// 获取服务器地址
  String get serverUrl => _serverUrl;

  /// 设置认证令牌
  void setAuthToken(String token, String userId) {
    _authToken = token;
    _userId = userId;
    if (kDebugMode) {
      print('🔐 云同步认证已设置，用户: $userId');
    }
  }

  /// 清除认证信息
  void clearAuth() {
    _authToken = null;
    _userId = null;
    if (kDebugMode) {
      print('🔐 云同步认证已清除');
    }
  }

  /// 设置冲突解决策略
  set conflictStrategy(SyncConflictStrategy strategy) {
    _conflictStrategy = strategy;
  }

  /// 登录
  Future<SyncResult> login(String username, String password) async {
    if (_serverUrl.isEmpty) {
      return SyncResult.error('服务器地址未配置');
    }
    
    try {
      _syncState = SyncState.authenticating;
      
      final response = await _httpClient.post(
        Uri.parse('$_serverUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['token'];
        _userId = data['userId'];
        
        _syncState = SyncState.idle;
        
        if (kDebugMode) {
          print('✅ 云同步登录成功: $username');
        }
        
        return SyncResult.success('登录成功');
      } else {
        _syncState = SyncState.error;
        return SyncResult.error('登录失败: ${response.statusCode}');
      }
    } catch (e) {
      _syncState = SyncState.error;
      if (kDebugMode) {
        print('❌ 云同步登录失败: $e');
      }
      return SyncResult.error('登录失败: $e');
    }
  }

  /// 登出
  Future<void> logout() async {
    clearAuth();
    _pendingSyncQueue.clear();
    _syncState = SyncState.idle;
    
    if (kDebugMode) {
      print('👋 云同步已登出');
    }
  }

  /// 同步歌词到云端
  Future<SyncResult> uploadLyric({
    required String title,
    required String artist,
    required String lrcContent,
    String? language,
    bool isPublic = false,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isLoggedIn) {
      return SyncResult.error('请先登录');
    }
    
    try {
      _syncState = SyncState.uploading;
      
      final response = await _httpClient.post(
        Uri.parse('$_serverUrl/api/lyrics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'title': title,
          'artist': artist,
          'lrcContent': lrcContent,
          'language': language,
          'isPublic': isPublic,
          'metadata': metadata,
        }),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        _syncState = SyncState.idle;
        
        if (kDebugMode) {
          print('✅ 歌词已上传: $title - $artist');
        }
        
        return SyncResult.success('上传成功');
      } else {
        _syncState = SyncState.error;
        return SyncResult.error('上传失败: ${response.statusCode}');
      }
    } catch (e) {
      _syncState = SyncState.error;
      
      // 加入待同步队列
      _pendingSyncQueue.add(LyricSyncItem(
        title: title,
        artist: artist,
        lrcContent: lrcContent,
        language: language,
        isPublic: isPublic,
        metadata: metadata,
        action: SyncAction.upload,
        createdAt: DateTime.now(),
      ));
      
      await _savePendingQueue();
      
      if (kDebugMode) {
        print('⚠️ 歌词上传失败，已加入待同步队列: $e');
      }
      
      return SyncResult.error('上传失败，已加入待同步队列');
    }
  }

  /// 从云端下载歌词
  Future<LyricCloudItem?> downloadLyric({
    required String title,
    required String artist,
    String? language,
  }) async {
    if (!isLoggedIn) {
      return null;
    }
    
    try {
      _syncState = SyncState.downloading;
      
      final queryParams = {
        'title': title,
        'artist': artist,
        if (language != null) 'language': language,
      };
      
      final response = await _httpClient.get(
        Uri.parse('$_serverUrl/api/lyrics').replace(queryParameters: queryParams),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _syncState = SyncState.idle;
        
        if (kDebugMode) {
          print('✅ 歌词已下载: $title - $artist');
        }
        
        return LyricCloudItem.fromJson(data);
      } else if (response.statusCode == 404) {
        _syncState = SyncState.idle;
        return null;
      } else {
        _syncState = SyncState.error;
        return null;
      }
    } catch (e) {
      _syncState = SyncState.error;
      if (kDebugMode) {
        print('❌ 歌词下载失败: $e');
      }
      return null;
    }
  }

  /// 同步用户歌词库
  Future<SyncResult> syncUserLibrary() async {
    if (!isLoggedIn) {
      return SyncResult.error('请先登录');
    }
    
    try {
      _syncState = SyncState.syncing;
      
      // 1. 获取云端歌词列表
      final cloudLyrics = await _fetchCloudLyricList();
      
      // 2. 获取本地歌词列表
      final localLyrics = await _getLocalLyricList();
      
      // 3. 合并歌词列表
      final mergeResult = _mergeLyricLists(cloudLyrics, localLyrics);
      
      // 4. 处理上传
      for (final item in mergeResult.needUpload) {
        await _uploadLyricInternal(item);
      }
      
      // 5. 处理下载
      for (final item in mergeResult.needDownload) {
        await _downloadLyricInternal(item);
      }
      
      // 6. 处理冲突
      for (final conflict in mergeResult.conflicts) {
        await _resolveConflict(conflict);
      }
      
      _lastSyncTime = DateTime.now();
      _syncState = SyncState.idle;
      
      if (kDebugMode) {
        print('✅ 歌词库同步完成');
        print('📤 上传: ${mergeResult.needUpload.length}');
        print('📥 下载: ${mergeResult.needDownload.length}');
        print('⚡ 冲突: ${mergeResult.conflicts.length}');
      }
      
      return SyncResult.success('同步完成');
    } catch (e) {
      _syncState = SyncState.error;
      if (kDebugMode) {
        print('❌ 歌词库同步失败: $e');
      }
      return SyncResult.error('同步失败: $e');
    }
  }

  /// 获取用户云端歌词列表
  Future<List<LyricCloudItem>> _fetchCloudLyricList() async {
    try {
      final response = await _httpClient.get(
        Uri.parse('$_serverUrl/api/lyrics/user'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => LyricCloudItem.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 获取本地歌词列表
  Future<List<LyricSyncItem>> _getLocalLyricList() async {
    final stats = await _cacheService.getCacheStats();
    // 返回本地缓存的歌词列表
    return [];
  }

  /// 合并歌词列表
  _MergeResult _mergeLyricLists(
    List<LyricCloudItem> cloudLyrics,
    List<LyricSyncItem> localLyrics,
  ) {
    final needUpload = <LyricSyncItem>[];
    final needDownload = <LyricCloudItem>[];
    final conflicts = <SyncConflict>[];
    
    final cloudMap = {for (var c in cloudLyrics) '${c.title}_${c.artist}': c};
    final localMap = {for (var l in localLyrics) '${l.title}_${l.artist}': l};
    
    // 找出需要上传的（本地有，云端没有）
    for (final local in localLyrics) {
      final key = '${local.title}_${local.artist}';
      if (!cloudMap.containsKey(key)) {
        needUpload.add(local);
      } else {
        // 检查是否需要更新
        final cloud = cloudMap[key]!;
        if (local.updatedAt != null && 
            cloud.updatedAt != null && 
            local.updatedAt!.isAfter(cloud.updatedAt!)) {
          needUpload.add(local);
        }
      }
    }
    
    // 找出需要下载的（云端有，本地没有）
    for (final cloud in cloudLyrics) {
      final key = '${cloud.title}_${cloud.artist}';
      if (!localMap.containsKey(key)) {
        needDownload.add(cloud);
      }
    }
    
    return _MergeResult(
      needUpload: needUpload,
      needDownload: needDownload,
      conflicts: conflicts,
    );
  }

  /// 上传歌词（内部方法）
  Future<void> _uploadLyricInternal(LyricSyncItem item) async {
    try {
      await _httpClient.post(
        Uri.parse('$_serverUrl/api/lyrics'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({
          'title': item.title,
          'artist': item.artist,
          'lrcContent': item.lrcContent,
          'language': item.language,
          'isPublic': item.isPublic,
          'metadata': item.metadata,
        }),
      );
    } catch (e) {
      // 忽略错误
    }
  }

  /// 下载歌词（内部方法）
  Future<void> _downloadLyricInternal(LyricCloudItem item) async {
    try {
      // 保存到本地缓存
      if (item.lrcContent != null) {
        await _cacheService.cacheLyric(
          title: item.title,
          artist: item.artist,
          language: item.language,
          lrcContent: item.lrcContent!,
        );
      }
    } catch (e) {
      // 忽略错误
    }
  }

  /// 解决冲突
  Future<void> _resolveConflict(SyncConflict conflict) async {
    switch (_conflictStrategy) {
      case SyncConflictStrategy.serverWins:
        await _downloadLyricInternal(conflict.cloudItem);
        break;
      case SyncConflictStrategy.clientWins:
        await _uploadLyricInternal(conflict.localItem);
        break;
      case SyncConflictStrategy.keepBoth:
        // 重命名为新标题
        final newItem = conflict.localItem.copyWith(
          title: '${conflict.localItem.title} (本地)',
        );
        await _uploadLyricInternal(newItem);
        break;
      case SyncConflictStrategy.manual:
        // 手动解决，由用户决定
        _pendingSyncQueue.add(LyricSyncItem(
          title: conflict.localItem.title,
          artist: conflict.localItem.artist,
          lrcContent: conflict.localItem.lrcContent,
          action: SyncAction.conflict,
          createdAt: DateTime.now(),
        ));
        break;
    }
  }

  /// 获取收藏的歌词列表
  Future<List<LyricCloudItem>> getFavoritedLyrics() async {
    if (!isLoggedIn) return [];
    
    try {
      final response = await _httpClient.get(
        Uri.parse('$_serverUrl/api/lyrics/favorites'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => LyricCloudItem.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 收藏歌词
  Future<bool> favoriteLyric(String lyricId) async {
    if (!isLoggedIn) return false;
    
    try {
      final response = await _httpClient.post(
        Uri.parse('$_serverUrl/api/lyrics/$lyricId/favorite'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 取消收藏歌词
  Future<bool> unfavoriteLyric(String lyricId) async {
    if (!isLoggedIn) return false;
    
    try {
      final response = await _httpClient.delete(
        Uri.parse('$_serverUrl/api/lyrics/$lyricId/favorite'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 获取编辑历史
  Future<List<LyricEditHistory>> getEditHistory(String lyricId) async {
    if (!isLoggedIn) return [];
    
    try {
      final response = await _httpClient.get(
        Uri.parse('$_serverUrl/api/lyrics/$lyricId/history'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => LyricEditHistory.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// 保存待同步队列
  Future<void> _savePendingQueue() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(path.join(dir.path, 'pending_sync_queue.json'));
      await file.writeAsString(jsonEncode(_pendingSyncQueue.map((e) => e.toJson()).toList()));
    } catch (e) {
      // 忽略错误
    }
  }

  /// 获取待同步队列状态
  int get pendingSyncCount => _pendingSyncQueue.length;

  /// 同步待同步队列
  Future<void> syncPendingQueue() async {
    if (!isLoggedIn || _pendingSyncQueue.isEmpty) return;
    
    final queue = List<LyricSyncItem>.from(_pendingSyncQueue);
    _pendingSyncQueue.clear();
    
    for (final item in queue) {
      if (item.action == SyncAction.upload) {
        await uploadLyric(
          title: item.title,
          artist: item.artist,
          lrcContent: item.lrcContent ?? '',
          language: item.language,
        );
      }
    }
  }
}

/// 同步状态
enum SyncState {
  idle,           // 空闲
  authenticating, // 认证中
  syncing,        // 同步中
  uploading,      // 上传中
  downloading,    // 下载中
  error,          // 错误
}

/// 同步操作
enum SyncAction {
  upload,   // 上传
  download, // 下载
  conflict, // 冲突
}

/// 冲突解决策略
enum SyncConflictStrategy {
  serverWins, // 服务端优先
  clientWins, // 客户端优先
  keepBoth,   // 保留两者
  manual,     // 手动解决
}

/// 同步结果
class SyncResult {
  final bool success;
  final String message;

  SyncResult._(this.success, this.message);

  factory SyncResult.success(String message) => SyncResult._(true, message);
  factory SyncResult.error(String message) => SyncResult._(false, message);
}

/// 歌词同步项
class LyricSyncItem {
  final String title;
  final String artist;
  final String? lrcContent;
  final String? language;
  final bool isPublic;
  final Map<String, dynamic>? metadata;
  final SyncAction action;
  final DateTime createdAt;
  final DateTime? updatedAt;

  LyricSyncItem({
    required this.title,
    required this.artist,
    this.lrcContent,
    this.language,
    this.isPublic = false,
    this.metadata,
    required this.action,
    required this.createdAt,
    this.updatedAt,
  });

  LyricSyncItem copyWith({
    String? title,
    String? artist,
    String? lrcContent,
    String? language,
    bool? isPublic,
    Map<String, dynamic>? metadata,
    SyncAction? action,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LyricSyncItem(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      lrcContent: lrcContent ?? this.lrcContent,
      language: language ?? this.language,
      isPublic: isPublic ?? this.isPublic,
      metadata: metadata ?? this.metadata,
      action: action ?? this.action,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'artist': artist,
    'lrcContent': lrcContent,
    'language': language,
    'isPublic': isPublic,
    'metadata': metadata,
    'action': action.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}

/// 云端歌词项
class LyricCloudItem {
  final String id;
  final String title;
  final String artist;
  final String? lrcContent;
  final String? language;
  final String? userId;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? metadata;

  LyricCloudItem({
    required this.id,
    required this.title,
    required this.artist,
    this.lrcContent,
    this.language,
    this.userId,
    this.isPublic = false,
    required this.createdAt,
    this.updatedAt,
    this.metadata,
  });

  factory LyricCloudItem.fromJson(Map<String, dynamic> json) {
    return LyricCloudItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artist: json['artist'] ?? '',
      lrcContent: json['lrcContent'],
      language: json['language'],
      userId: json['userId'],
      isPublic: json['isPublic'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      metadata: json['metadata'],
    );
  }
}

/// 歌词编辑历史
class LyricEditHistory {
  final String id;
  final String lyricId;
  final String lrcContent;
  final String editedBy;
  final DateTime editedAt;
  final String? editNote;

  LyricEditHistory({
    required this.id,
    required this.lyricId,
    required this.lrcContent,
    required this.editedBy,
    required this.editedAt,
    this.editNote,
  });

  factory LyricEditHistory.fromJson(Map<String, dynamic> json) {
    return LyricEditHistory(
      id: json['id'] ?? '',
      lyricId: json['lyricId'] ?? '',
      lrcContent: json['lrcContent'] ?? '',
      editedBy: json['editedBy'] ?? '',
      editedAt: DateTime.parse(json['editedAt']),
      editNote: json['editNote'],
    );
  }
}

/// 同步冲突
class SyncConflict {
  final LyricCloudItem cloudItem;
  final LyricSyncItem localItem;

  SyncConflict({
    required this.cloudItem,
    required this.localItem,
  });
}

/// 合并结果
class _MergeResult {
  final List<LyricSyncItem> needUpload;
  final List<LyricCloudItem> needDownload;
  final List<SyncConflict> conflicts;

  _MergeResult({
    required this.needUpload,
    required this.needDownload,
    required this.conflicts,
  });
}
