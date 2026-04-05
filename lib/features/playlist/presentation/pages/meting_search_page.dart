import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';
import 'package:wuaimusic/features/playlist/providers/meting_provider.dart';
import 'package:wuaimusic/features/playlist/presentation/pages/meting_playlist_detail_page.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Meting 歌单搜索页面
class MetingSearchPage extends ConsumerStatefulWidget {
  const MetingSearchPage({super.key});

  @override
  ConsumerState<MetingSearchPage> createState() => _MetingSearchPageState();
}

class _MetingSearchPageState extends ConsumerState<MetingSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // 初始化时检查连接
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(metingPlaylistActionsProvider).checkConnection();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _performSearch() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    ref.read(metingPlaylistActionsProvider).searchPlaylists(keyword).then((_) {
      setState(() {
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(playlistSearchResultsProvider);
    final searchHistory = ref.watch(searchHistoryProvider);
    final searchState = ref.watch(searchStateProvider);
    final isConnected = ref.watch(metingConnectionStateProvider);
    final platforms = ref.watch(supportedPlatformsProvider);
    final currentPlatform = ref.watch(currentPlatformProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索歌单'),
        actions: [
          // 平台切换按钮
          PopupMenuButton<String>(
            icon: Icon(
              _getPlatformIcon(currentPlatform),
            ),
            tooltip: '选择平台',
            onSelected: (platform) {
              ref.read(metingPlaylistActionsProvider).switchPlatform(platform);
            },
            itemBuilder: (context) {
              return platforms
                  .where((p) => p['enabled'] == true)
                  .map((platform) {
                return PopupMenuItem<String>(
                  value: platform['code'] as String,
                  child: Row(
                    children: [
                      Icon(_getPlatformIcon(platform['code'] as String), size: 20),
                      const SizedBox(width: 8),
                      Text(platform['name'] as String),
                      if (platform['code'] == currentPlatform)
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: Icon(Icons.check, size: 16),
                        ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
          // 连接状态指示器
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              isConnected ? Icons.cloud_done : Icons.cloud_off,
              color: isConnected ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: '搜索歌单、歌曲、艺人...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _performSearch(),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // 搜索历史（如果没有搜索）
          if (searchResults.isEmpty && searchHistory.isNotEmpty && !_isSearching)
            _buildSearchHistory(searchHistory),

          // 搜索结果
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : searchResults.isEmpty && _searchController.text.isNotEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              '未找到相关歌单',
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _getPlatformIcon(currentPlatform),
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '在 ${_getPlatformName(currentPlatform)} 搜索歌单',
                                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _performSearch,
                                  icon: const Icon(Icons.search),
                                  label: const Text('搜索'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final playlist = searchResults[index];
                              return _buildPlaylistItem(playlist);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory(List<String> history) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  ref.read(metingPlaylistActionsProvider).clearSearchHistory();
                },
                child: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: history.map((keyword) {
              return Chip(
                label: Text(keyword),
                onDeleted: () {
                  ref.read(metingPlaylistActionsProvider).removeFromSearchHistory(keyword);
                },
                deleteIcon: const Icon(Icons.close, size: 16),
                avatar: const Icon(Icons.history, size: 16),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(MetingPlaylistDetail playlist) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: playlist.pic != null
            ? Image.network(
                playlist.pic!,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
                  );
                },
              )
            : Container(
                width: 56,
                height: 56,
                color: Colors.grey[300],
                child: const Icon(Icons.music_note),
              ),
      ),
      title: Text(
        playlist.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${playlist.artist} · ${playlist.songs.length} 首歌曲',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MetingPlaylistDetailPage(
              playlistId: playlist.id,
              platform: playlist.platform,
            ),
          ),
        );
      },
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'netease':
        return PhosphorIcons.musicNotesSimple();
      case 'tencent':
        return PhosphorIcons.musicNote();
      case 'kugou':
        return PhosphorIcons.musicNotes();
      case 'kuwo':
        return PhosphorIcons.playCircle();
      default:
        return PhosphorIcons.musicNotesSimple();
    }
  }

  String _getPlatformName(String platform) {
    final platforms = ref.read(supportedPlatformsProvider);
    final p = platforms.firstWhere((p) => p['code'] == platform, orElse: () => {'name': '未知'});
    return p['name'] as String;
  }
}
