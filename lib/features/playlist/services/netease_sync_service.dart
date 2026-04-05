import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'netease_api_service.dart';
import '../models/netease_models.dart';

/// 网易云音乐同步服务
class NeteaseSyncService extends ChangeNotifier {
  final NeteaseApiService _apiService;
  
  // 用户信息
  String? _userId;
  String? _nickname;
  String? _avatarUrl;
  
  // 歌单
  List<NeteasePlaylist> _userPlaylists = [];
  List<NeteasePlaylist> _recommendPlaylists = [];
  NeteasePlaylist? _currentPlaylist;
  List<NeteaseSong> _currentTracks = [];
  
  // 状态
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  double _syncProgress = 0.0;
  
  // 缓存
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _cookieKey = 'netease_cookie';
  static const String _userIdKey = 'netease_user_id';
  static const String _playlistsCacheKey = 'netease_playlists_cache';
  DateTime? _lastSyncTime;
  
  NeteaseSyncService(this._apiService) {
    _init();
  }
  
  // ─── Getters ───────────────────────────────────────────────────────────────
  
  String? get userId => _userId;
  String? get nickname => _nickname;
  String? get avatarUrl => _avatarUrl;
  List<NeteasePlaylist> get userPlaylists => List.unmodifiable(_userPlaylists);
  List<NeteasePlaylist> get recommendPlaylists => List.unmodifiable(_recommendPlaylists);
  NeteasePlaylist? get currentPlaylist => _currentPlaylist;
  List<NeteaseSong> get currentTracks => List.unmodifiable(_currentTracks);
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  double get syncProgress => _syncProgress;
  bool get isLoggedIn => _apiService.isLoggedIn;
  DateTime? get lastSyncTime => _lastSyncTime;
  
  // ─── 初始化 ─────────────────────────────────────────────────────────────
  
  Future<void> _init() async {
    // 恢复登录状态
    await _restoreLoginState();
    
    // 加载歌单缓存
    await _loadPlaylistsFromCache();
  }
  
  /// 恢复登录状态
  Future<void> _restoreLoginState() async {
    try {
      final cookie = await _secureStorage.read(key: _cookieKey);
      final savedUserId = await _secureStorage.read(key: _userIdKey);

      if (cookie != null) {
        _apiService.setCookie(cookie, userId: savedUserId);
        _userId = savedUserId;

        // 刷新登录状态 + 补全用户信息
        final loginResult = await _apiService.getLoginStatus();
        if (loginResult != null && loginResult.success) {
          _userId = loginResult.userId;
          _nickname = loginResult.nickname;
          _avatarUrl = loginResult.avatarUrl;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Restore login state error: $e');
    }
  }
  
  /// 加载歌单缓存
  Future<void> _loadPlaylistsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_playlistsCacheKey);
      
      if (cacheJson != null) {
        final cacheData = json.decode(cacheJson);
        _lastSyncTime = cacheData['lastSync'] != null 
            ? DateTime.parse(cacheData['lastSync']) 
            : null;
        
        if (cacheData['playlists'] != null) {
          _userPlaylists = (cacheData['playlists'] as List)
              .map((p) => NeteasePlaylist.fromJson(p))
              .toList();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Load playlists cache error: $e');
    }
  }
  
  /// 保存歌单到缓存
  Future<void> _savePlaylistsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'lastSync': DateTime.now().toIso8601String(),
        'playlists': _userPlaylists.map((p) => p.toJson()).toList(),
      };
      await prefs.setString(_playlistsCacheKey, json.encode(cacheData));
      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Save playlists cache error: $e');
    }
  }
  
  // ─── 登录 ─────────────────────────────────────────────────────────────────
  
  /// 手机号登录
  Future<bool> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final result = await _apiService.loginWithPhone(
        phone: phone,
        password: password,
      );
      
      if (result.success) {
        _userId = result.userId;
        _nickname = result.nickname;
        _avatarUrl = result.avatarUrl;
        
        // 保存登录状态
        await _secureStorage.write(key: _cookieKey, value: result.cookie);
        await _secureStorage.write(key: _userIdKey, value: result.userId);
        
        // 加载用户歌单
        await loadUserPlaylists();
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = result.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = '登录失败: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// 二维码登录 - 获取 key 和二维码 URL
  Future<QrCodeInfo?> createQrCode() async {
    final key = await _apiService.createQrCodeKey();
    if (key == null) return null;

    final qrUrl = await _apiService.createQrCodeImage(key);
    if (qrUrl == null) return null;

    return QrCodeInfo(key: key, qrUrl: qrUrl);
  }

  /// 检查二维码状态 - 成功后自动获取并保存用户信息
  Future<bool> checkQrCodeStatus(String key) async {
    final status = await _apiService.checkQrCodeStatus(key);

    switch (status) {
      case NeteaseQrLoginStatus.success:
        // 登录成功，通过 /login/status 获取用户信息
        final loginResult = await _apiService.getLoginStatus();
        if (loginResult != null && loginResult.success) {
          _userId = loginResult.userId;
          _nickname = loginResult.nickname;
          _avatarUrl = loginResult.avatarUrl;

          // 保存登录状态
          await _secureStorage.write(key: _cookieKey, value: _apiService.cookie ?? '');
          await _secureStorage.write(key: _userIdKey, value: _userId ?? '');

          // 自动加载用户歌单
          await loadUserPlaylists();
        } else {
          // 即使没拿到详细信息，也保存 cookie
          await _secureStorage.write(key: _cookieKey, value: _apiService.cookie ?? '');
        }
        notifyListeners();
        return true;
      case NeteaseQrLoginStatus.expired:
        _errorMessage = '二维码已过期，请刷新重试';
        notifyListeners();
        return false;
      case NeteaseQrLoginStatus.error:
        _errorMessage = '扫码登录失败';
        notifyListeners();
        return false;
      default:
        return false;
    }
  }
  
  /// 登出
  Future<void> logout() async {
    await _apiService.logout();
    await _secureStorage.delete(key: _cookieKey);
    await _secureStorage.delete(key: _userIdKey);
    
    _userId = null;
    _nickname = null;
    _avatarUrl = null;
    _userPlaylists = [];
    _currentPlaylist = null;
    _currentTracks = [];
    
    notifyListeners();
  }
  
  // ─── 歌单加载 ─────────────────────────────────────────────────────────────
  
  /// 加载用户歌单
  Future<void> loadUserPlaylists() async {
    if (_userId == null) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      _userPlaylists = await _apiService.getUserPlaylists(_userId!);
      await _savePlaylistsToCache();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载歌单失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 加载推荐歌单
  Future<void> loadRecommendPlaylists() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      _recommendPlaylists = await _apiService.getRecommendPlaylists();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载推荐歌单失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// 加载歌单详情
  Future<void> loadPlaylistDetail(NeteasePlaylist playlist) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final detail = await _apiService.getPlaylistDetail(playlist.id);
      
      if (detail != null) {
        _currentPlaylist = detail.playlist;
        _currentTracks = detail.tracks;
      }
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '加载歌单详情失败: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // ─── 歌曲操作 ─────────────────────────────────────────────────────────────
  
  /// 获取歌曲播放链接
  Future<String?> getSongUrl(String songId) async {
    return await _apiService.getSongUrl(songId);
  }
  
  /// 获取多个歌曲播放链接
  Future<Map<String, String>> getSongsUrl(List<String> songIds) async {
    return await _apiService.getSongsUrl(songIds);
  }
  
  /// 获取歌词
  Future<NeteaseLyric?> getLyric(String songId) async {
    return await _apiService.getLyric(songId);
  }
  
  /// 搜索歌曲
  Future<List<NeteaseSong>> searchSongs(String keyword) async {
    return await _apiService.searchSongs(keyword);
  }
  
  // ─── 同步 ─────────────────────────────────────────────────────────────────
  
  /// 同步所有歌单
  Future<void> syncAllPlaylists() async {
    if (_userId == null) return;
    
    _isSyncing = true;
    _syncProgress = 0.0;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // 获取最新歌单
      final playlists = await _apiService.getUserPlaylists(_userId!);
      _syncProgress = 0.3;
      notifyListeners();
      
      // 更新歌曲链接
      final songIds = <String>[];
      for (final playlist in playlists) {
        final detail = await _apiService.getPlaylistDetail(playlist.id);
        if (detail != null) {
          songIds.addAll(detail.tracks.map((t) => t.id));
        }
        _syncProgress += 0.1;
        notifyListeners();
      }
      
      // 获取播放链接
      if (songIds.isNotEmpty) {
        await _apiService.getSongsUrl(songIds);
      }
      
      // 保存歌单
      _userPlaylists = playlists;
      await _savePlaylistsToCache();
      
      _syncProgress = 1.0;
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '同步失败: $e';
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// 同步单个歌单
  Future<void> syncPlaylist(NeteasePlaylist playlist) async {
    _isSyncing = true;
    _syncProgress = 0.0;
    notifyListeners();
    
    try {
      // 更新歌单详情
      final detail = await _apiService.getPlaylistDetail(playlist.id);
      if (detail != null) {
        // 更新本地歌单列表中的这首歌单
        final index = _userPlaylists.indexWhere((p) => p.id == playlist.id);
        if (index >= 0) {
          _userPlaylists[index] = detail.playlist;
        }
        
        // 更新歌曲链接
        final songIds = detail.tracks.map((t) => t.id).toList();
        if (songIds.isNotEmpty) {
          await _apiService.getSongsUrl(songIds);
        }
      }
      
      await _savePlaylistsToCache();
      
      _syncProgress = 1.0;
      _isSyncing = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = '同步歌单失败: $e';
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// 清除错误消息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
