import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/lyrics_provider.dart';
import '../service/lyrics_service.dart';

/// 歌词配色方案（只改文字颜色，不改背景）
class LyricsColorSchemes {
  // 预设的文字配色方案
  static const List<LyricsTextColorScheme> schemes = [
    LyricsTextColorScheme(
      name: '💙 海洋蓝',
      primaryColor: Color(0xFF2196F3),
      highlightColor: Color(0xFF64B5F6),
      pastColor: Color(0xFF64B5F6),
    ),
    LyricsTextColorScheme(
      name: '💜 浪漫紫',
      primaryColor: Color(0xFF9C27B0),
      highlightColor: Color(0xFFCE93D8),
      pastColor: Color(0xFFCE93D8),
    ),
    LyricsTextColorScheme(
      name: '💚 清新青',
      primaryColor: Color(0xFF00BCD4),
      highlightColor: Color(0xFF80DEEA),
      pastColor: Color(0xFF80DEEA),
    ),
    LyricsTextColorScheme(
      name: '🧡 活力橙',
      primaryColor: Color(0xFFFF9800),
      highlightColor: Color(0xFFFFCC80),
      pastColor: Color(0xFFFFCC80),
    ),
    LyricsTextColorScheme(
      name: '💗 少女粉',
      primaryColor: Color(0xFFE91E63),
      highlightColor: Color(0xFFF48FB1),
      pastColor: Color(0xFFF48FB1),
    ),
    LyricsTextColorScheme(
      name: '💚 自然绿',
      primaryColor: Color(0xFF4CAF50),
      highlightColor: Color(0xFF81C784),
      pastColor: Color(0xFF81C784),
    ),
    LyricsTextColorScheme(
      name: '❤️ 热情红',
      primaryColor: Color(0xFFF44336),
      highlightColor: Color(0xFFEF9A9A),
      pastColor: Color(0xFFEF9A9A),
    ),
    LyricsTextColorScheme(
      name: '✨ 金色典',
      primaryColor: Color(0xFFFFD700),
      highlightColor: Color(0xFFFFE082),
      pastColor: Color(0xFFFFE082),
    ),
    LyricsTextColorScheme(
      name: '🌈 彩虹',
      primaryColor: Color(0xFFFF5722),
      highlightColor: Color(0xFFFFEB3B),
      pastColor: Color(0xFF4CAF50),
    ),
    LyricsTextColorScheme(
      name: '🌌 极光',
      primaryColor: Color(0xFF00FF88),
      highlightColor: Color(0xFF00BFFF),
      pastColor: Color(0xFF00BFFF),
    ),
  ];
}

class LyricsTextColorScheme {
  final String name;
  final Color primaryColor;   // 当前歌词颜色
  final Color highlightColor; // 卡拉OK高亮
  final Color pastColor;     // 已唱过歌词

  const LyricsTextColorScheme({
    required this.name,
    required this.primaryColor,
    required this.highlightColor,
    required this.pastColor,
  });
}

/// 歌词行距配置
class LyricsLineSpacingNotifier extends StateNotifier<double> {
  LyricsLineSpacingNotifier() : super(8.0); // 默认行距

  void setSpacing(double spacing) {
    state = spacing.clamp(2.0, 20.0);
  }

  void increase() {
    state = (state + 1).clamp(2.0, 20.0);
  }

  void decrease() {
    state = (state - 1).clamp(2.0, 20.0);
  }
}

final lyricsLineSpacingProvider =
    StateNotifierProvider<LyricsLineSpacingNotifier, double>((ref) {
  return LyricsLineSpacingNotifier();
});

/// 歌词文字大小配置
class LyricsFontSizeNotifier extends StateNotifier<double> {
  LyricsFontSizeNotifier() : super(18.0); // 默认字号

  void setSize(double size) {
    state = size.clamp(14.0, 36.0);
  }

  void increase() {
    state = (state + 1).clamp(14.0, 36.0);
  }

  void decrease() {
    state = (state - 1).clamp(14.0, 36.0);
  }
}

final lyricsFontSizeProvider =
    StateNotifierProvider<LyricsFontSizeNotifier, double>((ref) {
  return LyricsFontSizeNotifier();
});

class LyricsTextColorNotifier extends StateNotifier<int> {
  LyricsTextColorNotifier() : super(0);

  void setScheme(int index) {
    if (index >= 0 && index < LyricsColorSchemes.schemes.length) {
      state = index;
    }
  }

  void nextScheme() {
    state = (state + 1) % LyricsColorSchemes.schemes.length;
  }

  LyricsTextColorScheme get currentScheme => LyricsColorSchemes.schemes[state];
}

final lyricsTextColorProvider =
    StateNotifierProvider<LyricsTextColorNotifier, int>((ref) {
  return LyricsTextColorNotifier();
});

/// 全屏歌词显示组件
///
/// 核心设计：
/// - 固定行高（lineHeight），所有歌词行等高，精确计算滚动偏移
/// - 使用 Stack + Positioned 实现绝对定位的高亮背景条
/// - 中心点偏移：高亮行固定在容器可视区域的指定比例位置
/// - LayoutBuilder 处理容器尺寸变化（类似 window resize）
class LyricsViewer extends ConsumerStatefulWidget {
  final Duration currentPosition;
  final bool isDarkMode;
  final VoidCallback? onTap;

  /// 高亮行固定在歌词可见区域的位置比例 (0.0=顶部, 0.5=中间, 1.0=底部)
  final double fixedHighlightPosition;

  /// 固定行高（类似 CSS line-height），默认 30
  final double lineHeight;

  const LyricsViewer({
    super.key,
    required this.currentPosition,
    required this.isDarkMode,
    this.onTap,
    this.fixedHighlightPosition = 0.35,
    this.lineHeight = 30.0,
  });

  @override
  ConsumerState<LyricsViewer> createState() => _LyricsViewerState();
}

class _LyricsViewerState extends ConsumerState<LyricsViewer> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(LyricsViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scrollToCurrentLyric();
  }

  void _scrollToCurrentLyric() {
    final lyricsService = ref.read(lyricsServiceProvider);
    final currentIndex = lyricsService.currentIndex;

    if (currentIndex < 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final lyrics = lyricsService.lyrics;
      if (currentIndex >= lyrics.length) return;

      final lineHeight = widget.lineHeight;
      final highlightRatio = widget.fixedHighlightPosition;

      // 可视区域高度
      final viewportHeight = _scrollController.position.viewportDimension;

      // 滚动目标计算：
      // 高亮行的中心应该出现在 viewportHeight * highlightRatio 的位置
      // scrollOffset = currentIndex * lineHeight + lineHeight/2 - viewportHeight * highlightRatio
      final targetOffset = currentIndex * lineHeight + (lineHeight / 2) - (viewportHeight * highlightRatio);

      // 边界限制
      final maxScroll = _scrollController.position.maxScrollExtent;
      final clampedTarget = targetOffset.clamp(0.0, maxScroll);

      _animateTo(clampedTarget, currentIndex);
    });
  }

  void _animateTo(double target, int currentIndex) {
    final currentScroll = _scrollController.offset;
    final diff = (target - currentScroll).abs();

    if (diff > 2) {
      // 根据距离动态调整动画时长
      final baseDuration = (diff / 100 * 300).round();
      final clampedDuration = baseDuration.clamp(200, 800);

      _scrollController.animateTo(
        target,
        duration: Duration(milliseconds: clampedDuration),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsService = ref.watch(lyricsServiceProvider);
    final colorIndex = ref.watch(lyricsTextColorProvider);
    final colorScheme = LyricsColorSchemes.schemes[colorIndex];
    final userFontSize = ref.watch(lyricsFontSizeProvider);
    final globalTextScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final baseFontSize = userFontSize * globalTextScaleFactor;
    lyricsService.updateCurrentLyric(widget.currentPosition);

    // 根据是否暗色模式设置歌词颜色
    final currentTextColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final pastTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;
    final futureTextColor = widget.isDarkMode ? Colors.white60 : Colors.black38;

    if (!lyricsService.hasLyrics) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 64,
                color: colorScheme.primaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                lyricsService.errorMessage ?? '播放音乐自动搜索歌词',
                style: TextStyle(
                  fontSize: baseFontSize,
                  color: currentTextColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lyrics = lyricsService.lyrics;
    final currentIndex = lyricsService.currentIndex;
    final lineHeight = widget.lineHeight;

    return GestureDetector(
      onTap: widget.onTap,
      child: ListView.builder(
        controller: _scrollController,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: lyrics.length,
        itemExtent: lineHeight, // 强制固定行高
        itemBuilder: (context, index) {
          final lyric = lyrics[index];
          final isCurrent = index == currentIndex;
          final isPast = index < currentIndex;

          // 高亮行背景直接在 item 内渲染，避免 Positioned 定位问题
          final showHighlight = isCurrent;

          return Container(
            height: lineHeight,
            alignment: Alignment.center,
            decoration: showHighlight
                ? BoxDecoration(
                    color: colorScheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(lineHeight / 2),
                  )
                : null,
            child: _KaraokeText(
              text: lyric.text,
              isCurrent: isCurrent,
              isPast: isPast,
              colorScheme: colorScheme,
              currentTextColor: currentTextColor,
              pastTextColor: pastTextColor,
              futureTextColor: futureTextColor,
              position: widget.currentPosition,
              startTime: lyric.startTime,
              endTime: lyric.endTime,
              baseFontSize: baseFontSize,
              lineHeight: lineHeight,
              words: lyric.words,
              translation: lyric.translation,
              isCurrentLine: isCurrent,
            ),
          );
        },
      ),
    );
  }
}

class _KaraokeText extends StatefulWidget {
  final String text;
  final bool isCurrent;
  final bool isPast;
  final LyricsTextColorScheme colorScheme;
  final Color currentTextColor;
  final Color pastTextColor;
  final Color futureTextColor;
  final Duration position;
  final Duration startTime;
  final Duration endTime;
  final double baseFontSize;
  final double lineHeight;
  final List<LyricWord>? words;
  final String? translation;
  final bool isCurrentLine;

  const _KaraokeText({
    required this.text,
    required this.isCurrent,
    required this.isPast,
    required this.colorScheme,
    required this.currentTextColor,
    required this.pastTextColor,
    required this.futureTextColor,
    required this.position,
    required this.startTime,
    required this.endTime,
    required this.baseFontSize,
    required this.lineHeight,
    this.words,
    this.translation,
    required this.isCurrentLine,
  });

  @override
  State<_KaraokeText> createState() => _KaraokeTextState();
}

class _KaraokeTextState extends State<_KaraokeText> {
  double _progress = 0.0;

  @override
  void didUpdateWidget(_KaraokeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _calculateProgress();
  }

  void _calculateProgress() {
    if (widget.isCurrent) {
      if (widget.words != null && widget.words!.isNotEmpty) {
        final positionMs = widget.position.inMilliseconds;
        final words = widget.words!;

        int currentWordIndex = -1;
        for (int i = 0; i < words.length; i++) {
          if (positionMs >= words[i].startTime.inMilliseconds &&
              positionMs < words[i].endTime.inMilliseconds) {
            currentWordIndex = i;
            break;
          }
          if (positionMs >= words[i].startTime.inMilliseconds) {
            currentWordIndex = i;
          }
        }

        if (currentWordIndex >= 0 && currentWordIndex < words.length) {
          final word = words[currentWordIndex];
          final wordStart = word.startTime.inMilliseconds;
          final wordEnd = word.endTime.inMilliseconds;
          final wordDuration = wordEnd - wordStart;

          double wordProgress = 0.0;
          if (wordDuration > 0) {
            wordProgress = ((positionMs - wordStart) / wordDuration).clamp(0.0, 1.0);
          }

          _progress = (currentWordIndex + wordProgress) / words.length;
        } else if (currentWordIndex >= words.length - 1) {
          _progress = 1.0;
        } else {
          _progress = 0.0;
        }
      } else {
        final totalDuration = widget.endTime.inMilliseconds - widget.startTime.inMilliseconds;
        final elapsed = widget.position.inMilliseconds - widget.startTime.inMilliseconds;
        _progress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTranslation = widget.translation != null && widget.translation!.isNotEmpty;
    final lineH = widget.lineHeight;
    // 有翻译时，文字区域占行高的一部分
    final textLineHeight = hasTranslation ? lineH * 0.55 : lineH;
    final transLineHeight = hasTranslation ? lineH * 0.35 : 0.0;

    if (widget.isPast) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: textLineHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: widget.baseFontSize,
                  color: widget.pastTextColor,
                ),
              ),
            ),
          ),
          if (hasTranslation)
            SizedBox(
              height: transLineHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.translation!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: widget.baseFontSize * 0.72,
                    color: widget.pastTextColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (widget.isCurrent) {
      if (widget.words != null && widget.words!.isNotEmpty) {
        return _buildWordByWordKaraoke(textLineHeight, transLineHeight, hasTranslation);
      }
      return _buildLineKaraoke(textLineHeight, transLineHeight, hasTranslation);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: textLineHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.baseFontSize - 2,
                color: widget.futureTextColor,
              ),
            ),
          ),
        ),
        if (hasTranslation)
          SizedBox(
            height: transLineHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.translation!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.baseFontSize * 0.65,
                  color: widget.futureTextColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 逐字卡拉OK效果
  Widget _buildWordByWordKaraoke(double textLineHeight, double transLineHeight, bool hasTranslation) {
    final positionMs = widget.position.inMilliseconds;
    final words = widget.words!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: textLineHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 2,
              runSpacing: 2,
              children: List.generate(words.length, (index) {
                final word = words[index];
                final isPast = positionMs >= word.endTime.inMilliseconds;
                final isCurrent = positionMs >= word.startTime.inMilliseconds &&
                    positionMs < word.endTime.inMilliseconds;

                double wordProgress = 0;
                if (isCurrent) {
                  final wordElapsed = positionMs - word.startTime.inMilliseconds;
                  final wordDuration = word.endTime.inMilliseconds - word.startTime.inMilliseconds;
                  wordProgress = wordDuration > 0 ? (wordElapsed / wordDuration).clamp(0.0, 1.0) : 0.0;
                }

                if (isPast) {
                  return Text(
                    word.word,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.baseFontSize + 2,
                      fontWeight: FontWeight.w600,
                      color: widget.colorScheme.primaryColor,
                    ),
                  );
                } else if (isCurrent) {
                  return _buildCurrentWord(word.word, wordProgress);
                } else {
                  return Text(
                    word.word,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: widget.baseFontSize + 2,
                      fontWeight: FontWeight.w600,
                      color: widget.currentTextColor.withValues(alpha: 0.25),
                    ),
                  );
                }
              }),
            ),
          ),
        ),
        if (hasTranslation)
          SizedBox(
            height: transLineHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.translation!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.baseFontSize * 0.72,
                  color: widget.currentTextColor.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 当前字的逐字渐变效果
  Widget _buildCurrentWord(String word, double progress) {
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Text(
          word,
          style: TextStyle(
            fontSize: widget.baseFontSize + 2,
            fontWeight: FontWeight.w600,
            color: widget.currentTextColor.withValues(alpha: 0.25),
          ),
        ),
        ClipRect(
          clipper: _WordProgressClipper(progress),
          child: ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  widget.colorScheme.primaryColor,
                  widget.colorScheme.highlightColor,
                ],
              ).createShader(bounds);
            },
            child: Text(
              word,
              style: TextStyle(
                fontSize: widget.baseFontSize + 2,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 整行卡拉OK效果
  Widget _buildLineKaraoke(double textLineHeight, double transLineHeight, bool hasTranslation) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          height: textLineHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 底层：未唱部分
                Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.baseFontSize + 4,
                    fontWeight: FontWeight.w600,
                    color: widget.currentTextColor.withValues(alpha: 0.2),
                  ),
                ),
                // 上层：卡拉OK效果
                ClipRect(
                  clipper: _ProgressClipper(_progress),
                  child: ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          widget.colorScheme.primaryColor,
                          widget.colorScheme.highlightColor,
                          widget.colorScheme.highlightColor,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ).createShader(bounds);
                    },
                    child: Text(
                      widget.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: widget.baseFontSize + 4,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasTranslation)
          SizedBox(
            height: transLineHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.translation!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: widget.baseFontSize * 0.72,
                  color: widget.currentTextColor.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 单字进度裁剪器
class _WordProgressClipper extends CustomClipper<Rect> {
  final double progress;
  _WordProgressClipper(this.progress);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress, size.height);
  }

  @override
  bool shouldReclip(_WordProgressClipper oldClipper) => progress != oldClipper.progress;
}

class _ProgressClipper extends CustomClipper<Rect> {
  final double progress;
  _ProgressClipper(this.progress);
  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * progress, size.height);
  }
  @override
  bool shouldReclip(_ProgressClipper oldClipper) => progress != oldClipper.progress;
}

/// 简洁歌词条形显示
class LyricsBar extends ConsumerWidget {
  final Duration currentPosition;
  final double height;
  final VoidCallback? onTap;

  const LyricsBar({
    super.key,
    required this.currentPosition,
    this.height = 80,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricsService = ref.watch(lyricsServiceProvider);
    final colorIndex = ref.watch(lyricsTextColorProvider);
    final colorScheme = LyricsColorSchemes.schemes[colorIndex];
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    lyricsService.updateCurrentLyric(currentPosition);

    final textColor = isDarkMode ? Colors.white : Colors.black87;

    if (!lyricsService.hasLyrics) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 24,
                color: colorScheme.primaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 4),
              Text(
                '播放音乐自动搜索歌词',
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lyric = lyricsService.currentLyric!;
    final translation = lyricsService.lyrics[lyricsService.currentIndex].translation;

    return Container(
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            lyric,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: colorScheme.primaryColor,
            ),
          ),
          if (translation != null && translation.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              translation,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: textColor.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
