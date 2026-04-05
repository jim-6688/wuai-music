import 'package:equatable/equatable.dart';

/// 音乐曲目模型
class Track extends Equatable {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtPath;
  final String filePath;
  final Duration duration;
  final DateTime? addedAt;

  const Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtPath,
    required this.filePath,
    required this.duration,
    this.addedAt,
  });

  factory Track.fromFile({
    required String id,
    required String filePath,
    String? title,
    String? artist,
    String? album,
    String? albumArtPath,
    Duration? duration,
  }) {
    final fileName = filePath.split('/').last.split('\\').last;
    final nameWithoutExt = fileName.contains('.') 
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
    
    return Track(
      id: id,
      title: title ?? nameWithoutExt,
      artist: artist ?? '未知艺术家',
      album: album ?? '未知专辑',
      albumArtPath: albumArtPath,
      filePath: filePath,
      duration: duration ?? Duration.zero,
      addedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [id, title, artist, album, filePath];
}

/// 播放列表模型
class Playlist extends Equatable {
  final String id;
  final String name;
  final List<Track> tracks;
  final DateTime createdAt;
  final bool isDefault;

  const Playlist({
    required this.id,
    required this.name,
    required this.tracks,
    required this.createdAt,
    this.isDefault = false,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<Track>? tracks,
    DateTime? createdAt,
    bool? isDefault,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      tracks: tracks ?? this.tracks,
      createdAt: createdAt ?? this.createdAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [id, name, tracks.length];
}

/// 播放模式
enum PlayMode {
  single,    // 单曲循环
  loop,       // 列表循环
  sequential, // 顺序播放
  shuffle,   // 随机播放
}

extension PlayModeExtension on PlayMode {
  String get displayName {
    switch (this) {
      case PlayMode.single:
        return '单曲循环';
      case PlayMode.loop:
        return '列表循环';
      case PlayMode.sequential:
        return '顺序播放';
      case PlayMode.shuffle:
        return '随机播放';
    }
  }

  String get iconName {
    switch (this) {
      case PlayMode.single:
        return 'repeat_one';
      case PlayMode.loop:
        return 'repeat';
      case PlayMode.sequential:
        return 'play_arrow';
      case PlayMode.shuffle:
        return 'shuffle';
    }
  }
}