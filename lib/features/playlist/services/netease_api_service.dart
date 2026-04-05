import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/netease_models.dart';
import 'netease_leaderboard_service.dart';

/// 网易云音乐 API 配置
class NeteaseApiConfig {
  // API 服务地址（从 NeteaseLeaderboardService 同步获取）
  static Future<String> get baseUrl async {
    await NeteaseLeaderboardService.instance.initialize();
    return NeteaseLeaderboardService.instance.baseUrl;
  }
  
  // 超时配置
  static const Duration connectTimeout = Duration(seconds: 6);
  static const Duration receiveTimeout = Duration(seconds: 15);
}

/// 网易云音乐 API 服务
class NeteaseApiService extends ChangeNotifier {
  late final Dio _dio;
  
  String? _cookie;
  String? _userId;
  bool _isLoggedIn = false;
  
  NeteaseApiService() {
    _dio = _createDio();
    
    // 添加拦截器
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // 添加 Cookie
        if (_cookie != null) {
          options.headers['cookie'] = _cookie;
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        debugPrint('API Error: ${error.message}');
        return handler.next(error);
      },
    ));
    
    // 异步初始化（获取保存的 base URL）
    _initializeFromStorage();
  }

  static Dio _createDio() {
    final opts = BaseOptions();
    opts.baseUrl = 'http://localhost:3000';
    opts.connectTimeout = NeteaseApiConfig.connectTimeout;
    opts.receiveTimeout = NeteaseApiConfig.receiveTimeout;
    opts.headers = {
      'Content-Type': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    };
    return Dio(opts);
  }

  /// 从本地存储初始化配置
  Future<void> _initializeFromStorage() async {
    try {
      await NeteaseLeaderboardService.instance.initialize();
      final savedUrl = NeteaseLeaderboardService.instance.baseUrl;
      _dio.options.baseUrl = savedUrl;
      if (kDebugMode) {
        print('✅ NeteaseApiService 初始化完成, baseUrl: $savedUrl');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ NeteaseApiService 初始化失败: $e');
    }
  }

  /// 更新 base URL（与 NeteaseLeaderboardService 同步）
  Future<void> updateBaseUrl(String url) async {
    _dio.options.baseUrl = url;
    if (kDebugMode) print('✅ NeteaseApiService baseUrl 已更新: $url');
  }
  
  // ─── Getters ───────────────────────────────────────────────────────────────
  
  bool get isLoggedIn => _isLoggedIn;
  String? get cookie => _cookie;
  String? get userId => _userId;
  
  // ─── 认证相关 ─────────────────────────────────────────────────────────────
  
  /// 手机号登录
  Future<NeteaseLoginResult> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/login/cellphone',
        queryParameters: {
          'phone': phone,
          'password': password,
        },
      );
      
      final data = response.data;
      
      if (data['code'] == 200) {
        _cookie = data['cookie'];
        _userId = data['profile']['userId']?.toString();
        _isLoggedIn = true;
        notifyListeners();
        
        return NeteaseLoginResult.success(
          userId: data['profile']['userId'].toString(),
          nickname: data['profile']['nickname'],
          avatarUrl: data['profile']['avatarUrl'],
          cookie: _cookie!,
        );
      } else {
        return NeteaseLoginResult.failure(
          message: data['msg'] ?? '登录失败',
          code: data['code'],
        );
      }
    } on DioException catch (e) {
      return NeteaseLoginResult.failure(
        message: '网络错误: ${e.message}',
        code: -1,
      );
    } catch (e) {
      return NeteaseLoginResult.failure(
        message: '未知错误: $e',
        code: -1,
      );
    }
  }
  
  /// 二维码登录 - 第1步：获取 key
  Future<String?> createQrCodeKey() async {
    try {
      final response = await _dio.get('/login/qr/key');
      final data = response.data;

      if (data['code'] == 200) {
        return data['unikey'];
      }
      return null;
    } catch (e) {
      debugPrint('Create QR key error: $e');
      return null;
    }
  }

  /// 二维码登录 - 第2步：用 key 生成二维码图片 URL
  Future<String?> createQrCodeImage(String key) async {
    try {
      final response = await _dio.post(
        '/login/qr/create',
        queryParameters: {'key': key, 'qrimg': true},
      );
      final data = response.data;

      if (data['code'] == 200 && data['data']?['qrurl'] != null) {
        return data['data']['qrurl'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Create QR image error: $e');
      return null;
    }
  }

  /// 二维码登录 - 第3步：检查扫码状态
  Future<NeteaseQrLoginStatus> checkQrCodeStatus(String key) async {
    try {
      final response = await _dio.get(
        '/login/qr/check',
        queryParameters: {'key': key},
      );

      final data = response.data;
      final code = data['code'];

      switch (code) {
        case 800:
          return NeteaseQrLoginStatus.expired;
        case 801:
          return NeteaseQrLoginStatus.waiting;
        case 802:
          return NeteaseQrLoginStatus.confirmed;
        case 803:
          // 登录成功，cookie 在响应头或响应体中
          _cookie = data['cookie'] ?? _dio.options.headers['cookie'];
          _isLoggedIn = true;
          notifyListeners();
          return NeteaseQrLoginStatus.success;
        default:
          return NeteaseQrLoginStatus.waiting;
      }
    } catch (e) {
      return NeteaseQrLoginStatus.error;
    }
  }

  /// 获取当前登录状态（含用户信息）
  /// 用于二维码登录后补全用户信息，或恢复登录状态
  Future<NeteaseLoginResult?> getLoginStatus() async {
    try {
      final response = await _dio.post('/login/status');
      final data = response.data;

      final profile = data['data']?['profile'];

      if (profile != null) {
        _userId = profile['userId']?.toString();
        _isLoggedIn = true;

        return NeteaseLoginResult.success(
          userId: profile['userId']?.toString() ?? '',
          nickname: profile['nickname'] ?? '',
          avatarUrl: profile['avatarUrl'],
          cookie: _cookie ?? '',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Get login status error: $e');
      return null;
    }
  }
  
  /// 刷新登录状态
  Future<bool> refreshLogin() async {
    if (_cookie == null) return false;
    
    try {
      final response = await _dio.post('/login/refresh');
      final data = response.data;
      
      if (data['code'] == 200) {
        _isLoggedIn = true;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _isLoggedIn = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 登出
  Future<void> logout() async {
    try {
      await _dio.get('/logout');
    } catch (e) {
      // 忽略错误
    } finally {
      _cookie = null;
      _isLoggedIn = false;
      notifyListeners();
    }
  }
  
  // ─── 用户歌单 ─────────────────────────────────────────────────────────────
  
  /// 获取用户歌单列表
  Future<List<NeteasePlaylist>> getUserPlaylists(String uid) async {
    try {
      final response = await _dio.get(
        '/user/playlist',
        queryParameters: {'uid': uid, 'limit': 100},
      );
      
      final data = response.data;
      
      if (data['code'] == 200) {
        final playlists = (data['playlist'] as List)
            .map((p) => NeteasePlaylist.fromJson(p))
            .toList();
        return playlists;
      }
      return [];
    } catch (e) {
      debugPrint('Get user playlists error: $e');
      return [];
    }
  }
  
  /// 获取推荐歌单
  Future<List<NeteasePlaylist>> getRecommendPlaylists({int limit = 30}) async {
    try {
      final response = await _dio.get('/recommend/resource');
      final data = response.data;
      
      if (data['code'] == 200) {
        final playlists = (data['recommend'] as List)
            .map((p) => NeteasePlaylist.fromJson(p))
            .toList();
        return playlists;
      }
      return [];
    } catch (e) {
      debugPrint('Get recommend playlists error: $e');
      return [];
    }
  }
  
  /// 获取歌单详情
  Future<NeteasePlaylistDetail?> getPlaylistDetail(String id) async {
    try {
      final response = await _dio.get(
        '/playlist/detail',
        queryParameters: {'id': id},
      );
      
      final data = response.data;
      
      if (data['code'] == 200) {
        return NeteasePlaylistDetail.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Get playlist detail error: $e');
      return null;
    }
  }
  
  // ─── 歌曲相关 ─────────────────────────────────────────────────────────────
  
  /// 获取歌曲播放链接
  Future<String?> getSongUrl(String id, {int level = 1}) async {
    try {
      final response = await _dio.get(
        '/song/url',
        queryParameters: {'id': id, 'level': level},
      );
      
      final data = response.data;
      
      if (data['code'] == 200 && data['data'].isNotEmpty) {
        return data['data'][0]['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Get song url error: $e');
      return null;
    }
  }
  
  /// 获取多个歌曲播放链接
  Future<Map<String, String>> getSongsUrl(List<String> ids, {int level = 1}) async {
    try {
      final response = await _dio.get(
        '/song/url',
        queryParameters: {'ids': ids.join(','), 'level': level},
      );
      
      final data = response.data;
      final result = <String, String>{};
      
      if (data['code'] == 200 && data['data'] != null) {
        for (final song in data['data']) {
          if (song['url'] != null) {
            result[song['id'].toString()] = song['url'];
          }
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Get songs url error: $e');
      return {};
    }
  }
  
  /// 获取歌曲详情
  Future<List<NeteaseSong>?> getSongDetail(List<String> ids) async {
    try {
      final response = await _dio.get(
        '/song/detail',
        queryParameters: {'ids': ids.join(',')},
      );
      
      final data = response.data;
      
      if (data['code'] == 200) {
        return (data['songs'] as List)
            .map((s) => NeteaseSong.fromJson(s))
            .toList();
      }
      return null;
    } catch (e) {
      debugPrint('Get song detail error: $e');
      return null;
    }
  }
  
  // ─── 歌词 ─────────────────────────────────────────────────────────────────
  
  /// 获取歌词
  Future<NeteaseLyric?> getLyric(String id) async {
    try {
      final response = await _dio.get(
        '/lyric',
        queryParameters: {'id': id},
      );
      
      final data = response.data;
      
      if (data['code'] == 200) {
        return NeteaseLyric.fromJson(data);
      }
      return null;
    } catch (e) {
      debugPrint('Get lyric error: $e');
      return null;
    }
  }
  
  // ─── 搜索 ─────────────────────────────────────────────────────────────────
  
  /// 搜索歌曲/歌手/专辑/歌单
  Future<NeteaseSearchResult> search({
    required String keywords,
    int type = 1, // 1: 歌曲, 100: 歌手, 10: 专辑, 1000: 歌单
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/cloudsearch',
        queryParameters: {
          'keywords': keywords,
          'type': type,
          'limit': limit,
          'offset': offset,
        },
      );
      
      final data = response.data;
      
      if (data['code'] == 200) {
        return NeteaseSearchResult.fromJson(data, type);
      }
      return NeteaseSearchResult.empty();
    } catch (e) {
      debugPrint('Search error: $e');
      return NeteaseSearchResult.empty();
    }
  }
  
  /// 搜索歌曲（快捷方法）
  Future<List<NeteaseSong>> searchSongs(String keyword, {int limit = 30}) async {
    final result = await search(keywords: keyword, type: 1, limit: limit);
    return result.songs;
  }
  
  // ─── 设置 Cookie（用于恢复登录状态）─────────────────────────────────────────
  
  void setCookie(String cookie, {String? userId}) {
    _cookie = cookie;
    _userId = userId;
    _isLoggedIn = true;
    notifyListeners();
  }
}
