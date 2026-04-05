import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../service/album_art_service.dart';

final albumArtServiceProvider = Provider((ref) => AlbumArtService());

final albumCoverProvider =
    StateNotifierProvider<AlbumCoverNotifier, AlbumCoverState>((ref) {
  return AlbumCoverNotifier(ref.read(albumArtServiceProvider));
});

/// 专辑封面状态
///
/// - [coverBytes]：网络/LrcApi 获取到的图片字节，用 Image.memory 渲染
/// - [localPath]：本地嵌入式封面文件路径，用 Image.file 渲染
/// 两者互斥，优先使用 localPath（若存在）
class AlbumCoverState {
  final Uint8List? coverBytes;
  final String? localPath;
  final bool isLoading;
  final String? error;
  final String? currentTrackId;

  const AlbumCoverState({
    this.coverBytes,
    this.localPath,
    this.isLoading = false,
    this.error,
    this.currentTrackId,
  });

  /// 是否有封面可显示
  bool get hasCover => localPath != null || coverBytes != null;

  /// 兼容旧代码：如需 URL 字符串（例如 _CatEarPainter.albumCoverUrl），
  /// 本地路径直接返回，网络封面返回 null（调用方应改用 coverBytes）
  String? get coverUrl => localPath;

  AlbumCoverState copyWith({
    Uint8List? coverBytes,
    bool clearBytes = false,
    String? localPath,
    bool clearLocal = false,
    bool? isLoading,
    String? error,
    String? currentTrackId,
  }) {
    return AlbumCoverState(
      coverBytes: clearBytes ? null : (coverBytes ?? this.coverBytes),
      localPath: clearLocal ? null : (localPath ?? this.localPath),
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      currentTrackId: currentTrackId ?? this.currentTrackId,
    );
  }
}

/// 专辑封面管理器
class AlbumCoverNotifier extends StateNotifier<AlbumCoverState> {
  final AlbumArtService _albumArtService;

  AlbumCoverNotifier(this._albumArtService) : super(const AlbumCoverState());

  /// 设置本地封面（已存在的嵌入式封面路径）
  void setLocalCover(String trackId, String path) {
    state = AlbumCoverState(
      localPath: path,
      coverBytes: null,
      isLoading: false,
      currentTrackId: trackId,
    );
  }

  /// 获取当前播放歌曲的专辑封面（字节缓存方式）
  Future<void> fetchAlbumCoverForTrack(
    String trackId,
    String title, {
    String? artist,
    String? album,
  }) async {
    // 同一首歌已有封面，不重复获取
    if (state.currentTrackId == trackId && state.hasCover) return;

    state = AlbumCoverState(
      currentTrackId: trackId,
      isLoading: true,
    );

    try {
      final bytes = await _albumArtService.getAlbumCoverBytes(
        title,
        artist: artist,
        album: album,
      );

      state = AlbumCoverState(
        currentTrackId: trackId,
        coverBytes: bytes,
        isLoading: false,
        error: bytes == null ? '未找到专辑封面' : null,
      );
    } catch (e) {
      state = AlbumCoverState(
        currentTrackId: trackId,
        isLoading: false,
        error: '获取封面失败: $e',
      );
    }
  }

  /// 清除当前封面
  void clearCover() {
    state = const AlbumCoverState();
  }

  /// 清除缓存
  void clearCache() {
    _albumArtService.clearCache();
    state = const AlbumCoverState();
  }
}
