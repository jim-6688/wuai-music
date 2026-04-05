import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import '../../../playlist/services/netease_leaderboard_service.dart';
import '../../../playlist/services/qq_music_leaderboard_service.dart';
import '../../services/custom_source_service.dart';
import '../../data/models/music_source.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../files/data/models/track.dart';

/// 统一榜单详情页面
/// 支持网易云API和JS音源两种数据源
class UnifiedLeaderboardDetailPage extends ConsumerStatefulWidget {
  final UnifiedLeaderboard leaderboard;

  const UnifiedLeaderboardDetailPage({
    super.key,
    required this.leaderboard,
  });

  @override
  ConsumerState<UnifiedLeaderboardDetailPage> createState() =>
      _UnifiedLeaderboardDetailPageState();
}

class _UnifiedLeaderboardDetailPageState
    extends ConsumerState<UnifiedLeaderboardDetailPage> {
  List<UnifiedSong> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<UnifiedSong> songs = [];

      if (widget.leaderboard.sourceType == LeaderboardSourceType.netease) {
        // 网易云API获取
        final service = NeteaseLeaderboardService.instance;
        final detail = await service.getLeaderboardDetail(widget.leaderboard.id);

        if (detail != null) {
          songs = detail.tracks
              .map((song) => UnifiedSong.fromNetease(song))
              .toList();
        }
      } else if (widget.leaderboard.sourceType == LeaderboardSourceType.qq) {
        // QQ音乐API获取
        final service = QQMusicLeaderboardService.instance;
        await service.initialize();
        final qqSongs = await service.getLeaderboardDetail(widget.leaderboard.id);

        songs = qqSongs
            .map((song) => UnifiedSong.fromQQMusic(song))
            .toList();
      } else {
        // JS音源获取
        final customService = ref.read(customSourceServiceProvider.notifier);

        // 转换为LeaderboardInfo
        final info = LeaderboardInfo(
          id: widget.leaderboard.id,
          name: widget.leaderboard.name,
          source: widget.leaderboard.source,
          sourceId: widget.leaderboard.sourceId,
          img: widget.leaderboard.coverUrl,
          description: widget.leaderboard.description,
        );

        final detail = await customService.getLeaderboardDetail(info);

        if (detail != null) {
          songs = detail.songs
              .map((song) => UnifiedSong.fromJsSource(song))
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _songs = songs;
          _isLoading = false;

          if (songs.isEmpty) {
            _errorMessage = '暂无歌曲数据';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.deepPurple.shade900, Colors.indigo.shade900]
                : [Colors.purple.shade100, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              _buildHeader(isDarkMode),

              // 歌曲列表
              Expanded(
                child: _buildContent(isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),

          const SizedBox(width: 8),

          // 榜单封面
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _getSourceColor(widget.leaderboard.source),
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.leaderboard.coverUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.leaderboard.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.leaderboard_rounded,
                        color: Colors.white.withAlpha(150),
                      ),
                    ),
                  )
                : Icon(
                    Icons.leaderboard_rounded,
                    color: Colors.white.withAlpha(150),
                  ),
          ),

          const SizedBox(width: 12),

          // 榜单信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.leaderboard.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildSourceBadge(),
                    const SizedBox(width: 8),
                    Text(
                      '${_songs.length}首',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 播放全部按钮
          if (_songs.isNotEmpty)
            GlassButton(
              onPressed: _playAll,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '播放全部',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge() {
    final isNetease = widget.leaderboard.sourceType == LeaderboardSourceType.netease;
    final isQQ = widget.leaderboard.sourceType == LeaderboardSourceType.qq;
    final Color badgeColor = isNetease ? Colors.red : isQQ ? Colors.green : Colors.purple;
    final String badgeText = isNetease ? '网易云' : isQQ ? 'QQ音乐' : 'JS音源';
    final IconData badgeIcon = isNetease ? Icons.cloud_rounded : isQQ ? Icons.music_note_rounded : Icons.code_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(40),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, size: 12, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            badgeText,
            style: TextStyle(
              fontSize: 11,
              color: badgeColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDarkMode) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDetail,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 64,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无歌曲',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDetail,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _songs.length,
        itemBuilder: (context, index) {
          return _buildSongCard(_songs[index], index + 1, isDarkMode);
        },
      ),
    );
  }

  Widget _buildSongCard(UnifiedSong song, int rank, bool isDarkMode) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: () => _playSong(song),
      child: Row(
        children: [
          // 排名
          Container(
            width: 36,
            alignment: Alignment.center,
            child: Text(
              rank.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: rank <= 3
                    ? _getRankColor(rank)
                    : (isDarkMode ? Colors.white54 : Colors.black45),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 封面
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withAlpha(20)
                  : Colors.black.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: song.albumCover != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.albumCover!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.music_note_rounded,
                        color: isDarkMode ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  )
                : Icon(
                    Icons.music_note_rounded,
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
          ),

          const SizedBox(width: 12),

          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // 时长
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              _formatDuration(song.duration ~/ 1000),
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
          ),

          // 音质标识
          if (song.sourceType == LeaderboardSourceType.jsSource)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FLAC',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.purple.shade400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'kw':
        return Colors.orange;
      case 'kg':
        return Colors.blue;
      case 'tx':
      case 'qq':
        return Colors.green;
      case 'wy':
        return Colors.red;
      case 'mg':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _playSong(UnifiedSong song) async {
    try {
      String? url;

      if (song.sourceType == LeaderboardSourceType.netease) {
        // 网易云API获取URL
        final service = NeteaseLeaderboardService.instance;
        final songUrl = await service.getSongUrl(song.id, level: 2); // 高品320k
        url = songUrl?.url;
      } else {
        // JS音源获取URL
        final service = ref.read(customSourceServiceProvider.notifier);
        final urlInfo = await service.getMusicUrl(
          song.sourceId,
          song.id,
          'flac',
          sourceKey: song.source,
        );
        url = urlInfo?.url;
      }

      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取播放链接')),
          );
        }
        return;
      }

      final track = Track(
        id: song.id,
        title: song.name,
        artist: song.artist,
        album: song.album ?? '',
        filePath: url,
        duration: Duration(milliseconds: song.duration),
        albumArt: song.albumCover,
      );

      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playTrack(track);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在播放: ${song.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }

  void _playAll() async {
    if (_songs.isEmpty) return;

    try {
      final tracks = <Track>[];

      // 预先获取前10首歌曲的URL
      final songsToPlay = _songs.take(10).toList();

      for (final song in songsToPlay) {
        String? url;

        if (song.sourceType == LeaderboardSourceType.netease) {
          final service = NeteaseLeaderboardService.instance;
          final songUrl = await service.getSongUrl(song.id, level: 2);
          url = songUrl?.url;
        } else {
          final service = ref.read(customSourceServiceProvider.notifier);
          final urlInfo = await service.getMusicUrl(
            song.sourceId,
            song.id,
            'flac',
            sourceKey: song.source,
          );
          url = urlInfo?.url;
        }

        tracks.add(Track(
          id: song.id,
          title: song.name,
          artist: song.artist,
          album: song.album ?? '',
          filePath: url ?? '',
          duration: Duration(milliseconds: song.duration),
          albumArt: song.albumCover,
        ));
      }

      if (tracks.isEmpty || tracks.every((t) => t.filePath.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取播放链接')),
          );
        }
        return;
      }

      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playTrack(
        tracks.firstWhere((t) => t.filePath.isNotEmpty),
        playlist: tracks.where((t) => t.filePath.isNotEmpty).toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在播放: ${tracks.first.title}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e')),
        );
      }
    }
  }
}
