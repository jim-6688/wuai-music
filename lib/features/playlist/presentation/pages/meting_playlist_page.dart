import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:wuaimusic/features/playlist/providers/meting_provider.dart';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';
import 'package:wuaimusic/features/playlist/services/meting_api_client.dart';
import 'package:wuaimusic/features/files/data/models/track.dart';
import 'package:wuaimusic/shared/widgets/glass_widgets.dart';
import 'package:wuaimusic/features/player/presentation/providers/player_provider.dart';

/// 榜单配置
class LeaderboardConfig {
  final String name;
  final String id;
  final IconData icon;
  final Color color;

  const LeaderboardConfig({
    required this.name,
    required this.id,
    required this.icon,
    required this.color,
  });
}

/// 榜单列表
const List<LeaderboardConfig> kLeaderboards = [
  LeaderboardConfig(name: '热歌榜', id: '3778678', icon: Icons.local_fire_department, color: Colors.red),
  LeaderboardConfig(name: '新歌榜', id: '3779629', icon: Icons.fiber_new, color: Colors.orange),
  LeaderboardConfig(name: '飙升榜', id: '19723756', icon: Icons.trending_up, color: Colors.blue),
  LeaderboardConfig(name: '说唱榜', id: '2884035', icon: Icons.mic, color: Colors.purple),
  LeaderboardConfig(name: '电音榜', id: '3812895', icon: Icons.electrical_services, color: Colors.cyan),
  LeaderboardConfig(name: '搜索', id: 'search', icon: Icons.search, color: Colors.green),
];

/// Meting 歌单管理主页面
/// 
/// 顶部 Tab 栏：每个榜单一个 Tab
class MetingPlaylistPage extends ConsumerWidget {
  const MetingPlaylistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(metingConnectionStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: kLeaderboards.length,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('在线音乐'),
          backgroundColor: isDark 
            ? Colors.black.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.3),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark 
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          bottom: TabBar(
            isScrollable: true,
            indicatorColor: isDark ? Colors.white54 : Colors.black54,
            tabs: kLeaderboards.map((lb) => Tab(
              icon: Icon(lb.icon, size: 18),
              text: lb.name,
            )).toList(),
          ),
          actions: [
            // 连接状态
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                isConnected ? Icons.cloud_done : Icons.cloud_off,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        body: LiquidBackground(
          colors: isDark 
            ? [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f3460)]
            : [const Color(0xFF667eea), const Color(0xFF764ba2), const Color(0xFFf093fb)],
          child: SafeArea(
            child: TabBarView(
              children: kLeaderboards.map((lb) {
                if (lb.id == 'search') {
                  return const _SongSearchTab();
                }
                return _LeaderboardTab(leaderboard: lb);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// 榜单 Tab - 自动加载并显示榜单歌曲
class _LeaderboardTab extends ConsumerStatefulWidget {
  final LeaderboardConfig leaderboard;

  const _LeaderboardTab({required this.leaderboard});

  @override
  ConsumerState<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends ConsumerState<_LeaderboardTab> with AutomaticKeepAliveClientMixin {
  MetingPlaylistDetail? _playlist;
  bool _isLoading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  Future<void> _loadPlaylist() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = MetingApiClient();
      print('🔍 [Leaderboard] 开始加载榜单: ${widget.leaderboard.name}');
      final result = await apiClient.getPlaylist(widget.leaderboard.id, platform: 'netease');
      
      print('🔍 [Leaderboard] API 返回: success=${result.success}, error=${result.error}, data=${result.data?.songs.length}');

      if (result.success && result.data != null) {
        print('✅ [Leaderboard] 成功加载 ${result.data!.songs.length} 首歌曲');
        setState(() {
          _playlist = result.data;
          _isLoading = false;
        });
      } else {
        print('❌ [Leaderboard] 加载失败: ${result.error}');
        setState(() {
          _error = result.error ?? '加载失败';
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      print('❌ [Leaderboard] 异常: $e');
      print('Stack: $stack');
      setState(() {
        _error = '加载失败: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: widget.leaderboard.color),
            const SizedBox(height: 16),
            Text('正在加载${widget.leaderboard.name}...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadPlaylist,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_playlist == null || _playlist!.songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无歌曲', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylist,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        itemCount: _playlist!.songs.length,
        itemBuilder: (context, index) {
          final song = _playlist!.songs[index];
          final isDark = Theme.of(context).brightness == Brightness.dark;
          
          return GlassContainer(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(12),
            borderRadius: 12,
            backgroundColor: isDark 
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.6),
            child: Row(
              children: [
                // 排名
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.leaderboard.color,
                        widget.leaderboard.color.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 14,
                      ),
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
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                // 播放按钮
                IconButton(
                  icon: Icon(
                    Icons.play_circle_fill,
                    color: widget.leaderboard.color,
                    size: 36,
                  ),
                  onPressed: () => _playSong(song, index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 播放歌曲
  Future<void> _playSong(MetingSong song, int index) async {
    try {
      // 显示加载提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在加载: ${song.name}'),
          duration: const Duration(seconds: 1),
        ),
      );

      // 获取播放器服务
      final playerService = ref.read(audioPlayerServiceProvider);
      
      // 创建当前歌曲的 Track
      final track = Track(
        id: '${song.platform}:${song.id}',
        filePath: song.url,
        title: song.name,
        artist: song.artist,
        album: song.album,
        albumArt: song.pic,
      );

      // 创建完整播放列表（用于上一曲/下一曲功能）
      final playlist = _playlist!.songs.map((s) => Track(
        id: '${s.platform}:${s.id}',
        filePath: s.url,
        title: s.name,
        artist: s.artist,
        album: s.album,
        albumArt: s.pic,
      )).toList();

      // 播放（传入播放列表和当前索引）
      await playerService.playTrack(track, playlist: playlist);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('正在播放: ${song.name}'),
            backgroundColor: Colors.green,
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
}

/// 歌曲搜索标签页
class _SongSearchTab extends ConsumerStatefulWidget {
  const _SongSearchTab();

  @override
  ConsumerState<_SongSearchTab> createState() => _SongSearchTabState();
}

class _SongSearchTabState extends ConsumerState<_SongSearchTab> {
  final TextEditingController _searchController = TextEditingController();
  List<MetingSong> _searchResults = [];
  bool _isLoading = false;
  final List<String> _searchHistory = [];

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    // TODO: 加载搜索历史
  }

  Future<void> _searchSongs(String keyword) async {
    if (keyword.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchResults = [];
    });

    try {
      final apiClient = MetingApiClient();
      final result = await apiClient.searchSongs(keyword, platform: 'netease', limit: 30);

      if (result.success && result.data != null) {
        setState(() {
          _searchResults = result.data!;
        });

        // 保存到搜索历史
        if (!_searchHistory.contains(keyword)) {
          _searchHistory.insert(0, keyword);
          if (_searchHistory.length > 10) {
            _searchHistory.removeLast();
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('搜索失败: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 搜索框
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索歌曲、艺人、专辑...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (keyword) => _searchSongs(keyword),
          ),
        ),

        // 搜索结果或历史
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isNotEmpty
                  ? _buildSearchResults()
                  : _buildSearchHistory(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.primaries[index % Colors.primaries.length].withValues(alpha: 0.2),
            child: Icon(
              Icons.music_note,
              color: Colors.primaries[index % Colors.primaries.length],
            ),
          ),
          title: Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${song.artist} · ${song.album}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () {
              // TODO: 播放歌曲
            },
          ),
          onTap: () {
            // TODO: 播放歌曲
          },
        );
      },
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIcons.magnifyingGlass(),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '搜索歌曲',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '输入关键词开始搜索',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '搜索历史',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _searchHistory.clear();
                  });
                },
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var keyword in _searchHistory)
                GestureDetector(
                  onTap: () {
                    _searchController.text = keyword;
                    _searchSongs(keyword);
                  },
                  child: Chip(
                    label: Text(keyword),
                    onDeleted: () {
                      setState(() {
                        _searchHistory.remove(keyword);
                      });
                    },
                    deleteIcon: const Icon(Icons.close, size: 16),
                    avatar: const Icon(Icons.history, size: 16),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
