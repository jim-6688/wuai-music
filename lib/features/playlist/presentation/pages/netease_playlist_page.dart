import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/netease_provider.dart';
import '../../models/netease_models.dart';
import '../../../custom_source/presentation/pages/custom_source_songs_page.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../files/data/models/track.dart';
import 'netease_login_page.dart';

/// 网易云音乐歌单列表页面
class NeteasePlaylistPage extends ConsumerStatefulWidget {
  const NeteasePlaylistPage({super.key});

  @override
  ConsumerState<NeteasePlaylistPage> createState() => _NeteasePlaylistPageState();
}

class _NeteasePlaylistPageState extends ConsumerState<NeteasePlaylistPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showUserPlaylists = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 改为3个标签
    _tabController.addListener(() {
      setState(() {
        _showUserPlaylists = _tabController.index == 0;
      });
    });
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
    final syncService = ref.read(neteaseSyncServiceProvider);
    
    // 加载用户歌单
    if (syncService.isLoggedIn) {
      await syncService.loadUserPlaylists();
    }
    
    // 加载推荐歌单
    await syncService.loadRecommendPlaylists();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(neteaseSyncServiceProvider);
    final userInfo = ref.watch(neteaseUserInfoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('网易云音乐'),
        actions: [
          if (syncService.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: () => _showSyncDialog(context),
              tooltip: '同步歌单',
            ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
            tooltip: '搜索歌曲',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我的歌单'),
            Tab(text: '推荐歌单'),
            Tab(text: '在线搜索'), // 新增标签
          ],
        ),
      ),
      body: Column(
        children: [
          // 用户信息
          if (syncService.isLoggedIn && userInfo != null)
            _buildUserInfo(userInfo),
          
          // 歌单列表
          Expanded(
            child: syncService.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPlaylistList(
                        _showUserPlaylists
                            ? syncService.userPlaylists
                            : syncService.recommendPlaylists,
                        isUserPlaylist: _showUserPlaylists,
                      ),
                      _buildPlaylistList(
                        syncService.recommendPlaylists,
                        isUserPlaylist: false,
                      ),
                      // 新增：自定义音源搜索页面
                      const CustomSourceSongsPage(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: !syncService.isLoggedIn
          ? FloatingActionButton.extended(
              onPressed: () => _showLoginDialog(context),
              backgroundColor: Colors.red,
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('登录', style: TextStyle(color: Colors.white)),
            )
          : null,
    );
  }

  Widget _buildUserInfo(NeteaseUserInfo userInfo) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: userInfo.avatarUrl != null
                ? CachedNetworkImageProvider(userInfo.avatarUrl!)
                : null,
            child: userInfo.avatarUrl == null
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userInfo.nickname,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'UID: ${userInfo.userId}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _logout(context),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistList(List<NeteasePlaylist> playlists,
      {required bool isUserPlaylist}) {
    if (playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isUserPlaylist ? Icons.library_music : Icons.explore,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isUserPlaylist ? '暂无歌单' : '暂无推荐歌单',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            if (isUserPlaylist && !isLoggedIn)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton(
                  onPressed: () => _showLoginDialog(context),
                  child: const Text('登录网易云音乐'),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlaylists,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          return _PlaylistCard(
            playlist: playlists[index],
            onTap: () => _openPlaylistDetail(playlists[index]),
          );
        },
      ),
    );
  }

  bool get isLoggedIn => ref.read(neteaseSyncServiceProvider).isLoggedIn;

  void _showLoginDialog(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const NeteaseLoginPage(),
      ),
    );
    
    if (result == true) {
      // 登录成功，刷新歌单
      _loadPlaylists();
    }
  }

  void _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出网易云音乐登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(neteaseSyncServiceProvider).logout();
    }
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final syncService = ref.watch(neteaseSyncServiceProvider);
          
          return AlertDialog(
            title: const Text('同步歌单'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (syncService.isSyncing)
                  Column(
                    children: [
                      LinearProgressIndicator(
                        value: syncService.syncProgress,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      const SizedBox(height: 16),
                      Text('同步中... ${(syncService.syncProgress * 100).toInt()}%'),
                    ],
                  )
                else
                  const Text('点击确定开始同步您的歌单'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              if (!syncService.isSyncing)
                ElevatedButton(
                  onPressed: () {
                    syncService.syncAllPlaylists();
                  },
                  child: const Text('开始同步'),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const NeteaseSearchDialog(),
    );
  }

  void _openPlaylistDetail(NeteasePlaylist playlist) {
    // 使用原生网易云 API 加载歌单详情并播放
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _NeteasePlaylistDetailPage(playlist: playlist),
      ),
    );
  }
}

/// 歌单卡片组件
class _PlaylistCard extends StatelessWidget {
  final NeteasePlaylist playlist;
  final VoidCallback onTap;

  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 封面
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: playlist.coverImgUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.music_note),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.music_note),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.trackCount} 首',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (playlist.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: playlist.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.red.shade700,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 播放量
              Column(
                children: [
                  Icon(
                    Icons.play_arrow,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  Text(
                    _formatPlayCount(playlist.playCount),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPlayCount(int count) {
    if (count >= 100000000) {
      return '${(count / 100000000).toStringAsFixed(1)}亿';
    } else if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}万';
    }
    return count.toString();
  }
}

/// 歌单详情页面 - 使用原生网易云 API 加载歌曲并播放
class _NeteasePlaylistDetailPage extends ConsumerStatefulWidget {
  final NeteasePlaylist playlist;

  const _NeteasePlaylistDetailPage({
    required this.playlist,
  });

  @override
  ConsumerState<_NeteasePlaylistDetailPage> createState() =>
      _NeteasePlaylistDetailPageState();
}

class _NeteasePlaylistDetailPageState
    extends ConsumerState<_NeteasePlaylistDetailPage> {
  List<NeteaseSong> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPlaylistDetail();
  }

  Future<void> _loadPlaylistDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apiService = ref.read(neteaseApiServiceProvider);
      final detail = await apiService.getPlaylistDetail(widget.playlist.id);

      if (detail != null && detail.tracks.isNotEmpty) {
        setState(() {
          _tracks = detail.tracks;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '歌单为空或加载失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '加载歌单失败: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack(int index) async {
    try {
      final song = _tracks[index];
      final apiService = ref.read(neteaseApiServiceProvider);
      final url = await apiService.getSongUrl(song.id, level: 2);

      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取播放链接，可能是 VIP 或付费歌曲'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 构建播放列表
      final tracks = _tracks.map((s) => Track(
        id: s.id,
        filePath: '',
        title: s.name,
        artist: s.artistsName,
        album: s.albumName ?? '',
        duration: Duration(milliseconds: s.duration),
        albumArt: s.albumCoverUrl,
      )).toList();

      final currentTrack = tracks[index].copyWith(filePath: url);
      tracks[index] = currentTrack;

      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playTrack(currentTrack, playlist: tracks);

      if (mounted) {
        Navigator.of(context).pop();
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

  Future<void> _playAll() async {
    if (_tracks.isEmpty) return;
    try {
      final apiService = ref.read(neteaseApiServiceProvider);

      // 预取前 10 首歌曲的播放链接
      final songsToFetch = _tracks.take(10).toList();
      final urlMap = await apiService.getSongsUrl(
        songsToFetch.map((s) => s.id).toList(),
        level: 2,
      );

      final tracks = _tracks.map((s) {
        final url = urlMap[s.id] ?? '';
        return Track(
          id: s.id,
          filePath: url,
          title: s.name,
          artist: s.artistsName,
          album: s.albumName ?? '',
          duration: Duration(milliseconds: s.duration),
          albumArt: s.albumCoverUrl,
        );
      }).toList();

      if (tracks.isNotEmpty && tracks.first.filePath.isNotEmpty) {
        final audioService = ref.read(audioPlayerServiceProvider);
        await audioService.playTrack(tracks.first, playlist: tracks);
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取播放链接'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shufflePlay() async {
    if (_tracks.isEmpty) return;
    try {
      final random = DateTime.now().millisecondsSinceEpoch % _tracks.length;
      await _playTrack(random);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('随机播放失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.playlist.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.playlist.coverImgUrl,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.play_arrow),
                onPressed: _isLoading ? null : _playAll,
                tooltip: '播放全部',
              ),
              IconButton(
                icon: const Icon(Icons.shuffle),
                onPressed: _isLoading ? null : _shufflePlay,
                tooltip: '随机播放',
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.play_arrow, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text(_formatPlayCount(widget.playlist.playCount),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(width: 16),
                      Icon(Icons.music_note, size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      Text('${_tracks.length} 首',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                  if (widget.playlist.description != null) ...[
                    const SizedBox(height: 12),
                    Text(widget.playlist.description!,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(_errorMessage!, style: TextStyle(color: Colors.grey.shade600), textAlign: TextAlign.center),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _loadPlaylistDetail, child: const Text('重试')),
                  ],
                ),
              ),
            )
          else if (_tracks.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('暂无歌曲')))
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _SongListTile(
                    track: _tracks[index],
                    index: index + 1,
                    onTap: () => _playTrack(index),
                  );
                },
                childCount: _tracks.length,
              ),
            ),
        ],
      ),
    );
  }

  String _formatPlayCount(int count) {
    if (count >= 100000000) return '${(count / 100000000).toStringAsFixed(1)}亿';
    if (count >= 10000) return '${(count / 10000).toStringAsFixed(1)}万';
    return count.toString();
  }
}

/// 歌曲列表项
class _SongListTile extends StatelessWidget {
  final NeteaseSong track;
  final int index;
  final VoidCallback onTap;

  const _SongListTile({
    required this.track,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
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
      title: Text(
        track.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        track.artistsName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (track.isVipOnly)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'VIP',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
          if (track.needPurchase)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '付费',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.shade800,
                ),
              ),
            ),
          const SizedBox(width: 8),
          Icon(Icons.more_vert, size: 20, color: Colors.grey.shade400),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// 搜索对话框
class NeteaseSearchDialog extends ConsumerStatefulWidget {
  const NeteaseSearchDialog({super.key});

  @override
  ConsumerState<NeteaseSearchDialog> createState() =>
      _NeteaseSearchDialogState();
}

class _NeteaseSearchDialogState extends ConsumerState<NeteaseSearchDialog> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _search() {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      ref.read(neteaseSearchProvider.notifier).search(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(neteaseSearchProvider);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 搜索框
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: '搜索歌曲、歌手、专辑',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 搜索结果
            Expanded(
              child: searchState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : searchState.songs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchState.keyword.isEmpty
                                    ? '输入关键词搜索'
                                    : '未找到相关结果',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: searchState.songs.length,
                          itemBuilder: (context, index) {
                            final song = searchState.songs[index];
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.grey.shade200,
                                ),
                                child: const Icon(Icons.music_note),
                              ),
                              title: Text(
                                song.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artistsName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Text(
                                _formatDuration(song.duration),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              onTap: () async {
                                Navigator.of(context).pop();
                                await _playSearchSong(song, searchState.songs);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 播放搜索结果中的歌曲
  Future<void> _playSearchSong(NeteaseSong song, List<NeteaseSong> allSongs) async {
    try {
      // 通过 NeteaseApiService 获取播放链接
      final apiService = ref.read(neteaseApiServiceProvider);
      final url = await apiService.getSongUrl(song.id, level: 2);

      if (url == null || url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法获取播放链接，可能是 VIP 或付费歌曲'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 将搜索结果列表转为 Track 列表
      final tracks = allSongs.map((s) => Track(
        id: s.id,
        filePath: '', // 先不填 URL，播放时按需获取
        title: s.name,
        artist: s.artistsName,
        album: s.albumName ?? '',
        duration: Duration(milliseconds: s.duration),
        albumArt: s.albumCoverUrl,
      )).toList();

      // 设置当前歌曲的播放链接
      final currentTrack = tracks.firstWhere((t) => t.id == song.id);
      final trackWithUrl = currentTrack.copyWith(filePath: url);

      // 替换列表中的当前歌曲
      final idx = tracks.indexWhere((t) => t.id == song.id);
      if (idx >= 0) tracks[idx] = trackWithUrl;

      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playTrack(trackWithUrl, playlist: tracks);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('正在播放: ${song.name} - ${song.artistsName}')),
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
