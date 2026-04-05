import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/custom_source_service.dart';
import '../../data/models/music_source.dart';
import 'custom_source_manager_page.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../files/data/models/track.dart';

/// 自定义音源搜索页面
class CustomSourceSearchPage extends ConsumerStatefulWidget {
  const CustomSourceSearchPage({super.key});

  @override
  ConsumerState<CustomSourceSearchPage> createState() => 
      _CustomSourceSearchPageState();
}

class _CustomSourceSearchPageState 
    extends ConsumerState<CustomSourceSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<MusicSearchResult> _searchResults = [];
  bool _isLoading = false;
  String _currentQuery = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sources = ref.watch(customSourceServiceProvider);
    final enabledSources = sources.where((s) => s.isEnabled).toList();
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.teal.shade900, Colors.indigo.shade900]
                : [Colors.cyan.shade100, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              _buildHeader(isDarkMode),
              
              // 搜索栏
              _buildSearchBar(isDarkMode, enabledSources),
              
              // 搜索结果
              Expanded(
                child: enabledSources.isEmpty
                    ? _buildNoSourceState(isDarkMode)
                    : _buildSearchResults(isDarkMode),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建顶部标题栏
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '搜索音乐',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '从自定义音源搜索音乐',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建搜索栏
  Widget _buildSearchBar(bool isDarkMode, List<MusicSource> enabledSources) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: enabledSources.isEmpty
                          ? '请先导入音源'
                          : '搜索歌曲、歌手、专辑',
                      hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                    ),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _performSearch(value);
                      }
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: isDarkMode ? Colors.cyan.shade300 : Colors.cyan,
                    ),
                    onPressed: _searchController.text.isEmpty
                        ? null
                        : () => _performSearch(_searchController.text),
                  ),
              ],
            ),
          ),
          
          // 启用的音源提示
          if (enabledSources.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Colors.green.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '已启用 ${enabledSources.length} 个音源: ${enabledSources.map((s) => s.name).join(", ")}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// 构建无音源状态
  Widget _buildNoSourceState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_rounded,
            size: 80,
            color: isDarkMode ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无可用音源',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请先导入并启用音源脚本',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // 跳转到音源管理页面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CustomSourceManagerPage(),
                ),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('导入音源'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建搜索结果
  Widget _buildSearchResults(bool isDarkMode) {
    if (_searchResults.isEmpty && _currentQuery.isNotEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到相关音乐',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '尝试更换关键词或音源',
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 80,
              color: isDarkMode ? Colors.white24 : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              '搜索你喜欢的音乐',
              style: TextStyle(
                fontSize: 18,
                color: isDarkMode ? Colors.white54 : Colors.black45,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSourceResultSection(result, isDarkMode);
      },
    );
  }
  
  /// 构建音源结果区块
  Widget _buildSourceResultSection(
    MusicSearchResult result,
    bool isDarkMode,
  ) {
    final source = ref.read(customSourceServiceProvider)
        .firstWhere((s) => s.id == result.sourceId);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 音源标题
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.cyan.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.library_music_rounded,
                      size: 16,
                      color: isDarkMode ? Colors.cyan.shade300 : Colors.cyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      source.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.cyan.shade300 : Colors.cyan,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${result.list.length}首)',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // 歌曲列表
        ...result.list.map((music) => _buildMusicCard(music, isDarkMode, source)),
        
        const SizedBox(height: 24),
      ],
    );
  }
  
  /// 构建音乐卡片
  Widget _buildMusicCard(
    MusicInfo music,
    bool isDarkMode,
    MusicSource source,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        onTap: () => _playMusic(music, source),
        child: Row(
          children: [
            // 封面
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.white.withValues(alpha: 0.1) 
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: music.img != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        music.img!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.music_note_rounded,
                            color: isDarkMode ? Colors.white38 : Colors.black38,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.music_note_rounded,
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    music.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    music.singer,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (music.album != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      music.album!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // 时长
            if (music.interval != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _formatDuration(music.interval!),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
            
            // 播放按钮
            IconButton(
              icon: Icon(
                Icons.play_circle_outline_rounded,
                color: isDarkMode ? Colors.cyan.shade300 : Colors.cyan,
                size: 32,
              ),
              onPressed: () => _playMusic(music, source),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 格式化时长
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
  
  /// 执行搜索
  Future<void> _performSearch(String keyword) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _currentQuery = keyword;
    });
    
    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      final results = await service.searchMusic(keyword);
      
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('搜索失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// 播放音乐
  Future<void> _playMusic(MusicInfo music, MusicSource source) async {
    // 显示加载提示
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('获取播放链接: ${music.name}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      // 获取当前音源支持的第一个平台
      final initResult = service.getSourceInitResult(source.id);
      final platform = initResult?.sources.keys.first ?? 'local';

      final urlInfo = await service.getMusicUrl(
        source.id,
        music.id,
        '128k',
        sourceKey: platform,
        musicInfo: {'id': music.id, 'songId': music.id ?? ''},
      );

      if (urlInfo == null || urlInfo.url.isEmpty) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('无法获取播放链接，请检查音源'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 构建播放列表（全部搜索结果）
      final allSongs = _searchResults.expand((r) => r.list).toList();
      final playlistTracks = allSongs.map((s) => Track(
        id: s.id,
        title: s.name,
        artist: s.singer,
        album: s.album ?? '',
        filePath: '', // 占位，点击时再获取
        duration: Duration(seconds: s.interval ?? 0),
        albumArt: s.img,
      )).toList();

      // 当前曲目使用已获取的URL
      final currentTrack = Track(
        id: music.id,
        title: music.name,
        artist: music.singer,
        album: music.album ?? '',
        filePath: urlInfo.url,
        duration: Duration(seconds: music.interval ?? 0),
        albumArt: music.img,
      );

      final audioService = ref.read(audioPlayerServiceProvider);
      await audioService.playTrack(currentTrack, playlist: playlistTracks);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('正在播放: ${music.name} - ${music.singer}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
