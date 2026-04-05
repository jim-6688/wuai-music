import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';
import 'package:wuaimusic/features/playlist/providers/meting_provider.dart';
import 'package:wuaimusic/features/files/data/models/track.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Meting 歌单详情页面
class MetingPlaylistDetailPage extends ConsumerStatefulWidget {
  final String playlistId;
  final String platform;

  const MetingPlaylistDetailPage({
    super.key,
    required this.playlistId,
    required this.platform,
  });

  @override
  ConsumerState<MetingPlaylistDetailPage> createState() =>
      _MetingPlaylistDetailPageState();
}

class _MetingPlaylistDetailPageState
    extends ConsumerState<MetingPlaylistDetailPage> {
  @override
  void initState() {
    super.initState();
    // 延迟到widget树构建完成后执行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 切换到指定平台
      ref.read(metingPlaylistActionsProvider).switchPlatform(widget.platform);
      // 加载歌单
      ref
          .read(metingPlaylistDetailStateProvider.notifier)
          .loadPlaylist(widget.playlistId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(metingPlaylistDetailStateProvider);
    final currentPlatform = ref.watch(currentPlatformProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部歌单信息
          _buildSliverHeader(state, currentPlatform),

          // 歌曲列表
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      state.error!,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(metingPlaylistDetailStateProvider.notifier)
                            .loadPlaylist(widget.playlistId);
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          else if (state.tracks.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = state.tracks[index];
                  return _buildTrackItem(track, index);
                },
                childCount: state.tracks.length,
              ),
            )
          else
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.music_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      '歌单为空',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(
      MetingPlaylistDetailState state, String platform) {
    final playlist = state.playlist;

    if (playlist == null) {
      return SliverAppBar(
        title: const Text('加载中...'),
        pinned: true,
      );
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 背景封面
            if (playlist.pic != null)
              Image.network(
                playlist.pic!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[900],
                  );
                },
              )
            else
              Container(color: Colors.grey[900]),
            // 渐变遮罩
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: Row(
            children: [
              // 歌单封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: playlist.pic != null
                    ? Image.network(
                        playlist.pic!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 50,
                            height: 50,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, color: Colors.white),
                          );
                        },
                      )
                    : Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, color: Colors.white),
                      ),
              ),
              const SizedBox(width: 12),
              // 歌单信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      playlist.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.artist} · ${state.tracks.length} 首歌曲',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 播放按钮
              IconButton(
                onPressed: () {
                  _playAll();
                },
                icon: const Icon(Icons.play_circle_filled, color: Colors.white),
                iconSize: 48,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackItem(Track track, int index) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('${index + 1}'),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () {
              _addToQueue(index);
            },
            tooltip: '添加到队列',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () {
              _playTrack(index);
            },
            tooltip: '播放',
          ),
        ],
      ),
      onTap: () {
        _playTrack(index);
      },
    );
  }

  void _playTrack(int index) async {
    try {
      await ref.read(metingPlaylistActionsProvider).playSong(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始播放'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _playAll() async {
    try {
      await ref.read(metingPlaylistActionsProvider).playPlaylist();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始播放整个歌单'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addToQueue(int index) async {
    try {
      await ref.read(metingPlaylistActionsProvider).addToQueue(index);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已添加到播放队列'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // 清理状态
    ref.read(metingPlaylistDetailStateProvider.notifier).clear();
    super.dispose();
  }
}
