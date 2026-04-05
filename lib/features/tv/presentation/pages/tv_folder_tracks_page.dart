import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/theme_provider.dart';
import '../../../files/data/models/track.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/service/audio_player_service.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import 'tv_player_page.dart';

/// TV 文件夹内歌曲列表页面
///
/// 功能：
/// - 显示指定文件夹下的所有歌曲
/// - 遥控器方向键导航
/// - 确认键播放
/// - 返回键返回文件夹列表
class TVFolderTracksPage extends ConsumerStatefulWidget {
  final String folderPath;
  final List<Track> tracks;
  final List<Track> allTracks; // 全部歌曲，用于设置完整播放列表

  const TVFolderTracksPage({
    super.key,
    required this.folderPath,
    required this.tracks,
    required this.allTracks,
  });

  @override
  ConsumerState<TVFolderTracksPage> createState() => _TVFolderTracksPageState();
}

class _TVFolderTracksPageState extends ConsumerState<TVFolderTracksPage> {
  int _focusIndex = 0;
  final FocusNode _rootFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex--);
        _scrollToFocused();
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < widget.tracks.length - 1) {
        setState(() => _focusIndex++);
        _scrollToFocused();
      }
    } else if (key == LogicalKeyboardKey.enter ||
               key == LogicalKeyboardKey.select ||
               key == LogicalKeyboardKey.gameButtonA) {
      if (_focusIndex >= 0 && _focusIndex < widget.tracks.length) {
        _playTrack(widget.tracks[_focusIndex]);
      }
    } else if (key == LogicalKeyboardKey.escape ||
               key == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToFocused() {
    if (!_scrollController.hasClients) return;
    if (_focusIndex < 0 || _focusIndex >= widget.tracks.length) return;

    const itemHeight = 88.0;
    final position = _scrollController.position;

    final itemTop = _focusIndex * itemHeight;
    final itemBottom = itemTop + itemHeight;
    final viewportTop = position.pixels;
    final viewportBottom = position.pixels + position.viewportDimension;

    const margin = itemHeight * 2;
    double targetOffset = position.pixels;

    if (itemTop < viewportTop + margin) {
      targetOffset = (itemTop - margin).clamp(0.0, position.maxScrollExtent);
    } else if (itemBottom > viewportBottom - margin) {
      targetOffset = (itemBottom - position.viewportDimension + margin)
          .clamp(0.0, position.maxScrollExtent);
    } else {
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
    );
  }

  void _playTrack(Track track) {
    final audioService = ref.read(audioPlayerServiceProvider);
    // 使用当前文件夹的歌曲作为播放列表
    audioService.playTrack(track, playlist: widget.tracks);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TVPlayerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(themeProvider);
    final isDark = themeConfig.themeMode == AppThemeMode.dark;
    final adapter = TvScreenAdapter.of(context);
    final scale = adapter.scale;
    final primaryColor = Theme.of(context).primaryColor;
    final folderName = p.basename(widget.folderPath);

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.grey[100],
          body: SafeArea(
            child: Column(
              children: [
                // === 顶部标题栏 ===
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 48 * scale,
                    vertical: 24 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back,
                          size: 32 * scale,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      Container(
                        padding: EdgeInsets.all(16 * scale),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.folder_rounded,
                          size: 32 * scale,
                          color: Colors.orange,
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              folderName,
                              style: TextStyle(
                                fontSize: 32 * scale,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.tracks.length} 首歌曲',
                              style: TextStyle(
                                fontSize: 18 * scale,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 播放全部按钮
                      TVFocusCard(
                        width: 160 * scale,
                        height: 52 * scale,
                        focusColor: primaryColor,
                        borderRadius: 26,
                        onTap: () {
                          if (widget.tracks.isNotEmpty) {
                            final audioService = ref.read(audioPlayerServiceProvider);
                            audioService.playTrack(widget.tracks.first, playlist: widget.tracks);
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TVPlayerPage()),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_circle_rounded, size: 24 * scale, color: isDark ? Colors.white : Colors.black87),
                            SizedBox(width: 8 * scale),
                            Text(
                              '播放全部',
                              style: TextStyle(
                                fontSize: 20 * scale,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // === 歌曲列表 ===
                Expanded(
                  child: widget.tracks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.music_off_rounded,
                                size: 80 * scale,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              SizedBox(height: 16 * scale),
                              Text(
                                '该文件夹暂无歌曲',
                                style: TextStyle(
                                  fontSize: 24 * scale,
                                  color: isDark ? Colors.white54 : Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(16 * scale),
                          itemCount: widget.tracks.length,
                          itemBuilder: (context, index) {
                            final track = widget.tracks[index];
                            final isFocused = index == _focusIndex;

                            return Padding(
                              padding: EdgeInsets.only(bottom: 4 * scale),
                              child: Container(
                                height: 88 * scale,
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : primaryColor.withValues(alpha: 0.1))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isFocused ? primaryColor : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 20 * scale, vertical: 4 * scale),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${index + 1}',
                                        style: TextStyle(
                                          fontSize: 20 * scale,
                                          color: isFocused ? primaryColor : (isDark ? Colors.white38 : Colors.black38),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(width: 12 * scale),
                                      Container(
                                        width: 44 * scale,
                                        height: 44 * scale,
                                        decoration: BoxDecoration(
                                          color: isFocused
                                              ? primaryColor
                                              : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.music_note,
                                          size: 24 * scale,
                                          color: isFocused ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
                                        ),
                                      ),
                                    ],
                                  ),
                                  title: Text(
                                    track.title,
                                    style: TextStyle(
                                      fontSize: 22 * scale,
                                      fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    track.artist,
                                    style: TextStyle(
                                      fontSize: 18 * scale,
                                      color: isDark ? Colors.white54 : Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: isFocused
                                      ? Icon(Icons.play_circle_filled, color: primaryColor, size: 36 * scale)
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // === 底部提示 ===
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 48 * scale,
                    vertical: 16 * scale,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildKeyHint(Icons.arrow_upward, '上下选择', scale, isDark),
                      SizedBox(width: 32 * scale),
                      _buildKeyHint(Icons.check_circle, '确认播放', scale, isDark),
                      SizedBox(width: 32 * scale),
                      _buildKeyHint(Icons.arrow_back, '返回', scale, isDark),
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

  Widget _buildKeyHint(IconData icon, String label, double scale, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24 * scale, color: isDark ? Colors.white54 : Colors.black45),
        SizedBox(width: 8 * scale),
        Text(
          label,
          style: TextStyle(fontSize: 20 * scale, color: isDark ? Colors.white54 : Colors.black45),
        ),
      ],
    );
  }
}
