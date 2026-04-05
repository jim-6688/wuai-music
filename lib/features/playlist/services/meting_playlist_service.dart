import 'package:flutter/foundation.dart';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';
import 'package:wuaimusic/features/playlist/data/models/playlist.dart';
import 'package:wuaimusic/features/playlist/services/meting_api_client.dart';
import 'package:wuaimusic/features/files/data/models/track.dart';
import 'package:wuaimusic/features/player/service/audio_player_service.dart';
import 'package:wuaimusic/features/custom_source/services/custom_source_service.dart';

/// Meting 歌单服务
/// 
/// 管理歌单状态和业务逻辑，包括歌单加载、歌曲播放、搜索等
/// 支持与 JS 音源服务组合，获取高质量播放链接
class MetingPlaylistService {
  final MetingApiClient _apiClient;
  final AudioPlayerService _playerService;
  
  /// JS 音源服务（可选，用于获取高质量播放链接）
  CustomSourceService? _customSourceService;

  // 当前歌单
  MetingPlaylistDetail? _currentPlaylist;

  // 当前平台
  String _currentPlatform = 'netease';

  // 搜索历史
  final List<String> _searchHistory = [];

  // 播放列表（Track 格式）
  List<Track> _tracks = [];

  // 歌曲 URL 缓存 (songId -> url)
  final Map<String, String> _urlCache = {};

  // 是否启用 JS 音源获取高质量链接
  bool _useJsSourceForHighQuality = true;

  MetingPlaylistService({
    required MetingApiClient apiClient,
    required AudioPlayerService playerService,
  })  : _apiClient = apiClient,
        _playerService = playerService;
  
  /// 设置 JS 音源服务（用于获取高质量链接）
  void setCustomSourceService(CustomSourceService? service) {
    _customSourceService = service;
    if (kDebugMode) {
      print('🎵 [Meting] JS音源服务已${service != null ? "启用" : "禁用"}');
    }
  }
  
  /// 启用/禁用高质量音源获取
  void setHighQualityEnabled(bool enabled) {
    _useJsSourceForHighQuality = enabled;
    if (kDebugMode) {
      print('🎵 [Meting] 高质量音源: $enabled');
    }
  }
  
  /// 获取启用的 JS 音源
  CustomSourceService? get customSourceService => _customSourceService;

  // Getters
  MetingPlaylistDetail? get currentPlaylist => _currentPlaylist;
  String get currentPlatform => _currentPlatform;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  List<Track> get tracks => List.unmodifiable(_tracks);
  List<Track> get getTrackList => List.unmodifiable(_tracks);

  /// 加载歌单详情
  Future<MetingResponse<void>> loadPlaylist(String id) async {
    try {
      final response = await _apiClient.getPlaylist(id, platform: _currentPlatform);

      if (response.success && response.data != null) {
        _currentPlaylist = response.data!;

        // 清空 URL 缓存
        _urlCache.clear();

        // 转换为 Track 列表（暂时使用空 URL，播放时会获取）
        _tracks = response.data!.songs.map((song) => song.toTrack()).toList();

        return MetingResponse.success(null);
      }

      return MetingResponse.error(response.error ?? '加载歌单失败');
    } catch (e) {
      return MetingResponse.error('加载歌单失败: $e');
    }
  }

  /// 搜索歌单
  Future<MetingResponse<List<MetingPlaylistDetail>>> searchPlaylists(
    String keyword, {
    int limit = 30,
  }) async {
    try {
      // 保存搜索历史
      if (keyword.isNotEmpty && !_searchHistory.contains(keyword)) {
        _searchHistory.insert(0, keyword);
        if (_searchHistory.length > 10) {
          _searchHistory.removeLast();
        }
      }

      final response = await _apiClient.searchPlaylists(
        keyword,
        platform: _currentPlatform,
        limit: limit,
      );

      return response;
    } catch (e) {
      return MetingResponse.error('搜索失败: $e');
    }
  }

  /// 获取用户歌单
  Future<MetingResponse<List<Playlist>>> getUserPlaylists(String uid) async {
    try {
      final response = await _apiClient.getUserPlaylists(
        uid,
        platform: _currentPlatform,
      );

      return response;
    } catch (e) {
      return MetingResponse.error('获取用户歌单失败: $e');
    }
  }

  /// 播放歌单中的指定歌曲
  /// 
  /// 优先使用 JS 音源获取高质量播放链接，失败时回退到 Meting API
  Future<MetingResponse<void>> playSong(int index) async {
    try {
      if (kDebugMode) print('🎵 [Meting] 开始播放歌曲, index: $index');

      if (index < 0 || index >= _tracks.length) {
        if (kDebugMode) print('❌ [Meting] 歌曲索引超出范围: $index / ${_tracks.length}');
        return MetingResponse.error('歌曲索引超出范围');
      }

      if (_currentPlaylist == null || _currentPlaylist!.songs.isEmpty) {
        if (kDebugMode) print('❌ [Meting] 歌单未加载');
        return MetingResponse.error('歌单未加载');
      }

      final song = _currentPlaylist!.songs[index];

      if (kDebugMode) {
        print('🎵 [Meting] 歌曲: ${song.name} - ${song.artist}');
        print('   原始URL: ${song.url.isNotEmpty ? song.url : "(空)"}');
      }

      // 获取播放 URL（优先 JS 音源，回退到 Meting API）
      String? playUrl = await _getHighQualityPlayUrl(song);
      
      // 如果 JS 音源获取失败，回退到 Meting API
      if (playUrl == null || playUrl.isEmpty) {
        if (kDebugMode) print('   📡 回退到 Meting API 获取播放地址...');
        playUrl = song.url;
        if (playUrl.isEmpty) {
          playUrl = _urlCache[song.id] ?? '';
        }
        
        if (playUrl.isEmpty) {
          final urlResponse = await _apiClient.getSongUrl(song.id, platform: _currentPlatform);
          if (urlResponse.success && urlResponse.data != null && urlResponse.data!.isNotEmpty) {
            playUrl = urlResponse.data!;
            _urlCache[song.id] = playUrl;
            if (kDebugMode) print('   ✅ Meting API 获取成功');
          }
        }
      }

      if (playUrl == null || playUrl.isEmpty) {
        if (kDebugMode) print('❌ [Meting] 无法获取播放地址');
        return MetingResponse.error('无法获取播放地址');
      }

      // 使用获取到的 URL 创建 Track
      final track = Track(
        id: '${_currentPlatform}:${song.id}',
        filePath: playUrl,
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
        albumArt: song.pic,
      );

      if (kDebugMode) print('   正在调用 AudioPlayerService.playTrack...');

      await _playerService.playTrack(track, playlist: _tracks);

      if (kDebugMode) print('✅ [Meting] 播放成功');

      return MetingResponse.success(null);
    } catch (e) {
      if (kDebugMode) print('❌ [Meting] 播放失败: $e');
      return MetingResponse.error('播放失败: $e');
    }
  }
  
  /// 获取高质量播放链接
  /// 
  /// 优先使用 JS 音源获取无损/高清链接，失败时返回 null
  Future<String?> _getHighQualityPlayUrl(MetingSong song) async {
    // 检查是否启用 JS 音源且服务可用
    if (!_useJsSourceForHighQuality || _customSourceService == null) {
      if (kDebugMode) print('   ⚠️ JS音源未启用或服务不可用');
      return null;
    }
    
    final enabledSources = _customSourceService!.enabledSources;
    if (enabledSources.isEmpty) {
      if (kDebugMode) print('   ⚠️ 没有启用的 JS 音源');
      return null;
    }
    
    // 尝试各 JS 音源
    for (final source in enabledSources) {
      try {
        // 优先尝试无损音质 flac
        var result = await _customSourceService!.getMusicUrlWithQualityFallback(
          sourceId: source.id,
          musicId: song.id,
          preferredQuality: 'flac',
        );
        
        // 如果 flac 失败，尝试 320k
        if (result == null || !result.isSuccess) {
          result = await _customSourceService!.getMusicUrlWithQualityFallback(
            sourceId: source.id,
            musicId: song.id,
            preferredQuality: '320k',
          );
        }
        
        if (result?.isSuccess == true && result!.url != null) {
          if (kDebugMode) {
            print('   ✅ JS音源获取成功: ${source.name}');
            print('      音质: ${result.actualQuality ?? "未知"}');
            print('      降级: ${result.isQualityDowngraded == true ? "是" : "否"}');
            print('      平台: ${result.platform ?? "未知"}');
          }
          return result.url;
        }
      } catch (e) {
        if (kDebugMode) print('   ⚠️ 音源 ${source.name} 获取失败: $e');
        continue;
      }
    }
    
    if (kDebugMode) print('   ❌ 所有 JS 音源均无法获取播放链接');
    return null;
  }

  /// 播放整个歌单
  /// 
  /// 优先使用 JS 音源获取高质量播放链接，失败时回退到 Meting API
  Future<MetingResponse<void>> playPlaylist() async {
    try {
      if (kDebugMode) print('🎵 [Meting] 开始播放整个歌单');

      if (_tracks.isEmpty) {
        if (kDebugMode) print('❌ [Meting] 歌单为空');
        return MetingResponse.error('歌单为空');
      }

      if (_currentPlaylist == null || _currentPlaylist!.songs.isEmpty) {
        if (kDebugMode) print('❌ [Meting] 歌单未加载');
        return MetingResponse.error('歌单未加载');
      }

      // 获取第一首歌曲
      final song = _currentPlaylist!.songs[0];

      if (kDebugMode) {
        print('   歌单: ${_currentPlaylist!.name}');
        print('   歌曲: ${song.name} - ${song.artist}');
        print('   共 ${_tracks.length} 首');
      }

      // 获取播放 URL（优先 JS 音源，回退到 Meting API）
      String? playUrl = await _getHighQualityPlayUrl(song);
      
      // 如果 JS 音源获取失败，回退到 Meting API
      if (playUrl == null || playUrl.isEmpty) {
        if (kDebugMode) print('   📡 回退到 Meting API 获取播放地址...');
        playUrl = song.url;
        if (playUrl.isEmpty) {
          playUrl = _urlCache[song.id] ?? '';
        }
        
        if (playUrl.isEmpty) {
          final urlResponse = await _apiClient.getSongUrl(song.id, platform: _currentPlatform);
          if (urlResponse.success && urlResponse.data != null && urlResponse.data!.isNotEmpty) {
            playUrl = urlResponse.data!;
            _urlCache[song.id] = playUrl;
            if (kDebugMode) print('   ✅ Meting API 获取成功');
          }
        }
      }

      if (playUrl == null || playUrl.isEmpty) {
        if (kDebugMode) print('❌ [Meting] 无法获取播放地址');
        return MetingResponse.error('无法获取播放地址,请检查网络或稍后重试');
      }

      // 使用获取到的 URL 创建 Track
      final track = Track(
        id: '${_currentPlatform}:${song.id}',
        filePath: playUrl,
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
        albumArt: song.pic,
      );

      if (kDebugMode) print('   正在调用 AudioPlayerService.playTrack...');

      await _playerService.playTrack(track, playlist: _tracks);

      if (kDebugMode) print('✅ [Meting] 播放成功');

      return MetingResponse.success(null);
    } catch (e) {
      if (kDebugMode) print('❌ [Meting] 播放失败: $e');
      return MetingResponse.error('播放失败: $e');
    }
  }

  /// 将歌单添加到播放队列
  Future<MetingResponse<void>> addToQueue(int index) async {
    try {
      if (index < 0 || index >= _tracks.length) {
        return MetingResponse.error('歌曲索引超出范围');
      }

      if (_currentPlaylist == null || _currentPlaylist!.songs.isEmpty) {
        return MetingResponse.error('歌单未加载');
      }

      final song = _currentPlaylist!.songs[index];

      // 检查或获取播放 URL
      String playUrl = song.url;
      if (playUrl.isEmpty) {
        playUrl = _urlCache[song.id] ?? '';
      }

      if (playUrl.isEmpty) {
        // 获取播放地址
        final urlResponse = await _apiClient.getSongUrl(song.id, platform: _currentPlatform);
        if (urlResponse.success && urlResponse.data != null && urlResponse.data!.isNotEmpty) {
          playUrl = urlResponse.data!;
          _urlCache[song.id] = playUrl;
        }
      }

      if (playUrl.isEmpty) {
        return MetingResponse.error('无法获取播放地址');
      }

      // 使用缓存中的 URL 创建 Track
      final track = Track(
        id: '${_currentPlatform}:${song.id}',
        filePath: playUrl,
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
        albumArt: song.pic,
      );

      await _playerService.playTrack(track, playlist: [..._tracks, track]);

      return MetingResponse.success(null);
    } catch (e) {
      return MetingResponse.error('添加失败: $e');
    }
  }

  /// 将整个歌单添加到播放队列
  Future<MetingResponse<void>> addPlaylistToQueue() async {
    try {
      if (_currentPlaylist == null || _currentPlaylist!.songs.isEmpty) {
        return MetingResponse.error('歌单未加载');
      }

      final song = _currentPlaylist!.songs[0];

      // 检查或获取播放 URL
      String playUrl = song.url;
      if (playUrl.isEmpty) {
        playUrl = _urlCache[song.id] ?? '';
      }

      if (playUrl.isEmpty) {
        // 获取播放地址
        final urlResponse = await _apiClient.getSongUrl(song.id, platform: _currentPlatform);
        if (urlResponse.success && urlResponse.data != null && urlResponse.data!.isNotEmpty) {
          playUrl = urlResponse.data!;
          _urlCache[song.id] = playUrl;
        }
      }

      if (playUrl.isEmpty) {
        return MetingResponse.error('无法获取播放地址');
      }

      // 使用缓存中的 URL 创建 Track
      final track = Track(
        id: '${_currentPlatform}:${song.id}',
        filePath: playUrl,
        title: song.name,
        artist: song.artist,
        album: song.album,
        duration: song.duration != null ? Duration(milliseconds: song.duration!) : null,
        albumArt: song.pic,
      );

      await _playerService.playTrack(track, playlist: _tracks);

      return MetingResponse.success(null);
    } catch (e) {
      return MetingResponse.error('添加失败: $e');
    }
  }

  /// 获取歌曲歌词
  Future<MetingResponse<String>> getLyric(String songId) async {
    try {
      final response = await _apiClient.getLyric(
        songId,
        platform: _currentPlatform,
      );

      return response;
    } catch (e) {
      return MetingResponse.error('获取歌词失败: $e');
    }
  }

  /// 更新歌曲播放地址
  Future<MetingResponse<String>> getSongUrl(String songId) async {
    try {
      final response = await _apiClient.getSongUrl(
        songId,
        platform: _currentPlatform,
      );

      return response;
    } catch (e) {
      return MetingResponse.error('获取播放地址失败: $e');
    }
  }

  /// 切换平台
  void switchPlatform(String platform) {
    _currentPlatform = platform;
    // 清空当前歌单和缓存
    _currentPlaylist = null;
    _tracks.clear();
    _urlCache.clear();
  }

  /// 清空搜索历史
  void clearSearchHistory() {
    _searchHistory.clear();
  }

  /// 从搜索历史中删除
  void removeFromSearchHistory(String keyword) {
    _searchHistory.remove(keyword);
  }

  /// 验证 API 连接
  Future<bool> checkConnection() async {
    return await _apiClient.checkConnection();
  }

  /// 更新 API 基础 URL
  void updateApiBaseUrl(String newBaseUrl) {
    _apiClient.updateBaseUrl(newBaseUrl);
  }

  /// 根据索引获取歌曲
  Track? getTrack(int index) {
    if (index >= 0 && index < _tracks.length) {
      return _tracks[index];
    }
    return null;
  }

  /// 获取歌单中的歌曲数量
  int get trackCount => _tracks.length;

  /// 检查歌单是否已加载
  bool get isPlaylistLoaded => _currentPlaylist != null;

  /// 获取歌单封面
  String? get playlistCover {
    return _currentPlaylist?.pic ?? _currentPlaylist?.picUrl;
  }

  /// 获取歌单名称
  String? get playlistName {
    return _currentPlaylist?.name;
  }

  /// 获取歌单描述
  String? get playlistDescription {
    return _currentPlaylist?.info;
  }
}
