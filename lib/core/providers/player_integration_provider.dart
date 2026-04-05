import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/player/presentation/providers/player_provider.dart';
import '../../features/nas/providers/nas_playlist_provider.dart';

/// 播放器集成服务 Provider
/// 负责将 NAS 歌单服务与播放器服务连接
final playerIntegrationProvider = Provider<void>((ref) {
  final audioPlayerService = ref.watch(audioPlayerServiceProvider);
  final nasPlaylistService = ref.watch(nasPlaylistServiceProvider);
  
  // 注册 NAS 路径回调
  audioPlayerService.onNasPathDetected = (track) async {
    return await nasPlaylistService.getPlayablePath(track);
  };
});
