/// 歌单数据模型
class Playlist {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? creator;
  final int trackCount;
  final int playCount;
  final DateTime? createTime;
  final DateTime? updateTime;
  final List<PlaylistTrack>? tracks;
  final String? source; // netease, qq, kugou, local

  const Playlist({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    this.creator,
    this.trackCount = 0,
    this.playCount = 0,
    this.createTime,
    this.updateTime,
    this.tracks,
    this.source,
  });

  Playlist copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    String? creator,
    int? trackCount,
    int? playCount,
    DateTime? createTime,
    DateTime? updateTime,
    List<PlaylistTrack>? tracks,
    String? source,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      creator: creator ?? this.creator,
      trackCount: trackCount ?? this.trackCount,
      playCount: playCount ?? this.playCount,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      tracks: tracks ?? this.tracks,
      source: source ?? this.source,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'coverUrl': coverUrl,
      'creator': creator,
      'trackCount': trackCount,
      'playCount': playCount,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'tracks': tracks?.map((t) => t.toJson()).toList(),
      'source': source,
    };
  }

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      coverUrl: json['coverUrl']?.toString() ?? json['coverImgUrl']?.toString(),
      creator: json['creator']?['nickname']?.toString() ?? json['creator']?.toString(),
      trackCount: json['trackCount'] ?? json['track_count'] ?? 0,
      playCount: json['playCount'] ?? json['play_count'] ?? 0,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'].toString())
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'].toString())
          : null,
      tracks: json['tracks'] != null
          ? (json['tracks'] as List).map((t) => PlaylistTrack.fromJson(t)).toList()
          : null,
      source: json['source']?.toString(),
    );
  }
}

/// 歌单曲目标
class PlaylistTrack {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final int duration; // 毫秒
  final String? coverUrl;
  final String? audioUrl;
  final String? source;

  const PlaylistTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.duration = 0,
    this.coverUrl,
    this.audioUrl,
    this.source,
  });

  PlaylistTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    int? duration,
    String? coverUrl,
    String? audioUrl,
    String? source,
  }) {
    return PlaylistTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      coverUrl: coverUrl ?? this.coverUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      source: source ?? this.source,
    );
  }

  String get durationFormatted {
    final d = Duration(milliseconds: duration);
    final minutes = d.inMinutes;
    final seconds = d.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'duration': duration,
      'coverUrl': coverUrl,
      'audioUrl': audioUrl,
      'source': source,
    };
  }

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) {
    return PlaylistTrack(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? json['title']?.toString() ?? '',
      artist: json['ar'] != null
          ? (json['ar'] as List).map((a) => a['name']?.toString() ?? '').join('/')
          : json['artist']?.toString() ?? '',
      album: json['al']?['name']?.toString() ?? json['album']?.toString(),
      duration: json['dt'] ?? json['duration'] ?? 0,
      coverUrl: json['al']?['picUrl']?.toString() ?? json['coverUrl']?.toString(),
      audioUrl: json['audioUrl']?.toString(),
      source: json['source']?.toString(),
    );
  }
}
