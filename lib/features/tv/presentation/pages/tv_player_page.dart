import 'dart:async';
import 'dart:io' as dart_io;
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../player/service/audio_player_service.dart';
import '../../../player/service/audio_visualizer_service.dart';
import '../../../player/service/lyrics_service.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../player/presentation/providers/lyrics_provider.dart';
import '../../../player/providers/album_art_provider.dart';
import '../../../player/widgets/audio_visualizer.dart';
import '../../../player/widgets/lyrics_viewer.dart';
import '../../../player/widgets/lyrics_with_fountain.dart';
import '../../../player/widgets/cover_blur_background.dart';
import '../../../files/data/models/track.dart' as file_track;
import '../../../files/presentation/providers/file_provider_debug.dart';
import '../../../../core/providers/unified_tracks_provider.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../player/presentation/providers/equalizer_provider.dart';
import 'tv_equalizer_page.dart';

/// TV 播放器页面 - 左右分栏布局（控制区域始终可见）
/// 
/// 布局规范:
/// - 左侧: 封面 + 歌曲信息 + 可视化
/// - 右侧: 歌词显示
/// - 底部: 进度条 + 控制按钮（始终可见）
class TVPlayerPage extends ConsumerStatefulWidget {
  const TVPlayerPage({super.key});

  @override
  ConsumerState<TVPlayerPage> createState() => _TVPlayerPageState();
}

class _TVPlayerPageState extends ConsumerState<TVPlayerPage> with SingleTickerProviderStateMixin {
  String? _lastTrackId;
  AudioVisualizerMode _spectrumMode = AudioVisualizerMode.bars;
  late FocusNode _rootFocusNode;
  int _focusedControlIndex = 2; // 默认焦点在播放按钮
  
  // 焦点控制相关
  final List<FocusNode> _controlFocusNodes = [];
  final List<FocusNode> _extraFocusNodes = [];
  int _currentFocusZone = 0; // 0=控制按钮区, 1=进度条区
  double _focusedProgressValue = 0.0;
  bool _isAdjustingProgress = false;

  // 可视化相关状态 — 使用真实频谱数据
  List<double> _spectrumData = [];
  StreamSubscription<List<double>>? _spectrumSubscription;
  Timer? _animationTimer;
  double _phase = 0.0;
  double _rotationAngle = 0.0;
  List<_TvParticle> _particles = [];
  final Random _random = Random();
  
  // 频谱平滑：保存上一帧数据用于插值
  List<double> _smoothedSpectrum = [];
  static const double _smoothingFactor = 0.3; // 越小越平滑

  static const List<AudioVisualizerMode> _allSpectrumModes = [
    AudioVisualizerMode.bars,       // 条形频谱
    AudioVisualizerMode.waveform,   // 单线波形
    AudioVisualizerMode.tiktok,     // 双向镜像线谱
    AudioVisualizerMode.line,       // 双层波形
    AudioVisualizerMode.fountain,   // 水柱喷泉
    AudioVisualizerMode.catEar,     // 环形频谱
    AudioVisualizerMode.vinyl,      // 黑胶唱片
    AudioVisualizerMode.neonPulse,  // 霓虹脉冲
    AudioVisualizerMode.waveRibbon, // 波浪丝带
    AudioVisualizerMode.particle,   // 粒子爆发
    AudioVisualizerMode.crystalPrism, // 水晶棱镜
    AudioVisualizerMode.ringPulse,  // 环形脉冲
  ];

  // TV 设计规范常量
  static const double _cardSpacing = 32.0;
  static const double _titleTextSize = 36.0;
  static const double _subtitleTextSize = 28.0;
  static const double _bodyTextSize = 20.0;
  static const double _iconSize = 80.0;
  static const double _controlButtonSize = 100.0;

  @override
  void initState() {
    super.initState();
    _rootFocusNode = FocusNode();
    _spectrumData = List.generate(32, (_) => 0.0);
    _smoothedSpectrum = List.generate(32, (_) => 0.0);
    
    // 初始化控制按钮焦点节点（6个：播放模式/上一曲/播放暂停/下一曲/均衡器/频谱模式）
    for (int i = 0; i < 6; i++) {
      _controlFocusNodes.add(FocusNode());
    }
    // 初始化额外功能区焦点节点（进度条）
    _extraFocusNodes.add(FocusNode());
    
    // 启用阻止电视休眠
    WakelockPlus.enable();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
      if (_controlFocusNodes.length > 2) {
        _controlFocusNodes[2].requestFocus();
      }
      // 订阅真实频谱数据流
      _subscribeToSpectrumStream();
      // 自动开始播放本地音乐（随机全部）
      _autoPlayLocalMusic();
    });
  }

  @override
  void dispose() {
    _spectrumSubscription?.cancel();
    _animationTimer?.cancel();
    // 禁用阻止电视休眠
    WakelockPlus.disable();
    _rootFocusNode.dispose();
    for (final node in _controlFocusNodes) {
      node.dispose();
    }
    for (final node in _extraFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkTrackChange();
  }

  void _checkTrackChange() {
    final audioService = ref.read(audioPlayerServiceProvider);
    final currentTrack = audioService.currentTrack;
    final trackId = currentTrack?.id;
    final isPlaying = audioService.state.isPlaying;

    // 启动/停止动画定时器（粒子、旋转等）
    _startAnimationTimer(isPlaying);
    
    if (trackId != _lastTrackId) {
      _lastTrackId = trackId;
      
      if (currentTrack != null) {
        _fetchLyricsForCurrentTrack(currentTrack);
        _fetchAlbumCoverForCurrentTrack(currentTrack);
      } else {
        ref.read(lyricsServiceProvider).clearLyrics();
        ref.read(albumCoverProvider.notifier).clearCover();
      }
    }
  }

  /// 订阅 AudioPlayerService 的真实频谱数据流
  void _subscribeToSpectrumStream() {
    final audioService = ref.read(audioPlayerServiceProvider);
    _spectrumSubscription?.cancel();
    _spectrumSubscription = audioService.spectrumStream.listen((data) {
      if (!mounted) return;
      // 平滑插值处理
      setState(() {
        if (_smoothedSpectrum.length != data.length) {
          _smoothedSpectrum = List.from(data);
        } else {
          for (int i = 0; i < data.length; i++) {
            // 平滑：新值和旧值之间插值，下落速度快于上升速度
            final target = data[i];
            final current = _smoothedSpectrum[i];
            if (target > current) {
              // 上升：快速响应
              _smoothedSpectrum[i] = current + (target - current) * 0.6;
            } else {
              // 下落：缓慢衰减
              _smoothedSpectrum[i] = current + (target - current) * _smoothingFactor;
            }
          }
        }
        _spectrumData = List.from(_smoothedSpectrum);
      });
    });
  }

  /// 动画定时器（驱动粒子、旋转角度、相位）
  void _startAnimationTimer(bool isPlaying) {
    if (isPlaying) {
      _animationTimer ??= Timer.periodic(const Duration(milliseconds: 50), (timer) {
        if (!mounted) return;
        final primaryColor = Theme.of(context).primaryColor;
        setState(() {
          _phase += 0.05;
          _rotationAngle += 0.01;
          _updateTvParticles(primaryColor);
        });
      });
    } else {
      _animationTimer?.cancel();
      _animationTimer = null;
      if (mounted) {
        setState(() {
          _spectrumData = List.generate(32, (_) => 0.0);
          _smoothedSpectrum = List.generate(32, (_) => 0.0);
          _particles.clear();
        });
      }
    }
  }

  void _updateTvParticles(Color particleColor) {
    _particles.removeWhere((p) => !p.isAlive);
    for (final particle in _particles) {
      particle.x += particle.vx;
      particle.y += particle.vy;
      particle.life -= 0.02;
      particle.vy += 0.05;
    }
    if (_spectrumData.isNotEmpty) {
      final energy = _spectrumData.reduce((a, b) => a + b) / _spectrumData.length;
      final peak = _spectrumData.reduce((a, b) => a > b ? a : b);
      if (energy > 0.3 && _random.nextDouble() < energy * 0.3) {
        _spawnTvParticle(energy, particleColor);
      }
      if (peak > 0.7 && _random.nextDouble() < 0.2) {
        _spawnTvBurstParticle(peak, particleColor);
      }
    }
  }

  void _spawnTvParticle(double energy, Color particleColor) {
    final angle = _random.nextDouble() * 2 * pi;
    final speed = 1 + _random.nextDouble() * 2;
    // TV 横屏布局，粒子围绕可视化区域中心
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width * 0.175; // 左侧区域中心
    final centerY = screenSize.height * 0.45;
    _particles.add(_TvParticle(
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

  void _spawnTvBurstParticle(double energy, Color particleColor) {
    final screenSize = MediaQuery.of(context).size;
    final centerX = screenSize.width * 0.175;
    final centerY = screenSize.height * 0.45;
    for (int i = 0; i < 5; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = 2 + _random.nextDouble() * 4;
      _particles.add(_TvParticle(
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

  Future<void> _fetchAlbumCoverForCurrentTrack(file_track.Track track) async {
    await ref.read(albumCoverProvider.notifier).fetchAlbumCoverForTrack(
      track.id,
      track.title,
      artist: track.artist,
      album: track.album,
    );
  }

  Future<void> _fetchLyricsForCurrentTrack(file_track.Track track) async {
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
        final lrcFile = dart_io.File('$basePath.lrc');
        if (await lrcFile.exists()) {
          final lrcContent = await lrcFile.readAsString();
          if (lrcContent.trim().isNotEmpty && lrcContent.contains('[')) {
            lyricsService.loadFromLrcContent(lrcContent);
            loaded = lyricsService.hasLyrics;
          }
        }
      } catch (_) {}
    }

    // ── 本地无歌词时走网络 ──────────────────────────────────────────────
    if (!loaded) {
      await lyricsService.fetchLyricsAuto(
        track.title,
        artist: track.artist,
        songId: track.id.isNotEmpty ? track.id : null,
        durationMs: track.duration?.inMilliseconds,
      );
    }
  }

  /// 自动开始播放本地音乐（随机全部）
  Future<void> _autoPlayLocalMusic() async {
    final audioService = ref.read(audioPlayerServiceProvider);
    // 如果已有曲目在播放，跳过
    if (audioService.currentTrack != null && audioService.state.isPlaying) return;

    final tracks = ref.read(unifiedTracksProvider);
    if (tracks.isEmpty) return;

    // 打乱顺序，从随机位置开始
    final shuffled = List<file_track.Track>.from(tracks);
    shuffled.shuffle(_random);
    final startIndex = _random.nextInt(shuffled.length);
    final startTrack = shuffled.removeAt(startIndex);
    // 将起始曲目放回列表开头
    shuffled.insert(0, startTrack);

    // 设置随机播放模式
    audioService.setPlayMode(PlayMode.shuffle);

    await audioService.playTrack(startTrack, playlist: shuffled);
    if (mounted) {
      _showFeedback('随机播放: ${startTrack.title}');
    }
  }

  IconData _getPlayModeIcon(PlayMode mode) {
    return switch (mode) {
      PlayMode.loop => Icons.repeat_rounded,
      PlayMode.one => Icons.repeat_one_rounded,
      PlayMode.shuffle => Icons.shuffle_rounded,
    };
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;
    final audioService = ref.read(audioPlayerServiceProvider);

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.of(context).pop();
      return;
    }

    // 菜单键 / F1 → 歌词搜索
    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.f1 ||
        key == LogicalKeyboardKey.keyM) {
      _showTvLyricsSearch();
      return;
    }

    // 遥控器多媒体键支持
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.mediaPlay ||
        key == LogicalKeyboardKey.mediaPause) {
      audioService.togglePlay();
      _showFeedback('播放/暂停');
      return;
    }
    
    if (key == LogicalKeyboardKey.mediaTrackNext) {
      audioService.next();
      _showFeedback('下一曲');
      return;
    }
    
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      audioService.previous();
      _showFeedback('上一曲');
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_currentFocusZone == 0) {
        _activateControlButton(_focusedControlIndex);
      } else if (_currentFocusZone == 1 && _isAdjustingProgress) {
        _isAdjustingProgress = false;
        _showFeedback('进度已调整');
      }
      return;
    }

    // 控制按钮区导航
    if (_currentFocusZone == 0) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _moveControlFocus(-1);
        return;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _moveControlFocus(1);
        return;
      }
      // 上键切换到进度条区
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _currentFocusZone = 1;
          _isAdjustingProgress = true;
          _focusedProgressValue = audioService.state.duration > 0
              ? audioService.state.currentPosition / audioService.state.duration
              : 0.0;
        });
        _extraFocusNodes[0].requestFocus();
        _showFeedback('上下键调整进度，确认键保存');
        return;
      }
    }

    // 进度条区导航
    if (_currentFocusZone == 1 && _isAdjustingProgress) {
      if (key == LogicalKeyboardKey.arrowLeft) {
        _adjustProgress(-0.05);
        return;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        _adjustProgress(0.05);
        return;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _currentFocusZone = 0;
          _isAdjustingProgress = false;
        });
        _controlFocusNodes[_focusedControlIndex].requestFocus();
        return;
      }
    }
  }

  void _moveControlFocus(int direction) {
    final newIndex = (_focusedControlIndex + direction).clamp(0, 5);
    if (newIndex != _focusedControlIndex) {
      setState(() => _focusedControlIndex = newIndex);
      _controlFocusNodes[newIndex].requestFocus();
    }
  }

  void _adjustProgress(double delta) {
    final audioService = ref.read(audioPlayerServiceProvider);
    setState(() {
      _focusedProgressValue = (_focusedProgressValue + delta).clamp(0.0, 1.0);
    });
    final positionMs = (_focusedProgressValue * audioService.state.duration).toInt();
    audioService.seek(Duration(milliseconds: positionMs));
  }

  void _showFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  void _activateControlButton(int index) {
    final audioService = ref.read(audioPlayerServiceProvider);
    switch (index) {
      case 0:
        audioService.togglePlayMode();
        break;
      case 1:
        audioService.previous();
        break;
      case 2:
        audioService.togglePlay();
        break;
      case 3:
        audioService.next();
        break;
      case 4:
        // 均衡器 — 跳转到均衡器设置页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const TvEqualizerPage()),
        );
        break;
      case 5:
        setState(() {
          final currentIndex = _allSpectrumModes.indexOf(_spectrumMode);
          _spectrumMode = _allSpectrumModes[(currentIndex + 1) % _allSpectrumModes.length];
        });
        break;
    }
  }

  String _getSpectrumModeName(AudioVisualizerMode mode) {
    return switch (mode) {
      AudioVisualizerMode.bars       => '条形频谱',
      AudioVisualizerMode.waveform   => '单线波形',
      AudioVisualizerMode.tiktok     => '双向线谱',
      AudioVisualizerMode.line       => '双层波形',
      AudioVisualizerMode.fountain   => '水柱喷泉',
      AudioVisualizerMode.catEar     => '环形频谱',
      AudioVisualizerMode.vinyl      => '黑胶唱片',
      AudioVisualizerMode.neonPulse => '霓虹脉冲',
      AudioVisualizerMode.waveRibbon => '波浪丝带',
      AudioVisualizerMode.particle   => '粒子爆发',
      AudioVisualizerMode.crystalPrism => '水晶棱镜',
      AudioVisualizerMode.ringPulse  => '环形脉冲',
      _                              => mode.name,
    };
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 构建控制按钮
  Widget _buildControlButton({
    required int index,
    required Color focusColor,
    required double size,
    required IconData icon,
    required double iconSize,
    required VoidCallback onPressed,
  }) {
    final isFocused = _currentFocusZone == 0 && _focusedControlIndex == index;
    
    return Focus(
      focusNode: _controlFocusNodes[index],
      onFocusChange: (focused) {
        if (focused) {
          setState(() {
            _currentFocusZone = 0;
            _focusedControlIndex = index;
          });
        }
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus || isFocused;
          
          return GestureDetector(
            onTap: onPressed,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasFocus 
                    ? focusColor.withValues(alpha: 0.25)
                    : (focusColor.withValues(alpha: 0.08)),
                border: Border.all(
                  color: hasFocus ? focusColor : focusColor.withValues(alpha: 0.3),
                  width: hasFocus ? 3 : 1.5,
                ),
                boxShadow: hasFocus 
                    ? [
                        BoxShadow(
                          color: focusColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: hasFocus ? focusColor : focusColor.withValues(alpha: 0.6),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkTrackChange();
    
    final audioService = ref.watch(audioPlayerServiceProvider);
    final playerState = audioService.state;
    final currentTrack = audioService.currentTrack;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final lyricsService = ref.watch(lyricsServiceProvider);
    final currentPosition = Duration(milliseconds: playerState.currentPosition);
    final primaryColor = Theme.of(context).primaryColor;
    final albumCoverState = ref.watch(albumCoverProvider);
    
    // 响应式缩放（支持 720p ~ 8K）
    final adapter = TvScreenAdapter.of(context);
    final scale = adapter.scale;
    final scaledSpacing = adapter.spacing(_cardSpacing);
    final scaledTextSize = adapter.sp(_bodyTextSize);
    final scaledIconSize = adapter.size(_iconSize);
    final scaledButtonSize = adapter.size(_controlButtonSize);
    final screenSize = MediaQuery.of(context).size;

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
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 全屏封面背景模糊效果
              CoverBlurBackground(
                localCoverPath: albumCoverState.localPath,
                coverBytes: albumCoverState.coverBytes,
                blurSigma: 40.0,
                overlayOpacity: isDarkMode ? 0.5 : 0.4,
                isDarkMode: isDarkMode,
              ),

              // 主内容区域
              SafeArea(
                bottom: false, // 让底部控制区域自己处理 SafeArea
                child: Column(
                  children: [
                    // ─── 顶部标题栏 ───────────────────────────────────────
                    Padding(
                      padding: EdgeInsets.all(scaledSpacing),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.headphones_rounded,
                                size: 40 * scale,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                              SizedBox(width: scaledSpacing * 0.5),
                              Text(
                                '正在播放',
                                style: TextStyle(
                                  fontSize: 32 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20 * scale,
                              vertical: 10 * scale,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: isDarkMode 
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04),
                            ),
                            child: Text(
                              _getCurrentTime(),
                              style: TextStyle(
                                fontSize: 24 * scale,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ─── 主体内容（左右分栏）────────────────────────────────
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: scaledSpacing),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch, // stretch 使左右子项高度一致，底部对齐
                          children: [
                            // ─── 左侧：封面(缩小) + 可视化(放大) ──────────────
                            SizedBox(
                              width: screenSize.width * 0.35,
                              child: Column(
                                children: [
                                  // 封面卡片（紧凑版）
                                  Container(
                                    padding: EdgeInsets.all(scaledSpacing * 0.6),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: isDarkMode
                                          ? Colors.white.withValues(alpha: 0.08)
                                          : Colors.black.withValues(alpha: 0.05),
                                      border: Border.all(
                                        color: isDarkMode
                                            ? Colors.white.withValues(alpha: 0.12)
                                            : Colors.black.withValues(alpha: 0.08),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // 封面图（缩小）
                                        Container(
                                          width: double.infinity,
                                          height: 140 * scale,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: LinearGradient(
                                              colors: [
                                                primaryColor.withValues(alpha: 0.6),
                                                primaryColor.withValues(alpha: 0.2),
                                              ],
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: _buildAlbumCover(
                                              albumCoverState,
                                              primaryColor,
                                              scale,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: scaledSpacing * 0.5),
                                        // 歌曲信息
                                        Text(
                                          currentTrack?.title ?? '未播放',
                                          style: TextStyle(
                                            fontSize: 22 * scale,
                                            fontWeight: FontWeight.w600,
                                            color: isDarkMode ? Colors.white : Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: scaledSpacing * 0.2),
                                        Text(
                                          currentTrack?.artist ?? '请选择歌曲播放',
                                          style: TextStyle(
                                            fontSize: 16 * scale,
                                            color: isDarkMode 
                                                ? Colors.white60 
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                  SizedBox(height: scaledSpacing * 0.6),
                                
                                  // ─── 频谱模式切换提示 ──────────────────────────
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 16 * scale,
                                      vertical: 8 * scale,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: primaryColor.withValues(alpha: 0.15),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.equalizer_rounded,
                                          size: 20 * scale,
                                          color: primaryColor,
                                        ),
                                        SizedBox(width: 8 * scale),
                                        Text(
                                          '可视化: ${_getSpectrumModeName(_spectrumMode)}',
                                          style: TextStyle(
                                            fontSize: 14 * scale,
                                            color: primaryColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(height: scaledSpacing * 0.6),
                                  
                                  // ─── 音频可视化（Expanded 占满剩余空间）──
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: isDarkMode
                                            ? Colors.black.withValues(alpha: 0.3)
                                            : Colors.white.withValues(alpha: 0.3),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: _buildVisualizerWidget(
                                          playerState.isPlaying,
                                          isDarkMode,
                                          primaryColor,
                                          scale,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(width: scaledSpacing * 1.5),

                            // ─── 右侧：歌词 ───────────────────────────
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                padding: EdgeInsets.all(scaledSpacing),
                                child: LyricsViewer(
                                  currentPosition: currentPosition,
                                  isDarkMode: isDarkMode,
                                  fixedHighlightPosition: 0.45,
                                  lineHeight: 30.0, // 固定行高
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ─── 底部控制区域 ─────────────────────────────
                    // 横向频谱条（穿透进度条上方）
                    Container(
                      height: 40 * scale,
                      child: ClipRect(
                        child: _buildHorizontalSpectrum(
                          playerState.isPlaying,
                          isDarkMode,
                          primaryColor,
                          scale,
                        ),
                      ),
                    ),
                    Container(
                      height: 220 * scale, // 加大控制栏高度
                      padding: EdgeInsets.symmetric(
                        horizontal: scaledSpacing,
                        vertical: scaledSpacing * 0.2, // 减小内边距，按钮更靠上
                      ),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center, // 垂直居中分配空间
                        children: [
                          // ─── 进度条 ───────────────────────────────────────
                          Focus(
                            focusNode: _extraFocusNodes[0],
                            onFocusChange: (focused) {
                              if (focused) {
                                setState(() {
                                  _currentFocusZone = 1;
                                  _isAdjustingProgress = true;
                                  _focusedProgressValue = playerState.duration > 0
                                      ? playerState.currentPosition / playerState.duration
                                      : 0.0;
                                });
                              }
                            },
                            child: Column(
                              children: [
                                // 进度提示
                                if (_currentFocusZone == 1 && _isAdjustingProgress)
                                  Container(
                                    margin: EdgeInsets.only(bottom: 4 * scale),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12 * scale,
                                      vertical: 4 * scale,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: primaryColor.withValues(alpha: 0.15),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.schedule_rounded, size: 14 * scale, color: primaryColor),
                                        SizedBox(width: 4 * scale),
                                        Text(
                                          '左右键调整进度',
                                          style: TextStyle(
                                            fontSize: 12 * scale,
                                            color: primaryColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                
                                // 进度条
                                SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: _currentFocusZone == 1 ? 10 : 6,
                                    thumbShape: RoundSliderThumbShape(
                                      enabledThumbRadius: (_currentFocusZone == 1 ? 14 : 10) * scale,
                                    ),
                                    overlayShape: RoundSliderOverlayShape(
                                      overlayRadius: (_currentFocusZone == 1 ? 22 : 16) * scale,
                                    ),
                                  ),
                                  child: Slider(
                                    value: _isAdjustingProgress && _currentFocusZone == 1
                                        ? _focusedProgressValue
                                        : (playerState.duration > 0
                                            ? (playerState.currentPosition / playerState.duration).clamp(0.0, 1.0)
                                            : 0.0),
                                    onChanged: (value) {
                                      final positionMs = (value * playerState.duration).toInt();
                                      audioService.seek(Duration(milliseconds: positionMs));
                                    },
                                    activeColor: primaryColor,
                                    inactiveColor: isDarkMode ? Colors.white24 : Colors.black12,
                                  ),
                                ),
                                
                                // 时间显示
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: scaledSpacing * 0.5),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(playerState.currentPosition),
                                        style: TextStyle(
                                          fontSize: scaledTextSize * 0.95,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(playerState.duration),
                                        style: TextStyle(
                                          fontSize: scaledTextSize * 0.95,
                                          fontWeight: FontWeight.w500,
                                          color: isDarkMode ? Colors.white60 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: scaledSpacing * 0.3),
                          
                          // ─── 控制按钮行 ─────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // 播放模式
                              _buildControlButton(
                                index: 0,
                                focusColor: Colors.purple,
                                size: scaledButtonSize * 0.8,
                                icon: _getPlayModeIcon(playerState.playMode),
                                iconSize: scaledIconSize * 0.45,
                                onPressed: () => audioService.togglePlayMode(),
                              ),
                              SizedBox(width: scaledSpacing * 0.8),
                              // 上一曲
                              _buildControlButton(
                                index: 1,
                                focusColor: Colors.orange,
                                size: scaledButtonSize * 0.8,
                                icon: Icons.skip_previous_rounded,
                                iconSize: scaledIconSize * 0.45,
                                onPressed: () => audioService.previous(),
                              ),
                              SizedBox(width: scaledSpacing * 0.8),
                              // 播放/暂停（最大按钮）
                              _buildControlButton(
                                index: 2,
                                focusColor: primaryColor,
                                size: scaledButtonSize * 1.15,
                                icon: playerState.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                iconSize: scaledIconSize * 0.6,
                                onPressed: () async {
                                  if (playerState.isPlaying) {
                                    audioService.pause();
                                  } else {
                                    // 如果当前没有播放曲目，自动从本地音乐列表播放
                                    if (currentTrack == null || playerState.playlistLength == 0) {
                                      final tracks = ref.read(unifiedTracksProvider);
                                      if (tracks.isNotEmpty) {
                                        await audioService.playTrack(tracks.first, playlist: tracks);
                                        _showFeedback('播放本地音乐: ${tracks.first.title}');
                                      } else {
                                        _showFeedback('本地音乐列表为空，请先扫描音乐');
                                      }
                                    } else {
                                      audioService.play();
                                    }
                                  }
                                },
                              ),
                              SizedBox(width: scaledSpacing * 0.8),
                              // 下一曲
                              _buildControlButton(
                                index: 3,
                                focusColor: Colors.teal,
                                size: scaledButtonSize * 0.8,
                                icon: Icons.skip_next_rounded,
                                iconSize: scaledIconSize * 0.45,
                                onPressed: () => audioService.next(),
                              ),
                              SizedBox(width: scaledSpacing * 0.8),
                              // 均衡器（跳转设置页）
                              _buildControlButton(
                                index: 4,
                                focusColor: Colors.amber,
                                size: scaledButtonSize * 0.8,
                                icon: Icons.tune_rounded,
                                iconSize: scaledIconSize * 0.45,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const TvEqualizerPage()),
                                  );
                                },
                              ),
                              SizedBox(width: scaledSpacing * 0.8),
                              // 频谱模式切换
                              _buildControlButton(
                                index: 5,
                                focusColor: Colors.green,
                                size: scaledButtonSize * 0.8,
                                icon: Icons.waves_rounded,
                                iconSize: scaledIconSize * 0.45,
                                onPressed: () {
                                  setState(() {
                                    final currentIndex = _allSpectrumModes.indexOf(_spectrumMode);
                                    final nextIndex = (currentIndex + 1) % _allSpectrumModes.length;
                                    _spectrumMode = _allSpectrumModes[nextIndex];
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildAlbumCover(AlbumCoverState state, Color primaryColor, double scale) {
    // 优先使用本地路径
    if (state.localPath != null) {
      return Image.file(
        dart_io.File(state.localPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildAlbumCoverPlaceholder(primaryColor, scale),
      );
    }
    // 其次使用内存字节（网络封面）
    if (state.coverBytes != null) {
      return Image.memory(
        state.coverBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildAlbumCoverPlaceholder(primaryColor, scale),
      );
    }
    // 加载中
    if (state.isLoading) {
      return Container(
        color: primaryColor.withValues(alpha: 0.15),
        child: Center(
          child: SizedBox(
            width: 40 * scale,
            height: 40 * scale,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }
    // 无封面占位
    return _buildAlbumCoverPlaceholder(primaryColor, scale);
  }

  Widget _buildAlbumCoverPlaceholder(Color primaryColor, double scale) {
    return Container(
      color: primaryColor.withValues(alpha: 0.15),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 80 * scale,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  /// TV 歌词搜索 — 弹出搜索对话框，输入关键词后在多平台搜索歌词
  Future<void> _showTvLyricsSearch() async {
    final audioService = ref.read(audioPlayerServiceProvider);
    final currentTrack = audioService.currentTrack;
    final scale = TvScreenAdapter.of(context).scale;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final titleController = TextEditingController(text: currentTrack?.title ?? '');
    final artistController = TextEditingController(text: currentTrack?.artist ?? '');
    final searchFocusNode = FocusNode();
    final buttonFocusNode = FocusNode();

    // 0=搜索按钮, 1=歌名输入框, 2=歌手输入框
    int focusedIndex = 0;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return KeyboardListener(
              focusNode: searchFocusNode,
              autofocus: true,
              onKeyEvent: (event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
                final key = event.logicalKey;

                if (key == LogicalKeyboardKey.escape ||
                    key == LogicalKeyboardKey.goBack ||
                    key == LogicalKeyboardKey.gameButtonB) {
                  Navigator.of(ctx).pop();
                  return;
                }

                if (key == LogicalKeyboardKey.arrowUp ||
                    key == LogicalKeyboardKey.arrowDown) {
                  setDialogState(() {
                    focusedIndex = (focusedIndex + 1) % 3;
                  });
                  if (focusedIndex == 0) {
                    buttonFocusNode.requestFocus();
                  } else if (focusedIndex == 1) {
                    searchFocusNode.requestFocus();
                  }
                  return;
                }

                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.select ||
                    key == LogicalKeyboardKey.gameButtonA) {
                  if (focusedIndex == 0) {
                    // 按下搜索按钮
                    final title = titleController.text.trim();
                    if (title.isNotEmpty) {
                      Navigator.of(ctx).pop(title);
                    }
                  } else if (focusedIndex == 1) {
                    // 歌名输入框获得焦点
                    searchFocusNode.requestFocus();
                  } else {
                    // 歌手输入框获得焦点（如果有需要可以添加）
                    searchFocusNode.requestFocus();
                  }
                  return;
                }
              },
              child: AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Row(
                  children: [
                    Icon(Icons.lyrics_rounded,
                        color: Theme.of(context).primaryColor, size: 32 * scale),
                    SizedBox(width: 12 * scale),
                    Text(
                      '搜索歌词',
                      style: TextStyle(
                        fontSize: 28 * scale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: 500 * scale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 歌名输入框
                      Focus(
                        onFocusChange: (hasFocus) {
                          if (hasFocus) setDialogState(() => focusedIndex = 1);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: focusedIndex == 1
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: TextField(
                          controller: titleController,
                          autofocus: true,
                          style: TextStyle(
                            fontSize: 22 * scale,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          decoration: InputDecoration(
                            labelText: '歌曲名称',
                            labelStyle: TextStyle(
                              fontSize: 18 * scale,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                            hintText: '输入歌曲名称',
                            hintStyle: TextStyle(
                              fontSize: 18 * scale,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: focusedIndex == 1
                                    ? Theme.of(context).primaryColor
                                    : (isDark ? Colors.white24 : Colors.black12),
                                width: focusedIndex == 1 ? 2 : 1,
                              ),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(
                                color: Theme.of(context).primaryColor,
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.music_note,
                                size: 22 * scale,
                                color: isDark ? Colors.white38 : Colors.black26),
                          ),
                        ),
                      ),
                      ),
                      SizedBox(height: 24 * scale),
                      // 歌手输入框
                      TextField(
                        controller: artistController,
                        style: TextStyle(
                          fontSize: 22 * scale,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          labelText: '歌手（可选）',
                          labelStyle: TextStyle(
                            fontSize: 18 * scale,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          hintText: '输入歌手名称',
                          hintStyle: TextStyle(
                            fontSize: 18 * scale,
                            color: isDark ? Colors.white38 : Colors.black26,
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: isDark ? Colors.white24 : Colors.black12,
                            ),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Theme.of(context).primaryColor,
                              width: 2,
                            ),
                          ),
                          suffixIcon: Icon(Icons.person,
                              size: 22 * scale,
                              color: isDark ? Colors.white38 : Colors.black26),
                        ),
                      ),
                      SizedBox(height: 32 * scale),
                      // 搜索按钮
                      Focus(
                        focusNode: buttonFocusNode,
                        onFocusChange: (hasFocus) {
                          if (hasFocus) setDialogState(() => focusedIndex = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: double.infinity,
                          height: 56 * scale,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: focusedIndex == 0
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: focusedIndex == 0
                                ? [
                                    BoxShadow(
                                      color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                                      blurRadius: 16,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final title = titleController.text.trim();
                              if (title.isNotEmpty) {
                                Navigator.of(ctx).pop(title);
                              }
                            },
                            icon: Icon(Icons.search, size: 26 * scale),
                            label: Text(
                              '搜索歌词',
                              style: TextStyle(fontSize: 20 * scale),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16 * scale),
                      // 提示
                      Text(
                        '↑↓ 切换焦点 · 确认键搜索 · 返回键关闭',
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchFocusNode.dispose();
    buttonFocusNode.dispose();

    // 如果用户输入了关键词，开始搜索
    if (result != null && result.isNotEmpty) {
      await _showTvLyricsCandidates(result, artistController.text.trim());
    }
  }

  /// TV 歌词候选选择 — 全屏对话框，支持遥控器上下导航
  Future<void> _showTvLyricsCandidates(String title, String artist) async {
    if (!mounted) return;

    final scale = TvScreenAdapter.of(context).scale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black45;

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Padding(
          padding: EdgeInsets.symmetric(vertical: 24 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: primaryColor),
              SizedBox(width: 20 * scale),
              Text(
                '正在搜索多平台歌词...',
                style: TextStyle(
                  fontSize: 20 * scale,
                  color: textColor,
                ),
              ),
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
      _showFeedback('未找到歌词，请尝试修改关键词');
      return;
    }

    // 显示候选列表
    if (!mounted) return;
    final selected = await showDialog<LyricsCandidate>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        int focusedIdx = 0;
        final scrollController = ScrollController();

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return KeyboardListener(
              autofocus: true,
              focusNode: FocusNode(),
              onKeyEvent: (event) {
                if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
                final key = event.logicalKey;

                if (key == LogicalKeyboardKey.escape ||
                    key == LogicalKeyboardKey.goBack ||
                    key == LogicalKeyboardKey.gameButtonB) {
                  Navigator.of(ctx).pop();
                  return;
                }

                if (key == LogicalKeyboardKey.arrowUp) {
                  if (focusedIdx > 0) {
                    setDialogState(() => focusedIdx--);
                    scrollController.animateTo(
                      focusedIdx * 80.0 * scale,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                  return;
                }

                if (key == LogicalKeyboardKey.arrowDown) {
                  if (focusedIdx < candidates.length - 1) {
                    setDialogState(() => focusedIdx++);
                    scrollController.animateTo(
                      (focusedIdx - 2) * 80.0 * scale,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                  return;
                }

                if (key == LogicalKeyboardKey.enter ||
                    key == LogicalKeyboardKey.select ||
                    key == LogicalKeyboardKey.gameButtonA) {
                  Navigator.of(ctx).pop(candidates[focusedIdx]);
                  return;
                }
              },
              child: Dialog(
                backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24 * scale),
                  child: SizedBox(
                    width: 700 * scale,
                    height: 500 * scale,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 标题
                        Row(
                          children: [
                            Icon(Icons.lyrics_rounded,
                                color: primaryColor, size: 28 * scale),
                            SizedBox(width: 12 * scale),
                            Text(
                              '选择歌词',
                              style: TextStyle(
                                fontSize: 26 * scale,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '共 ${candidates.length} 条结果',
                              style: TextStyle(
                                fontSize: 16 * scale,
                                color: subColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4 * scale),
                        Divider(color: isDark ? Colors.white12 : Colors.black12),
                        SizedBox(height: 8 * scale),
                        // 搜索信息
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12 * scale,
                            vertical: 6 * scale,
                          ),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 16 * scale, color: primaryColor),
                              SizedBox(width: 6 * scale),
                              Text(
                                '"$title"${artist.isNotEmpty ? " - $artist" : ""}',
                                style: TextStyle(
                                  fontSize: 14 * scale,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12 * scale),
                        // 候选列表
                        Expanded(
                          child: ListView.builder(
                            controller: scrollController,
                            itemCount: candidates.length,
                            itemExtent: 72 * scale,
                            itemBuilder: (context, index) {
                              final candidate = candidates[index];
                              final isFocused = index == focusedIdx;

                              final platformColor = switch (candidate.platform) {
                                'lrccx' => const Color(0xFF6B5B95),
                                'qq' => const Color(0xFF1DB954),
                                'netease' => const Color(0xFFE60026),
                                'kugou' => const Color(0xFF3498DB),
                                'kuwo' => const Color(0xFFE67E22),
                                _ => const Color(0xFF888888),
                              };

                              return GestureDetector(
                                onTap: () => Navigator.of(ctx).pop(candidate),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: EdgeInsets.symmetric(vertical: 3 * scale),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16 * scale,
                                    vertical: 8 * scale,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isFocused
                                        ? primaryColor.withValues(alpha: 0.15)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: isFocused
                                        ? Border.all(
                                            color: primaryColor.withValues(alpha: 0.4),
                                            width: 2,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      // 平台标记
                                      Container(
                                        width: 10 * scale,
                                        height: 10 * scale,
                                        decoration: BoxDecoration(
                                          color: platformColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 12 * scale),
                                      // 歌曲信息
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              candidate.title,
                                              style: TextStyle(
                                                fontSize: 18 * scale,
                                                fontWeight: isFocused
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                color: isFocused
                                                    ? primaryColor
                                                    : textColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            SizedBox(height: 4 * scale),
                                            Text(
                                              '${candidate.platformLabel} · ${candidate.artist}'
                                              '${candidate.album != null ? " · ${candidate.album}" : ""}',
                                              style: TextStyle(
                                                fontSize: 14 * scale,
                                                color: subColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      // 右侧信息
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (candidate.duration != null)
                                            Text(
                                              candidate.duration!,
                                              style: TextStyle(
                                                fontSize: 14 * scale,
                                                color: subColor,
                                              ),
                                            ),
                                          if (candidate.matchScore >= 60)
                                            Container(
                                              margin: EdgeInsets.only(top: 4 * scale),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6 * scale,
                                                vertical: 2 * scale,
                                              ),
                                              decoration: BoxDecoration(
                                                color: platformColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '${candidate.matchScore}%匹配',
                                                style: TextStyle(
                                                  fontSize: 12 * scale,
                                                  color: platformColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // 底部提示
                        Padding(
                          padding: EdgeInsets.only(top: 8 * scale),
                          child: Text(
                            '↑↓ 选择歌词 · 确认键应用 · 返回键取消',
                            style: TextStyle(
                              fontSize: 14 * scale,
                              color: isDark ? Colors.white38 : Colors.black26,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // 应用选择的歌词
    if (selected != null) {
      _showFeedback('正在加载${selected.platformLabel}歌词...');

      final success = await lyricsService.fetchLyricsFromCandidate(selected);
      if (mounted) {
        if (success) {
          _showFeedback('已加载 ${selected.platformLabel} 歌词: ${selected.title}');
        } else {
          _showFeedback('歌词加载失败: ${lyricsService.errorMessage ?? "未知错误"}');
        }
      }
    }
  }

  Widget _buildHint(IconData icon, String label, bool isDark) {
    final scale = TvScreenAdapter.of(context).scale;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18 * scale, color: isDark ? Colors.white54 : Colors.black38),
        SizedBox(width: 4 * scale),
        Text(
          label,
          style: TextStyle(
            fontSize: 14 * scale,
            color: isDark ? Colors.white54 : Colors.black38,
          ),
        ),
      ],
    );
  }

  /// 构建横向频谱条（穿透歌词/进度条上方显示）
  Widget _buildHorizontalSpectrum(bool isPlaying, bool isDarkMode, Color primaryColor, double scale) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AudioVisualizer(
          mode: AudioVisualizerMode.bars,
          barCount: 128, // 横向更多频谱条，更细腻
          isPlaying: isPlaying,
          color: primaryColor,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          smoothing: 0.8,
          spectrumStream: ref.read(audioPlayerServiceProvider).spectrumStream,
        );
      },
    );
  }

  /// 构建可视化区域（根据模式切换不同可视化效果）
  Widget _buildVisualizerWidget(bool isPlaying, bool isDarkMode, Color primaryColor, double scale) {
    // 使用 LayoutBuilder 获取父容器实际高度
    return LayoutBuilder(
      builder: (context, constraints) {
        final visHeight = constraints.maxHeight;

        switch (_spectrumMode) {
          case AudioVisualizerMode.fountain:
            return SizedBox(
              width: double.infinity,
              height: visHeight,
              child: LyricsWithFountain(
                spectrumData: _spectrumData,
                isPlaying: isPlaying,
                color: primaryColor,
                fountainHeight: visHeight,
                lyricsWidget: const SizedBox.shrink(),
              ),
            );
          case AudioVisualizerMode.catEar:
            return SizedBox(
              width: double.infinity,
              height: visHeight,
              child: CustomPaint(
                painter: _TvCatEarPainter(
                  spectrumData: _spectrumData,
                  isPlaying: isPlaying,
                  color: primaryColor,
                  phase: _phase,
                  particles: _particles,
                  showVinyl: false,
                  rotationAngle: _rotationAngle,
                ),
              ),
            );
          case AudioVisualizerMode.vinyl:
            return SizedBox(
              width: double.infinity,
              height: visHeight,
              child: CustomPaint(
                painter: _TvCatEarPainter(
                  spectrumData: _spectrumData,
                  isPlaying: isPlaying,
                  color: primaryColor,
                  phase: _phase,
                  particles: _particles,
                  showVinyl: true,
                  rotationAngle: _rotationAngle,
                ),
              ),
            );
          case AudioVisualizerMode.line:
            return SizedBox(
              width: double.infinity,
              height: visHeight,
              child: CustomPaint(
                painter: _TvWaveformLayerPainter(
                  data: _spectrumData,
                  isPlaying: isPlaying,
                  color: primaryColor,
                  phase: _phase,
                ),
              ),
            );
          default:
            return AudioVisualizer(
              mode: _spectrumMode,
              barCount: 64,
              isPlaying: isPlaying,
              color: primaryColor,
              width: double.infinity,
              height: visHeight,
              smoothing: 0.8,
              spectrumStream: ref.read(audioPlayerServiceProvider).spectrumStream,
            );
        }
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TV 端粒子类
// ═══════════════════════════════════════════════════════════════════════════
class _TvParticle {
  double x, y;
  double vx, vy;
  double life;
  double maxLife;
  double size;
  Color color;
  int type; // 0: 光点, 1: 拖尾, 2: 爆发

  _TvParticle({
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

// ═══════════════════════════════════════════════════════════════════════════
// TV 端环形频谱可视化器（适配横屏布局）
// showVinyl=false → 纯环形频谱（catEar 模式）
// showVinyl=true  → 黑胶唱片 + 频谱（vinyl 模式）
// ═══════════════════════════════════════════════════════════════════════════
class _TvCatEarPainter extends CustomPainter {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double phase;
  final List<_TvParticle> particles;
  final double rotationAngle;
  final bool showVinyl;

  _TvCatEarPainter({
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.phase = 0.0,
    List<_TvParticle>? particles,
    this.rotationAngle = 0.0,
    this.showVinyl = false,
  }) : particles = particles ?? [];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.5);
    // 调整比例：中心圆更大，条形更短
    final innerRadius = size.height * 0.30;
    final vinylRadius = showVinyl ? innerRadius * 2.0 : innerRadius * 1.15;
    final maxBarLength = size.height * 0.22;

    double energy = 0;
    if (spectrumData.isNotEmpty && isPlaying) {
      energy = spectrumData.reduce((a, b) => a + b) / spectrumData.length;
      energy = energy.clamp(0.0, 1.0);
    }

    if (!showVinyl) _drawEnergyField(canvas, size, center, energy);
    if (!showVinyl) _drawWaveBackground(canvas, size, center, energy);
    _drawParticles(canvas, size, center);
    _drawInnerGlow(canvas, center, innerRadius, energy);

    if (showVinyl) {
      _drawRotatingVinyl(canvas, center, innerRadius, rotationAngle);
    } else {
      _drawCenterCircle(canvas, center, innerRadius, energy);
    }

    _drawSpectrumBars(canvas, center, vinylRadius, maxBarLength, energy);
    _drawOrbitRings(canvas, center, vinylRadius, energy);
  }

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
      ).createShader(Rect.fromCircle(center: center, radius: size.height * 0.5));
    canvas.drawCircle(center, size.height * 0.5, fieldPaint);

    if (energy > 0.3) {
      for (int i = 0; i < 5; i++) {
        final angle = phase * 0.5 + i * pi * 2 / 5;
        final dist = size.height * (0.2 + 0.1 * sin(phase + i));
        final spotX = center.dx + cos(angle) * dist;
        final spotY = center.dy + sin(angle) * dist;
        final spotRadius = 15 + energy * 20;
        final spotPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              color.withAlpha((energy * 40).toInt()),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: Offset(spotX, spotY), radius: spotRadius));
        canvas.drawCircle(Offset(spotX, spotY), spotRadius, spotPaint);
      }
    }
  }

  void _drawWaveBackground(Canvas canvas, Size size, Offset center, double energy) {
    if (!isPlaying || energy < 0.15) return;
    final wavePaint = Paint()
      ..color = color.withAlpha(15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (int layer = 0; layer < 3; layer++) {
      final path = Path();
      final waveRadius = size.height * (0.35 + layer * 0.08);
      final wavePoints = 60;
      final layerPhase = phase + layer * 0.5;
      for (int i = 0; i <= wavePoints; i++) {
        final angle = i * 2 * pi / wavePoints;
        final waveOffset = sin(angle * 3 + layerPhase) * (8 + energy * 10);
        final r = waveRadius + waveOffset;
        final x = center.dx + cos(angle) * r;
        final y = center.dy + sin(angle) * r;
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      path.close();
      canvas.drawPath(path, wavePaint);
    }
  }

  void _drawParticles(Canvas canvas, Size size, Offset center) {
    for (final particle in particles) {
      if (!particle.isAlive) continue;
      final alpha = (particle.progress * 255).toInt();
      final currentSize = particle.size * particle.progress;
      if (particle.type == 0) {
        canvas.drawCircle(
          Offset(particle.x, particle.y),
          currentSize,
          Paint()
            ..color = particle.color.withAlpha(alpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2),
        );
      } else if (particle.type == 1) {
        canvas.drawLine(
          Offset(particle.x, particle.y),
          Offset(particle.x - particle.vx * 3, particle.y - particle.vy * 3),
          Paint()
            ..color = particle.color.withAlpha(alpha)
            ..strokeWidth = currentSize
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke,
        );
      } else {
        canvas.drawCircle(
          Offset(particle.x, particle.y),
          currentSize * 2,
          Paint()
            ..shader = RadialGradient(
              colors: [
                particle.color.withAlpha(alpha),
                particle.color.withAlpha(alpha ~/ 2),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: Offset(particle.x, particle.y), radius: currentSize * 2)),
        );
      }
    }
  }

  void _drawInnerGlow(Canvas canvas, Offset center, double radius, double energy) {
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
    for (int i = 0; i < 3; i++) {
      final pulseProgress = ((phase * 0.5 + i / 3) % 1.0);
      final pulseRadius = radius * (1.2 + pulseProgress * 0.8);
      final pulseAlpha = (energy * 40 * (1 - pulseProgress)).toInt();
      if (pulseAlpha > 0) {
        canvas.drawCircle(
          center,
          pulseRadius,
          Paint()
            ..color = color.withAlpha(pulseAlpha)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawCenterCircle(Canvas canvas, Offset center, double radius, double energy) {
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
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: [color.withAlpha(180), color.withAlpha(60), color.withAlpha(180)],
        startAngle: phase,
        endAngle: phase + 2 * pi,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(center, radius, ringPaint);
  }

  void _drawRotatingVinyl(Canvas canvas, Offset center, double innerRadius, double rotationAngle) {
    final vinylRadius = innerRadius * 2.2;
    canvas.drawCircle(center, vinylRadius, Paint()..color = Colors.black.withAlpha(220));

    // 唱片纹理
    final texturePaint = Paint()
      ..color = Colors.grey.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    for (int i = 0; i < 36; i++) {
      final angle = rotationAngle + i * pi / 18;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * vinylRadius * 0.7, center.dy + sin(angle) * vinylRadius * 0.7),
        Offset(center.dx + cos(angle) * vinylRadius, center.dy + sin(angle) * vinylRadius),
        texturePaint,
      );
    }

    // 标签
    canvas.drawCircle(
      center,
      vinylRadius * 0.3,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white.withAlpha(200), Colors.white.withAlpha(100), Colors.transparent],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: vinylRadius * 0.3)),
    );

    // 刻度
    for (int i = 0; i < 60; i++) {
      final angle = rotationAngle + i * pi / 30;
      canvas.drawCircle(
        Offset(center.dx + cos(angle) * vinylRadius, center.dy + sin(angle) * vinylRadius),
        1.5,
        Paint()..color = Colors.white.withAlpha(150)..style = PaintingStyle.stroke..strokeWidth = 1.0,
      );
    }

    // 封面区域
    canvas.drawCircle(
      center,
      vinylRadius * 0.6,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black.withAlpha(180), Colors.black.withAlpha(120), Colors.transparent],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: vinylRadius * 0.6)),
    );

    // 旋转光晕
    canvas.drawCircle(
      center,
      vinylRadius,
      Paint()
        ..shader = SweepGradient(
          colors: [Colors.white.withAlpha(80), Colors.transparent, Colors.white.withAlpha(80)],
          startAngle: rotationAngle,
          endAngle: rotationAngle + pi * 2,
        ).createShader(Rect.fromCircle(center: center, radius: vinylRadius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 中心孔
    canvas.drawCircle(center, vinylRadius * 0.1, Paint()..color = Colors.black.withAlpha(200));
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
      final smoothValue = value * 0.6 + prevValue * 0.2 + nextValue * 0.2;
      if (smoothValue < 0.02) continue;
      final waveOffset = sin(phase * 3 + i * 0.2) * 0.05;
      final animatedValue = (smoothValue + waveOffset).clamp(0.0, 1.0);
      final barLength = animatedValue * maxBarLength + 2;
      final angle = i * angleStep - pi / 2;
      final startX = center.dx + cos(angle) * innerRadius;
      final startY = center.dy + sin(angle) * innerRadius;
      final endX = center.dx + cos(angle) * (innerRadius + barLength);
      final endY = center.dy + sin(angle) * (innerRadius + barLength);
      final barWidth = 1.5 + animatedValue * 3.0;
      final hueShift = (i / barCount) * 60 + phase * 20;
      final baseHsl = HSLColor.fromColor(color);
      final barHue = (baseHsl.hue + hueShift) % 360;
      final barColor = HSLColor.fromAHSL(1.0, barHue, 0.85 + animatedValue * 0.15, 0.55 + animatedValue * 0.25).toColor();
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [barColor.withAlpha(200), barColor.withAlpha(255), HSLColor.fromAHSL(1.0, barHue, 0.3, 0.9).toColor().withAlpha(230)],
          ).createShader(Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)))
          ..strokeCap = StrokeCap.round
          ..strokeWidth = barWidth
          ..style = PaintingStyle.stroke,
      );
      if (animatedValue > 0.35) {
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          Paint()
            ..color = barColor.withAlpha((animatedValue * 100).toInt())
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + animatedValue * 5)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = barWidth * 2.5
            ..style = PaintingStyle.stroke,
        );
      }
      if (animatedValue > 0.2) {
        canvas.drawCircle(
          Offset(endX, endY),
          barWidth * 1.5,
          Paint()
            ..shader = RadialGradient(
              colors: [Colors.white.withAlpha((animatedValue * 220).toInt()), barColor.withAlpha((animatedValue * 150).toInt()), Colors.transparent],
            ).createShader(Rect.fromCircle(center: Offset(endX, endY), radius: barWidth * 1.5)),
        );
      }
    }
  }

  void _drawOrbitRings(Canvas canvas, Offset center, double innerRadius, double energy) {
    if (energy < 0.2) return;
    for (int ring = 0; ring < 2; ring++) {
      final orbitRadius = innerRadius * (1.8 + ring * 0.5);
      final orbitPaint = Paint()
        ..color = color.withAlpha((30 + energy * 30 - ring * 15).toInt())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      final dashCount = 60;
      for (int i = 0; i < dashCount; i++) {
        if (i % 2 == 0) {
          final startAngle = i * 2 * pi / dashCount + phase * (0.2 + ring * 0.1);
          canvas.drawArc(
            Rect.fromCircle(center: center, radius: orbitRadius),
            startAngle,
            pi / dashCount * 0.8,
            false,
            orbitPaint,
          );
        }
      }
      final dotAngle = phase * (1 + ring * 0.5) + ring * pi;
      canvas.drawCircle(
        Offset(center.dx + cos(dotAngle) * orbitRadius, center.dy + sin(dotAngle) * orbitRadius),
        6,
        Paint()
          ..shader = RadialGradient(colors: [color.withAlpha((energy * 200).toInt()), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(center.dx + cos(dotAngle) * orbitRadius, center.dy + sin(dotAngle) * orbitRadius), radius: 6)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TvCatEarPainter oldDelegate) {
    if (oldDelegate.isPlaying != isPlaying) return true;
    if (oldDelegate.color != color) return true;
    if ((oldDelegate.phase - phase).abs() > 0.01) return true;
    if (oldDelegate.showVinyl != showVinyl) return true;
    if ((oldDelegate.rotationAngle - rotationAngle).abs() > 0.01) return true;
    for (int i = 0; i < spectrumData.length && i < oldDelegate.spectrumData.length; i++) {
      if ((oldDelegate.spectrumData[i] - spectrumData[i]).abs() > 0.01) return true;
    }
    return oldDelegate.spectrumData.length != spectrumData.length;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TV 端双层波形 Painter（line 模式，适配横屏布局）
// ═══════════════════════════════════════════════════════════════════════════
class _TvWaveformLayerPainter extends CustomPainter {
  final List<double> data;
  final bool isPlaying;
  final Color color;
  final double phase;

  _TvWaveformLayerPainter({
    required this.data,
    required this.isPlaying,
    required this.color,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    // 后层（低频，宽幅柔和）
    _drawLayer(canvas, size,
      amplitudeScale: 0.85, phaseOffset: 0.6,
      colorAlphaTop: 0.35, colorAlphaBottom: 0.05,
      strokeAlpha: 0.30, strokeWidth: 3.0, blurSigma: 6.0, yBaseRatio: 0.55);
    // 前层（高频，清晰锐利）
    _drawLayer(canvas, size,
      amplitudeScale: 1.0, phaseOffset: 0.0,
      colorAlphaTop: 0.65, colorAlphaBottom: 0.08,
      strokeAlpha: 0.90, strokeWidth: 2.0, blurSigma: 3.5, yBaseRatio: 0.50);
  }

  void _drawLayer(Canvas canvas, Size size, {
    required double amplitudeScale, required double phaseOffset,
    required double colorAlphaTop, required double colorAlphaBottom,
    required double strokeAlpha, required double strokeWidth,
    required double blurSigma, required double yBaseRatio,
  }) {
    final n = data.length;
    if (n < 2) return;
    final baseLine = size.height * yBaseRatio;
    final maxAmp = size.height * 0.45 * amplitudeScale;

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final value = data[i];
      final yOffset = value * maxAmp * sin(pi * i / n + phase * pi + phaseOffset);
      final y = baseLine - yOffset.abs() * (isPlaying ? 1.0 : 0.15);
      points.add(Offset(x, y));
    }

    final path = _buildSmoothPath(points);

    // 面积填充
    final fillPath = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: colorAlphaTop), color.withValues(alpha: colorAlphaBottom)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill);

    // 发光描边
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: strokeAlpha * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 3
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma));

    // 主线（彩虹色渐变）
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft, end: Alignment.centerRight,
        colors: [color.withValues(alpha: strokeAlpha * 0.8), Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: strokeAlpha), color.withValues(alpha: strokeAlpha * 0.8)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeJoin = StrokeJoin.round);

    // 波峰高亮圆点
    if (isPlaying) {
      for (int i = 0; i < points.length; i++) {
        final value = data[i];
        if (value < 0.72) continue;
        final intensity = (value - 0.72) / 0.28;
        canvas.drawCircle(points[i], 3.0 * intensity + 1, Paint()
          ..color = Colors.white.withValues(alpha: 0.85 * intensity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * intensity));
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
      path.cubicTo(
        p1.dx + (p2.dx - p0.dx) / 6.0, p1.dy + (p2.dy - p0.dy) / 6.0,
        p2.dx - (p3.dx - p1.dx) / 6.0, p2.dy - (p3.dy - p1.dy) / 6.0,
        p2.dx, p2.dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _TvWaveformLayerPainter old) {
    return old.isPlaying != isPlaying || old.color != color || (old.phase - phase).abs() > 0.01 || old.data.length != data.length;
  }
}
