import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/file_service_debug.dart';
import '../../data/models/track.dart';

// ─── 调试版主服务 Provider ──────────────────────────────────────────────────────────

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
