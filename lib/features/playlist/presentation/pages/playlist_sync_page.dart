import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../providers/playlist_provider.dart';
import '../../services/playlist_sync_service.dart';
import '../../services/multi_platform_playlist_service.dart';
import '../../data/models/playlist.dart';
import '../../data/models/music_platform.dart';

/// 歌单同步页面
class PlaylistSyncPage extends ConsumerStatefulWidget {
  const PlaylistSyncPage({super.key});

  @override
  ConsumerState<PlaylistSyncPage> createState() => _PlaylistSyncPageState();
}

class _PlaylistSyncPageState extends ConsumerState<PlaylistSyncPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0;
  
  // 分类标签
  final List<String> _categories = [
    '全部',
    '流行',
    '华语',
    '欧美',
    '摇滚',
    '民谣',
    '电子',
    '说唱',
    '轻音乐',
    '古典',
  ];
  
  @override
  void initState() {
    super.initState();
    // 加载推荐歌单
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multiPlatformPlaylistServiceProvider).getRecommendPlaylists();
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final playlistService = ref.watch(multiPlatformPlaylistServiceProvider);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.purple.shade900, Colors.indigo.shade900]
                : [Colors.purple.shade100, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              _buildHeader(isDarkMode),
              
              // 搜索栏
              _buildSearchBar(isDarkMode),
              
              // 分类标签
              _buildCategoryTabs(isDarkMode),
              
              // 歌单列表
              Expanded(
                child: _buildPlaylistGrid(playlistService, isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isDarkMode) {
    final multiService = ref.watch(multiPlatformPlaylistServiceProvider);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Text(
            '歌单同步',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          // 平台切换按钮
          _buildPlatformSelector(multiService, isDarkMode),
          const SizedBox(width: 8),
          GlassButton(
            onPressed: () => _showSyncHistory(),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.history_rounded,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPlatformSelector(MultiPlatformPlaylistService service, bool isDarkMode) {
    return GestureDetector(
      onTap: () => _showPlatformSelector(service),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: service.currentPlatform.color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: service.currentPlatform.color, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 16,
              color: service.currentPlatform.color,
            ),
            const SizedBox(width: 6),
            Text(
              service.currentPlatform.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: service.currentPlatform.color,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: service.currentPlatform.color,
            ),
          ],
        ),
      ),
    );
  }
  
  void _showPlatformSelector(MultiPlatformPlaylistService service) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '选择音乐平台',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: MusicPlatform.values.where((p) => p != MusicPlatform.local).map((platform) {
                final isSelected = service.currentPlatform == platform;
                return GestureDetector(
                  onTap: () {
                    service.switchPlatform(platform);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: platform.color.withValues(alpha: isSelected ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: platform.color,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          size: 18,
                          color: platform.color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          platform.label,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: platform.color,
                          ),
                        ),
                        if (platform != MusicPlatform.netease) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '即将支持',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSearchBar(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassContainer(
        borderRadius: 24,
        blur: 10,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: isDarkMode ? Colors.white54 : Colors.black38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: '搜索歌单、歌手、歌曲',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    ref.read(multiPlatformPlaylistServiceProvider).searchPlaylists(value);
                  }
                },
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                color: isDarkMode ? Colors.white38 : Colors.black38,
              ),
              onPressed: () {
                _searchController.clear();
                ref.read(multiPlatformPlaylistServiceProvider).getRecommendPlaylists();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCategoryTabs(bool isDarkMode) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTabIndex = index);
                
                final category = _categories[index];
                if (category == '全部') {
                  ref.read(multiPlatformPlaylistServiceProvider).getRecommendPlaylists();
                } else {
                  ref.read(multiPlatformPlaylistServiceProvider).getPlaylistsByCategory(category);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _categories[index],
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode ? Colors.white70 : Colors.black54),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPlaylistGrid(MultiPlatformPlaylistService service, bool isDarkMode) {
    if (service.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    if (service.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              service.errorMessage!,
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => service.getRecommendPlaylists(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    
    if (service.playlists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无歌单',
              style: TextStyle(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: () => service.getRecommendPlaylists(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: service.playlists.length,
        itemBuilder: (context, index) {
          final playlist = service.playlists[index];
          return _buildPlaylistCard(playlist, isDarkMode);
        },
      ),
    );
  }
  
  Widget _buildPlaylistCard(Playlist playlist, bool isDarkMode) {
    return GlassCard(
      onTap: () => _openPlaylistDetail(playlist),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图片
                  if (playlist.coverUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        playlist.coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildDefaultCover(isDarkMode),
                      ),
                    )
                  else
                    _buildDefaultCover(isDarkMode),
                  
                  // 播放量
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatPlayCount(playlist.playCount),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // 歌曲数量
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${playlist.trackCount}首',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 歌单名称
          Text(
            playlist.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          
          // 创建者
          if (playlist.creator != null) ...[
            const SizedBox(height: 4),
            Text(
              playlist.creator!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildDefaultCover(bool isDarkMode) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Colors.purple.shade400, Colors.blue.shade400]
              : [Colors.purple.shade200, Colors.blue.shade200],
        ),
      ),
      child: Icon(
        Icons.library_music_rounded,
        size: 48,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }
  
  void _openPlaylistDetail(Playlist playlist) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PlaylistDetailPage(playlist: playlist),
      ),
    );
  }
  
  void _showSyncHistory() {
    // TODO: 显示同步历史
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('同步历史功能开发中...')),
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

/// 歌单详情页面
class _PlaylistDetailPage extends ConsumerStatefulWidget {
  final Playlist playlist;
  
  const _PlaylistDetailPage({required this.playlist});
  
  @override
  ConsumerState<_PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends ConsumerState<_PlaylistDetailPage> {
  @override
  void initState() {
    super.initState();
    // 加载歌单详情
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(multiPlatformPlaylistServiceProvider).getPlaylistDetail(widget.playlist.id);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final service = ref.watch(multiPlatformPlaylistServiceProvider);
    final tracks = service.currentTracks;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.purple.shade900, Colors.indigo.shade900]
                : [Colors.purple.shade100, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.playlist.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.sync_rounded,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      onPressed: () => _syncPlaylist(),
                    ),
                  ],
                ),
              ),
              
              // 歌曲列表
              Expanded(
                child: tracks.isEmpty
                    ? Center(
                        child: service.isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                '暂无歌曲',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tracks.length,
                        itemBuilder: (context, index) {
                          final track = tracks[index];
                          return _buildTrackItem(track, index, isDarkMode);
                        },
                      ),
              ),
              
              // 底部操作栏
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _playAll(),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('播放全部'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _syncPlaylist(),
                        icon: const Icon(Icons.sync_rounded),
                        label: const Text('同步歌单'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTrackItem(PlaylistTrack track, int index, bool isDarkMode) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isDarkMode ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
          child: track.coverUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    track.coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.music_note_rounded,
                      color: isDarkMode ? Colors.white54 : Colors.black45,
                    ),
                  ),
                )
              : Icon(
                  Icons.music_note_rounded,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
        ),
        title: Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          '${track.artist} - ${track.album ?? ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.black45,
          ),
        ),
        trailing: Text(
          track.durationFormatted,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white38 : Colors.black38,
          ),
        ),
        onTap: () => _playTrack(track),
      ),
    );
  }
  
  void _playAll() {
    // TODO: 播放全部
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('播放全部功能开发中...')),
    );
  }
  
  void _playTrack(PlaylistTrack track) {
    // TODO: 播放歌曲
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('播放: ${track.title}')),
    );
  }
  
  void _syncPlaylist() {
    // TODO: 同步歌单到本地
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('同步歌单: ${widget.playlist.name}')),
    );
  }
}
