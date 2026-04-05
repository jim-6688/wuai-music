/// 网易云音乐统一数据模型
/// 所有网易云相关服务共用这些模型定义
library;

/// 网易云歌单
class NeteasePlaylist {
  final String id;
  final String name;
  final String coverImgUrl;
  final String? creatorName;
  final int trackCount;
  final int playCount;
  final String? description;
  final List<String> tags;
  final DateTime? createTime;
  final DateTime? updateTime;

  NeteasePlaylist({
    required this.id,
    required this.name,
    required this.coverImgUrl,
    this.creatorName,
    required this.trackCount,
    required this.playCount,
    this.description,
    this.tags = const [],
    this.createTime,
    this.updateTime,
  });

  factory NeteasePlaylist.fromJson(Map<String, dynamic> json) {
    return NeteasePlaylist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      coverImgUrl: json['coverImgUrl'] ?? json['picUrl'] ?? json['coverUrl'] ?? '',
      creatorName: json['creator']?['nickname'],
      trackCount: json['trackCount'] ?? 0,
      playCount: json['playCount'] ?? 0,
      description: json['description'],
      tags: json['tags'] != null
          ? List<String>.from(json['tags'])
          : (json['tag'] != null ? [json['tag']] : []),
      createTime: json['createTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['createTime'])
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updateTime'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coverImgUrl': coverImgUrl,
      'creatorName': creatorName,
      'trackCount': trackCount,
      'playCount': playCount,
      'description': description,
      'tags': tags,
    };
  }
}

/// 网易云歌曲
class NeteaseSong {
  final String id;
  final String name;
  final List<NeteaseArtist> artists;
  final String? albumName;
  final String? albumId;
  final String? albumCoverUrl;
  final int duration; // 毫秒
  final int? fee; // 0: 免费, 1: VIP, 4: 购买专辑
  final int index; // 在榜单/列表中的排名

  NeteaseSong({
    required this.id,
    required this.name,
    required this.artists,
    this.albumName,
    this.albumId,
    this.albumCoverUrl,
    required this.duration,
    this.fee,
    this.index = 0,
  });

  factory NeteaseSong.fromJson(Map<String, dynamic> json, {int index = 0}) {
    return NeteaseSong(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      artists: (json['ar'] as List?)
              ?.map((a) => NeteaseArtist.fromJson(a))
              .toList() ??
          (json['artists'] as List?)
              ?.map((a) => NeteaseArtist.fromJson(a))
              .toList() ??
          [],
      albumName: json['al']?['name'] ?? json['album']?['name'],
      albumId: json['al']?['id']?.toString() ?? json['album']?['id']?.toString(),
      albumCoverUrl: json['al']?['picUrl'] ?? json['album']?['picUrl'],
      duration: json['dt'] ?? json['duration'] ?? 0,
      fee: json['fee'],
      index: index,
    );
  }

  String get artistsName => artists.map((a) => a.name).join(', ');

  bool get isFree => fee == 0;
  bool get isVipOnly => fee == 1;
  bool get needPurchase => fee == 4;

  /// 转换为通用 MusicInfo 格式（用于榜单系统集成）
  Map<String, dynamic> toMusicInfo() {
    return {
      'id': id,
      'name': name,
      'artist': artistsName,
      'album': albumName,
      'albumId': albumId,
      'duration': duration,
      'picUrl': albumCoverUrl,
      'source': 'wy',
      'sourceId': 'netease_official',
    };
  }
}

/// 网易云歌手
class NeteaseArtist {
  final String id;
  final String name;
  final String? coverUrl;

  NeteaseArtist({
    required this.id,
    required this.name,
    this.coverUrl,
  });

  factory NeteaseArtist.fromJson(Map<String, dynamic> json) {
    return NeteaseArtist(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      coverUrl: json['picUrl'] ?? json['img1v1Url'],
    );
  }
}

/// 歌曲播放链接
class NeteaseSongUrl {
  final String id;
  final String? url;
  final int level; // 音质等级
  final String? type; // flac, mp3 等
  final int size; // 文件大小

  NeteaseSongUrl({
    required this.id,
    this.url,
    required this.level,
    this.type,
    required this.size,
  });

  factory NeteaseSongUrl.fromJson(Map<String, dynamic> json) {
    return NeteaseSongUrl(
      id: json['id']?.toString() ?? '',
      url: json['url'],
      level: json['level'] == 'lossless'
          ? 3
          : json['level'] == 'hires'
              ? 4
              : json['level'] == 'exhigh'
                  ? 2
                  : json['level'] == 'higher'
                      ? 1
                      : 0,
      type: json['type'],
      size: json['size'] ?? 0,
    );
  }

  bool get isAvailable => url != null && url!.isNotEmpty;
}

/// 歌词
class NeteaseLyric {
  final String? lyric;
  final String? tlyric; // 中文翻译
  final bool hasLyric;

  NeteaseLyric({
    this.lyric,
    this.tlyric,
    required this.hasLyric,
  });

  factory NeteaseLyric.fromJson(Map<String, dynamic> json) {
    return NeteaseLyric(
      lyric: json['lrc']?['lyric'],
      tlyric: json['tlyric']?['lyric'],
      hasLyric: json['lrc']?['lyric'] != null,
    );
  }

  factory NeteaseLyric.empty() => NeteaseLyric(hasLyric: false);
}

/// 歌单详情
class NeteasePlaylistDetail {
  final NeteasePlaylist playlist;
  final List<NeteaseSong> tracks;
  final List<NeteaseSong> privileges;

  NeteasePlaylistDetail({
    required this.playlist,
    required this.tracks,
    this.privileges = const [],
  });

  factory NeteasePlaylistDetail.fromJson(Map<String, dynamic> json) {
    return NeteasePlaylistDetail(
      playlist: NeteasePlaylist.fromJson(json['playlist']),
      tracks: (json['tracks'] as List?)
              ?.map((t) => NeteaseSong.fromJson(t))
              .toList() ??
          [],
      privileges: (json['privileges'] as List?)
              ?.map((p) => NeteaseSong.fromJson(p))
              .toList() ??
          [],
    );
  }
}

/// 网易云榜单（用于榜单列表）
class NeteaseLeaderboard {
  final String id;
  final String name;
  final String coverUrl;
  final int trackCount;
  final int playCount;
  final String? description;
  final List<String> tags;
  final String? creatorName;

  NeteaseLeaderboard({
    required this.id,
    required this.name,
    required this.coverUrl,
    required this.trackCount,
    required this.playCount,
    this.description,
    this.tags = const [],
    this.creatorName,
  });

  factory NeteaseLeaderboard.fromJson(Map<String, dynamic> json) {
    return NeteaseLeaderboard(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      coverUrl: json['coverUrl'] ?? json['picUrl'] ?? json['coverImgUrl'] ?? '',
      trackCount: json['trackCount'] ?? 0,
      playCount: json['playCount'] ?? 0,
      description: json['description'],
      tags: json['tags'] != null ? List<String>.from(json['tags']) : [],
      creatorName: json['creator']?['nickname'],
    );
  }

  /// 转换为通用 LeaderboardInfo 格式
  Map<String, dynamic> toLeaderboardInfo() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'img': coverUrl,
      'source': 'wy',
      'sourceId': 'netease_official',
    };
  }
}

/// 网易云榜单详情（含歌曲列表）
class NeteaseLeaderboardDetail {
  final NeteaseLeaderboard leaderboard;
  final List<NeteaseSong> tracks;

  NeteaseLeaderboardDetail({
    required this.leaderboard,
    required this.tracks,
  });

  factory NeteaseLeaderboardDetail.fromJson(Map<String, dynamic> json) {
    return NeteaseLeaderboardDetail(
      leaderboard: NeteaseLeaderboard.fromJson(json['playlist']),
      tracks: (json['playlist']?['tracks'] as List? ?? [])
          .asMap()
          .entries
          .map((entry) => NeteaseSong.fromJson(entry.value, index: entry.key))
          .toList(),
    );
  }
}

/// 登录结果
class NeteaseLoginResult {
  final bool success;
  final String? userId;
  final String? nickname;
  final String? avatarUrl;
  final String? cookie;
  final String? message;
  final int? code;

  NeteaseLoginResult._({
    required this.success,
    this.userId,
    this.nickname,
    this.avatarUrl,
    this.cookie,
    this.message,
    this.code,
  });

  factory NeteaseLoginResult.success({
    required String userId,
    required String nickname,
    String? avatarUrl,
    required String cookie,
  }) {
    return NeteaseLoginResult._(
      success: true,
      userId: userId,
      nickname: nickname,
      avatarUrl: avatarUrl,
      cookie: cookie,
    );
  }

  factory NeteaseLoginResult.failure({
    required String message,
    int? code,
  }) {
    return NeteaseLoginResult._(
      success: false,
      message: message,
      code: code,
    );
  }
}

/// 二维码登录状态
enum NeteaseQrLoginStatus {
  waiting, // 等待扫码
  confirmed, // 已确认，待登录
  success, // 登录成功
  expired, // 二维码已过期
  error, // 错误
}

/// 二维码信息（key + 二维码图片 URL）
class QrCodeInfo {
  final String key;
  final String qrUrl;

  const QrCodeInfo({required this.key, required this.qrUrl});
}

/// 搜索结果
class NeteaseSearchResult {
  final List<NeteaseSong> songs;
  final int total;
  final int type;

  NeteaseSearchResult({
    required this.songs,
    required this.total,
    required this.type,
  });

  factory NeteaseSearchResult.empty() {
    return NeteaseSearchResult(songs: [], total: 0, type: 1);
  }

  factory NeteaseSearchResult.fromJson(Map<String, dynamic> json, int type) {
    List<NeteaseSong> songs = [];

    if (type == 1 || type == 0) {
      songs = (json['result']?['songs'] as List?)
              ?.map((s) => NeteaseSong.fromJson(s))
              .toList() ??
          [];
      return NeteaseSearchResult(
        songs: songs,
        total: json['result']?['songCount'] ?? 0,
        type: type,
      );
    }

    return NeteaseSearchResult(songs: songs, total: 0, type: type);
  }
}
