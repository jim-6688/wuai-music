import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/netease_api_service.dart';
import '../services/netease_sync_service.dart';
import '../models/netease_models.dart';

/// Netease API Service Provider
final neteaseApiServiceProvider = ChangeNotifierProvider<NeteaseApiService>((ref) {
  return NeteaseApiService();
});

/// Netease Sync Service Provider
final neteaseSyncServiceProvider = ChangeNotifierProvider<NeteaseSyncService>((ref) {
  final apiService = ref.watch(neteaseApiServiceProvider);
  return NeteaseSyncService(apiService);
});

/// User playlists provider
final userPlaylistsProvider = Provider<List<NeteasePlaylist>>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.userPlaylists;
});

/// Recommend playlists provider
final recommendPlaylistsProvider = Provider<List<NeteasePlaylist>>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.recommendPlaylists;
});

/// Current playlist provider
final currentPlaylistProvider = Provider<NeteasePlaylist?>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.currentPlaylist;
});

/// Current playlist tracks provider
final currentPlaylistTracksProvider = Provider<List<NeteaseSong>>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.currentTracks;
});

/// Is logged in provider
final isNeteaseLoggedInProvider = Provider<bool>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.isLoggedIn;
});

/// Is loading provider
final neteaseIsLoadingProvider = Provider<bool>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.isLoading;
});

/// Is syncing provider
final neteaseIsSyncingProvider = Provider<bool>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.isSyncing;
});

/// Sync progress provider
final neteaseSyncProgressProvider = Provider<double>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.syncProgress;
});

/// User info provider
final neteaseUserInfoProvider = Provider<NeteaseUserInfo?>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  if (syncService.userId == null) return null;
  return NeteaseUserInfo(
    userId: syncService.userId!,
    nickname: syncService.nickname ?? '',
    avatarUrl: syncService.avatarUrl,
  );
});

/// Error message provider
final neteaseErrorProvider = Provider<String?>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.errorMessage;
});

/// Last sync time provider
final neteaseLastSyncTimeProvider = Provider<DateTime?>((ref) {
  final syncService = ref.watch(neteaseSyncServiceProvider);
  return syncService.lastSyncTime;
});

/// 用户信息
class NeteaseUserInfo {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  
  NeteaseUserInfo({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
  });
}

/// Search results state
class NeteaseSearchState {
  final List<NeteaseSong> songs;
  final bool isLoading;
  final String? error;
  final String keyword;
  
  NeteaseSearchState({
    this.songs = const [],
    this.isLoading = false,
    this.error,
    this.keyword = '',
  });
  
  NeteaseSearchState copyWith({
    List<NeteaseSong>? songs,
    bool? isLoading,
    String? error,
    String? keyword,
  }) {
    return NeteaseSearchState(
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      keyword: keyword ?? this.keyword,
    );
  }
}

/// Search notifier
class NeteaseSearchNotifier extends StateNotifier<NeteaseSearchState> {
  final NeteaseApiService _apiService;
  
  NeteaseSearchNotifier(this._apiService) : super(NeteaseSearchState());
  
  Future<void> search(String keyword) async {
    if (keyword.trim().isEmpty) {
      state = NeteaseSearchState();
      return;
    }
    
    state = state.copyWith(isLoading: true, keyword: keyword, error: null);
    
    try {
      final songs = await _apiService.searchSongs(keyword);
      state = state.copyWith(songs: songs, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '搜索失败: $e');
    }
  }
  
  void clear() {
    state = NeteaseSearchState();
  }
}

/// Search provider
final neteaseSearchProvider = StateNotifierProvider<NeteaseSearchNotifier, NeteaseSearchState>((ref) {
  final apiService = ref.watch(neteaseApiServiceProvider);
  return NeteaseSearchNotifier(apiService);
});
