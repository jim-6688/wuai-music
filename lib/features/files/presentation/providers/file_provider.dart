import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../service/file_service.dart';
import '../../data/models/track.dart';

// ─── 主服务 Provider ──────────────────────────────────────────────────────────

final fileServiceProvider = ChangeNotifierProvider<FileService>((ref) {
  return FileService();
});

// ─── 派生状态 Providers（只关心具体数据的子 consumers）──────────────────────

/// 扫描结果（触发 UI 重建）
final scanResultProvider = Provider<ScanResult>((ref) {
  return ref.watch(fileServiceProvider.select((s) => s.scanResult));
});

/// 音乐列表
final tracksProvider = Provider<List<Track>>((ref) {
  return ref.watch(fileServiceProvider.select((s) => s.tracks));
});

/// 是否正在扫描
final isScanningProvider = Provider<bool>((ref) {
  return ref.watch(scanResultProvider).isScanning;
});

/// 音乐文件夹浏览
final currentFilesProvider = Provider<List<FileItem>>((ref) {
  return ref.watch(fileServiceProvider.select((s) => s.currentFiles));
});

final musicFoldersProvider = Provider<List<FileItem>>((ref) {
  return ref.watch(fileServiceProvider.select((s) => s.musicFolders));
});

/// 按文件夹分组的本地音乐（TV 端使用）
/// 返回 Map<文件夹路径, 该文件夹下的歌曲列表>，按文件夹名排序
final tracksByFolderProvider = Provider<Map<String, List<Track>>>((ref) {
  final tracks = ref.watch(tracksProvider);
  final grouped = <String, List<Track>>{};

  for (final track in tracks) {
    final dir = p.dirname(track.filePath);
    grouped.putIfAbsent(dir, () => []).add(track);
  }

  // 按文件夹名排序
  final sortedKeys = grouped.keys.toList()
    ..sort((a, b) => p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));

  return Map.fromEntries(
    sortedKeys.map((k) => MapEntry(k, grouped[k]!)),
  );
});
