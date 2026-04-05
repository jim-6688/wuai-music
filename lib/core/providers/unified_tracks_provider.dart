import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/files/data/models/track.dart';
import '../../features/files/presentation/providers/file_provider.dart';
import '../../features/nas/providers/nas_playlist_provider.dart';

/// 合并的本地音乐 + NAS 音乐列表
/// 用于在本地音乐页面显示所有可用音乐
final unifiedTracksProvider = Provider<List<Track>>((ref) {
  final localTracks = ref.watch(tracksProvider);
  final nasTracks = ref.watch(nasTracksProvider);
  
  // 合并列表，本地在前，NAS 在后
  return [...localTracks, ...nasTracks];
});

/// 合并的音乐按文件夹分组
/// 本地文件夹在前，NAS 文件夹在后
final unifiedTracksByFolderProvider = Provider<Map<String, List<Track>>>((ref) {
  final localByFolder = ref.watch(tracksByFolderProvider);
  final nasByFolder = ref.watch(nasTracksByFolderProvider);
  
  // 合并，本地在前
  return {...localByFolder, ...nasByFolder};
});

/// 是否有任何音乐（本地或 NAS）
final hasAnyTracksProvider = Provider<bool>((ref) {
  final unified = ref.watch(unifiedTracksProvider);
  return unified.isNotEmpty;
});

/// NAS 音乐数量
final nasTrackCountProvider = Provider<int>((ref) {
  return ref.watch(nasTracksProvider).length;
});

/// 本地音乐数量
final localTrackCountProvider = Provider<int>((ref) {
  return ref.watch(tracksProvider).length;
});
