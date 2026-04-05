/// Meting API 数据模型
/// 
/// Meting API 返回的数据结构定义

import 'package:wuaimusic/features/files/data/models/track.dart';
import 'package:wuaimusic/features/playlist/data/models/playlist.dart';

/// 支持的音乐平台枚举
enum MetingPlatform {
  netease('netease', '网易云音乐'),
  tencent('tencent', 'QQ音乐'),
  kugou('kugou', '酷狗音乐'),
  kuwo('kuwo', '酷我音乐'),
  baidu('baidu', '百度音乐'),
  youtube('youtube', 'YouTube Music'),
  spotify('spotify', 'Spotify');

  final String code;
  final String name;

  const MetingPlatform(this.code, this.name);

  static MetingPlatform fromCode(String code) {
    return values.firstWhere(
      (p) => p.code == code,
      orElse: () => netease,
    );
  }
}

/// Meting 播放列表项（单个歌曲信息）
class MetingSong {
  final String id;
  final String name;
  final String artist;
  final String album;
  final String? pic;
  final String url;
  final int? duration;
  final String platform;
  final String? picId;
  final String? urlId;
  final String? lyricId;
  final String? source;
  final String? sign;

  MetingSong({
    required this.id,
    required this.name,
    required this.artist,
    required this.album,
    this.pic,
    required this.url,
    this.duration,
    required this.platform,
    this.picId,
    this.urlId,
    this.lyricId,
    this.source,
    this.sign,
  });

  factory MetingSong.fromJson(Map<String, dynamic> json) {
    // 处理 artist 字段 - 可能是数组或字符串
    String artistStr = '';
    if (json['artist'] != null) {
      if (json['artist'] is List) {
        // 数组格式：["艺人1", "艺人2"] -> "艺人1, 艺人2"
        artistStr = (json['artist'] as List).join(', ');
      } else {
        artistStr = json['artist']?.toString() ?? '';
      }
    } else if (json['author'] != null) {
      // 兼容 author 字段
      if (json['author'] is List) {
        artistStr = (json['author'] as List).join(', ');
      } else {
        artistStr = json['author']?.toString() ?? '';
      }
    }

    return MetingSong(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artist: artistStr,
      album: json['album']?.toString() ?? '',
      pic: json['pic']?.toString(),
      url: json['url']?.toString() ?? '',
      duration: json['duration'] as int?,
      platform: json['platform']?.toString() ?? json['source']?.toString() ?? 'netease',
      picId: json['pic_id']?.toString(),
      urlId: json['url_id']?.toString(),
      lyricId: json['lyric_id']?.toString(),
      source: json['source']?.toString(),
      sign: json['sign']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'album': album,
      'pic': pic,
      'url': url,
      'duration': duration,
      'platform': platform,
      'pic_id': picId,
      'url_id': urlId,
      'lyric_id': lyricId,
      'source': source,
      'sign': sign,
    };
  }

  /// 转换为 Track 模型（与现有的播放器集成）
  Track toTrack() {
    return Track(
      id: '$platform:$id',
      filePath: url,
      title: name,
      artist: artist,
      album: album,
      duration: duration != null ? Duration(milliseconds: duration!) : null,
      albumArt: pic,
    );
  }
}

/// Meting 播放列表详情（包含歌单信息和歌曲列表）
class MetingPlaylistDetail {
  final String id;
  final String name;
  final String artist;
  final String? pic;
  final String? picUrl;
  final String url;
  final String? info;
  final String platform;
  final List<MetingSong> songs;

  MetingPlaylistDetail({
    required this.id,
    required this.name,
    required this.artist,
    this.pic,
    this.picUrl,
    required this.url,
    this.info,
    required this.platform,
    required this.songs,
  });

  factory MetingPlaylistDetail.fromJson(Map<String, dynamic> json) {
    List<MetingSong> songsList = [];
    
    // 处理歌曲列表 - Meting 可能返回多种格式
    if (json['songs'] != null) {
      if (json['songs'] is List) {
        songsList = (json['songs'] as List)
            .map((e) => MetingSong.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } else if (json['url'] != null && json['url'] is List) {
      // 另一种格式：歌曲在 url 字段中
      songsList = (json['url'] as List)
          .map((e) => MetingSong.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 处理封面图片
    String? coverPic = json['pic']?.toString();
    String? coverPicUrl = json['pic_url']?.toString();
    if (coverPicUrl != null && coverPic == null) {
      coverPic = coverPicUrl;
    }

    return MetingPlaylistDetail(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? '',
      artist: json['artist']?.toString() ?? json['author']?.toString() ?? '',
      pic: coverPic,
      picUrl: coverPicUrl,
      url: json['url']?.toString() ?? '',
      info: json['info']?.toString(),
      platform: json['platform']?.toString() ?? 'netease',
      songs: songsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'artist': artist,
      'pic': pic,
      'pic_url': picUrl,
      'url': url,
      'info': info,
      'platform': platform,
      'songs': songs.map((e) => e.toJson()).toList(),
    };
  }

  /// 转换为 Playlist 模型（与现有的歌单列表集成）
  Playlist toPlaylist() {
    return Playlist(
      id: 'meting:$platform:$id',
      name: name,
      creator: artist,
      coverUrl: pic ?? picUrl,
      trackCount: songs.length,
      description: info,
      source: platform,
    );
  }
}

/// Meting 搜索结果（用于歌单搜索）
class MetingSearchResult {
  final List<MetingPlaylistDetail> playlists;
  final int? total;

  MetingSearchResult({
    required this.playlists,
    this.total,
  });

  factory MetingSearchResult.fromJson(Map<String, dynamic> json) {
    List<MetingPlaylistDetail> playlistsList = [];
    
    // Meting 搜索可能返回数组或对象
    List<dynamic> items = [];
    if (json is List) {
      items = json as List;
    } else if (json['playlists'] != null) {
      items = json['playlists'] as List;
    } else if (json['data'] != null) {
      items = json['data'] as List;
    }

    playlistsList = items
        .map((e) => MetingPlaylistDetail.fromJson(e as Map<String, dynamic>))
        .toList();

    return MetingSearchResult(
      playlists: playlistsList,
      total: json['total'] as int?,
    );
  }
}

/// Meting 用户信息
class MetingUser {
  final String id;
  final String name;
  final String? avatar;
  final String platform;
  final int? playlistCount;

  MetingUser({
    required this.id,
    required this.name,
    this.avatar,
    required this.platform,
    this.playlistCount,
  });

  factory MetingUser.fromJson(Map<String, dynamic> json) {
    return MetingUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['nickname']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? json['pic']?.toString(),
      platform: json['platform']?.toString() ?? 'netease',
      playlistCount: json['playlist_count'] as int?,
    );
  }
}

/// Meting 响应包装器（处理 API 响应）
class MetingResponse<T> {
  final bool success;
  final T? data;
  final String? error;
  final int? code;

  MetingResponse({
    required this.success,
    this.data,
    this.error,
    this.code,
  });

  factory MetingResponse.success(T data) {
    return MetingResponse(
      success: true,
      data: data,
    );
  }

  factory MetingResponse.error(String error, {int? code}) {
    return MetingResponse(
      success: false,
      error: error,
      code: code,
    );
  }
}
