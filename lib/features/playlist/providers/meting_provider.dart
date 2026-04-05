import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';
import 'package:wuaimusic/features/playlist/data/models/playlist.dart';
import 'package:wuaimusic/features/playlist/services/meting_api_client.dart';
import 'package:wuaimusic/features/playlist/services/meting_playlist_service.dart';
import 'package:wuaimusic/features/player/service/audio_player_service.dart';
import 'package:wuaimusic/features/player/presentation/providers/player_provider.dart';
import 'package:wuaimusic/features/files/data/models/track.dart';
import 'package:wuaimusic/features/custom_source/services/custom_source_service.dart';

/// Meting API 基础 URL Provider
final metingApiUrlProvider = StateProvider<String>((ref) {
  // 默认使用公开的 Meting API
  return 'https://api.injahow.cn/meting';
});

/// Meting API 客户端 Provider
final metingApiClientProvider = Provider<MetingApiClient>((ref) {
  // 使用单例 MetingApiClient，内部通过 NeteaseApiConfigStorage 获取 API 地址
  return MetingApiClient();
});

/// Meting 歌单服务 Provider
final metingPlaylistServiceProvider = Provider<MetingPlaylistService>((ref) {
  final apiClient = ref.watch(metingApiClientProvider);
  final playerService = ref.watch(audioPlayerServiceProvider.notifier);
  
  // 尝试获取 JS 音源服务（可能为空）
  CustomSourceService? customSourceService;
  try {
    customSourceService = ref.watch(customSourceServiceProvider.notifier);
  } catch (_) {
    // JS 音源服务未初始化，忽略
  }
  
  final service = MetingPlaylistService(
    apiClient: apiClient,
    playerService: playerService,
  );
  
  // 设置 JS 音源服务
  service.setCustomSourceService(customSourceService);
  
  return service;
});

/// 当前平台 Provider
final currentPlatformProvider = StateProvider<String>((ref) {
  return 'netease'; // 默认网易云
});

/// 当前歌单 Provider
final currentMetingPlaylistProvider = StateProvider<MetingPlaylistDetail?>((ref) {
  return null;
});

/// 歌单加载状态 Provider
enum PlaylistLoadingState {
  idle,
  loading,
  success,
  error,
}

final playlistLoadingStateProvider = StateProvider<PlaylistLoadingState>((ref) {
  return PlaylistLoadingState.idle;
});

/// 歌单加载错误消息 Provider
final playlistErrorMessageProvider = StateProvider<String?>((ref) {
  return null;
});

/// 歌单搜索结果 Provider
final playlistSearchResultsProvider = StateProvider<List<MetingPlaylistDetail>>((ref) {
  return [];
});

/// 搜索状态 Provider
final searchStateProvider = StateProvider<PlaylistLoadingState>((ref) {
  return PlaylistLoadingState.idle;
});

/// 搜索历史 Provider
final searchHistoryProvider = StateProvider<List<String>>((ref) {
  return [];
});

/// 歌单 Track 列表 Provider
final metingTracksProvider = StateProvider<List<Track>>((ref) {
  return [];
});

/// Meting API 连接状态 Provider
final metingConnectionStateProvider = StateProvider<bool>((ref) {
  return false;
});

/// 支持的音乐平台列表 Provider
final supportedPlatformsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return [
    {'code': 'netease', 'name': '网易云音乐', 'enabled': true},
    {'code': 'tencent', 'name': 'QQ音乐', 'enabled': true},
    {'code': 'kugou', 'name': '酷狗音乐', 'enabled': true},
    {'code': 'kuwo', 'name': '酷我音乐', 'enabled': true},
    {'code': 'baidu', 'name': '百度音乐', 'enabled': false},
    {'code': 'youtube', 'name': 'YouTube Music', 'enabled': false},
    {'code': 'spotify', 'name': 'Spotify', 'enabled': false},
  ];
});

/// 歌单操作类 Provider（暴露操作方法）
final metingPlaylistActionsProvider = Provider<MetingPlaylistActions>((ref) {
  return MetingPlaylistActions(ref);
});

/// Meting 歌单操作类
/// 
/// 封装所有歌单相关操作，包括加载、搜索、播放等
class MetingPlaylistActions {
  final Ref _ref;

  MetingPlaylistActions(this._ref);

  /// 加载歌单
  Future<void> loadPlaylist(String playlistId) async {
    final service = _ref.read(metingPlaylistServiceProvider);
    final platform = _ref.read(currentPlatformProvider);

    _ref.read(playlistLoadingStateProvider.notifier).state = PlaylistLoadingState.loading;
    _ref.read(playlistErrorMessageProvider.notifier).state = null;

    try {
      final response = await service.loadPlaylist(playlistId);

      if (response.success) {
        _ref.read(currentMetingPlaylistProvider.notifier).state = service.currentPlaylist;
        _ref.read(metingTracksProvider.notifier).state = service.getTrackList;
        _ref.read(playlistLoadingStateProvider.notifier).state = PlaylistLoadingState.success;
      } else {
        _ref.read(playlistLoadingStateProvider.notifier).state = PlaylistLoadingState.error;
        _ref.read(playlistErrorMessageProvider.notifier).state = response.error ?? '加载失败';
      }
    } catch (e) {
      _ref.read(playlistLoadingStateProvider.notifier).state = PlaylistLoadingState.error;
      _ref.read(playlistErrorMessageProvider.notifier).state = '加载失败: $e';
    }
  }

  /// 搜索歌单
  Future<void> searchPlaylists(String keyword, {int limit = 30}) async {
    final service = _ref.read(metingPlaylistServiceProvider);

    if (keyword.trim().isEmpty) {
      return;
    }

    _ref.read(searchStateProvider.notifier).state = PlaylistLoadingState.loading;

    try {
      final response = await service.searchPlaylists(keyword, limit: limit);

      if (response.success && response.data != null) {
        _ref.read(playlistSearchResultsProvider.notifier).state = response.data!;
        _ref.read(searchHistoryProvider.notifier).state = service.searchHistory;
        _ref.read(searchStateProvider.notifier).state = PlaylistLoadingState.success;
      } else {
        _ref.read(searchStateProvider.notifier).state = PlaylistLoadingState.error;
      }
    } catch (e) {
      _ref.read(searchStateProvider.notifier).state = PlaylistLoadingState.error;
    }
  }

  /// 获取用户歌单
  Future<List<Playlist>> getUserPlaylists(String uid) async {
    final service = _ref.read(metingPlaylistServiceProvider);

    final response = await service.getUserPlaylists(uid);

    if (response.success && response.data != null) {
      return response.data!;
    }

    return [];
  }

  /// 播放歌单中的指定歌曲
  Future<void> playSong(int index) async {
    final service = _ref.read(metingPlaylistServiceProvider);

    final response = await service.playSong(index);

    if (!response.success) {
      throw Exception(response.error ?? '播放失败');
    }
  }

  /// 播放整个歌单
  Future<void> playPlaylist() async {
    final service = _ref.read(metingPlaylistServiceProvider);

    final response = await service.playPlaylist();

    if (!response.success) {
      throw Exception(response.error ?? '播放失败');
    }
  }

  /// 将歌曲添加到播放队列
  Future<void> addToQueue(int index) async {
    final service = _ref.read(metingPlaylistServiceProvider);

    final response = await service.addToQueue(index);

    if (!response.success) {
      throw Exception(response.error ?? '添加失败');
    }
  }

  /// 将整个歌单添加到播放队列
  Future<void> addPlaylistToQueue() async {
    final service = _ref.read(metingPlaylistServiceProvider);

    final response = await service.addPlaylistToQueue();

    if (!response.success) {
      throw Exception(response.error ?? '添加失败');
    }
  }

  /// 切换平台
  void switchPlatform(String platform) {
    final service = _ref.read(metingPlaylistServiceProvider);
    
    _ref.read(currentPlatformProvider.notifier).state = platform;
    service.switchPlatform(platform);
    
    // 清空当前歌单
    _ref.read(currentMetingPlaylistProvider.notifier).state = null;
    _ref.read(metingTracksProvider.notifier).state = [];
  }

  /// 清空搜索历史
  void clearSearchHistory() {
    final service = _ref.read(metingPlaylistServiceProvider);
    service.clearSearchHistory();
    _ref.read(searchHistoryProvider.notifier).state = [];
  }

  /// 从搜索历史中删除
  void removeFromSearchHistory(String keyword) {
    final service = _ref.read(metingPlaylistServiceProvider);
    service.removeFromSearchHistory(keyword);
    _ref.read(searchHistoryProvider.notifier).state = service.searchHistory;
  }

  /// 验证 API 连接
  Future<bool> checkConnection() async {
    final service = _ref.read(metingPlaylistServiceProvider);
    final connected = await service.checkConnection();
    _ref.read(metingConnectionStateProvider.notifier).state = connected;
    return connected;
  }

  /// 更新 API 基础 URL
  void updateApiBaseUrl(String newBaseUrl) {
    final service = _ref.read(metingPlaylistServiceProvider);
    service.updateApiBaseUrl(newBaseUrl);
    _ref.read(metingApiUrlProvider.notifier).state = newBaseUrl;
  }

  /// 获取歌曲歌词
  Future<String?> getLyric(String songId) async {
    final service = _ref.read(metingPlaylistServiceProvider);
    
    final response = await service.getLyric(songId);
    
    if (response.success && response.data != null) {
      return response.data!;
    }

    return null;
  }

  /// 获取歌曲播放地址
  Future<String?> getSongUrl(String songId) async {
    final service = _ref.read(metingPlaylistServiceProvider);
    
    final response = await service.getSongUrl(songId);
    
    if (response.success && response.data != null) {
      return response.data!;
    }

    return null;
  }
}

/// 歌单详情状态 Provider（用于单个歌单页面）
class MetingPlaylistDetailState {
  final MetingPlaylistDetail? playlist;
  final List<Track> tracks;
  final bool isLoading;
  final String? error;

  MetingPlaylistDetailState({
    this.playlist,
    this.tracks = const [],
    this.isLoading = false,
    this.error,
  });

  MetingPlaylistDetailState copyWith({
    MetingPlaylistDetail? playlist,
    List<Track>? tracks,
    bool? isLoading,
    String? error,
  }) {
    return MetingPlaylistDetailState(
      playlist: playlist ?? this.playlist,
      tracks: tracks ?? this.tracks,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// 歌单详情状态管理 Provider
final metingPlaylistDetailStateProvider =
    StateNotifierProvider<MetingPlaylistDetailNotifier, MetingPlaylistDetailState>(
  (ref) {
    return MetingPlaylistDetailNotifier(ref);
  },
);

/// 歌单详情状态管理器
class MetingPlaylistDetailNotifier extends StateNotifier<MetingPlaylistDetailState> {
  final Ref _ref;

  MetingPlaylistDetailNotifier(this._ref) : super(MetingPlaylistDetailState());

  Future<void> loadPlaylist(String playlistId) async {
    state = state.copyWith(isLoading: true, error: null);

    final service = _ref.read(metingPlaylistServiceProvider);
    final platform = _ref.read(currentPlatformProvider);

    try {
      final response = await service.loadPlaylist(playlistId);

      if (response.success) {
        state = state.copyWith(
          playlist: service.currentPlaylist,
          tracks: service.getTrackList,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response.error ?? '加载失败',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载失败: $e',
      );
    }
  }

  void clear() {
    state = MetingPlaylistDetailState();
  }
}
