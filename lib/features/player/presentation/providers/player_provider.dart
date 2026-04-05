import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/audio_player_service.dart';
import '../../../files/data/models/track.dart';
import '../../../playlist/services/netease_leaderboard_service.dart';

/// 播放器服务（全局单例，不 autoDispose，保持播放状态跨页面）
final audioPlayerServiceProvider =
    ChangeNotifierProvider<AudioPlayerService>((ref) {
  final service = AudioPlayerService();

  // 注册 URL 懒加载回调：当网易云歌曲 URL 为空时自动通过 API 获取
  service.onUrlMissing = (String trackId) async {
    try {
      await NeteaseLeaderboardService.instance.initialize();
      final songUrl = await NeteaseLeaderboardService.instance.getSongUrl(trackId, level: 2);
      return songUrl?.url;
    } catch (e) {
      return null;
    }
  };

  return service;
});

/// 播放状态
final playerStateProvider = Provider<AudioPlayerState>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.state;
});

/// 播放列表
final playlistProvider = Provider<List<Track>>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.playlist;
});

/// 当前索引
final currentIndexProvider = Provider<int>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.currentIndex;
});

/// 播放进度 0.0~1.0
final playProgressProvider = Provider<double>((ref) {
  final state = ref.watch(playerStateProvider);
  if (state.duration == 0) return 0.0;
  return (state.currentPosition / state.duration).clamp(0.0, 1.0);
});

/// 当前曲目
final currentTrackProvider = Provider<Track?>((ref) {
  final service = ref.watch(audioPlayerServiceProvider);
  return service.currentTrack;
});

/// 当前音量
final volumeProvider = Provider<double>((ref) {
  final state = ref.watch(playerStateProvider);
  return state.volume;
});
