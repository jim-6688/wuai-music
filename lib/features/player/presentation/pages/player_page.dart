import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../service/audio_player_service.dart';
import '../../service/lyrics_service.dart';
import '../providers/player_provider.dart';
import '../providers/lyrics_provider.dart';
import '../../widgets/audio_visualizer.dart';
import '../../widgets/lyrics_viewer.dart';
import '../../widgets/lyrics_with_fountain.dart';
import '../../widgets/cover_blur_background.dart';
import '../../../files/data/models/track.dart' as file_track;
import '../../providers/album_art_provider.dart';

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> with SingleTickerProviderStateMixin {
  String? _lastTrackId;
  AudioVisualizerMode _visMode = AudioVisualizerMode.fountain;
  List<double> _simulatedSpectrum = [];
  Timer? _spectrumTimer;
  double _phase = 0.0;
  double _rotationAngle = 0.0; // 唱片旋转角度
  List<_Particle> _particles = []; // 粒子列表
  final Random _random = Random(); // 随机数生成器

  // 保留的可视化模式列表
  static final List<AudioVisualizerMode> _availableModes = [
    AudioVisualizerMode.fountain,  // 水柱喷射
    AudioVisualizerMode.catEar,    // 环形频谱
    AudioVisualizerMode.line,      // 五线谱
    AudioVisualizerMode.tiktok,    // 抖音双向线谱
  ];

  void _cycleAudioVisualizerMode() {
    setState(() {
      final currentIndex = _availableModes.indexOf(_visMode);
      _visMode = _availableModes[(currentIndex + 1) % _availableModes.length];
    });
  }

  // 是否正在加载歌词（防重入）
  bool _isFetchingLyrics = false;

  @override
  void initState() {
    super.initState();
    _simulatedSpectrum = List.generate(32, (_) => 0.0);
    // initState 中延迟一帧，等 ref 可用后主动触发一次检查
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkTrackChange();
    });
  }

  @override
  void dispose() {
    _spectrumTimer?.cancel();
    super.dispose();
  }

  void _startSpectrumSimulation(bool isPlaying) {
    if (isPlaying) {
      // 确保timer在运行
      _spectrumTimer ??= Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) return;
        // 获取当前颜色
        final colorIndex = ref.read(lyricsTextColorProvider);
        final particleColor = LyricsColorSchemes.schemes[colorIndex].primaryColor;
        
        setState(() {
          _phase += 0.05;
          _rotationAngle += 0.01; // 唱片旋转角度增加
          _simulatedSpectrum = _generateSpectrum();
          _updateParticles(particleColor); // 更新粒子，传递颜色
        });
      });
    } else {
      // 停止timer并清零
      _spectrumTimer?.cancel();
      _spectrumTimer = null;
      if (mounted) {
        setState(() {
          _simulatedSpectrum = List.generate(32, (_) => 0.0);
          _particles.clear(); // 清除粒子
        });
      }
    }
  }

  /// 更新粒子系统
  void _updateParticles(Color particleColor) {
    // 移除死亡粒子
    _particles.removeWhere((p) => !p.isAlive);

    // 更新存活粒子
    for (final particle in _particles) {
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.life -= 0.02;
      // 添加轻微重力
      particle.vy += 0.05;
    }

    // 根据能量生成新粒子
    if (_simulatedSpectrum.isNotEmpty) {
      final energy = _simulatedSpectrum.reduce((a, b) => a + b) / _simulatedSpectrum.length;
      final peak = _simulatedSpectrum.reduce((a, b) => a > b ? a : b);

      // 能量粒子
      if (energy > 0.3 && _random.nextDouble() < energy * 0.3) {
        _spawnParticle(energy, particleColor);
      }

      // 峰值爆发粒子
      if (peak > 0.7 && _random.nextDouble() < 0.2) {
        _spawnBurstParticle(peak, particleColor);
      }
    }
  }

  /// 生成普通粒子
  void _spawnParticle(double energy, Color particleColor) {
    final angle = _random.nextDouble() * 2 * pi;
    final speed = 1 + _random.nextDouble() * 2;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final centerX = screenWidth / 2;
    final centerY = screenHeight * 0.5;

    _particles.add(_Particle(
      x: centerX + cos(angle) * 50,
      y: centerY + sin(angle) * 50,
      vx: cos(angle) * speed,
      vy: sin(angle) * speed - 1,
      life: 0.8 + _random.nextDouble() * 0.5,
      maxLife: 1.0,
      size: 2 + _random.nextDouble() * 3,
      color: particleColor,
      type: _random.nextDouble() < 0.3 ? 1 : 0,
    ));
  }

  /// 生成爆发粒子
  void _spawnBurstParticle(double energy, Color particleColor) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final centerX = screenWidth / 2;
    final centerY = screenHeight * 0.5;

    for (int i = 0; i < 5; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 2 + _random.nextDouble() * 4;

      _particles.add(_Particle(
        x: centerX,
        y: centerY,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        life: 0.6 + _random.nextDouble() * 0.4,
        maxLife: 1.0,
        size: 3 + _random.nextDouble() * 4,
        color: particleColor,
        type: 2,
      ));
    }
  }

  List<double> _generateSpectrum() {
    final t = _phase;
    return List.generate(32, (i) {
      final freqRatio = i / 32;
      double value;
      if (i < 5) {
        value = (0.7 + 0.3 * _sin(t * 2 + i * 0.3).abs()) * (1 - freqRatio * 0.2);
      } else if (i < 14) {
        value = (0.5 + 0.3 * _sin(t * 3 + i * 0.4).abs()) * (1 - freqRatio * 0.3);
      } else if (i < 24) {
        value = (0.3 + 0.2 * _sin(t * 4 + i * 0.5).abs()) * (1 - freqRatio * 0.4);
      } else {
        value = (0.1 + 0.15 * _sin(t * 6 + i * 0.8).abs()) * 0.6;
      }
      return value.clamp(0.0, 1.0);
    });
  }

  double _sin(double x) {
    x = x % (2 * pi);
    if (x < 0) x += 2 * pi;
    return 2 * (x / pi - 0.5).abs() - 1;
  }

  void _checkTrackChange() {
    final audioService = ref.read(audioPlayerServiceProvider);
    final currentTrack = audioService.currentTrack;
    final trackId = currentTrack?.id;
    final isPlaying = audioService.state.isPlaying;

    _startSpectrumSimulation(isPlaying);

    // 曲目切换时更新歌词和封面
    if (trackId != _lastTrackId) {
      _lastTrackId = trackId;
      _isFetchingLyrics = false; // 新曲目，重置防重入标志
      if (currentTrack != null) {
        _fetchLyricsForCurrentTrack(currentTrack);
        // 封面立即触发（不等歌词完成）
        _fetchCoverForTrack(currentTrack);
      } else {
        ref.read(lyricsServiceProvider).clearLyrics();
        ref.read(albumCoverProvider.notifier).clearCover();
      }
    } else if (currentTrack != null && !_isFetchingLyrics) {
      // 同一曲目但歌词还没有（且没有错误也没有在加载中），补一次请求
      final lyricsService = ref.read(lyricsServiceProvider);
      if (!lyricsService.hasLyrics && !lyricsService.isLoading && lyricsService.errorMessage == null) {
        _fetchLyricsForCurrentTrack(currentTrack);
      }
      // 封面也补一次
      final coverState = ref.read(albumCoverProvider);
      if (!coverState.hasCover && !coverState.isLoading) {
        _fetchCoverForTrack(currentTrack);
      }
    }
  }

  Future<void> _fetchLyricsForCurrentTrack(file_track.Track track) async {
    if (_isFetchingLyrics) return;
    _isFetchingLyrics = true;

    try {
      final lyricsService = ref.read(lyricsServiceProvider);
      lyricsService.clearLyrics();

      // ── 优先读取本地 .lrc 文件（美化功能写入的歌词）──────────────────────
      bool loaded = false;
      if (track.filePath.isNotEmpty &&
          !track.filePath.startsWith('http') &&
          !track.filePath.startsWith('content://')) {
        try {
          final lastDot = track.filePath.lastIndexOf('.');
          final basePath = lastDot >= 0
              ? track.filePath.substring(0, lastDot)
              : track.filePath;
          final lrcFile = File('$basePath.lrc');
          if (await lrcFile.exists()) {
            final lrcContent = await lrcFile.readAsString();
            if (lrcContent.trim().isNotEmpty && lrcContent.contains('[')) {
              lyricsService.loadFromLrcContent(lrcContent);
              loaded = lyricsService.hasLyrics;
              if (kDebugMode) {
                print('📄 本地 LRC 加载成功: $basePath.lrc (${lyricsService.lyrics.length} 行)');
              }
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ 本地 LRC 读取失败: $e');
        }
      }

      // ── 本地无歌词时走网络 ──────────────────────────────────────────────
      if (!loaded) {
        await lyricsService.fetchLyricsAuto(
          track.title,
          artist: track.artist,
          songId: track.id.isNotEmpty ? track.id : null,
        );
      }
    } finally {
      _isFetchingLyrics = false;
    }

    // 封面获取独立执行（不受歌词成功与否影响）
    _fetchCoverForTrack(track);
  }

  void _fetchCoverForTrack(file_track.Track track) {
    final albumCoverNotifier = ref.read(albumCoverProvider.notifier);
    if (track.albumArt != null && track.albumArt!.isNotEmpty) {
      albumCoverNotifier.setLocalCover(track.id, track.albumArt!);
    } else {
      albumCoverNotifier.fetchAlbumCoverForTrack(
        track.id.isNotEmpty ? track.id : '${track.title}_${track.artist}',
        track.title,
        artist: track.artist,
        album: track.album.isNotEmpty ? track.album : null,
      );
    }
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    return switch (mode) {
      PlayMode.loop => Icons.repeat_rounded,
      PlayMode.one => Icons.repeat_one_rounded,
      PlayMode.shuffle => Icons.shuffle_rounded,
    };
  }

  IconData _getVisualizerIcon(AudioVisualizerMode mode) {
    return switch (mode) {
      AudioVisualizerMode.fountain  => Icons.water_rounded,
      AudioVisualizerMode.bars      => Icons.equalizer_rounded,
      AudioVisualizerMode.catEar    => Icons.radio_button_checked_rounded,
      AudioVisualizerMode.circular  => Icons.radio_button_unchecked_rounded,
      AudioVisualizerMode.fft       => Icons.multiline_chart_rounded,
      AudioVisualizerMode.waveform  => Icons.show_chart_rounded,
      AudioVisualizerMode.starry    => Icons.star_rounded,
      AudioVisualizerMode.line      => Icons.stacked_line_chart_rounded,
      AudioVisualizerMode.vinyl     => Icons.album_rounded,
      AudioVisualizerMode.tiktok    => Icons.waves_rounded,
      AudioVisualizerMode.neonPulse => Icons.gradient_rounded,
      AudioVisualizerMode.waveRibbon => Icons.sailing_rounded,
      AudioVisualizerMode.particle  => Icons.blur_on_rounded,
      AudioVisualizerMode.crystalPrism => Icons.diamond_rounded,
      AudioVisualizerMode.ringPulse => Icons.ring_volume_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final audioService = ref.watch(audioPlayerServiceProvider);
    final playerState = audioService.state;
    final currentTrack = audioService.currentTrack;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentPosition = Duration(milliseconds: playerState.currentPosition);
    final primaryColor = Theme.of(context).primaryColor;

    // 监听播放服务状态变化，触发频谱和歌词检查（避免在 build 直接调用产生副作用）
    ref.listen<AudioPlayerService>(audioPlayerServiceProvider, (_, __) {
      _checkTrackChange();
    });

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 获取封面状态
          _buildCoverBlurBackground(isDarkMode),
          
          // 保留水波纹效果（在模糊层之上）
          CustomPaint(
            painter: _TikTokRippleBackgroundPainter(
              phase: (_phase * 0.1) % 1.0,
              color: primaryColor,
              isPlaying: playerState.isPlaying,
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '吾爱Music',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87),
                      ),
                      Row(
                        children: [
                          Consumer(
                            builder: (context, ref, _) {
                              final colorIndex = ref.watch(lyricsTextColorProvider);
                              final scheme = LyricsColorSchemes.schemes[colorIndex];
                              return GlassButton(
                                onPressed: () => _showColorSchemeDialog(context, ref),
                                padding: const EdgeInsets.all(10),
                                child: Icon(Icons.palette_rounded, color: scheme.primaryColor),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          GlassButton(
                            onPressed: _cycleAudioVisualizerMode,
                            padding: const EdgeInsets.all(10),
                            child: Icon(_getVisualizerIcon(_visMode), color: isDarkMode ? Colors.white70 : Colors.black54),
                          ),
                          const SizedBox(width: 8),
                          GlassButton(
                            onPressed: () {},
                            padding: const EdgeInsets.all(10),
                            child: Icon(Icons.list_rounded, color: isDarkMode ? Colors.white70 : Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Text(
                        currentTrack?.title ?? 'No Track',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentTrack?.artist ?? 'Select a song',
                        style: TextStyle(fontSize: 13, color: isDarkMode ? Colors.white60 : Colors.black54),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildVisualizerArea(audioService, playerState.isPlaying, isDarkMode, primaryColor, currentPosition),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                        ),
                        child: Slider(
                          value: playerState.duration > 0 ? (playerState.currentPosition / playerState.duration).clamp(0.0, 1.0) : 0.0,
                          onChanged: (value) {
                            final positionMs = (value * playerState.duration).toInt();
                            audioService.seek(Duration(milliseconds: positionMs));
                          },
                          activeColor: primaryColor,
                          inactiveColor: isDarkMode ? Colors.white24 : Colors.black12,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(playerState.currentPosition), style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black45)),
                            Text(_formatDuration(playerState.duration), style: TextStyle(fontSize: 12, color: isDarkMode ? Colors.white54 : Colors.black45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(_getPlayModeIcon(playerState.playMode), size: 24, color: isDarkMode ? Colors.white70 : Colors.black54),
                        onPressed: () => audioService.togglePlayMode(),
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_previous_rounded, size: 36, color: isDarkMode ? Colors.white : Colors.black87),
                        onPressed: () => audioService.previous(),
                      ),
                      // 播放按钮（无频谱背景）
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 12,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            playerState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 36,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            if (playerState.isPlaying) audioService.pause();
                            else audioService.play();
                          },
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.skip_next_rounded, size: 36, color: isDarkMode ? Colors.white : Colors.black87),
                        onPressed: () => audioService.next(),
                      ),
                      IconButton(
                        icon: Icon(_getVisualizerIcon(_visMode), size: 24, color: isDarkMode ? Colors.white70 : Colors.black54),
                        onPressed: _cycleAudioVisualizerMode,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizerArea(AudioPlayerService audioService, bool isPlaying, bool isDarkMode, Color primaryColor, Duration currentPosition) {
    // 获取歌词配色
    final colorIndex = ref.watch(lyricsTextColorProvider);
    final lyricsColor = LyricsColorSchemes.schemes[colorIndex].primaryColor;

    switch (_visMode) {
      case AudioVisualizerMode.fountain:
        return LyricsWithFountain(
          spectrumData: _simulatedSpectrum,
          isPlaying: isPlaying,
          color: lyricsColor, // 使用歌词配色
          fountainHeight: 220,
          lyricsWidget: _buildLyricsWidget(isDarkMode, currentPosition),
        );
      case AudioVisualizerMode.bars:
        // bars 模式保留但不在切换列表中，降级显示为线谱
        return Column(
          children: [
            Expanded(child: _buildLyricsWidget(isDarkMode, currentPosition)),
            SizedBox(
              height: 150,
              child: AudioVisualizer(
                mode: AudioVisualizerMode.line,
                barCount: 64,
                isPlaying: isPlaying,
                color: lyricsColor,
                width: double.infinity,
                height: double.infinity,
                mirror: true,
                spectrumStream: audioService.spectrumStream,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      case AudioVisualizerMode.line:
        return _buildLineVisualizer(isPlaying, isDarkMode, lyricsColor, currentPosition);
      case AudioVisualizerMode.tiktok:
        return _buildTikTokVisualizer(isPlaying, isDarkMode, lyricsColor, currentPosition);
      case AudioVisualizerMode.catEar:
        return _buildCatEarVisualizer(isPlaying, isDarkMode, lyricsColor, currentPosition); // 纯环形频谱（无黑胶）
      case AudioVisualizerMode.vinyl:
        return _buildVinylVisualizer(isPlaying, isDarkMode, lyricsColor, currentPosition); // 黑胶唱片+线谱
      case AudioVisualizerMode.circular:
        return Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0,
              height: MediaQuery.of(context).size.height * 0.45,
              child: _buildLyricsWidget(isDarkMode, currentPosition),
            ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              height: MediaQuery.of(context).size.height * 0.25,
              child: AudioVisualizer(
                mode: AudioVisualizerMode.circular,
                barCount: 64,
                isPlaying: isPlaying,
                color: lyricsColor, // 使用歌词配色
                width: double.infinity,
                height: double.infinity,
                smoothing: 0.8,
              ),
            ),
          ],
        );
      case AudioVisualizerMode.fft:
        // fft 模式保留但不在切换列表中，降级显示为线谱
        return Column(
          children: [
            Expanded(child: _buildLyricsWidget(isDarkMode, currentPosition)),
            SizedBox(
              height: 150,
              child: AudioVisualizer(
                mode: AudioVisualizerMode.line,
                barCount: 64,
                isPlaying: isPlaying,
                color: lyricsColor,
                width: double.infinity,
                height: double.infinity,
                mirror: true,
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      case AudioVisualizerMode.waveform:
        // 波形模式改为显示抖音风格单线细线谱
        return _buildThinLineVisualizer(isPlaying, isDarkMode, lyricsColor, currentPosition);
      case AudioVisualizerMode.starry:
        return LyricsWithFountain(
          spectrumData: _simulatedSpectrum,
          isPlaying: isPlaying,
          color: lyricsColor, // 使用歌词配色
          fountainHeight: 220,
          lyricsWidget: _buildLyricsWidget(isDarkMode, currentPosition),
        );
      case AudioVisualizerMode.neonPulse:
      case AudioVisualizerMode.waveRibbon:
      case AudioVisualizerMode.particle:
      case AudioVisualizerMode.crystalPrism:
      case AudioVisualizerMode.ringPulse:
        return _buildLineVisualizer(isPlaying, isDarkMode, lyricsColor, currentPosition);
    }
  }

  /// 波形线谱可视化（沉浸式：歌词区 + 双层波形底部）
  Widget _buildLineVisualizer(bool isPlaying, bool isDarkMode, Color primaryColor, Duration currentPosition) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        // 歌词层（全屏覆盖，透明背景）
        Positioned.fill(
          child: _buildLyricsWidget(isDarkMode, currentPosition),
        ),
        // 双层波形（底部，高度约 22% 屏幕）
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: screenHeight * 0.22,
          child: CustomPaint(
            painter: _WaveformLayerPainter(
              data: _simulatedSpectrum,
              isPlaying: isPlaying,
              color: primaryColor,
              phase: _phase,
            ),
          ),
        ),
      ],
    );
  }

  /// 抖音双向镜像线谱（沉浸式：歌词区 + 中部双向波形）
  Widget _buildTikTokVisualizer(bool isPlaying, bool isDarkMode, Color primaryColor, Duration currentPosition) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        // 歌词层（全屏，透明背景）
        Positioned.fill(
          child: _buildLyricsWidget(isDarkMode, currentPosition),
        ),
        // 抖音双向线谱（底部 28% 区域）
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: screenHeight * 0.28,
          child: AudioVisualizer(
            mode: AudioVisualizerMode.tiktok,
            barCount: 64,
            isPlaying: isPlaying,
            color: primaryColor,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ],
    );
  }

  /// 抖音风格单线细线谱（沉浸式：歌词区 + 底部单线波形）
  Widget _buildThinLineVisualizer(bool isPlaying, bool isDarkMode, Color primaryColor, Duration currentPosition) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Stack(
      children: [
        // 歌词层（全屏，透明背景）
        Positioned.fill(
          child: _buildLyricsWidget(isDarkMode, currentPosition),
        ),
        // 单线细线谱（底部 20% 区域，更细更简洁）
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: screenHeight * 0.20,
          child: AudioVisualizer(
            mode: AudioVisualizerMode.waveform,
            barCount: 64,
            isPlaying: isPlaying,
            color: primaryColor,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ],
    );
  }

  Widget _buildCatEarVisualizer(bool isPlaying, bool isDarkMode, Color primaryColor, Duration currentPosition) {
    // 获取专辑封面URL
    final albumCoverState = ref.watch(albumCoverProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Stack(
      children: [
        // 底层：环形频谱（无黑胶，纯频谱+中心封面）
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: screenHeight * 0.45,
          child: CustomPaint(
            painter: _CatEarPainter(
              spectrumData: _simulatedSpectrum,
              isPlaying: isPlaying,
              color: primaryColor,
              phase: _phase,
              particles: _particles,
              showVinyl: false, // 不显示黑胶唱片
              rotationAngle: _rotationAngle,
            ),
          ),
        ),
        // 中心封面圆（直接叠加在频谱中心）
        Positioned(
          left: 0, right: 0,
          bottom: screenHeight * 0.45 * 0.5 - screenWidth * 0.14,
          child: Center(
            child: ClipOval(
              child: albumCoverState.coverBytes != null
                ? Image.memory(
                    albumCoverState.coverBytes!,
                    width: screenWidth * 0.28,
                    height: screenWidth * 0.28,
                    fit: BoxFit.cover,
                  )
                : albumCoverState.localPath != null
                  ? _buildCoverImage(albumCoverState.localPath!, size: screenWidth * 0.28)
                  : Container(
                      width: screenWidth * 0.28,
                      height: screenWidth * 0.28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor.withValues(alpha: 0.2),
                    ),
                    child: Icon(Icons.music_note, color: primaryColor, size: screenWidth * 0.14),
                  ),
            ),
          ),
        ),
        // 顶层：歌词区域
        Positioned.fill(
          child: _buildLyricsWidget(isDarkMode, currentPosition),
        ),
      ],
    );
  }

  /// 黑胶唱片可视化（透明背景，底部黑胶+顶部歌词）
  Widget _buildVinylVisualizer(bool isPlaying, bool isDarkMode, Color primaryColor, Duration currentPosition) {
    final albumCoverState = ref.watch(albumCoverProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // 黑胶区域高度
    final vinylAreaHeight = screenHeight * 0.38;

    return Stack(
      children: [
        // 歌词区域（顶部，底部为黑胶区域）
        Positioned(
          top: 0, left: 0, right: 0,
          bottom: vinylAreaHeight,
          child: _buildLyricsWidget(isDarkMode, currentPosition),
        ),
        // 黑胶唱片（底部，透明背景）
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: vinylAreaHeight,
          child: CustomPaint(
            painter: _CatEarPainter(
              spectrumData: _simulatedSpectrum,
              isPlaying: isPlaying,
              color: primaryColor,
              phase: _phase,
              particles: _particles,
              showVinyl: true,
              albumCoverUrl: albumCoverState.coverUrl,
              rotationAngle: _rotationAngle,
            ),
          ),
        ),
        // 封面叠加在唱片中心
        if (albumCoverState.hasCover)
          Positioned(
            left: 0, right: 0,
            bottom: vinylAreaHeight * 0.5 - screenWidth * 0.095,
            child: Center(
              child: ClipOval(
                child: _buildCoverWidget(
                  albumCoverState,
                  size: screenWidth * 0.19,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 根据封面状态构建封面 Widget（优先字节 → 本地路径 → 占位）
  Widget _buildCoverWidget(AlbumCoverState state, {required double size, Color? placeholderColor}) {
    if (state.coverBytes != null) {
      return Image.memory(
        state.coverBytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      );
    } else if (state.localPath != null) {
      return _buildCoverImage(state.localPath!, size: size);
    }
    return SizedBox(width: size, height: size);
  }

  /// 构建封面模糊背景（抖音风格）
  Widget _buildCoverBlurBackground(bool isDarkMode) {
    final albumCoverState = ref.watch(albumCoverProvider);
    
    return AnimatedCoverBlurBackground(
      localCoverPath: albumCoverState.localPath,
      coverBytes: albumCoverState.coverBytes,
      blurSigma: 30.0,
      overlayOpacity: 0.4,
      isDarkMode: isDarkMode,
    );
  }

  /// 智能加载封面：本地文件用 Image.file，网络 URL 用 Image.network
  Widget _buildCoverImage(String path, {required double size}) {
    final isNetworkUrl = path.startsWith('http://') || path.startsWith('https://');
    if (isNetworkUrl) {
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      );
    } else {
      final file = File(path);
      return Image.file(
        file,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => SizedBox(width: size, height: size),
      );
    }
  }

  Widget _buildLyricsWidget(bool isDarkMode, Duration currentPosition) {
    return LyricsViewer(
      currentPosition: currentPosition,
      isDarkMode: isDarkMode,
      fixedHighlightPosition: 0.25, // 手机端：高亮行在偏上方位置
      lineHeight: 30.0, // 固定行高
      onTap: () => _showSearchLyricsDialog(),
    );
  }

  void _showSearchLyricsDialog() {
    final titleCtrl = TextEditingController();
    final artistCtrl = TextEditingController();
    final currentTrack = ref.read(audioPlayerServiceProvider).currentTrack;
    if (currentTrack != null) {
      titleCtrl.text = currentTrack.title;
      artistCtrl.text = currentTrack.artist;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('搜索歌词'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '歌曲名称',
                prefixIcon: Icon(Icons.music_note),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: artistCtrl,
              decoration: const InputDecoration(
                labelText: '歌手（可选）',
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.search, size: 18),
            label: const Text('搜索'),
            onPressed: () {
              Navigator.pop(ctx);
              _showLyricsCandidatesPage(titleCtrl.text, artistCtrl.text);
            },
          ),
        ],
      ),
    );
  }

  /// 显示多平台歌词候选列表页
  Future<void> _showLyricsCandidatesPage(String title, String artist) async {
    if (title.isEmpty) return;

    // 先显示加载提示
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('正在搜索多平台歌词...'),
            ],
          ),
        ),
      ),
    );

    final lyricsService = ref.read(lyricsServiceProvider);
    final candidates = await lyricsService.searchLyricsCandidates(
      title,
      artist: artist.isNotEmpty ? artist : null,
    );

    if (!mounted) return;
    Navigator.of(context).pop(); // 关闭加载框

    if (candidates.isEmpty) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('搜索结果'),
          content: const Text('未找到相关歌词，请尝试修改关键词'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
      return;
    }

    // 显示候选列表底部面板
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LyricsCandidatesSheet(
        candidates: candidates,
        onSelect: (candidate) async {
          Navigator.pop(ctx);
          // 显示加载中
          if (!mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const AlertDialog(
              content: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text('加载歌词中...'),
                  ],
                ),
              ),
            ),
          );
          final success = await lyricsService.fetchLyricsFromCandidate(candidate);
          if (!mounted) return;
          Navigator.of(context).pop(); // 关闭加载框
          if (!success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('歌词加载失败: ${lyricsService.errorMessage ?? "未知错误"}'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已加载 ${candidate.platformLabel} 歌词: ${candidate.title}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
      ),
    );
  }

  void _showColorSchemeDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassBottomSheet(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('歌词设置', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('颜色主题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(LyricsColorSchemes.schemes.length, (index) {
                final scheme = LyricsColorSchemes.schemes[index];
                final isSelected = ref.read(lyricsTextColorProvider) == index;
                return GestureDetector(
                  onTap: () {
                    ref.read(lyricsTextColorProvider.notifier).setScheme(index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: scheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? scheme.primaryColor : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      scheme.name,
                      style: TextStyle(
                        color: scheme.primaryColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            // 文字大小设置
            Row(
              children: [
                const Text('文字大小', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref.read(lyricsFontSizeProvider.notifier).decrease();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 28,
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final size = ref.watch(lyricsFontSizeProvider);
                    return Container(
                      width: 50,
                      alignment: Alignment.center,
                      child: Text(
                        '${size.toInt()}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: () {
                    ref.read(lyricsFontSizeProvider.notifier).increase();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 行距设置
            Row(
              children: [
                const Text('行距', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    ref.read(lyricsLineSpacingProvider.notifier).decrease();
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                  iconSize: 28,
                ),
                Consumer(
                  builder: (context, ref, _) {
                    final spacing = ref.watch(lyricsLineSpacingProvider);
                    return Container(
                      width: 50,
                      alignment: Alignment.center,
                      child: Text(
                        '${spacing.toInt()}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    );
                  },
                ),
                IconButton(
                  onPressed: () {
                    ref.read(lyricsLineSpacingProvider.notifier).increase();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  iconSize: 28,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    return '${duration.inMinutes}:${duration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
  }
}

/// 粒子类 - 用于动态粒子效果
class _Particle {
  double x, y;
  double vx, vy;
  double life;
  double maxLife;
  double size;
  Color color;
  int type; // 0: 光点, 1: 拖尾, 2: 爆发

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.maxLife,
    required this.size,
    required this.color,
    this.type = 0,
  });

  bool get isAlive => life > 0;
  double get progress => life / maxLife;
}

// ─────────────────────────────────────────────────────────────────────────────
/// 双层波形 Painter（line 模式底部）
/// 两层波形叠加：后层低频宽幅 + 前层高频细腻，形成立体感
// ─────────────────────────────────────────────────────────────────────────────
class _WaveformLayerPainter extends CustomPainter {
  final List<double> data;
  final bool isPlaying;
  final Color color;
  final double phase;

  _WaveformLayerPainter({
    required this.data,
    required this.isPlaying,
    required this.color,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // ── 后层（低频，宽幅柔和，偏移半拍）──────────────────────────────────────
    _drawLayer(
      canvas, size,
      amplitudeScale: 0.85,
      phaseOffset: 0.6,
      colorAlphaTop: 0.35,
      colorAlphaBottom: 0.05,
      strokeAlpha: 0.30,
      strokeWidth: 3.0,
      blurSigma: 6.0,
      yBaseRatio: 0.55, // 中心偏下
    );

    // ── 前层（高频，清晰锐利）────────────────────────────────────────────────
    _drawLayer(
      canvas, size,
      amplitudeScale: 1.0,
      phaseOffset: 0.0,
      colorAlphaTop: 0.65,
      colorAlphaBottom: 0.08,
      strokeAlpha: 0.90,
      strokeWidth: 2.0,
      blurSigma: 3.5,
      yBaseRatio: 0.50,
    );
  }

  void _drawLayer(
    Canvas canvas,
    Size size, {
    required double amplitudeScale,
    required double phaseOffset,
    required double colorAlphaTop,
    required double colorAlphaBottom,
    required double strokeAlpha,
    required double strokeWidth,
    required double blurSigma,
    required double yBaseRatio,
  }) {
    final n = data.length;
    if (n < 2) return;

    final baseLine = size.height * yBaseRatio;
    final maxAmp = size.height * 0.45 * amplitudeScale;

    // 生成波形点（使用 Catmull-Rom 插值平滑）
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      // 添加相位偏移让两层错开，形成立体感
      final value = data[i];
      final yOffset = value * maxAmp * sin(pi * i / n + phase * pi + phaseOffset);
      final y = baseLine - yOffset.abs() * (isPlaying ? 1.0 : 0.15);
      points.add(Offset(x, y));
    }

    final path = _buildSmoothPath(points);

    // 面积填充
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: colorAlphaTop),
          color.withValues(alpha: colorAlphaBottom),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 发光描边
    final glowPaint = Paint()
      ..color = color.withValues(alpha: strokeAlpha * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    canvas.drawPath(path, glowPaint);

    // 主线（彩虹色渐变）
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: strokeAlpha * 0.8),
          Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: strokeAlpha),
          color.withValues(alpha: strokeAlpha * 0.8),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // 波峰高亮圆点
    if (isPlaying) {
      for (int i = 0; i < points.length; i++) {
        final value = data[i];
        if (value < 0.72) continue;
        final intensity = (value - 0.72) / 0.28;
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * intensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * intensity);
        canvas.drawCircle(points[i], 3.0 * intensity + 1, dotPaint);
      }
    }
  }

  Path _buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _WaveformLayerPainter old) {
    return old.isPlaying != isPlaying ||
        old.color != color ||
        (old.phase - phase).abs() > 0.01 ||
        old.data.length != data.length;
  }
}

/// 环形频谱可视化器 — 增强版：粒子系统 + 动态效果
/// showVinyl=false → 纯环形频谱（catEar 模式）
/// showVinyl=true  → 黑胶唱片 + 频谱（vinyl 模式）
class _CatEarPainter extends CustomPainter {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double phase;
  final List<_Particle> particles;
  final String? albumCoverUrl;
  final double rotationAngle;
  final bool showVinyl; // 是否绘制黑胶唱片

  _CatEarPainter({
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.phase = 0.0,
    List<_Particle>? particles,
    this.albumCoverUrl,
    this.rotationAngle = 0.0,
    this.showVinyl = false,
  }) : particles = particles ?? [];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.5);
    final innerRadius = size.width * 0.15; // 中心圆半径（加大 0.12→0.15）
    // 频谱条从 vinylRadius 开始（有唱片时从唱片外圈，无唱片时从中心圆外圈）
    final vinylRadius = showVinyl ? innerRadius * 2.2 : innerRadius * 1.1; // 唱片加大：1.8→2.2
    final maxBarLength = size.width * 0.20; // 频谱条略短以适配更大唱片

    // 计算平均能量
    double energy = 0;
    double peakEnergy = 0;
    if (spectrumData.isNotEmpty && isPlaying) {
      energy = spectrumData.reduce((a, b) => a + b) / spectrumData.length;
      peakEnergy = spectrumData.reduce((a, b) => a > b ? a : b);
      energy = energy.clamp(0.0, 1.0);
      peakEnergy = peakEnergy.clamp(0.0, 1.0);
    }

    // 1. 动态背景能量场（vinyl 透明背景时跳过）
    if (!showVinyl) _drawEnergyField(canvas, size, center, energy);

    // 2. 流动波浪背景（vinyl 透明背景时跳过）
    if (!showVinyl) _drawWaveBackground(canvas, size, center, energy);

    // 3. 绘制粒子
    _drawParticles(canvas, size, center);

    // 4. 绘制内圈光晕
    _drawInnerGlow(canvas, center, innerRadius, energy);

    if (showVinyl) {
      // 5a. 绘制旋转黑胶唱片
      _drawRotatingVinyl(canvas, center, innerRadius, rotationAngle, albumCoverUrl);
    } else {
      // 5b. 绘制中心圆（无黑胶）
      _drawCenterCircle(canvas, center, innerRadius, energy);
    }

    // 6. 绘制频谱条（从唱片/中心圆外圈向外）
    _drawSpectrumBars(canvas, center, vinylRadius, maxBarLength, energy);

    // 7. 绘制轨道环
    _drawOrbitRings(canvas, center, vinylRadius, energy);
  }

  /// 动态能量场背景
  void _drawEnergyField(Canvas canvas, Size size, Offset center, double energy) {
    if (energy < 0.1) return;

    final fieldPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha((energy * 30).toInt()),
          color.withAlpha((energy * 15).toInt()),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: size.width * 0.5,
      ));

    canvas.drawCircle(center, size.width * 0.5, fieldPaint);

    // 添加动态光斑
    if (energy > 0.3) {
      for (int i = 0; i < 5; i++) {
        final angle = phase * 0.5 + i * pi * 2 / 5;
        final dist = size.width * (0.2 + 0.1 * sin(phase + i));
        final spotX = center.dx + cos(angle) * dist;
        final spotY = center.dy + sin(angle) * dist;
        final spotRadius = 20 + energy * 30;

        final spotPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              color.withAlpha((energy * 40).toInt()),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(
            center: Offset(spotX, spotY),
            radius: spotRadius,
          ));

        canvas.drawCircle(Offset(spotX, spotY), spotRadius, spotPaint);
      }
    }
  }

  /// 流动波浪背景
  void _drawWaveBackground(Canvas canvas, Size size, Offset center, double energy) {
    if (!isPlaying || energy < 0.15) return;

    final wavePaint = Paint()
      ..color = color.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // 绘制多层波浪
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final waveRadius = size.width * (0.35 + layer * 0.08);
      final wavePoints = 60;
      final layerPhase = phase + layer * 0.5;

      for (int i = 0; i <= wavePoints; i++) {
        final angle = i * 2 * pi / wavePoints;
        final waveOffset = sin(angle * 3 + layerPhase) * (10 + energy * 15);
        final r = waveRadius + waveOffset;
        final x = center.dx + cos(angle) * r;
        final y = center.dy + sin(angle) * r;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, wavePaint);
    }
  }

  /// 绘制粒子
  void _drawParticles(Canvas canvas, Size size, Offset center) {
    for (final particle in particles) {
      if (!particle.isAlive) continue;

      final alpha = (particle.progress * 255).toInt();
      final currentSize = particle.size * particle.progress;

      if (particle.type == 0) {
        // 光点粒子
        final paint = Paint()
          ..color = particle.color.withAlpha(alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset(particle.x, particle.y), currentSize, paint);
      } else if (particle.type == 1) {
        // 拖尾粒子
        final paint = Paint()
          ..color = particle.color.withAlpha(alpha)
          ..strokeWidth = currentSize
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(particle.x, particle.y),
          Offset(particle.x - particle.vx * 3, particle.y - particle.vy * 3),
          paint,
        );
      } else {
        // 爆发粒子 - 带发光
        final paint = Paint()
          ..shader = RadialGradient(
            colors: [
              particle.color.withAlpha(alpha),
              particle.color.withAlpha(alpha ~/ 2),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(
            center: Offset(particle.x, particle.y),
            radius: currentSize * 2,
          ));
        canvas.drawCircle(Offset(particle.x, particle.y), currentSize * 2, paint);
      }
    }
  }

  void _drawInnerGlow(Canvas canvas, Offset center, double radius, double energy) {
    // 多层光晕
    for (int i = 3; i >= 0; i--) {
      final glowRadius = radius * (1.5 + i * 0.3);
      final glowPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withAlpha((energy * (25 - i * 5)).toInt()),
            color.withAlpha((energy * (15 - i * 3)).toInt()),
            Colors.transparent,
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius));

      canvas.drawCircle(center, glowRadius, glowPaint);
    }

    // 动态脉冲光环
    final pulseCount = 3;
    for (int i = 0; i < pulseCount; i++) {
      final pulseProgress = ((phase * 0.5 + i / pulseCount) % 1.0);
      final pulseRadius = radius * (1.2 + pulseProgress * 0.8);
      final pulseAlpha = (energy * 40 * (1 - pulseProgress)).toInt();

      if (pulseAlpha > 0) {
        final pulsePaint = Paint()
          ..color = color.withAlpha(pulseAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(center, pulseRadius, pulsePaint);
      }
    }
  }

  /// 中心光晕圆（catEar 无黑胶模式）
  void _drawCenterCircle(Canvas canvas, Offset center, double radius, double energy) {
    // 主圆填充
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha((80 + energy * 60).toInt()),
          color.withAlpha((30 + energy * 20).toInt()),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, fillPaint);

    // 旋转光环描边
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withAlpha(180),
          color.withAlpha(60),
          color.withAlpha(180),
        ],
        startAngle: phase,
        endAngle: phase + 2 * pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius, ringPaint);
  }

  void _drawSpectrumBars(Canvas canvas, Offset center, double innerRadius, double maxBarLength, double avgEnergy) {
    if (spectrumData.isEmpty) return;

    const barCount = 72;
    final angleStep = 2 * pi / barCount;

    for (int i = 0; i < barCount; i++) {
      final specIdx = (i * spectrumData.length / barCount).floor() % spectrumData.length;
      final value = spectrumData[specIdx];
      final prevValue = spectrumData[(specIdx - 1).clamp(0, spectrumData.length - 1)];
      final nextValue = spectrumData[(specIdx + 1) % spectrumData.length];

      // 平滑处理
      final smoothValue = (value * 0.6 + prevValue * 0.2 + nextValue * 0.2);

      if (smoothValue < 0.02) continue;

      // 添加微小波动使动画更生动
      final waveOffset = sin(phase * 3 + i * 0.2) * 0.05;
      final animatedValue = (smoothValue + waveOffset).clamp(0.0, 1.0);

      final barLength = animatedValue * maxBarLength + 2;
      final angle = i * angleStep - pi / 2;

      // 计算位置
      final startX = center.dx + cos(angle) * innerRadius;
      final startY = center.dy + sin(angle) * innerRadius;
      final endX = center.dx + cos(angle) * (innerRadius + barLength);
      final endY = center.dy + sin(angle) * (innerRadius + barLength);

      // 条宽度
      final barWidth = 1.5 + animatedValue * 3.0;

      // 彩虹色渐变
      final hueShift = (i / barCount) * 60 + phase * 20;
      final baseHsl = HSLColor.fromColor(color);
      final barHue = (baseHsl.hue + hueShift) % 360;
      final barColor = HSLColor.fromAHSL(
        1.0,
        barHue,
        0.85 + animatedValue * 0.15,
        0.55 + animatedValue * 0.25,
      ).toColor();

      // 主条形 - 渐变
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            barColor.withAlpha(200),
            barColor.withAlpha(255),
            HSLColor.fromAHSL(1.0, barHue, 0.3, 0.9).toColor().withAlpha(230),
          ],
        ).createShader(Rect.fromPoints(
          Offset(startX, startY),
          Offset(endX, endY),
        ))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), barPaint);

      // 发光效果
      if (animatedValue > 0.35) {
        final glowPaint = Paint()
          ..color = barColor.withAlpha((animatedValue * 100).toInt())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + animatedValue * 5)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = barWidth * 2.5
          ..style = PaintingStyle.stroke;

        canvas.drawLine(Offset(startX, startY), Offset(endX, endY), glowPaint);
      }

      // 末端亮点
      if (animatedValue > 0.2) {
        final dotPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withAlpha((animatedValue * 220).toInt()),
              barColor.withAlpha((animatedValue * 150).toInt()),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(
            center: Offset(endX, endY),
            radius: barWidth * 1.5,
          ));
        canvas.drawCircle(Offset(endX, endY), barWidth * 1.5, dotPaint);
      }
    }
  }

  /// 放大后的中心区域 - 包含软件logo
  void _drawEnlargedCenter(Canvas canvas, Offset center, double innerRadius, double energy) {
    // 1. 放大后的中心圆（半径放大1.5倍）
    final enlargedRadius = innerRadius * 1.5;
    
    // 背景渐变圆
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha((60 + energy * 40).toInt()),
          color.withAlpha((30 + energy * 20).toInt()),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: enlargedRadius,
      ));

    canvas.drawCircle(center, enlargedRadius, backgroundPaint);

    // 2. 外圈发光效果
    final glowPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withAlpha(180),
          color.withAlpha(100),
          color.withAlpha(180),
        ],
        startAngle: phase,
        endAngle: phase + 2 * pi,
      ).createShader(Rect.fromCircle(center: center, radius: enlargedRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5.0);

    canvas.drawCircle(center, enlargedRadius, glowPaint);

    // 3. 绘制软件logo文字：吾爱Music
    final textPainter = TextPainter(
      text: TextSpan(
        text: '吾爱',
        style: TextStyle(
          color: Colors.white.withAlpha((200 + energy * 55).toInt()),
          fontSize: enlargedRadius * 0.35,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: color.withAlpha((150 + energy * 100).toInt()),
              blurRadius: 8.0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height * 0.8,
      ),
    );

    // 绘制"Music"文字
    final musicPainter = TextPainter(
      text: TextSpan(
        text: 'Music',
        style: TextStyle(
          color: Colors.white.withAlpha((180 + energy * 75).toInt()),
          fontSize: enlargedRadius * 0.25,
          fontWeight: FontWeight.w600,
          fontStyle: FontStyle.italic,
          shadows: [
            Shadow(
              color: color.withAlpha((120 + energy * 80).toInt()),
              blurRadius: 6.0,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    musicPainter.layout();
    musicPainter.paint(
      canvas,
      Offset(
        center.dx - musicPainter.width / 2,
        center.dy + textPainter.height * 0.1,
      ),
    );

    // 4. 中心核心光点
    if (energy > 0.1) {
      final corePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withAlpha((energy * 250).toInt()),
            Colors.white.withAlpha((energy * 120).toInt()),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: enlargedRadius * 0.3));

      canvas.drawCircle(center, enlargedRadius * 0.3, corePaint);
    }

    // 5. 旋转装饰点
    final decorCount = 8;
    for (int i = 0; i < decorCount; i++) {
      final angle = phase * 0.5 + i * 2 * pi / decorCount;
      final decorRadius = enlargedRadius * (0.85 + sin(phase * 3 + i) * 0.05);
      final x = center.dx + cos(angle) * decorRadius;
      final y = center.dy + sin(angle) * decorRadius;

      canvas.drawCircle(
        Offset(x, y),
        2.5 + energy * 3,
        Paint()..color = color.withAlpha((120 + energy * 100).toInt()),
      );
    }
  }

  /// 中心装饰 - 更精致
  void _drawCenterDecoration(Canvas canvas, Offset center, double radius, double energy) {
    // 外圈旋转装饰
    final decorCount = 12;
    for (int i = 0; i < decorCount; i++) {
      final angle = phase * 0.3 + i * 2 * pi / decorCount;
      final decorRadius = radius * (0.9 + sin(phase * 2 + i) * 0.1);
      final x = center.dx + cos(angle) * decorRadius;
      final y = center.dy + sin(angle) * decorRadius;

      canvas.drawCircle(
        Offset(x, y),
        2 + energy * 2,
        Paint()..color = color.withAlpha((100 + energy * 80).toInt()),
      );
    }

    // 内圈填充
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha(60),
          color.withAlpha(30),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, fillPaint);

    // 外环
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withAlpha(150),
          color.withAlpha(80),
          color.withAlpha(150),
        ],
        startAngle: phase,
        endAngle: phase + 2 * pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, ringPaint);

    // 中心核心
    if (energy > 0.15) {
      final corePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withAlpha((energy * 200).toInt()),
            color.withAlpha((energy * 150).toInt()),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: center,
          radius: 5 + energy * 8,
        ));
      canvas.drawCircle(center, 5 + energy * 8, corePaint);
    }
  }

  /// 轨道环
  void _drawOrbitRings(Canvas canvas, Offset center, double innerRadius, double energy) {
    if (energy < 0.2) return;

    // 多层轨道环
    for (int ring = 0; ring < 2; ring++) {
      final orbitRadius = innerRadius * (1.8 + ring * 0.5);
      final orbitPaint = Paint()
        ..color = color.withAlpha((30 + energy * 30 - ring * 15).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      // 虚线效果
      final dashCount = 60;
      for (int i = 0; i < dashCount; i++) {
        if (i % 2 == 0) {
          final startAngle = i * 2 * pi / dashCount + phase * (0.2 + ring * 0.1);
          final sweepAngle = pi / dashCount * 0.8;
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: orbitRadius),
            startAngle,
            sweepAngle,
            false,
            orbitPaint,
          );
        }
      }

      // 轨道上的光点
      final dotAngle = phase * (1 + ring * 0.5) + ring * pi;
      final dotX = center.dx + cos(dotAngle) * orbitRadius;
      final dotY = center.dy + sin(dotAngle) * orbitRadius;

      final dotPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withAlpha((energy * 200).toInt()),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(dotX, dotY),
          radius: 6,
        ));
      canvas.drawCircle(Offset(dotX, dotY), 6, dotPaint);
    }
  }

  /// 绘制旋转唱片（抖音风格）
  void _drawRotatingVinyl(Canvas canvas, Offset center, double innerRadius, double rotationAngle, String? albumCoverUrl) {
    // 唱片外圈半径（加大：1.8→2.2）
    final vinylRadius = innerRadius * 2.2;
    
    // 1. 唱片外圈 - 黑色唱片质感
    final vinylPaint = Paint()
      ..color = Colors.black.withAlpha(220)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, vinylRadius, vinylPaint);
    
    // 2. 唱片纹理 - 模拟唱片纹理
    final texturePaint = Paint()
      ..color = Colors.grey.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    // 唱片纹理线条
    for (int i = 0; i < 36; i++) {
      final angle = rotationAngle + i * pi / 18;
      final startX = center.dx + cos(angle) * (vinylRadius * 0.7);
      final startY = center.dy + sin(angle) * (vinylRadius * 0.7);
      final endX = center.dx + cos(angle) * vinylRadius;
      final endY = center.dy + sin(angle) * vinylRadius;
      
      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), texturePaint);
    }
    
    // 3. 唱片标签 - 唱片中心标签
    final labelRadius = vinylRadius * 0.3;
    final labelPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withAlpha(200),
          Colors.white.withAlpha(100),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: labelRadius,
      ));
    
    canvas.drawCircle(center, labelRadius, labelPaint);
    
    // 4. 唱片刻度 - 唱片边缘刻度
    final scalePaint = Paint()
      ..color = Colors.white.withAlpha(150)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (int i = 0; i < 60; i++) {
      final angle = rotationAngle + i * pi / 30;
      final scaleX = center.dx + cos(angle) * vinylRadius;
      final scaleY = center.dy + sin(angle) * vinylRadius;
      
      canvas.drawCircle(Offset(scaleX, scaleY), 1.5, scalePaint);
    }
    
    // 5. 专辑封面显示区域
    final coverRadius = vinylRadius * 0.6;
    final coverPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withAlpha(180),
          Colors.black.withAlpha(120),
          Colors.transparent,
        ],
        stops: const [0.0, 0.7, 1.0],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: coverRadius,
      ));
    
    canvas.drawCircle(center, coverRadius, coverPaint);
    
    // 6. 唱片旋转动画效果 - 旋转光晕
    if (albumCoverUrl == null) {
      // 如果没有封面，显示默认唱片图案
      final defaultPatternPaint = Paint()
        ..shader = SweepGradient(
          colors: [
            Colors.white.withAlpha(80),
            Colors.transparent,
            Colors.white.withAlpha(80),
          ],
          startAngle: rotationAngle,
          endAngle: rotationAngle + pi * 2,
        ).createShader(Rect.fromCircle(
          center: center,
          radius: vinylRadius,
        ))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(center, vinylRadius, defaultPatternPaint);
    }
    
    // 7. 唱片中心孔洞
    final holeRadius = vinylRadius * 0.1;
    final holePaint = Paint()
      ..color = Colors.black.withAlpha(200)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, holeRadius, holePaint);
  }

  @override
  bool shouldRepaint(covariant _CatEarPainter oldDelegate) {
    if (oldDelegate.isPlaying != isPlaying) return true;
    if (oldDelegate.color != color) return true;
    if ((oldDelegate.phase - phase).abs() > 0.01) return true;
    if (oldDelegate.particles.length != particles.length) return true;
    if (oldDelegate.spectrumData.length != spectrumData.length) return true;
    if (oldDelegate.albumCoverUrl != albumCoverUrl) return true;
    if ((oldDelegate.rotationAngle - rotationAngle).abs() > 0.01) return true;
    if (oldDelegate.showVinyl != showVinyl) return true;
    for (int i = 0; i < spectrumData.length; i++) {
      if ((oldDelegate.spectrumData[i] - spectrumData[i]).abs() > 0.01) return true;
    }
    return false;
  }
}

/// 抖音风格水波纹背景效果
class _TikTokRippleBackgroundPainter extends CustomPainter {
  final double phase;
  final Color color;
  final bool isPlaying;

  _TikTokRippleBackgroundPainter({
    required this.phase,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    if (!isPlaying) return;

    // 绘制多层水波纹
    for (int i = 0; i < 3; i++) {
      final rippleProgress = (phase + i * 0.3) % 1.0;
      final rippleRadius = (size.width * 0.5) * (0.2 + rippleProgress * 0.8);
      final rippleAlpha = (150 * (1 - rippleProgress)).toInt();

      // 水波纹圆环
      final ripplePaint = Paint()
        ..color = color.withAlpha(rippleAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10.0);

      canvas.drawCircle(center, rippleRadius, ripplePaint);

      // 内部淡入圆环
      final innerRadius = rippleRadius * 0.8;
      final innerPaint = Paint()
        ..color = color.withAlpha((rippleAlpha * 0.7).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0);

      canvas.drawCircle(center, innerRadius, innerPaint);
    }

    // 中心光点
    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha(100),
          color.withAlpha(50),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: center,
        radius: size.width * 0.1,
      ));

    canvas.drawCircle(center, size.width * 0.1, centerPaint);
  }

  @override
  bool shouldRepaint(covariant _TikTokRippleBackgroundPainter oldDelegate) {
    return oldDelegate.phase != phase ||
           oldDelegate.color != color ||
           oldDelegate.isPlaying != isPlaying;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 歌词候选列表底部面板
// ─────────────────────────────────────────────────────────────────────────────

/// 多平台歌词候选列表面板
class _LyricsCandidatesSheet extends StatelessWidget {
  final List<LyricsCandidate> candidates;
  final ValueChanged<LyricsCandidate> onSelect;

  const _LyricsCandidatesSheet({
    required this.candidates,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 按平台分组
    final lrcCxCandidates = candidates.where((c) => c.platform == 'lrccx').toList();
    final qqCandidates = candidates.where((c) => c.platform == 'qq').toList();
    final neteaseCandidates = candidates.where((c) => c.platform == 'netease').toList();
    final kugouCandidates = candidates.where((c) => c.platform == 'kugou').toList();
    final kuwoCandidates = candidates.where((c) => c.platform == 'kuwo').toList();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: GlassBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部拖拽条
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Icon(Icons.lyrics_rounded,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '选择歌词',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '共 ${candidates.length} 条结果',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white24 : Colors.black12),
          // 列表内容
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // lrc.cx
                if (lrcCxCandidates.isNotEmpty) ...[
                  _buildPlatformHeader(
                      context, 'lrc.cx', const Color(0xFF6B5B95), lrcCxCandidates.length),
                  ...lrcCxCandidates.map(
                      (c) => _buildCandidateItem(context, c, isDark, textColor)),
                ],
                // QQ音乐
                if (qqCandidates.isNotEmpty) ...[
                  _buildPlatformHeader(
                      context, 'QQ音乐', const Color(0xFF1DB954), qqCandidates.length),
                  ...qqCandidates.map(
                      (c) => _buildCandidateItem(context, c, isDark, textColor)),
                ],
                // 网易云
                if (neteaseCandidates.isNotEmpty) ...[
                  _buildPlatformHeader(
                      context, '网易云', const Color(0xFFE60026), neteaseCandidates.length),
                  ...neteaseCandidates.map(
                      (c) => _buildCandidateItem(context, c, isDark, textColor)),
                ],
                // 酷狗
                if (kugouCandidates.isNotEmpty) ...[
                  _buildPlatformHeader(
                      context, '酷狗', const Color(0xFF3498DB), kugouCandidates.length),
                  ...kugouCandidates.map(
                      (c) => _buildCandidateItem(context, c, isDark, textColor)),
                ],
                // 酷我
                if (kuwoCandidates.isNotEmpty) ...[
                  _buildPlatformHeader(
                      context, '酷我', const Color(0xFFE67E22), kuwoCandidates.length),
                  ...kuwoCandidates.map(
                      (c) => _buildCandidateItem(context, c, isDark, textColor)),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildPlatformHeader(
      BuildContext context, String label, Color color, int count) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count 条',
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandidateItem(BuildContext context, LyricsCandidate candidate,
      bool isDark, Color textColor) {
    // 根据平台返回对应颜色
    final platformColor = switch (candidate.platform) {
      'lrccx' => const Color(0xFF6B5B95),
      'qq' => const Color(0xFF1DB954),
      'netease' => const Color(0xFFE60026),
      'kugou' => const Color(0xFF3498DB),
      'kuwo' => const Color(0xFFE67E22),
      _ => const Color(0xFF888888),
    };
    final subColor = isDark ? Colors.white54 : Colors.black45;

    return InkWell(
      onTap: () => onSelect(candidate),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            // 平台标记圆点
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: platformColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // 歌曲信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    candidate.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          candidate.artist,
                          style: TextStyle(fontSize: 13, color: subColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (candidate.album != null) ...[
                        Text(' · ', style: TextStyle(color: subColor, fontSize: 13)),
                        Flexible(
                          child: Text(
                            candidate.album!,
                            style: TextStyle(fontSize: 12, color: subColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // 时长 + 匹配分数
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (candidate.duration != null)
                  Text(
                    candidate.duration!,
                    style: TextStyle(fontSize: 12, color: subColor),
                  ),
                if (candidate.matchScore >= 60)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: platformColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '最佳匹配',
                      style: TextStyle(
                        fontSize: 10,
                        color: platformColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? Colors.white30 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
