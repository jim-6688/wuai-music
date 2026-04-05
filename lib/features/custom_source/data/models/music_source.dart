/// 自定义音源数据模型
/// 兼容洛雪音乐、六音等JS音源格式
class MusicSource {
  /// 音源ID
  final String id;
  
  /// 音源名称
  final String name;
  
  /// 音源描述
  final String? description;
  
  /// 音源版本
  final String version;
  
  /// 作者
  final String? author;
  
  /// 主页
  final String? homepage;
  
  /// 脚本内容 (原始JS代码)
  final String scriptContent;
  
  /// 脚本URL (在线导入时)
  final String? scriptUrl;
  
  /// 是否为本地导入
  final bool isLocal;
  
  /// 是否启用
  final bool isEnabled;
  
  /// 支持的音质列表
  final List<String> qualitys;
  
  /// 支持的功能
  final List<String> actions;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 更新时间
  final DateTime updatedAt;
  
  /// 最后使用时间
  final DateTime? lastUsedAt;
  
  const MusicSource({
    required this.id,
    required this.name,
    this.description,
    required this.version,
    this.author,
    this.homepage,
    required this.scriptContent,
    this.scriptUrl,
    this.isLocal = true,
    this.isEnabled = true,
    this.qualitys = const ['128k', '320k', 'flac'],
    this.actions = const ['musicUrl', 'lyric', 'pic'],
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
  });
  
  /// 从JSON创建
  factory MusicSource.fromJson(Map<String, dynamic> json) {
    return MusicSource(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      version: json['version'] as String,
      author: json['author'] as String?,
      homepage: json['homepage'] as String?,
      scriptContent: json['scriptContent'] as String,
      scriptUrl: json['scriptUrl'] as String?,
      isLocal: json['isLocal'] as bool? ?? true,
      isEnabled: json['isEnabled'] as bool? ?? true,
      qualitys: (json['qualitys'] as List<dynamic>?)?.cast<String>() ?? 
          const ['128k', '320k', 'flac'],
      actions: (json['actions'] as List<dynamic>?)?.cast<String>() ?? 
          const ['musicUrl', 'lyric', 'pic'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastUsedAt: json['lastUsedAt'] != null 
          ? DateTime.parse(json['lastUsedAt'] as String) 
          : null,
    );
  }
  
  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'version': version,
      'author': author,
      'homepage': homepage,
      'scriptContent': scriptContent,
      'scriptUrl': scriptUrl,
      'isLocal': isLocal,
      'isEnabled': isEnabled,
      'qualitys': qualitys,
      'actions': actions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
    };
  }
  
  /// 复制并修改
  MusicSource copyWith({
    String? id,
    String? name,
    String? description,
    String? version,
    String? author,
    String? homepage,
    String? scriptContent,
    String? scriptUrl,
    bool? isLocal,
    bool? isEnabled,
    List<String>? qualitys,
    List<String>? actions,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
  }) {
    return MusicSource(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      author: author ?? this.author,
      homepage: homepage ?? this.homepage,
      scriptContent: scriptContent ?? this.scriptContent,
      scriptUrl: scriptUrl ?? this.scriptUrl,
      isLocal: isLocal ?? this.isLocal,
      isEnabled: isEnabled ?? this.isEnabled,
      qualitys: qualitys ?? this.qualitys,
      actions: actions ?? this.actions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
    );
  }
  
  @override
  String toString() {
    return 'MusicSource(id: $id, name: $name, version: $version, isEnabled: $isEnabled)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MusicSource && other.id == id;
  }
  
  @override
  int get hashCode => id.hashCode;
}

/// 音乐搜索结果
class MusicSearchResult {
  /// 音乐列表
  final List<MusicInfo> list;
  
  /// 总数
  final int total;
  
  /// 当前页
  final int page;
  
  /// 每页数量
  final int limit;
  
  /// 音源ID
  final String sourceId;
  
  const MusicSearchResult({
    required this.list,
    required this.total,
    required this.page,
    required this.limit,
    required this.sourceId,
  });
  
  factory MusicSearchResult.fromJson(Map<String, dynamic> json, String sourceId) {
    return MusicSearchResult(
      list: (json['list'] as List<dynamic>)
          .map((item) => MusicInfo.fromJson(item as Map<String, dynamic>, sourceId))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 30,
      sourceId: sourceId,
    );
  }
}

/// 音乐信息
class MusicInfo {
  /// 音乐ID
  final String id;
  
  /// 歌曲名
  final String name;
  
  /// 歌手
  final String singer;
  
  /// 专辑
  final String? album;
  
  /// 音源ID
  final String sourceId;
  
  /// 时长(秒)
  final int? interval;
  
  /// 封面URL
  final String? img;
  
  /// 歌曲URL
  final String? songId;
  
  const MusicInfo({
    required this.id,
    required this.name,
    required this.singer,
    this.album,
    required this.sourceId,
    this.interval,
    this.img,
    this.songId,
  });
  
  factory MusicInfo.fromJson(Map<String, dynamic> json, String sourceId) {
    return MusicInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '未知歌曲',
      singer: json['singer'] as String? ?? '未知歌手',
      album: json['album'] as String?,
      sourceId: sourceId,
      interval: json['interval'] as int?,
      img: json['img'] as String? ?? json['albumId'] as String?,
      songId: json['songId']?.toString(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'singer': singer,
      'album': album,
      'sourceId': sourceId,
      'interval': interval,
      'img': img,
      'songId': songId,
    };
  }
}

/// 音乐URL信息
class MusicUrlInfo {
  /// 播放URL
  final String url;
  
  /// URL类型
  final String type;
  
  /// 码率
  final int? br;
  
  const MusicUrlInfo({
    required this.url,
    this.type = 'url',
    this.br,
  });
  
  factory MusicUrlInfo.fromJson(Map<String, dynamic> json) {
    return MusicUrlInfo(
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'url',
      br: json['br'] as int?,
    );
  }
}

/// 歌词信息
class LyricInfo {
  /// 歌词
  final String? lyric;
  
  /// 翻译歌词
  final String? tlyric;
  
  /// 罗马音歌词
  final String? rlyric;
  
  /// 逐字歌词
  final String? lxlyric;
  
  const LyricInfo({
    this.lyric,
    this.tlyric,
    this.rlyric,
    this.lxlyric,
  });
  
  factory LyricInfo.fromJson(Map<String, dynamic> json) {
    return LyricInfo(
      lyric: json['lyric'] as String?,
      tlyric: json['tlyric'] as String?,
      rlyric: json['rlyric'] as String?,
      lxlyric: json['lxlyric'] as String?,
    );
  }
}

/// 排行榜分类
class LeaderboardCategory {
  /// 分类ID
  final String id;
  
  /// 分类名称
  final String name;
  
  /// 分类图标
  final String? icon;
  
  /// 榜单列表
  final List<LeaderboardInfo> leaderboards;
  
  const LeaderboardCategory({
    required this.id,
    required this.name,
    this.icon,
    required this.leaderboards,
  });
  
  factory LeaderboardCategory.fromJson(Map<String, dynamic> json) {
    return LeaderboardCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '未知分类',
      icon: json['icon'] as String?,
      leaderboards: (json['list'] as List<dynamic>?)
          ?.map((item) => LeaderboardInfo.fromJson(item as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// 排行榜信息
class LeaderboardInfo {
  /// 榜单ID
  final String id;
  
  /// 榜单名称
  final String name;
  
  /// 榜单封面
  final String? img;
  
  /// 描述
  final String? description;
  
  /// 来源平台
  final String source;
  
  /// 音源ID
  final String sourceId;
  
  const LeaderboardInfo({
    required this.id,
    required this.name,
    this.img,
    this.description,
    required this.source,
    required this.sourceId,
  });
  
  factory LeaderboardInfo.fromJson(Map<String, dynamic> json, {String? sourceId}) {
    return LeaderboardInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '未知榜单',
      img: json['img'] as String? ?? json['cover'] as String?,
      description: json['description'] as String?,
      source: json['source'] as String? ?? 'unknown',
      sourceId: sourceId ?? json['sourceId'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'img': img,
      'description': description,
      'source': source,
      'sourceId': sourceId,
    };
  }
}

/// 榜单详情(歌曲列表)
class LeaderboardDetail {
  /// 榜单信息
  final LeaderboardInfo info;
  
  /// 歌曲列表
  final List<MusicInfo> songs;
  
  /// 更新时间
  final String? updateTime;
  
  const LeaderboardDetail({
    required this.info,
    required this.songs,
    this.updateTime,
  });
  
  factory LeaderboardDetail.fromJson(
    Map<String, dynamic> json,
    LeaderboardInfo info,
    String sourceId,
  ) {
    return LeaderboardDetail(
      info: info,
      songs: (json['list'] as List<dynamic>?)
          ?.map((item) => MusicInfo.fromJson(item as Map<String, dynamic>, sourceId))
          .toList() ?? [],
      updateTime: json['updateTime'] as String?,
    );
  }
}

/// 收藏的榜单
class FavoriteLeaderboard {
  /// 榜单信息
  final LeaderboardInfo leaderboard;
  
  /// 收藏时间
  final DateTime favoritedAt;
  
  const FavoriteLeaderboard({
    required this.leaderboard,
    required this.favoritedAt,
  });
  
  factory FavoriteLeaderboard.fromJson(Map<String, dynamic> json) {
    return FavoriteLeaderboard(
      leaderboard: LeaderboardInfo.fromJson(json['leaderboard'] as Map<String, dynamic>),
      favoritedAt: DateTime.parse(json['favoritedAt'] as String),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'leaderboard': leaderboard.toJson(),
      'favoritedAt': favoritedAt.toIso8601String(),
    };
  }
  
  /// 生成唯一ID (用于去重)
  String get uniqueId => '${leaderboard.sourceId}_${leaderboard.id}';
}
