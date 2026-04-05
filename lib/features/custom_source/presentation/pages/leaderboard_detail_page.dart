import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/custom_source_service.dart';
import '../../data/models/music_source.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../files/data/models/track.dart';

/// 榜单详情页面
class LeaderboardDetailPage extends ConsumerStatefulWidget {
  final LeaderboardInfo leaderboard;

  const LeaderboardDetailPage({
    super.key,
    required this.leaderboard,
  });

  @override
  ConsumerState<LeaderboardDetailPage> createState() => 
      _LeaderboardDetailPageState();
}

class _LeaderboardDetailPageState 
    extends ConsumerState<LeaderboardDetailPage> {
  LeaderboardDetail? _detail;
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
      final service = ref.read(customSourceServiceProvider.notifier);
      final detail = await service.getLeaderboardDetail(widget.leaderboard);

      if (mounted) {
        setState(() {
          _detail = detail;
          _isLoading = false;

          if (detail == null || detail.songs.isEmpty) {
            _errorMessage = '无法加载榜单详情';
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
            child: widget.leaderboard.img != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.leaderboard.img!,
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
                Text(
                  '${_getSourceLabel(widget.leaderboard.source)} · ${_detail?.songs.length ?? 0}首',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          
          // 播放全部按钮
          if (_detail != null && _detail!.songs.isNotEmpty)
            GlassButton(
              onPressed: () => _playAll(),
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

    if (_detail == null || _detail!.songs.isEmpty) {
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
        itemCount: _detail!.songs.length,
        itemBuilder: (context, index) {
          return _buildSongCard(_detail!.songs[index], index + 1, isDarkMode);
        },
      ),
    );
  }

  Widget _buildSongCard(MusicInfo song, int rank, bool isDarkMode) {
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
            child: song.img != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.img!,
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
                  song.singer,
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
          if (song.interval != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                _formatDuration(song.interval!),
                style: TextStyle(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
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
        return Colors.green;
      case 'wy':
        return Colors.red;
      case 'mg':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }

  String _getSourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'kw':
        return '酷我';
      case 'kg':
        return '酷狗';
      case 'tx':
        return 'QQ';
      case 'wy':
        return '网易';
      case 'mg':
        return '咪咕';
      default:
        return source.toUpperCase();
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

  void _playSong(MusicInfo song) async {
    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      final urlInfo = await service.getMusicUrl(
        song.sourceId,
        song.id,
        '320k',
      );

      if (urlInfo == null || urlInfo.url.isEmpty) {
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
        artist: song.singer,
        album: song.album ?? '',
        filePath: urlInfo.url,
        duration: Duration(seconds: song.interval ?? 0),
        albumArt: song.img,
      );

      final audioService = ref.read(audioPlayerServiceProvider);

      // 先用当前歌曲立即播放，同时把整个榜单（仅基础信息，无URL）作为占位放入队列
      // 后台再异步批量获取 URL 并更新队列，这样用户可以立即切换
      if (_detail != null && _detail!.songs.length > 1) {
        // 构建仅含基础信息的播放列表（URL 暂为空，后续异步填充）
        final allSongs = _detail!.songs;
        final placeholderList = allSongs.map((s) => Track(
          id: s.id,
          title: s.name,
          artist: s.singer,
          album: s.album ?? '',
          filePath: s.id == song.id ? urlInfo.url : '', // 当前曲先填入 URL
          duration: Duration(seconds: s.interval ?? 0),
          albumArt: s.img,
        )).toList();

        await audioService.playTrack(track, playlist: placeholderList);

        // 后台异步获取其他歌曲 URL 并更新队列
        _prefetchPlaylistUrls(allSongs, song.id);
      } else {
        await audioService.playTrack(track);
      }

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

  /// 后台异步预取播放列表中其他歌曲的 URL，并更新播放服务中的队列
  Future<void> _prefetchPlaylistUrls(List<MusicInfo> allSongs, String currentSongId) async {
    if (_detail == null) return;
    final service = ref.read(customSourceServiceProvider.notifier);
    final audioService = ref.read(audioPlayerServiceProvider);

    for (final s in allSongs) {
      if (s.id == currentSongId) continue; // 当前歌曲已有 URL，跳过
      if (!mounted) break;
      try {
        final info = await service.getMusicUrl(s.sourceId, s.id, '320k');
        if (info != null && info.url.isNotEmpty) {
          // 更新播放列表中对应条目的 URL
          audioService.updateTrackUrl(s.id, info.url);
        }
      } catch (_) {
        // 单首获取失败不影响其他
      }
    }
  }

  void _playAll() async {
    if (_detail == null || _detail!.songs.isEmpty) return;

    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      final tracks = <Track>[];

      // 预先获取所有歌曲的URL（只获取前10首，避免等待太久）
      final songsToPlay = _detail!.songs.take(10).toList();
      
      for (final song in songsToPlay) {
        final urlInfo = await service.getMusicUrl(
          song.sourceId,
          song.id,
          '320k',
        );

        tracks.add(Track(
          id: song.id,
          title: song.name,
          artist: song.singer,
          album: song.album ?? '',
          filePath: urlInfo?.url ?? '',
          duration: Duration(seconds: song.interval ?? 0),
          albumArt: song.img,
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
