import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../files/data/models/track.dart';
import '../../../files/presentation/providers/file_provider.dart';
import '../../../files/service/file_service.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/service/audio_player_service.dart';
import '../../../../core/providers/unified_tracks_provider.dart';
import '../../../../core/providers/player_integration_provider.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import 'tv_player_page.dart';

/// TV 本地音乐页面 - 支持遥控器操作
/// 
/// 功能：
/// - 显示已扫描的音乐列表
/// - 方向键导航
/// - 确认键播放
/// - 返回键退出应用
class TVLocalMusicPage extends ConsumerStatefulWidget {
  const TVLocalMusicPage({super.key});

  @override
  ConsumerState<TVLocalMusicPage> createState() => _TVLocalMusicPageState();
}

class _TVLocalMusicPageState extends ConsumerState<TVLocalMusicPage> {
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

  void _handleKey(KeyEvent event, List<Track> tracks) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex--);
        _scrollToFocusedItem();
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < tracks.length - 1) {
        setState(() => _focusIndex++);
        _scrollToFocusedItem();
      }
    } else if (key == LogicalKeyboardKey.enter || 
               key == LogicalKeyboardKey.select ||
               key == LogicalKeyboardKey.gameButtonA) {
      if (_focusIndex >= 0 && _focusIndex < tracks.length) {
        _playTrack(tracks[_focusIndex]);
      }
    } else if (key == LogicalKeyboardKey.escape || 
               key == LogicalKeyboardKey.goBack) {
      // 返回键返回上一页
      Navigator.of(context).pop();
    }
  }

  void _scrollToFocusedItem() {
    if (!_scrollController.hasClients) return;

    final tracks = ref.read(unifiedTracksProvider);
    if (_focusIndex < 0 || _focusIndex >= tracks.length) return;

    final position = _scrollController.position;
    const itemHeight = 88.0; // 80 + 8 (margin)

    // 当前选中项的像素位置
    final itemTop = _focusIndex * itemHeight;
    final itemBottom = itemTop + itemHeight;

    // 可视区域范围
    final viewportTop = position.pixels;
    final viewportBottom = position.pixels + position.viewportDimension;

    // 保持至少可见 2 行的边距
    const margin = itemHeight * 2;

    double targetOffset = position.pixels;

    if (itemTop < viewportTop + margin) {
      // 选中项在可视区域上方 — 向上滚，让选中项出现在顶部偏下位置
      targetOffset = (itemTop - margin).clamp(0.0, position.maxScrollExtent);
    } else if (itemBottom > viewportBottom - margin) {
      // 选中项在可视区域下方 — 向下滚，让选中项出现在底部偏上位置
      targetOffset = (itemBottom - position.viewportDimension + margin)
          .clamp(0.0, position.maxScrollExtent);
    } else {
      // 选中项已经在可视区域内，不滚动
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
    final tracks = ref.read(unifiedTracksProvider);
    
    // 找到当前曲目在列表中的索引
    final trackIndex = tracks.indexWhere((t) => t.id == track.id);
    if (trackIndex >= 0) {
      // 设置播放列表并播放指定曲目
      audioService.setPlaylist(tracks);
      audioService.playTrack(track);
      
      // 跳转到TV播放器页面
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TVPlayerPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fileService = ref.watch(fileServiceProvider);
    final scanResult = ref.watch(scanResultProvider);
    final tracks = ref.watch(unifiedTracksProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 确保 NAS 播放器集成已注册
    ref.watch(playerIntegrationProvider);

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (event) => _handleKey(event, tracks),
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
              // === 顶部标题栏 ==========================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
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
                      onPressed: () => SystemNavigator.pop(),
                      icon: Icon(
                        Icons.arrow_back,
                        size: 28,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.music_note_rounded,
                      size: 32,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '本地音乐',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    // 歌曲数量
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${tracks.length} 首',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // === 音乐列表 ============================================================
              Expanded(
                child: _buildContent(tracks, scanResult, isDark),
              ),

              // === 底部提示 ============================================================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildKeyHint(Icons.arrow_upward, '上下选择', isDark),
                    const SizedBox(width: 32),
                    _buildKeyHint(Icons.check_circle, '确认播放', isDark),
                    const SizedBox(width: 32),
                    _buildKeyHint(Icons.arrow_back, '返回退出', isDark),
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

  Widget _buildContent(List<Track> tracks, ScanResult scanResult, bool isDark) {
    if (scanResult.isScanning && tracks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载音乐...', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 80,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
            const SizedBox(height: 24),
            Text(
              '暂无音乐',
              style: TextStyle(
                fontSize: 24,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请返回主页扫描音乐文件',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        final isFocused = index == _focusIndex;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          decoration: BoxDecoration(
            color: isFocused
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isFocused
                    ? Theme.of(context).primaryColor
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.music_note,
                color: isFocused ? Colors.white : (isDark ? Colors.white54 : Colors.black45),
              ),
            ),
            title: Text(
              track.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              track.artist,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: isFocused
                ? Icon(
                    Icons.play_circle_filled,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildKeyHint(IconData icon, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}
