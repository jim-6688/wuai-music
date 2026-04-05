import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/custom_source_service.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../files/data/models/track.dart';

/// 自定义音源歌曲列表页面
class CustomSourceSongsPage extends ConsumerStatefulWidget {
  final String? initialQuery;

  const CustomSourceSongsPage({super.key, this.initialQuery});

  @override
  ConsumerState<CustomSourceSongsPage> createState() => _CustomSourceSongsPageState();
}

class _CustomSourceSongsPageState extends ConsumerState<CustomSourceSongsPage> {
  final TextEditingController _searchController = TextEditingController();
  List<MusicInfo> _songs = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _search(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      final results = await service.searchMusic(keyword);
      // 将所有搜索结果的歌曲合并到一个列表
      final allSongs = <MusicInfo>[];
      for (final result in results) {
        allSongs.addAll(result.list);
      }
      setState(() {
        _songs = allSongs;
        _isLoading = false;
        
        if (allSongs.isEmpty && results.isEmpty) {
          _errorMessage = '未找到相关歌曲，请检查音源是否正确导入';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '搜索失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('在线搜索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_music),
            onPressed: () {
              // 跳转到音源管理
              Navigator.of(context).pushNamed('/custom-source-manager');
            },
            tooltip: '音源管理',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索歌曲、歌手',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _songs = [];
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onSubmitted: _search,
              onChanged: (value) {
                setState(() {});
              },
            ),
          ),

          // 歌曲列表
          Expanded(
            child: _buildSongList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSongList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              '搜索你喜欢的音乐',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        final song = _songs[index];
        return _SongCard(
          song: song,
          index: index + 1,
          onTap: () => _playSong(index),
        );
      },
    );
  }

  void _playSong(int index) async {
    final song = _songs[index];

    try {
      // 获取播放URL
      final service = ref.read(customSourceServiceProvider.notifier);
      final urlInfo = await service.getMusicUrl(song.sourceId, song.id, '128k');
      
      if (urlInfo == null || urlInfo.url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取播放链接')),
          );
        }
        return;
      }

      // 转换为Track对象
      final track = Track(
        id: song.id,
        title: song.name,
        artist: song.singer,
        album: song.album ?? '',
        filePath: urlInfo.url,
        duration: Duration(seconds: song.interval ?? 0),
        albumArt: song.img,
      );

      // 添加到播放列表并播放
      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playTrack(track, playlist: _songs.map((s) => Track(
        id: s.id,
        title: s.name,
        artist: s.singer,
        album: s.album ?? '',
        filePath: '', // 稍后获取
        duration: Duration(seconds: s.interval ?? 0),
        albumArt: s.img,
      )).toList());

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
}

/// 歌曲卡片
class _SongCard extends StatelessWidget {
  final MusicInfo song;
  final int index;
  final VoidCallback onTap;

  const _SongCard({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          // 序号
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              index.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // 封面
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 48,
              height: 48,
              color: Colors.grey.shade300,
              child: song.img != null
                  ? Image.network(
                      song.img!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.music_note,
                        color: Colors.grey.shade500,
                      ),
                    )
                  : Icon(
                      Icons.music_note,
                      color: Colors.grey.shade500,
                    ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.singer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),

          // 更多操作
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: 显示更多操作菜单
            },
          ),
        ],
      ),
    );
  }
}
