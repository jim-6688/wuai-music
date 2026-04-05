import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/netease_leaderboard_service.dart';
import '../models/netease_models.dart';
import '../services/qq_music_leaderboard_service.dart';
import '../../custom_source/services/custom_source_service.dart';
import '../../custom_source/data/models/music_source.dart' show MusicInfo;

/// 网易云榜单服务Provider
final neteaseLeaderboardServiceProvider = Provider<NeteaseLeaderboardService>((ref) {
  return NeteaseLeaderboardService.instance;
});

/// 网易云官方榜单列表Provider
final neteaseLeaderboardsProvider = FutureProvider<List<NeteaseLeaderboard>>((ref) async {
  final service = ref.watch(neteaseLeaderboardServiceProvider);
  await service.initialize();
  return await service.getToplist();
});

/// 网易云榜单详情Provider
final neteaseLeaderboardDetailProvider = FutureProvider.family<NeteaseLeaderboardDetail?, String>((ref, id) async {
  final service = ref.watch(neteaseLeaderboardServiceProvider);
  return await service.getLeaderboardDetail(id);
});

/// 榜单数据源类型
enum LeaderboardSourceType {
  netease,  // 网易云API
  qq,       // QQ音乐API
  jsSource, // JS脚本
}

/// 统一榜单项（整合两个数据源）
class UnifiedLeaderboard {
  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final String source;  // wy, kw, kg, tx等
  final String sourceId; // 音源ID
  final LeaderboardSourceType sourceType;
  final Map<String, dynamic>? rawData; // 原始数据

  UnifiedLeaderboard({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.source,
    required this.sourceId,
    required this.sourceType,
    this.rawData,
  });

  /// 从网易云榜单转换
  factory UnifiedLeaderboard.fromNetease(NeteaseLeaderboard leaderboard) {
    return UnifiedLeaderboard(
      id: leaderboard.id,
      name: leaderboard.name,
      description: leaderboard.description,
      coverUrl: leaderboard.coverUrl,
      source: 'wy',
      sourceId: 'netease_official',
      sourceType: LeaderboardSourceType.netease,
      rawData: leaderboard.toLeaderboardInfo(),
    );
  }

  /// 从QQ音乐榜单转换
  factory UnifiedLeaderboard.fromQQMusic(QQMusicLeaderboard leaderboard) {
    return UnifiedLeaderboard(
      id: leaderboard.id,
      name: leaderboard.name,
      description: leaderboard.description,
      coverUrl: leaderboard.coverUrl,
      source: 'qq',
      sourceId: 'qq_music_official',
      sourceType: LeaderboardSourceType.qq,
      rawData: leaderboardToJson(leaderboard),
    );
  }

  /// 从JS音源榜单转换
  factory UnifiedLeaderboard.fromJsSource(LeaderboardInfo info) {
    return UnifiedLeaderboard(
      id: info.id,
      name: info.name,
      description: info.description,
      coverUrl: info.img,
      source: info.source,
      sourceId: info.sourceId,
      sourceType: LeaderboardSourceType.jsSource,
      rawData: {
        'id': info.id,
        'name': info.name,
        'description': info.description,
        'img': info.img,
        'source': info.source,
        'sourceId': info.sourceId,
      },
    );
  }
}

/// 统一榜单列表Provider（整合网易云API、QQ音乐API和JS音源）
final unifiedLeaderboardsProvider = FutureProvider<List<UnifiedLeaderboard>>((ref) async {
  final unifiedList = <UnifiedLeaderboard>[];

  // 1. 获取网易云官方榜单
  try {
    final service = NeteaseLeaderboardService.instance;
    await service.initialize();
    final neteaseLeaderboards = await service.getToplist();

    for (final leaderboard in neteaseLeaderboards) {
      unifiedList.add(UnifiedLeaderboard.fromNetease(leaderboard));
    }
  } catch (e) {
    // 忽略错误，继续获取其他数据源
  }

  // 2. 获取QQ音乐榜单（仅在用户开启同步时）
  try {
    final syncEnabled = await QQMusicSyncSettings.isEnabled();
    if (syncEnabled) {
      final qqService = QQMusicLeaderboardService.instance;
      await qqService.initialize();
      final qqLeaderboards = await qqService.getToplist();

      for (final leaderboard in qqLeaderboards) {
        unifiedList.add(UnifiedLeaderboard.fromQQMusic(leaderboard));
      }
    }
  } catch (e) {
    // 忽略错误，继续获取JS音源
  }

  // 3. 获取JS音源榜单
  try {
    final customService = ref.read(customSourceServiceProvider.notifier);
    final jsLeaderboards = await customService.getLeaderboards();

    for (final leaderboard in jsLeaderboards) {
      unifiedList.add(UnifiedLeaderboard.fromJsSource(leaderboard));
    }
  } catch (e) {
    // 忽略错误
  }

  return unifiedList;
});

/// 统一榜单详情
class UnifiedLeaderboardDetail {
  final UnifiedLeaderboard leaderboard;
  final List<UnifiedSong> songs;
  final LeaderboardSourceType sourceType;

  UnifiedLeaderboardDetail({
    required this.leaderboard,
    required this.songs,
    required this.sourceType,
  });
}

/// 统一歌曲信息
class UnifiedSong {
  final String id;
  final String name;
  final String artist;
  final String? album;
  final String? albumId;
  final String? albumCover;
  final int duration;
  final String source;
  final String sourceId;
  final LeaderboardSourceType sourceType;
  final Map<String, dynamic>? rawData;

  UnifiedSong({
    required this.id,
    required this.name,
    required this.artist,
    this.album,
    this.albumId,
    this.albumCover,
    required this.duration,
    required this.source,
    required this.sourceId,
    required this.sourceType,
    this.rawData,
  });

  /// 从网易云歌曲转换
  factory UnifiedSong.fromNetease(NeteaseSong song) {
    return UnifiedSong(
      id: song.id,
      name: song.name,
      artist: song.artistsName,
      album: song.albumName,
      albumId: song.albumId,
      albumCover: song.albumCoverUrl,
      duration: song.duration,
      source: 'wy',
      sourceId: 'netease_official',
      sourceType: LeaderboardSourceType.netease,
      rawData: song.toMusicInfo(),
    );
  }

  /// 从JS音源歌曲转换
  factory UnifiedSong.fromJsSource(MusicInfo info) {
    return UnifiedSong(
      id: info.id,
      name: info.name,
      artist: info.singer,
      album: info.album,
      albumId: info.songId,
      albumCover: info.img,
      duration: (info.interval ?? 0) * 1000, // 转换为毫秒
      source: 'js',
      sourceId: info.sourceId,
      sourceType: LeaderboardSourceType.jsSource,
      rawData: info.toJson(),
    );
  }

  /// 从QQ音乐歌曲转换
  factory UnifiedSong.fromQQMusic(QQMusicSong song) {
    return UnifiedSong(
      id: song.id,
      name: song.name,
      artist: song.singer,
      album: song.album,
      albumId: song.albumMid,
      albumCover: song.albumCover,
      duration: song.duration,
      source: 'qq',
      sourceId: 'qq_music_official',
      sourceType: LeaderboardSourceType.qq,
      rawData: {
        'id': song.id,
        'mid': song.mid,
        'name': song.name,
        'singer': song.singer,
        'album': song.album,
      },
    );
  }
}

/// 获取统一榜单详情（需要传入Ref）
Future<UnifiedLeaderboardDetail?> getUnifiedLeaderboardDetail(
  UnifiedLeaderboard leaderboard,
  Ref ref,
) async {
  if (leaderboard.sourceType == LeaderboardSourceType.netease) {
    // 从网易云API获取
    final service = NeteaseLeaderboardService.instance;
    final detail = await service.getLeaderboardDetail(leaderboard.id);

    if (detail != null) {
      return UnifiedLeaderboardDetail(
        leaderboard: leaderboard,
        songs: detail.tracks
            .map((song) => UnifiedSong.fromNetease(song))
            .toList(),
        sourceType: LeaderboardSourceType.netease,
      );
    }
  } else {
    // 从JS音源获取
    final customService = ref.read(customSourceServiceProvider.notifier);

    // 转换为LeaderboardInfo
    final info = LeaderboardInfo(
      id: leaderboard.id,
      name: leaderboard.name,
      source: leaderboard.source,
      sourceId: leaderboard.sourceId,
      img: leaderboard.coverUrl,
      description: leaderboard.description,
    );

    final detail = await customService.getLeaderboardDetail(info);

    if (detail != null) {
      return UnifiedLeaderboardDetail(
        leaderboard: leaderboard,
        songs: detail.songs
            .map((song) => UnifiedSong.fromJsSource(song))
            .toList(),
        sourceType: LeaderboardSourceType.jsSource,
      );
    }
  }

  return null;
}

/// QQ音乐榜单Provider
final qqMusicLeaderboardServiceProvider = Provider<QQMusicLeaderboardService>((ref) {
  return QQMusicLeaderboardService.instance;
});

/// QQ音乐同步开关Provider
final qqMusicSyncEnabledProvider = StateNotifierProvider<QQMusicSyncNotifier, bool>((ref) {
  return QQMusicSyncNotifier();
});

class QQMusicSyncNotifier extends StateNotifier<bool> {
  QQMusicSyncNotifier() : super(false) {
    _loadState();
  }

  Future<void> _loadState() async {
    final enabled = await QQMusicSyncSettings.isEnabled();
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    await QQMusicSyncSettings.setEnabled(enabled);
    state = enabled;
  }
}

/// QQ音乐榜单列表Provider
final qqMusicLeaderboardsProvider = FutureProvider<List<QQMusicLeaderboard>>((ref) async {
  final syncEnabled = ref.watch(qqMusicSyncEnabledProvider);
  if (!syncEnabled) return [];

  final service = QQMusicLeaderboardService.instance;
  await service.initialize();
  return await service.getToplist();
});

/// QQ音乐榜单数据转JSON
Map<String, dynamic> leaderboardToJson(QQMusicLeaderboard lb) {
  return {
    'id': lb.id,
    'name': lb.name,
    'coverUrl': lb.coverUrl,
    'trackCount': lb.trackCount,
    'description': lb.description,
    'updateTime': lb.updateTime,
    'period': lb.period,
  };
}
