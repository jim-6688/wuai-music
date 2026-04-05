import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/nas_service.dart';
import '../services/nas_playlist_service.dart';
import '../../files/data/models/track.dart';
import '../presentation/providers/nas_provider.dart'; // nasServiceProvider 在此定义

/// NAS 虚拟歌单服务 Provider
final nasPlaylistServiceProvider = ChangeNotifierProvider<NasPlaylistService>((ref) {
  final nasService = ref.watch(nasServiceProvider);
  return NasPlaylistService(nasService);
});

/// NAS 音乐列表（虚拟本地歌单）
final nasTracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(nasPlaylistServiceProvider).nasTracks;
});

/// NAS 音乐按文件夹分组
final nasTracksByFolderProvider = Provider<Map<String, List<Track>>>((ref) {
  return ref.watch(nasPlaylistServiceProvider).tracksByFolder;
});

/// NAS 扫描状态
final nasIsScanningProvider = Provider<bool>((ref) {
  return ref.watch(nasPlaylistServiceProvider).isScanning;
});

/// NAS 扫描进度
final nasScanProgressProvider = Provider<(int, int)>((ref) {
  final service = ref.watch(nasPlaylistServiceProvider);
  return (service.scannedCount, service.totalCount);
});
