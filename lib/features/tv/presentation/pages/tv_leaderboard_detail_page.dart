import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import '../../../playlist/services/qq_music_leaderboard_service.dart';
import '../../../custom_source/services/custom_source_service.dart';
import '../../../custom_source/data/models/music_source.dart';

/// TV版榜单详情页面
class TvLeaderboardDetailPage extends ConsumerStatefulWidget {
  final UnifiedLeaderboard leaderboard;

  const TvLeaderboardDetailPage({super.key, required this.leaderboard});

  @override
  ConsumerState<TvLeaderboardDetailPage> createState() => _TvLeaderboardDetailPageState();
}

class _TvLeaderboardDetailPageState extends ConsumerState<TvLeaderboardDetailPage> {
  final _focusNode = FocusNode();
  List<UnifiedSong> _songs = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _focusIndex = 0;
  int _playMode = 0; // 0: 播放选中, 1: 播放全部

  @override
  void initState() {
    super.initState();
    _loadSongs();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadSongs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<UnifiedSong> songs = [];
      
      if (widget.leaderboard.sourceType == LeaderboardSourceType.netease) {
        final service = ref.read(neteaseLeaderboardServiceProvider);
        final detail = await service.getLeaderboardDetail(widget.leaderboard.id);
        if (detail != null) {
          songs = detail.tracks.map((song) => UnifiedSong.fromNetease(song)).toList();
        }
      } else if (widget.leaderboard.sourceType == LeaderboardSourceType.qq) {
        final qqService = QQMusicLeaderboardService.instance;
        await qqService.initialize();
        final qqSongs = await qqService.getLeaderboardDetail(widget.leaderboard.id);
        songs = qqSongs.map((song) => UnifiedSong.fromQQMusic(song)).toList();
      } else {
        final customService = ref.read(customSourceServiceProvider.notifier);
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
          songs = detail.songs.map((song) => UnifiedSong.fromJsSource(song)).toList();
        }
      }

      setState(() {
        _songs = songs;
        _isLoading = false;
        if (songs.isEmpty) {
          _errorMessage = '暂无歌曲数据';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: $e';
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.of(context).pop();
      return;
    }

    // 上下导航
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_playMode == 0 && _focusIndex > 0) {
        setState(() => _focusIndex--);
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_playMode == 0 && _focusIndex < _songs.length - 1) {
        setState(() => _focusIndex++);
      }
      return;
    }

    // 左右切换模式
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _playMode = _playMode == 0 ? 1 : 0;
        _focusIndex = 0;
      });
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_playMode == 1) {
        _playAll();
      } else {
        _playSong(_focusIndex);
      }
      return;
    }
  }

  void _playSong(int index) {
    if (index < 0 || index >= _songs.length) return;
    
    final song = _songs[index];
    
    // TODO: 调用实际播放器播放
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已选择播放: ${song.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _playAll() {
    if (_songs.isEmpty) return;
    
    // TODO: 调用实际播放器播放全部
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已选择播放全部 ${_songs.length} 首歌曲'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scale = TvScreenAdapter.of(context).scale;
    final isNetease = widget.leaderboard.sourceType == LeaderboardSourceType.netease;
    final isQQ = widget.leaderboard.sourceType == LeaderboardSourceType.qq;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFE8F4FD),
                const Color(0xFFF0F9FF),
                const Color(0xFFF8FAFC),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 顶部标题栏
                Padding(
                  padding: EdgeInsets.all(48 * scale),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 48 * scale,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(width: 24 * scale),
                      Container(
                        width: 80 * scale,
                        height: 80 * scale,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16 * scale),
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        child: widget.leaderboard.coverUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16 * scale),
                                child: Image.network(
                                  widget.leaderboard.coverUrl!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Icon(
                                Icons.leaderboard_rounded,
                                size: 40 * scale,
                                color: Colors.red,
                              ),
                      ),
                      SizedBox(width: 24 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.leaderboard.name,
                              style: TextStyle(
                                fontSize: 36 * scale,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4 * scale),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12 * scale,
                                    vertical: 4 * scale,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isNetease ? Colors.red : isQQ ? Colors.green : Colors.purple,
                                    borderRadius: BorderRadius.circular(8 * scale),
                                  ),
                                  child: Text(
                                    isNetease ? '网易云API' : isQQ ? 'QQ音乐' : 'JS音源',
                                    style: TextStyle(
                                      fontSize: 14 * scale,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12 * scale),
                                Text(
                                  '${_songs.length} 首歌曲',
                                  style: TextStyle(
                                    fontSize: 18 * scale,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 歌曲列表
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: Colors.red),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  fontSize: 24 * scale,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            )
                          : _buildSongList(scale, isDark),
                ),

                // 底部控制栏
                Container(
                  padding: EdgeInsets.all(32 * scale),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                  child: Row(
                    children: [
                      // 播放选中
                      Expanded(
                        child: TVFocusCard(
                          height: 80 * scale,
                          focusColor: _playMode == 0 ? Colors.blue : Colors.transparent,
                          onTap: () {
                            setState(() => _playMode = 0);
                            _playSong(_focusIndex);
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_circle_rounded,
                                  size: 32 * scale,
                                  color: _playMode == 0 ? Colors.blue : (isDark ? Colors.white54 : Colors.black45),
                                ),
                                SizedBox(width: 12 * scale),
                                Text(
                                  '播放选中',
                                  style: TextStyle(
                                    fontSize: 24 * scale,
                                    color: _playMode == 0 ? Colors.blue : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 32 * scale),
                      // 播放全部
                      Expanded(
                        child: TVFocusCard(
                          height: 80 * scale,
                          focusColor: _playMode == 1 ? Colors.blue : Colors.transparent,
                          onTap: () {
                            setState(() => _playMode = 1);
                            _playAll();
                          },
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.queue_music_rounded,
                                  size: 32 * scale,
                                  color: _playMode == 1 ? Colors.blue : (isDark ? Colors.white54 : Colors.black45),
                                ),
                                SizedBox(width: 12 * scale),
                                Text(
                                  '播放全部',
                                  style: TextStyle(
                                    fontSize: 24 * scale,
                                    color: _playMode == 1 ? Colors.blue : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSongList(double scale, bool isDark) {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 48 * scale),
      itemCount: _songs.length,
      itemBuilder: (context, index) {
        final song = _songs[index];
        final isFocused = _playMode == 0 && _focusIndex == index;
        final isPlaying = false; // TODO: 关联播放状态
        
        return TVFocusCard(
          height: 80 * scale,
          focusColor: Colors.blue,
          onTap: () {
            setState(() {
              _playMode = 0;
              _focusIndex = index;
            });
            _playSong(index);
          },
          onFocus: () => setState(() {
            _playMode = 0;
            _focusIndex = index;
          }),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
            decoration: BoxDecoration(
              color: isFocused
                  ? Colors.blue.withValues(alpha: 0.1)
                  : (isDark 
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02)),
              borderRadius: BorderRadius.circular(12 * scale),
            ),
            child: Row(
              children: [
                // 序号
                SizedBox(
                  width: 48 * scale,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 20 * scale,
                      color: isFocused 
                          ? Colors.blue 
                          : (isDark ? Colors.white54 : Colors.black45),
                    ),
                  ),
                ),
                
                // 封面
                Container(
                  width: 56 * scale,
                  height: 56 * scale,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8 * scale),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                  child: song.albumCover != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8 * scale),
                          child: Image.network(
                            song.albumCover!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Icon(
                          Icons.music_note_rounded,
                          size: 24 * scale,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                ),
                
                SizedBox(width: 16 * scale),
                
                // 歌曲信息
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.name,
                        style: TextStyle(
                          fontSize: 22 * scale,
                          fontWeight: FontWeight.w600,
                          color: isFocused 
                              ? Colors.blue 
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        song.artist,
                        style: TextStyle(
                          fontSize: 16 * scale,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // 时长
                Text(
                  _formatDuration(song.duration),
                  style: TextStyle(
                    fontSize: 18 * scale,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
