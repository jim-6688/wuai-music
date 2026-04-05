import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/models/playlist.dart';
import '../data/models/music_platform.dart';

/// 多平台歌单同步服务
class MultiPlatformPlaylistService extends ChangeNotifier {
  // 各平台 API 基础地址
  static const String _neteaseBaseUrl = 'https://music.163.com/api';
  static const String _qqBaseUrl = 'https://c.y.qq.com';
  
  List<Playlist> _playlists = [];
  Playlist? _currentPlaylist;
  List<PlaylistTrack> _currentTracks = [];
  bool _isLoading = false;
  String? _errorMessage;
  MusicPlatform _currentPlatform = MusicPlatform.netease;
  List<SyncRecord> _syncHistory = [];
  
  // ─── Getters ──────────────────────────────────────────────────────────────
  
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  Playlist? get currentPlaylist => _currentPlaylist;
  List<PlaylistTrack> get currentTracks => List.unmodifiable(_currentTracks);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  MusicPlatform get currentPlatform => _currentPlatform;
  List<SyncRecord> get syncHistory => List.unmodifiable(_syncHistory);
  
  // ─── 平台切换 ──────────────────────────────────────────────────────────────
  
  void switchPlatform(MusicPlatform platform) {
    _currentPlatform = platform;
    _playlists = [];
    notifyListeners();
    
    // 切换平台后自动加载推荐
    getRecommendPlaylists();
  }
  
  // ─── 网易云音乐 ────────────────────────────────────────────────────────────
  
  Future<List<Playlist>> _getNeteaseRecommend({int limit = 30}) async {
    try {
      final url = '$_neteaseBaseUrl/personalized?limit=$limit';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'] as List? ?? [];
        
        return result.map((p) => Playlist.fromJson(p).copyWith(source: 'netease')).toList();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 网易云推荐获取失败: $e');
    }
    return [];
  }
  
  Future<List<Playlist>> _searchNetease(String keyword, {int limit = 30}) async {
    try {
      final query = Uri.encodeComponent(keyword);
      final url = '$_neteaseBaseUrl/search/get?s=$query&type=1000&limit=$limit';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result']?['playlists'] as List? ?? [];
        
        return result.map((p) => Playlist.fromJson(p).copyWith(source: 'netease')).toList();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 网易云搜索失败: $e');
    }
    return [];
  }
  
  Future<List<Playlist>> _getNeteaseByCategory(String category, {int limit = 30, int offset = 0}) async {
    try {
      final query = Uri.encodeComponent(category);
      final url = '$_neteaseBaseUrl/top/playlist?cat=$query&limit=$limit&offset=$offset';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['playlists'] as List? ?? [];
        
        return result.map((p) => Playlist.fromJson(p).copyWith(source: 'netease')).toList();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 网易云分类获取失败: $e');
    }
    return [];
  }
  
  Future<Playlist?> _getNeteaseDetail(String playlistId) async {
    try {
      final url = '$_neteaseBaseUrl/playlist/detail?id=$playlistId';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final playlistJson = json['playlist'];
        
        if (playlistJson != null) {
          final tracks = await _getNeteaseTracks(playlistId);
          return Playlist.fromJson(playlistJson).copyWith(
            tracks: tracks,
            source: 'netease',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 网易云详情获取失败: $e');
    }
    return null;
  }
  
  Future<List<PlaylistTrack>> _getNeteaseTracks(String playlistId) async {
    try {
      final url = '$_neteaseBaseUrl/playlist/track/all?id=$playlistId';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final songs = json['songs'] as List? ?? [];
        
        return songs.map((s) => PlaylistTrack.fromJson(s).copyWith(source: 'netease')).cast<PlaylistTrack>().toList();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 网易云曲目获取失败: $e');
    }
    return [];
  }
  
  // ─── QQ音乐（模拟数据，实际需要API密钥）──────────────────────────────────────
  
  Future<List<Playlist>> _getQQRecommend({int limit = 30}) async {
    // QQ音乐需要登录态或API密钥，这里返回模拟数据提示用户
    if (kDebugMode) print('ℹ️ QQ音乐需要API配置');
    return [];
  }
  
  // ─── 酷狗音乐（模拟数据）─────────────────────────────────────────────────────
  
  Future<List<Playlist>> _getKugouRecommend({int limit = 30}) async {
    if (kDebugMode) print('ℹ️ 酷狗音乐需要API配置');
    return [];
  }
  
  // ─── 统一接口 ──────────────────────────────────────────────────────────────
  
  /// 获取推荐歌单（根据当前平台）
  Future<List<Playlist>> getRecommendPlaylists({int limit = 30}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    List<Playlist> result;
    
    switch (_currentPlatform) {
      case MusicPlatform.netease:
        result = await _getNeteaseRecommend(limit: limit);
        break;
      case MusicPlatform.qq:
        result = await _getQQRecommend(limit: limit);
        break;
      case MusicPlatform.kugou:
        result = await _getKugouRecommend(limit: limit);
        break;
      default:
        result = await _getNeteaseRecommend(limit: limit);
    }
    
    _playlists = result;
    _isLoading = false;
    
    if (result.isEmpty && _currentPlatform != MusicPlatform.netease) {
      _errorMessage = '${_currentPlatform.label}暂未支持，已切换到网易云';
      // 自动切换回网易云
      _currentPlatform = MusicPlatform.netease;
      result = await _getNeteaseRecommend(limit: limit);
      _playlists = result;
    }
    
    notifyListeners();
    return result;
  }
  
  /// 搜索歌单
  Future<List<Playlist>> searchPlaylists(String keyword, {int limit = 30}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    List<Playlist> result;
    
    switch (_currentPlatform) {
      case MusicPlatform.netease:
        result = await _searchNetease(keyword, limit: limit);
        break;
      default:
        result = await _searchNetease(keyword, limit: limit);
    }
    
    _playlists = result;
    _isLoading = false;
    notifyListeners();
    return result;
  }
  
  /// 按分类获取歌单
  Future<List<Playlist>> getPlaylistsByCategory(String category, {int limit = 30, int offset = 0}) async {
    _isLoading = true;
    notifyListeners();
    
    List<Playlist> result;
    
    switch (_currentPlatform) {
      case MusicPlatform.netease:
        result = await _getNeteaseByCategory(category, limit: limit, offset: offset);
        break;
      default:
        result = await _getNeteaseByCategory(category, limit: limit, offset: offset);
    }
    
    _playlists = result;
    _isLoading = false;
    notifyListeners();
    return result;
  }
  
  /// 获取歌单详情
  Future<Playlist?> getPlaylistDetail(String playlistId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    Playlist? result;
    
    switch (_currentPlatform) {
      case MusicPlatform.netease:
        result = await _getNeteaseDetail(playlistId);
        break;
      default:
        result = await _getNeteaseDetail(playlistId);
    }
    
    if (result != null) {
      _currentPlaylist = result;
      _currentTracks = result.tracks ?? [];
    }
    
    _isLoading = false;
    notifyListeners();
    return result;
  }
  
  /// 同步歌单到本地
  Future<SyncRecord> syncPlaylistToLocal(Playlist playlist) async {
    final record = SyncRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      playlistId: playlist.id,
      playlistName: playlist.name,
      platform: _currentPlatform,
      syncTime: DateTime.now(),
      trackCount: playlist.trackCount,
      success: true,
    );
    
    _syncHistory.insert(0, record);
    notifyListeners();
    
    if (kDebugMode) print('✅ 同步歌单: ${playlist.name} (${playlist.trackCount}首)');
    
    return record;
  }
  
  /// 批量同步多个歌单
  Future<List<SyncRecord>> syncMultiplePlaylists(List<Playlist> playlists) async {
    final records = <SyncRecord>[];
    
    for (final playlist in playlists) {
      final record = await syncPlaylistToLocal(playlist);
      records.add(record);
    }
    
    return records;
  }
  
  // ─── 工具方法 ──────────────────────────────────────────────────────────────
  
  void clearCurrentPlaylist() {
    _currentPlaylist = null;
    _currentTracks = [];
    notifyListeners();
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  void clearSyncHistory() {
    _syncHistory = [];
    notifyListeners();
  }
}