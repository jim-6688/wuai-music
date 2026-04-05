import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// QQ音乐榜单数据模型
class QQMusicLeaderboard {
  final String id;
  final String name;
  final String coverUrl;
  final int trackCount;
  final String? description;
  final int updateTime;
  final String period; // 更新周期描述，如 "2024-01-15"

  QQMusicLeaderboard({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.trackCount,
    this.description,
    this.updateTime = 0,
    this.period = '',
  });

  factory QQMusicLeaderboard.fromJson(Map<String, dynamic> json) {
    return QQMusicLeaderboard(
      id: json['topId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['topName'] ?? json['name'] ?? '',
      coverUrl: json['frontPicUrl'] ?? json['picUrl'] ?? json['coverImgUrl'] ?? '',
      trackCount: json['songCount'] ?? json['trackCount'] ?? 0,
      description: json['intro'] ?? json['description'],
      updateTime: json['updateTime'] ?? 0,
      period: json['period'] ?? '',
    );
  }
}

/// QQ音乐榜单歌曲
class QQMusicSong {
  final String id;
  final String mid; // QQ音乐 songmid
  final String name;
  final String singer;
  final String? album;
  final String? albumMid;
  final String? albumCover;
  final int duration; // 毫秒
  final int rank; // 排名

  QQMusicSong({
    required this.id,
    this.mid = '',
    required this.name,
    required this.singer,
    this.album,
    this.albumMid,
    this.albumCover,
    required this.duration,
    this.rank = 0,
  });

  factory QQMusicSong.fromJson(Map<String, dynamic> json, {int rank = 0}) {
    // 解析歌手
    String singer = '';
    final singerData = json['singer'];
    if (singerData is List) {
      singer = singerData.map((s) => s['name'] ?? '').join('/');
    } else if (singerData is String) {
      singer = singerData;
    }

    // 解析专辑
    String? albumName;
    String? albumMid;
    String? albumCover;
    final albumData = json['album'];
    if (albumData is Map) {
      albumName = albumData['name'];
      albumMid = albumData['mid'];
      albumCover = albumData['picMid'] != null
          ? 'https://y.gtimg.cn/music/photo_new/T002R300x300M000${albumData['mid']}.jpg'
          : null;
    }

    return QQMusicSong(
      id: json['songid']?.toString() ?? json['id']?.toString() ?? '',
      mid: json['songmid'] ?? json['mid'] ?? '',
      name: json['songname'] ?? json['songname_original'] ?? json['name'] ?? '',
      singer: singer,
      album: albumName,
      albumMid: albumMid,
      albumCover: albumCover ??
          (json['albumPic'] ??
           json['albumImg'] ??
           json['pic']),
      duration: (json['interval'] ?? json['duration'] ?? 0) * 1000,
      rank: rank,
    );
  }
}

/// QQ音乐开发者配置
/// 
/// 【重要】请在此处填入你在QQ音乐开放平台申请的 API 凭证
/// 申请地址：https://y.qq.com/portal/developer.html
/// 
/// 注意：
/// 1. API Key 和 App Key 是开发者凭证，内置在 App 中
/// 2. 用户无需配置，直接使用
/// 3. 公共榜单无需用户登录即可访问
/// 4. 个人歌单需要用户扫码授权
class QQMusicDeveloperConfig {
  /// 开发者 API Key（从QQ音乐开放平台获取）
  /// TODO: 替换为你申请的 API Key（审核中）
  static const String apiKey = 'YOUR_QQMUSIC_API_KEY';
  
  /// 开发者 App Key（从QQ音乐开放平台获取）
  /// TODO: 替换为你申请的 App Key（审核中）
  static const String appKey = 'YOUR_QQMUSIC_APP_KEY';
  
  /// 开放平台 API 地址
  static const String officialBaseUrl = 'https://api.y.qq.com';
  
  /// Web API（临时使用，非官方授权）
  static const String webApiBaseUrl = 'https://c.y.qq.com';
  
  /// 是否已配置官方 API 凭证
  static bool get isOfficialConfigured => 
      apiKey != 'YOUR_QQMUSIC_API_KEY' && 
      appKey != 'YOUR_QQMUSIC_APP_KEY';
  
  /// 获取当前使用的 API 地址
  static String get currentBaseUrl => 
      isOfficialConfigured ? officialBaseUrl : webApiBaseUrl;
}

/// QQ音乐 API 配置（兼容旧代码）
class QQMusicApiConfig {
  /// 当前使用的 API 地址
  static String get currentBaseUrl => QQMusicDeveloperConfig.currentBaseUrl;
  
  /// 获取 API Key
  static String? get apiKey => QQMusicDeveloperConfig.isOfficialConfigured 
      ? QQMusicDeveloperConfig.apiKey 
      : null;
  
  /// 获取 App Key
  static String? get appKey => QQMusicDeveloperConfig.isOfficialConfigured 
      ? QQMusicDeveloperConfig.appKey 
      : null;
  
  /// 是否已配置官方 API
  static bool get isOfficialConfigured => QQMusicDeveloperConfig.isOfficialConfigured;
  
  /// 设置官方 API 凭证（审核通过后调用）
  static void setOfficialCredentials({
    required String apiKey,
    required String appKey,
  }) {
    // 注意：这个方法在当前架构下仅用于运行时更新
    // 实际应该直接修改 QQMusicDeveloperConfig 的常量
  }
}

/// QQ音乐榜单服务
/// 使用QQ音乐官方公开API获取榜单数据
class QQMusicLeaderboardService {
  Dio? _dio;
  bool _isInitialized = false;
  
  /// 获取当前 API 地址
  String get _baseUrl => QQMusicApiConfig.currentBaseUrl;

  QQMusicLeaderboardService._();
  static final QQMusicLeaderboardService _instance = QQMusicLeaderboardService._();
  static QQMusicLeaderboardService get instance => _instance;

  /// 初始化
  Future<void> initialize() async {
    if (_isInitialized) return;

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Referer': 'https://y.qq.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ));

    _isInitialized = true;
    if (kDebugMode) {
      print('✅ QQ音乐榜单服务初始化完成');
    }
  }

  Dio get _dioInstance {
    if (_dio == null) throw StateError('QQMusicLeaderboardService 未初始化');
    return _dio!;
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      await _ensureInitialized();
      final response = await _dioInstance.get(
        '/v8/fcg-bin/fcg_v8_toplist_cp.fcg',
        queryParameters: {
          'format': 'json',
          'topid': '4',
          'num': '1',
          'platform': 'h5',
        },
      );
      return response.statusCode == 200 && response.data?['code'] == 0;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐连接测试失败: $e');
      return false;
    }
  }

  /// 获取所有榜单分类和列表
  /// 使用QQ音乐官方 toplist 接口
  Future<List<QQMusicLeaderboard>> getToplist() async {
    try {
      await _ensureInitialized();

      // QQ音乐官方榜单接口
      final response = await _dioInstance.get(
        '/v8/fcg-bin/fcg_v8_toplist_cp.fcg',
        queryParameters: {
          'format': 'json',
          'num': '100',
          'platform': 'h5',
        },
      );

      final data = response.data;
      if (data == null) return [];

      // 解析榜单列表
      final List<QQMusicLeaderboard> leaderboards = [];

      // 接口返回格式：{ code: 0, data: { topList: [...] } }
      // 或直接返回列表
      List? topList;
      if (data is Map) {
        topList = data['data']?['topList'] ?? data['topList'] ?? data['list'];
      }

      if (topList == null) {
        // 尝试从 songList 解析
        if (data is Map && data['songList'] != null) {
          topList = data['songList'] as List?;
        }
      }

      if (topList == null) return [];

      for (final item in topList) {
        if (item == null) continue;
        final map = item is Map<String, dynamic> ? item : <String, dynamic>{};
        try {
          leaderboards.add(QQMusicLeaderboard.fromJson(map));
        } catch (e) {
          if (kDebugMode) print('⚠️ 解析QQ音乐榜单失败: $e');
        }
      }

      if (kDebugMode) {
        print('✅ QQ音乐榜单获取成功: ${leaderboards.length} 个');
      }

      return leaderboards;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐榜单获取失败: $e');
      return [];
    }
  }

  /// 获取热门榜单列表（精简版）
  Future<List<QQMusicLeaderboard>> getHotToplist() async {
    try {
      await _ensureInitialized();

      final response = await _dioInstance.get(
        '/v8/fcg-bin/v8.fcg',
        queryParameters: {
          'channel': 'singer',
          'page': 'list',
          'key': 'all_all_all',
          'pagesize': '100',
          'pagenum': '1',
          'g_tk': '5381',
          'loginUin': '0',
          'hostUin': '0',
          'format': 'json',
          'inCharset': 'utf-8',
          'outCharset': 'utf-8',
          'notice': '0',
          'platform': 'yqq.json',
          'needNewCode': '0',
        },
      );

      final data = response.data;
      if (data == null) return [];

      final list = data['data']?['topList'] as List? ?? [];
      return list
          .map((item) => QQMusicLeaderboard.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐热门榜单获取失败: $e');
      return [];
    }
  }

  /// 获取榜单详情（包含歌曲列表）
  Future<List<QQMusicSong>> getLeaderboardDetail(String topId, {int num = 100}) async {
    try {
      await _ensureInitialized();

      final response = await _dioInstance.get(
        '/v8/fcg-bin/fcg_v8_toplist_cp.fcg',
        queryParameters: {
          'topid': topId,
          'num': num,
          'format': 'json',
          'platform': 'h5',
        },
      );

      final data = response.data;
      if (data == null || data['code'] != 0) return [];

      // 从 songList 解析歌曲
      final songList = data['songList'] as List? ?? data['data']?['songList'] as List? ?? [];
      final songs = <QQMusicSong>[];

      for (int i = 0; i < songList.length; i++) {
        final songData = songList[i]?['data'] ?? songList[i];
        if (songData == null) continue;
        try {
          songs.add(QQMusicSong.fromJson(
            songData is Map<String, dynamic> ? songData : <String, dynamic>{},
            rank: i + 1,
          ));
        } catch (e) {
          if (kDebugMode) print('⚠️ 解析QQ音乐歌曲失败: $e');
        }
      }

      if (kDebugMode) {
        print('✅ QQ音乐榜单详情获取成功: ${songs.length} 首');
      }

      return songs;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐榜单详情获取失败: $e');
      return [];
    }
  }

  /// 获取歌曲播放链接
  /// QQ音乐需要特定的签名验证，这里通过公开接口尝试获取
  Future<String?> getSongUrl(String songMid) async {
    try {
      await _ensureInitialized();

      // 使用QQ音乐的公开播放接口
      final response = await _dioInstance.get(
        '/v8/fcg-bin/fcg_play_song.fcg',
        queryParameters: {
          'songmid': songMid,
          'format': 'json',
          'platform': 'h5',
        },
      );

      final data = response.data;
      if (data == null) return null;

      // 尝试从不同字段获取 URL
      final url = data['url'] ?? data['data']?['url'] ?? data['playUrl'];
      return url?.toString();
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐播放链接获取失败: $e');
      return null;
    }
  }

  /// 搜索歌曲（用于歌词匹配等）
  Future<List<QQMusicSong>> searchSongs(String keyword, {int limit = 20}) async {
    try {
      await _ensureInitialized();

      final response = await _dioInstance.get(
        '/soso/fcgi-bin/client_search_cp',
        queryParameters: {
          'format': 'json',
          'p': '1',
          'n': limit,
          'w': keyword,
          'aggr': '1',
          'lossless': '0',
          'cr': '1',
          'new_json': '1',
        },
      );

      final data = response.data;
      final songList = data?['data']?['song']?['list'] as List? ?? [];
      final songs = <QQMusicSong>[];

      for (int i = 0; i < songList.length; i++) {
        try {
          songs.add(QQMusicSong.fromJson(
            songList[i] as Map<String, dynamic>,
            rank: i + 1,
          ));
        } catch (_) {}
      }

      return songs;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐搜索失败: $e');
      return [];
    }
  }
}

/// QQ音乐同步设置持久化
class QQMusicSyncSettings {
  static const String _enabledKey = 'qq_music_leaderboard_enabled';

  /// 获取是否启用QQ音乐榜单同步
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  /// 设置是否启用QQ音乐榜单同步
  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }
}
