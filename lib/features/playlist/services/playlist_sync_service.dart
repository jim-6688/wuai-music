import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../data/models/playlist.dart';

/// 歌单同步服务
class PlaylistSyncService extends ChangeNotifier {
  // 网易云 API 基础地址（可替换为自己的服务器）
  static const String _neteaseBaseUrl = 'https://music.163.com/api';
  
  List<Playlist> _playlists = [];
  Playlist? _currentPlaylist;
  List<PlaylistTrack> _currentTracks = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // ─── Getters ──────────────────────────────────────────────────────────────
  
  List<Playlist> get playlists => List.unmodifiable(_playlists);
  Playlist? get currentPlaylist => _currentPlaylist;
  List<PlaylistTrack> get currentTracks => List.unmodifiable(_currentTracks);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // ─── 网易云歌单 ────────────────────────────────────────────────────────────
  
  /// 搜索歌单
  Future<List<Playlist>> searchPlaylists(String keyword, {int limit = 30}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final query = Uri.encodeComponent(keyword);
      final url = '$_neteaseBaseUrl/search/get?s=$query&type=1000&limit=$limit';
      
      if (kDebugMode) print('🔍 搜索歌单: $keyword');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'];
        final playlistList = result?['playlists'] as List? ?? [];
        
        final playlists = playlistList.map((p) => Playlist.fromJson(p)).toList();
        
        if (kDebugMode) print('✅ 找到 ${playlists.length} 个歌单');
        
        _playlists = playlists;
        _isLoading = false;
        notifyListeners();
        return playlists;
      }
      
      _errorMessage = '搜索失败 (${response.statusCode})';
      _isLoading = false;
      notifyListeners();
      return [];
    } catch (e) {
      _errorMessage = '网络错误: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }
  
  /// 获取歌单详情
  Future<Playlist?> getPlaylistDetail(String playlistId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final url = '$_neteaseBaseUrl/playlist/detail?id=$playlistId';
      
      if (kDebugMode) print('📥 获取歌单详情: $playlistId');
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final playlistJson = json['playlist'];
        
        if (playlistJson != null) {
          // 获取歌单曲目
          final tracks = await _getPlaylistTracks(playlistId);
          
          final playlist = Playlist.fromJson(playlistJson).copyWith(
            tracks: tracks,
            source: 'netease',
          );
          
          _currentPlaylist = playlist;
          _currentTracks = tracks;
          
          if (kDebugMode) print('✅ 歌单: ${playlist.name}, ${tracks.length} 首');
          
          _isLoading = false;
          notifyListeners();
          return playlist;
        }
      }
      
      _errorMessage = '获取歌单失败';
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = '网络错误: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
  
  /// 获取歌单曲目
  Future<List<PlaylistTrack>> _getPlaylistTracks(String playlistId) async {
    try {
      final url = '$_neteaseBaseUrl/playlist/track/all?id=$playlistId';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final songs = json['songs'] as List? ?? [];
        
        return songs.map((s) => PlaylistTrack.fromJson(s)).toList();
      }
      
      return [];
    } catch (e) {
      if (kDebugMode) print('⚠️ 获取曲目失败: $e');
      return [];
    }
  }
  
  /// 获取歌曲播放 URL
  Future<String?> getSongUrl(String songId) async {
    try {
      final url = '$_neteaseBaseUrl/song/url?id=$songId';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('timeout', 408),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] as List?;
        
        if (data != null && data.isNotEmpty) {
          return data[0]['url']?.toString();
        }
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) print('⚠️ 获取播放URL失败: $e');
      return null;
    }
  }
  
  // ─── 热门歌单 ──────────────────────────────────────────────────────────────
  
  /// 获取热门歌单分类
  Future<List<Map<String, dynamic>>> getHotCategories() async {
    try {
      final url = '$_neteaseBaseUrl/playlist/hot';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final tags = json['tags'] as List? ?? [];
        
        return tags.map((t) => {
          'name': t['name']?.toString() ?? '',
          'id': t['id']?.toString() ?? '',
        }).toList();
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }
  
  /// 获取分类下的歌单
  Future<List<Playlist>> getPlaylistsByCategory(String category, {int limit = 30, int offset = 0}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final query = Uri.encodeComponent(category);
      final url = '$_neteaseBaseUrl/top/playlist?cat=$query&limit=$limit&offset=$offset';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final playlistList = json['playlists'] as List? ?? [];
        
        final playlists = playlistList.map((p) => Playlist.fromJson(p)).toList();
        
        _playlists = playlists;
        _isLoading = false;
        notifyListeners();
        return playlists;
      }
      
      _isLoading = false;
      notifyListeners();
      return [];
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }
  
  // ─── 推荐歌单 ──────────────────────────────────────────────────────────────
  
  /// 获取推荐歌单
  Future<List<Playlist>> getRecommendPlaylists({int limit = 10}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      final url = '$_neteaseBaseUrl/personalized?limit=$limit';
      
      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'] as List? ?? [];
        
        final playlists = result.map((p) => Playlist.fromJson(p)).toList();
        
        _playlists = playlists;
        _isLoading = false;
        notifyListeners();
        return playlists;
      }
      
      _isLoading = false;
      notifyListeners();
      return [];
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return [];
    }
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
}
