import 'package:equatable/equatable.dart';

class Track extends Equatable {
  final String id;
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final String? albumArt;

  const Track({
    required this.id,
    required this.filePath,
    required this.title,
    required this.artist,
    required this.album,
    this.duration,
    this.albumArt,
  });

  factory Track.fromFile({
    required String id,
    required String filePath,
    required String title,
    required String artist,
    required String album,
    Duration? duration,
    String? albumArt,
  }) {
    return Track(
      id: id,
      filePath: filePath,
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      albumArt: albumArt,
    );
  }

  /// JSON 序列化
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration?.inMilliseconds,
      'albumArt': albumArt,
    };
  }

  /// JSON 反序列化
  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      duration: json['duration'] != null 
          ? Duration(milliseconds: json['duration'] as int) 
          : null,
      albumArt: json['albumArt'] as String?,
    );
  }

  Track copyWith({
    String? id,
    String? filePath,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? albumArt,
  }) {
    return Track(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      albumArt: albumArt ?? this.albumArt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    filePath,
    title,
    artist,
    album,
    duration,
    albumArt,
  ];
}
