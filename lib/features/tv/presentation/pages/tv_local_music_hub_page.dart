import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/theme/theme_provider.dart';
import '../../../files/data/models/track.dart';
import '../../../files/presentation/providers/file_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/service/audio_player_service.dart';
import '../../../../core/providers/unified_tracks_provider.dart';
import '../../../../core/providers/player_integration_provider.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import 'tv_file_browser.dart';
import 'tv_folder_tracks_page.dart';
import 'tv_local_music_page.dart';
import 'tv_player_page.dart';
import '../../../beautify/presentation/pages/tv_beautify_page.dart';
import '../../../beautify/providers/beautify_provider.dart';

/// TV 本地音乐中心页面 — 文件夹视图
///
/// 功能：
/// - 按文件夹分组显示本地音乐
/// - 统计信息（文件夹数、歌曲总数）
/// - 重新扫描（跳转文件管理器）
/// - 随机播放全部
/// - 遥控器全操作支持
class TVLocalMusicHubPage extends ConsumerStatefulWidget {
  const TVLocalMusicHubPage({super.key});

  @override
  ConsumerState<TVLocalMusicHubPage> createState() => _TVLocalMusicHubPageState();
}

class _TVLocalMusicHubPageState extends ConsumerState<TVLocalMusicHubPage> {
  int _focusIndex = 0;
  final FocusNode _rootFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const int _actionCount = 4; // 操作按钮数量（全部歌曲、扫描、随机播放、元数据修复）

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

  int _getMaxIndex() {
    final folders = ref.read(unifiedTracksByFolderProvider);
    return _actionCount + folders.length - 1;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final maxIndex = _getMaxIndex();

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex--);
        _scrollToFocused();
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < maxIndex) {
        setState(() => _focusIndex++);
        _scrollToFocused();
      }
    } else if (key == LogicalKeyboardKey.enter ||
               key == LogicalKeyboardKey.select ||
               key == LogicalKeyboardKey.gameButtonA) {
      _activateItem(_focusIndex);
    } else if (key == LogicalKeyboardKey.escape ||
               key == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
    }
  }

  void _scrollToFocused() {
    if (!_scrollController.hasClients) return;
    final adapter = TvScreenAdapter.of(context);
    final itemHeight = 120.0 * adapter.scale;
    final position = _scrollController.position;

    final itemTop = _focusIndex * itemHeight;
    final itemBottom = itemTop + itemHeight;
    final viewportTop = position.pixels;
    final viewportBottom = position.pixels + position.viewportDimension;

    const margin = 60.0;
    double targetOffset = position.pixels;

    if (itemTop < viewportTop + margin) {
      targetOffset = (itemTop - margin).clamp(0.0, position.maxScrollExtent);
    } else if (itemBottom > viewportBottom - margin) {
      targetOffset = (itemBottom - position.viewportDimension + margin)
          .clamp(0.0, position.maxScrollExtent);
    } else {
      return;
    }

    _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
  }

  void _activateItem(int index) {
    final tracks = ref.read(unifiedTracksProvider);
    final folders = ref.read(unifiedTracksByFolderProvider);
    final folderPaths = folders.keys.toList();

    if (index == 0) {
      // 查看全部歌曲
      if (tracks.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TVLocalMusicPage()),
        );
      }
    } else if (index == 1) {
      // 重新扫描
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TVFileBrowser()),
      );
    } else if (index == 2) {
      // 随机播放全部
      if (tracks.isNotEmpty) {
        final shuffled = List<Track>.from(tracks)..shuffle();
        final audioService = ref.read(audioPlayerServiceProvider);
        audioService.playTrack(shuffled.first, playlist: shuffled);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TVPlayerPage()),
        );
      }
    } else if (index == 3) {
      // 元数据修复
      if (tracks.isNotEmpty) {
        final beautifyNotifier = ref.read(beautifyProvider.notifier);
        final paths = tracks.map((t) => t.filePath).toList();
        beautifyNotifier.addFromPaths(paths);
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TvBeautifyPage()),
        );
      }
    } else {
      // 点击文件夹 → 进入文件夹内歌曲列表
      final folderIndex = index - _actionCount;
      if (folderIndex < folderPaths.length) {
        final folderPath = folderPaths[folderIndex];
        final folderTracks = folders[folderPath]!;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TVFolderTracksPage(
              folderPath: folderPath,
              tracks: folderTracks,
              allTracks: tracks,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(themeProvider);
    final isDark = themeConfig.themeMode == AppThemeMode.dark;
    final adapter = TvScreenAdapter.of(context);
    final scale = adapter.scale;
    final tracks = ref.watch(unifiedTracksProvider);
    final folders = ref.watch(unifiedTracksByFolderProvider);
    final primaryColor = Theme.of(context).primaryColor;
    // 确保 NAS 播放器集成已注册
    ref.watch(playerIntegrationProvider);

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
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
                          color: primaryColor.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          Icons.folder_open_rounded,
                          size: 36 * scale,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(width: 16 * scale),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '本地音乐',
                              style: TextStyle(
                                fontSize: 36 * scale,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            Text(
                              tracks.isEmpty
                                  ? '暂无歌曲，请扫描音乐文件'
                                  : '${folders.length} 个文件夹 · ${tracks.length} 首歌曲',
                              style: TextStyle(
                                fontSize: 20 * scale,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (tracks.isNotEmpty)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * scale,
                            vertical: 10 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Text(
                            '${tracks.length} 首',
                            style: TextStyle(
                              fontSize: 20 * scale,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // === 内容区域 ===
                Expanded(
                  child: tracks.isEmpty
                      ? _buildEmptyState(scale, isDark, primaryColor)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.all(24 * scale),
                          itemCount: _actionCount + folders.length as int,
                          itemBuilder: (context, index) {
                            if (index < _actionCount) {
                              return _buildActionItem(index, scale, isDark, primaryColor, tracks.length);
                            }
                            return _buildFolderItem(index - _actionCount, folders, scale, isDark, primaryColor);
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
                      _buildKeyHint(Icons.check_circle, '确认', scale, isDark),
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

  Widget _buildEmptyState(double scale, bool isDark, Color primaryColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.music_off_rounded,
            size: 120 * scale,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          SizedBox(height: 32 * scale),
          Text(
            '暂无本地音乐',
            style: TextStyle(
              fontSize: 36 * scale,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          SizedBox(height: 16 * scale),
          Text(
            '点击下方按钮扫描音乐文件',
            style: TextStyle(
              fontSize: 24 * scale,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          SizedBox(height: 48 * scale),
          TVFocusCard(
            width: 320 * scale,
            height: 80 * scale,
            focusColor: primaryColor,
            borderRadius: 24,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TVFileBrowser()),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_rounded, size: 36 * scale, color: primaryColor),
                SizedBox(width: 12 * scale),
                Text(
                  '扫描音乐',
                  style: TextStyle(
                    fontSize: 28 * scale,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(int index, double scale, bool isDark, Color primaryColor, int trackCount) {
    final isFocused = index == _focusIndex;

    IconData icon;
    String title;
    String subtitle;

    switch (index) {
      case 0:
        icon = Icons.list_rounded;
        title = '全部歌曲';
        subtitle = '查看 $trackCount 首歌曲列表';
        break;
      case 1:
        icon = Icons.folder_open_rounded;
        title = '扫描音乐';
        subtitle = '重新选择文件夹扫描';
        break;
      case 2:
        icon = Icons.shuffle_rounded;
        title = '随机播放全部';
        subtitle = trackCount > 0 ? '随机播放 $trackCount 首歌曲' : '暂无歌曲';
        break;
      case 3:
        icon = Icons.auto_fix_high_rounded;
        title = '元数据修复';
        subtitle = trackCount > 0 ? '智能识别并修复 $trackCount 首歌曲信息' : '暂无歌曲';
        break;
      default:
        icon = Icons.help_outline;
        title = '';
        subtitle = '';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 16 * scale),
      child: TVFocusCard(
        width: double.infinity,
        height: 120 * scale,
        focusColor: primaryColor,
        borderRadius: 20,
        onTap: () => _activateItem(index),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32 * scale),
          child: Row(
            children: [
              Container(
                width: 64 * scale,
                height: 64 * scale,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isFocused
                      ? primaryColor.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]),
                ),
                child: Icon(icon, size: 32 * scale,
                  color: isFocused ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              SizedBox(width: 24 * scale),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 28 * scale,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 20 * scale,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 36 * scale,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderItem(int listIndex, Map<String, List<Track>> folders, double scale, bool isDark, Color primaryColor) {
    final actualIndex = listIndex + _actionCount;
    final isFocused = actualIndex == _focusIndex;
    final folderPaths = folders.keys.toList();
    final folderPath = folderPaths[listIndex];
    final folderTracks = folders[folderPath]!;
    final folderName = p.basename(folderPath);

    // 提取父路径用于显示
    final parentPath = p.dirname(folderPath);
    final parentName = p.basename(parentPath);

    return Padding(
      padding: EdgeInsets.only(bottom: 8 * scale),
      child: TVFocusCard(
        width: double.infinity,
        height: 100 * scale,
        focusColor: primaryColor,
        borderRadius: 16,
        onTap: () => _activateItem(actualIndex),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24 * scale),
          child: Row(
            children: [
              // 文件夹图标
              Container(
                width: 56 * scale,
                height: 56 * scale,
                decoration: BoxDecoration(
                  color: isFocused
                      ? Colors.orange.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.orange.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.folder_rounded,
                  size: 30 * scale,
                  color: isFocused ? Colors.orange : (isDark ? Colors.orange.withValues(alpha: 0.7) : Colors.orange),
                ),
              ),
              SizedBox(width: 20 * scale),
              // 文件夹名称和路径
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folderName,
                      style: TextStyle(
                        fontSize: 24 * scale,
                        fontWeight: isFocused ? FontWeight.bold : FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4 * scale),
                    Text(
                      '$parentName/ · ${folderTracks.length} 首歌曲',
                      style: TextStyle(
                        fontSize: 18 * scale,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 歌曲数量角标
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 14 * scale,
                  vertical: 6 * scale,
                ),
                decoration: BoxDecoration(
                  color: isFocused
                      ? primaryColor.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${folderTracks.length}',
                  style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w600,
                    color: isFocused ? primaryColor : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ),
              SizedBox(width: 12 * scale),
              Icon(
                Icons.chevron_right_rounded,
                size: 32 * scale,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ],
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
