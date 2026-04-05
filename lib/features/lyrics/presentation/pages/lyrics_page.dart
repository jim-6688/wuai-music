import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../providers/lyric_provider.dart';
import '../../service/lyric_service.dart';
import '../../../player/presentation/providers/player_provider.dart';

// 专辑封面缓存
final _artworkCache = <int, Uint8List>{};

/// 专辑封面组件
class AlbumArtworkWidget extends StatelessWidget {
  final int? songId;
  final double size;
  final double borderRadius;
  final Color? placeholderColor;
  final IconData placeholderIcon;

  const AlbumArtworkWidget({
    super.key,
    this.songId,
    this.size = 200,
    this.borderRadius = 16,
    this.placeholderColor,
    this.placeholderIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    if (songId == null) {
      return _buildPlaceholder(context);
    }

    // 检查缓存
    if (_artworkCache.containsKey(songId)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.memory(
          _artworkCache[songId]!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(context),
        ),
      );
    }

    // 异步加载封面
    return FutureBuilder<Uint8List?>(
      future: _loadArtwork(songId!),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          // 缓存封面
          _artworkCache[songId!] = snapshot.data!;
          return ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: Image.memory(
              snapshot.data!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(context),
            ),
          );
        }
        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: placeholderColor ?? Colors.grey.shade200,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        placeholderIcon,
        size: size * 0.4,
        color: placeholderColor != null 
            ? placeholderColor!.withValues(alpha: 0.5) 
            : Colors.grey.shade400,
      ),
    );
  }

  Future<Uint8List?> _loadArtwork(int songId) async {
    try {
      final onAudioQuery = OnAudioQuery();
      final artwork = await onAudioQuery.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        format: ArtworkFormat.JPEG,
        size: 500,
        quality: 80,
      );
      return artwork;
    } catch (e) {
      debugPrint('⚠️ 获取专辑封面失败: $e');
      return null;
    }
  }
}

class LyricsPage extends ConsumerStatefulWidget {
  const LyricsPage({super.key});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(lyricServiceProvider).loadDemoLyric();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lyricService = ref.watch(lyricServiceProvider);
    final audioService = ref.watch(audioPlayerServiceProvider);
    final currentTrack = audioService.currentTrack;

    // 解析歌曲 ID
    int? songId;
    if (currentTrack?.id != null) {
      songId = int.tryParse(currentTrack!.id);
    }

    return LiquidBackground(
      child: SafeArea(
        child: Column(
          children: [
            // 顶部标题
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '歌词',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GlassButton(
                    onPressed: () {
                      // TODO: 打开歌词搜索
                    },
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            // 歌词内容
            Expanded(
              child: _buildLyricContent(lyricService, currentTrack, songId),
            ),

            // 底部控制
            _buildBottomControls(lyricService),
          ],
        ),
      ),
    );
  }

  Widget _buildLyricContent(
    LyricService lyricService,
    dynamic currentTrack,
    int? songId,
  ) {
    if (lyricService.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载歌词...'),
          ],
        ),
      );
    }

    if (!lyricService.hasLyric) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 专辑封面
            AlbumArtworkWidget(
              songId: songId,
              size: 120,
              borderRadius: 16,
            ),
            const SizedBox(height: 24),
            Text(
              currentTrack?.title ?? '暂无歌词',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              currentTrack?.artist ?? '点击下方按钮加载歌词',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final currentLyric = lyricService.currentLyric!;
    final currentLineIndex = lyricService.currentLineIndex;

    return Column(
      children: [
        // 歌曲信息 + 封面
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              // 专辑封面
              AlbumArtworkWidget(
                songId: songId,
                size: 60,
                borderRadius: 12,
              ),
              const SizedBox(width: 16),
              // 歌曲信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack?.title ?? currentLyric.title ?? '未知歌曲',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentTrack?.artist ?? currentLyric.artist ?? '未知艺术家',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // 歌词列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: currentLyric.lines.length,
            itemBuilder: (context, index) {
              final line = currentLyric.lines[index];
              final isCurrentLine = index == currentLineIndex;
              final isPastLine = index < currentLineIndex;

              return _LyricLineWidget(
                lyricLine: line,
                isCurrentLine: isCurrentLine,
                isPastLine: isPastLine,
                onTap: () {
                  ref.read(lyricServiceProvider).updatePosition(line.timestamp);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(LyricService lyricService) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // 进度条
          if (lyricService.hasLyric)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                    ),
                    child: Slider(
                      value: lyricService.currentPosition,
                      max: 90.0,
                      onChanged: (value) {
                        lyricService.updatePosition(value);
                      },
                      activeColor: Theme.of(context).primaryColor,
                      inactiveColor: Colors.grey.shade300,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTime(lyricService.currentPosition),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        _formatTime(90.0),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded),
                iconSize: 36,
                onPressed: () {
                  final current = lyricService.currentLine;
                  if (current != null && lyricService.previousLine != null) {
                    lyricService.updatePosition(lyricService.previousLine!.timestamp);
                  }
                },
              ),
              GlassButton(
                onPressed: () {
                  // 模拟播放/暂停
                },
                padding: const EdgeInsets.all(16),
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded),
                iconSize: 36,
                onPressed: () {
                  final current = lyricService.currentLine;
                  if (current != null && lyricService.nextLine != null) {
                    lyricService.updatePosition(lyricService.nextLine!.timestamp);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final secs = (seconds % 60).floor();
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

class _LyricLineWidget extends StatelessWidget {
  final dynamic lyricLine;
  final bool isCurrentLine;
  final bool isPastLine;
  final VoidCallback onTap;

  const _LyricLineWidget({
    required this.lyricLine,
    required this.isCurrentLine,
    required this.isPastLine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 当前行：高亮卡片 + 左侧彩条
    if (isCurrentLine) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primaryColor.withValues(alpha: isDark ? 0.45 : 0.30),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // 左侧彩条
                AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: 4,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 280),
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: primaryColor,
                        height: 1.4,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                      child: Text(lyricLine.text, textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 已过去的行：轻度卡片 + 删除线感的渐隐
    if (isPastLine) {
      return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.normal,
              color: isDark ? Colors.white30 : Colors.black26,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
            child: Text(lyricLine.text, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    // 未到的行：简洁无底色，稍微柔和
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: isDark ? Colors.white54 : Colors.black54,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
          child: Text(lyricLine.text, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
