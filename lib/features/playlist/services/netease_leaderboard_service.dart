import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/netease_models.dart';

/// 网易云音乐开发者配置
/// 
/// 【重要】请在此处填入你在网易云开放平台申请的 API 凭证
/// 申请地址：https://music.163.com/#/api
/// 
/// 注意：
/// 1. API Key 和 App Secret 是开发者凭证，内置在 App 中
/// 2. 用户无需配置，直接使用
/// 3. 公共榜单无需用户登录即可访问
/// 4. 个人歌单需要用户扫码授权
class NeteaseDeveloperConfig {
  /// 开发者 API Key（从网易云开放平台获取）
  /// 支持从环境变量或配置文件读取，开源友好
  static const String apiKey = String.fromEnvironment(
    'NETEASE_API_KEY',
    defaultValue: 'b3010d0000000000649a47b43323af61',
  );
  
  /// 开发者 App Secret（从网易云开放平台获取）
  static const String appSecret = String.fromEnvironment(
    'NETEASE_APP_SECRET',
    defaultValue: 'de5f0badda566acc5a11a4d0f5a40a31',
  );
  
  /// 开放平台 API 地址
  static const String officialBaseUrl = 'https://music.163.com/api';
  
  /// 第三方 Meting API（备用，未获得官方授权时使用）
  static const String fallbackBaseUrl = 'https://api.injahow.cn/meting/';
  
  /// 是否已配置官方 API 凭证
  static bool get isOfficialConfigured => true;
  
  /// 获取当前使用的 API 地址
  static String get currentBaseUrl => officialBaseUrl;
}

/// 网易云API配置
class NeteaseApiConfig {
  final String apiBaseUrl;
  final bool isConfigured;

  NeteaseApiConfig({
    required this.apiBaseUrl,
    required this.isConfigured,
  });
}

/// 用户登录信息存储（扫码登录后的凭证）
class NeteaseUserStorage {
  static const String _cookieKey = 'netease_user_cookie';
  static const String _userIdKey = 'netease_user_id';
  static const String _nicknameKey = 'netease_user_nickname';
  static const String _avatarKey = 'netease_user_avatar';
  static const String _tokenKey = 'netease_user_token';

  /// 保存用户登录信息
  static Future<void> saveUserInfo({
    required String cookie,
    required String userId,
    String? nickname,
    String? avatar,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cookieKey, cookie);
    await prefs.setString(_userIdKey, userId);
    if (nickname != null) await prefs.setString(_nicknameKey, nickname);
    if (avatar != null) await prefs.setString(_avatarKey, avatar);
    if (token != null) await prefs.setString(_tokenKey, token);
  }
  
  /// 获取用户 Cookie（用于 API 调用）
  static Future<String?> getCookie() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_cookieKey);
  }
  
  /// 获取用户 ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }
  
  /// 获取用户昵称
  static Future<String?> getNickname() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_nicknameKey);
  }
  
  /// 获取用户头像
  static Future<String?> getAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarKey);
  }
  
  /// 是否已登录
  static Future<bool> isLoggedIn() async {
    final cookie = await getCookie();
    return cookie != null && cookie.isNotEmpty;
  }
  
  /// 清除登录信息（退出登录）
  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cookieKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_nicknameKey);
    await prefs.remove(_avatarKey);
    await prefs.remove(_tokenKey);
  }
}

/// 网易云音乐 API 配置存储（保留用于自定义 API 地址）
class NeteaseApiConfigStorage {
  static const String _baseUrlKey = 'netease_api_base_url';

  /// 获取API地址（优先用户自定义，否则使用开发者配置）
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_baseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }
    return NeteaseDeveloperConfig.currentBaseUrl;
  }

  /// 保存自定义API地址
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, url);
  }

  /// 重置为默认地址
  static Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
  }
  
  /// 获取备用API地址
  static String get fallbackBaseUrl => NeteaseDeveloperConfig.fallbackBaseUrl;
  
  /// 获取官方API地址
  static String get officialBaseUrl => NeteaseDeveloperConfig.officialBaseUrl;
}

/// 网易云榜单服务
/// 使用网易云原生API获取官方榜单数据
class NeteaseLeaderboardService {
  Dio? _dio;
  String _baseUrl = 'http://localhost:3000';
  bool _isInitialized = false;

  NeteaseLeaderboardService._();

  static final NeteaseLeaderboardService _instance = NeteaseLeaderboardService._();
  static NeteaseLeaderboardService get instance => _instance;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    _baseUrl = await NeteaseApiConfigStorage.getBaseUrl();

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));

    _isInitialized = true;
    if (kDebugMode) {
      print('✅ 网易云榜单服务初始化完成, API: $_baseUrl');
    }
  }

  /// 更新API地址
  Future<void> updateBaseUrl(String url) async {
    _baseUrl = url;
    await NeteaseApiConfigStorage.setBaseUrl(url);

    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));

    if (kDebugMode) {
      print('✅ 网易云API地址已更新: $_baseUrl');
    }
  }

  /// 获取当前API地址
  String get baseUrl => _baseUrl;

  /// 获取配置信息
  Future<NeteaseApiConfig> getConfig() async {
    await initialize();
    return NeteaseApiConfig(
      apiBaseUrl: _baseUrl,
      isConfigured: _baseUrl != NeteaseApiConfigStorage.officialBaseUrl,
    );
  }

  /// 更新配置
  Future<void> updateConfig({String? apiBaseUrl}) async {
    if (apiBaseUrl != null) {
      await updateBaseUrl(apiBaseUrl);
    }
  }

  /// 重置配置
  Future<void> resetConfig() async {
    await NeteaseApiConfigStorage.resetBaseUrl();
    _baseUrl = NeteaseApiConfigStorage.officialBaseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));
  }

  /// 确保服务已初始化
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  /// 获取 Dio 实例（确保已初始化）
  Dio get _dioInstance {
    if (_dio == null) {
      throw StateError('NeteaseLeaderboardService 未初始化，请先调用 initialize()');
    }
    return _dio!;
  }

  /// 测试API连接（兼容网易云原生API和Meting API）
  Future<bool> testConnection() async {
    try {
      await _ensureInitialized();
      
      // 先尝试网易云原生 API 接口
      try {
        final response = await _dioInstance.get('/banner', queryParameters: {'type': 0});
        if (response.statusCode == 200) return true;
      } catch (_) {
        // 原生 API 失败，尝试 Meting API 格式
      }

      // 如果原生 API 不可用，尝试 Meting API 格式（?type=url&id=xxx）
      final metingTestUrl = _baseUrl.contains('?') 
          ? '$_baseUrl&type=url&id=347230' 
          : '$_baseUrl?type=url&id=347230';
      final testDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ));
      final response = await testDio.get(metingTestUrl);
      // Meting API 返回 302 重定向到音频文件表示成功
      if (response.statusCode == 302 || response.statusCode == 200) return true;
      // 有些 Meting 实现直接返回 JSON
      if (response.statusCode == 200 && response.data != null) return true;
      
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ API连接测试失败: $e');
      }
      return false;
    }
  }

  /// 获取所有榜单列表
  Future<List<NeteaseLeaderboard>> getToplist() async {
    try {
      await _ensureInitialized();
      final response = await _dioInstance.get('/toplist');
      final data = response.data;

      if (data['code'] == 200) {
        final list = data['list'] as List;
        return list.map((item) => NeteaseLeaderboard.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取榜单列表失败: $e');
      }
      return [];
    }
  }

  /// 获取榜单详情（包含歌曲列表）
  Future<NeteaseLeaderboardDetail?> getLeaderboardDetail(String id, {int limit = 100}) async {
    try {
      await _ensureInitialized();
      final response = await _dioInstance.get(
        '/playlist/detail',
        queryParameters: {'id': id, 'limit': limit, 'offset': 0},
      );
      final data = response.data;

      if (data['code'] == 200) {
        return NeteaseLeaderboardDetail.fromJson(data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取榜单详情失败: $e');
      }
      return null;
    }
  }

  /// 获取推荐歌单
  Future<List<NeteasePlaylist>> getRecommendPlaylists({int limit = 30}) async {
    try {
      await _ensureInitialized();
      final response = await _dioInstance.get('/recommend/resource', queryParameters: {'limit': limit});
      final data = response.data;

      if (data['code'] == 200) {
        final list = data['recommend'] as List;
        return list.map((item) => NeteasePlaylist.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取推荐歌单失败: $e');
      }
      return [];
    }
  }

  /// 获取歌曲播放链接（支持多种音质）
  Future<NeteaseSongUrl?> getSongUrl(String id, {int level = 1}) async {
    try {
      await _ensureInitialized();
      // level: 0: 浏览级(128k), 1: 标准(192k), 2: 高品(320k), 3: 无损(flac)
      final levelMap = {0: 'standard', 1: 'higher', 2: 'exhigh', 3: 'lossless', 4: 'hires'};
      final levelStr = levelMap[level] ?? 'standard';

      final response = await _dioInstance.get(
        '/song/url',
        queryParameters: {'id': id, 'level': levelStr},
      );
      final data = response.data;

      if (data['code'] == 200 && data['data'].isNotEmpty) {
        return NeteaseSongUrl.fromJson(data['data'][0]);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取歌曲URL失败: $e');
      }
      return null;
    }
  }

  /// 搜索歌曲
  Future<List<NeteaseSong>> searchSongs(String keyword, {int limit = 30}) async {
    try {
      await _ensureInitialized();
      final response = await _dioInstance.get(
        '/cloudsearch',
        queryParameters: {'keywords': keyword, 'type': 1, 'limit': limit},
      );
      final data = response.data;

      if (data['code'] == 200) {
        final songs = data['result']?['songs'] as List? ?? [];
        return songs.map((item) => NeteaseSong.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('❌ 搜索歌曲失败: $e');
      }
      return [];
    }
  }

  /// 获取歌词
  Future<NeteaseLyric?> getLyric(String id) async {
    try {
      await _ensureInitialized();
      final response = await _dioInstance.get('/lyric', queryParameters: {'id': id});
      final data = response.data;

      if (data['code'] == 200) {
        return NeteaseLyric.fromJson(data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取歌词失败: $e');
      }
      return null;
    }
  }
}
