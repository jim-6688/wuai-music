import 'dart:async';
import 'dart:math';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';
import '../../files/data/models/track.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'audio_visualizer_service.dart';

/// 播放状态枚举
enum PlaybackState {
  idle,      // 未初始化
  loading,   // 加载中
  playing,   // 播放中
  paused,    // 暂停
  stopped,   // 停止
  error,     // 错误
}

/// 播放模式枚举
enum PlayMode {
  loop,      // 列表循环
  one,       // 单曲循环
  shuffle,   // 随机播放
}

/// 播放器状态数据类
class AudioPlayerState extends Equatable {
  final PlaybackState playbackState;
  final PlayMode playMode;
  final int currentPosition;
  final int duration;
  final double volume;
  final double playbackSpeed;
  final bool isLoading;
  final String? errorMessage;
  final int currentIndex;
  final int playlistLength;

  const AudioPlayerState({
    this.playbackState = PlaybackState.idle,
    this.playMode = PlayMode.loop,
    this.currentPosition = 0,
    this.duration = 0,
    this.volume = 0.8,
    this.playbackSpeed = 1.0,
    this.isLoading = false,
    this.errorMessage,
    this.currentIndex = 0,
    this.playlistLength = 0,
  });

  bool get isPlaying => playbackState == PlaybackState.playing;
  bool get isPaused => playbackState == PlaybackState.paused;

  double get progress {
    if (duration == 0) return 0.0;
    return (currentPosition / duration).clamp(0.0, 1.0);
  }

  AudioPlayerState copyWith({
    PlaybackState? playbackState,
    PlayMode? playMode,
    int? currentPosition,
    int? duration,
    double? volume,
    double? playbackSpeed,
    bool? isLoading,
    String? errorMessage,
    int? currentIndex,
    int? playlistLength,
  }) {
    return AudioPlayerState(
      playbackState: playbackState ?? this.playbackState,
      playMode: playMode ?? this.playMode,
      currentPosition: currentPosition ?? this.currentPosition,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      currentIndex: currentIndex ?? this.currentIndex,
      playlistLength: playlistLength ?? this.playlistLength,
    );
  }

  @override
  List<Object?> get props => [
    playbackState,
    playMode,
    currentPosition,
    duration,
    volume,
    playbackSpeed,
    isLoading,
    errorMessage,
    currentIndex,
    playlistLength,
  ];
}

/// 音频播放器服务
class AudioPlayerService extends ChangeNotifier {
  late final AudioPlayer _audioPlayer;
  AudioPlayerState _state = const AudioPlayerState();
  final List<Track> _playlist = [];
  int _currentIndex = 0;

  /// 当播放的 Track 的 filePath 为空时，调用此回调尝试获取 URL
  /// 返回非空 URL 表示成功获取，返回 null 表示无法获取
  Future<String?> Function(String trackId)? onUrlMissing;

  /// 当检测到 NAS 虚拟路径 (smb://) 时，调用此回调获取本地缓存路径
  /// 返回非空路径表示缓存成功，返回 null 表示无法缓存
  Future<String?> Function(Track track)? onNasPathDetected;

  // 频谱相关
  final StreamController<List<double>> _spectrumController =
      StreamController<List<double>>.broadcast();
  Timer? _spectrumTimer;
  final Random _random = Random();

  // 防止播放完成回调重入
  bool _isHandlingCompletion = false;
  // 上一次检测到完成时的 position，用于去重
  int _lastCompletedPosition = -1;

  /// 频谱数据流（供 UI 订阅）
  Stream<List<double>> get spectrumStream => _spectrumController.stream;

  AudioPlayerState get state => _state;
  List<Track> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;

  /// 当前播放的完整 Track 对象
  Track? get currentTrack {
    if (_playlist.isEmpty || _currentIndex < 0 || _currentIndex >= _playlist.length) {
      return null;
    }
    return _playlist[_currentIndex];
  }

  AudioPlayerService() {
    _audioPlayer = AudioPlayer();
    _initializeListeners();
  }

  void _initializeListeners() {
    // ── 播放状态 + 频谱 ──────────────────────────────────────────────────────
    _audioPlayer.playerStateStream.listen((playerState) {
      _updatePlaybackState(playerState);
      if (playerState.playing) {
        _startSpectrumSimulation();
        // 开始新曲播放时清除完成保护
        _isHandlingCompletion = false;
        _lastCompletedPosition = -1;
      } else {
        _stopSpectrumSimulation();
      }
    });

    // ── 播放完成检测（唯一触发源：playbackEventStream）────────────────────────
    // 使用 playbackEventStream 而非 playerStateStream，因为它在
    // processingState=completed 时只触发一次，不存在多次回调的竞态问题。
    _audioPlayer.playbackEventStream.listen((event) {
      if (event.processingState == ProcessingState.completed) {
        // 用 updatePosition 的毫秒数做去重 key，防止同一 position 重复触发
        final pos = event.updatePosition.inMilliseconds;
        if (_isHandlingCompletion && pos == _lastCompletedPosition) {
          if (kDebugMode) print('⚠️ 重复的 completed 事件，已忽略 pos=$pos');
          return;
        }
        _isHandlingCompletion = true;
        _lastCompletedPosition = pos;
        if (kDebugMode) print('✅ [事件流] 检测到播放完成 pos=$pos，准备切下一曲');
        // 延迟一帧执行，避免在事件流回调里直接 setAudioSource 导致死锁
        Future.microtask(_onPlaybackCompleted);
      }
    }, onError: (e) {
      if (kDebugMode) print('❌ 播放事件流错误: $e');
    });

    _audioPlayer.positionStream.listen((position) {
      _updatePosition(position);
    });

    _audioPlayer.durationStream.listen((duration) {
      _updateDuration(duration);
    });

    _audioPlayer.volumeStream.listen((volume) {
      _updateVolume(volume);
    });

    _audioPlayer.speedStream.listen((speed) {
      _updatePlaybackSpeed(speed);
    });
  }

  void _updatePlaybackState(PlayerState playerState) {
    final isPlaying = playerState.playing;
    final processingState = playerState.processingState;

    final newPlaybackState = isPlaying
        ? PlaybackState.playing
        : PlaybackState.paused;

    _state = _state.copyWith(
      playbackState: newPlaybackState,
      isLoading: processingState == ProcessingState.loading,
    );
    notifyListeners();
  }

  void _updatePosition(Duration position) {
    _state = _state.copyWith(
      currentPosition: position.inMilliseconds,
    );
    notifyListeners();
  }

  void _updateDuration(Duration? duration) {
    _state = _state.copyWith(
      duration: duration?.inMilliseconds ?? 0,
    );
    notifyListeners();
  }

  void _updateVolume(double volume) {
    _state = _state.copyWith(volume: volume);
    notifyListeners();
  }

  void _updatePlaybackSpeed(double speed) {
    _state = _state.copyWith(playbackSpeed: speed);
    notifyListeners();
  }

  Future<void> _onPlaybackCompleted() async {
    if (kDebugMode) print('✅ 播放完成，准备下一曲，当前模式: ${_state.playMode}');

    if (_playlist.isEmpty) {
      if (kDebugMode) print('⚠️ 播放列表为空，无法继续播放');
      _isHandlingCompletion = false;
      _lastCompletedPosition = -1;
      return;
    }

    try {
      switch (_state.playMode) {
        case PlayMode.loop:
          // 列表循环模式
          final nextIdx = (_currentIndex < _playlist.length - 1)
              ? _currentIndex + 1
              : 0;
          if (kDebugMode) print('⏭️ 列表循环 - 下一曲: $nextIdx');
          await _playAtIndex(nextIdx);
          break;

        case PlayMode.one:
          // 单曲循环模式：seek 回头再 play，不调 setAudioSource
          if (kDebugMode) print('🔂 单曲循环 - 重新播放当前曲目');
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
          // 单曲循环播放成功后也要重置标志
          _isHandlingCompletion = false;
          _lastCompletedPosition = -1;
          break;

        case PlayMode.shuffle:
          // 随机播放模式
          if (_playlist.length == 1) {
            await _audioPlayer.seek(Duration.zero);
            await _audioPlayer.play();
            _isHandlingCompletion = false;
            _lastCompletedPosition = -1;
          } else {
            int nextIndex;
            do {
              nextIndex = _random.nextInt(_playlist.length);
            } while (nextIndex == _currentIndex && _playlist.length > 1);
            if (kDebugMode) print('🔀 随机播放: $nextIndex');
            await _playAtIndex(nextIndex);
          }
          break;
      }
    } catch (e) {
      if (kDebugMode) print('❌ 自动播放下一曲失败: $e');
      // 发生异常时重置标志，避免永久卡死
      _isHandlingCompletion = false;
      _lastCompletedPosition = -1;
    }
  }

  Future<void> setPlaylist(List<Track> playlist) async {
    try {
      _playlist.clear();
      _playlist.addAll(playlist);
      _currentIndex = 0;

      _state = _state.copyWith(
        playlistLength: playlist.length,
        currentIndex: 0,
      );
      notifyListeners();
    } catch (e) {
      _handleError('设置播放列表失败: $e');
    }
  }

  /// 播放指定曲目并设置播放列表
  Future<void> playTrack(Track track, {List<Track>? playlist}) async {
    try {
      if (kDebugMode) {
        print('🎵 [AudioPlayerService] playTrack: ${track.title}');
        print('   filePath: ${track.filePath}');
        print('   playlist length: ${playlist?.length ?? 0}');
      }

      // 设置播放列表
      if (playlist != null && playlist.isNotEmpty) {
        _playlist.clear();
        _playlist.addAll(playlist);

        // 找到指定曲目的索引
        _currentIndex = playlist.indexWhere((t) => t.id == track.id);
        if (_currentIndex < 0) {
          _currentIndex = 0;
        }
      } else {
        // 单曲播放
        _playlist.clear();
        _playlist.add(track);
        _currentIndex = 0;
      }

      _state = _state.copyWith(
        playlistLength: _playlist.length,
        currentIndex: _currentIndex,
      );

      await _playAtIndex(_currentIndex);
    } catch (e) {
      if (kDebugMode) print('❌ [AudioPlayerService] playTrack 失败: $e');
      _handleError('播放曲目失败: $e');
    }
  }

  /// 播放单个曲目（用于NAS等外部文件）
  Future<void> _playSingleTrack(Track track) async {
    try {
      _playlist.clear();
      _playlist.add(track);
      _currentIndex = 0;

      _state = _state.copyWith(
        playlistLength: 1,
        currentIndex: 0,
      );

      await _playAtIndex(0);
    } catch (e) {
      _handleError('播放曲目失败: $e');
    }
  }

  Future<void> _playAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) {
      _handleError('播放索引超出范围');
      return;
    }

    try {
      _currentIndex = index;
      _state = _state.copyWith(
        currentIndex: index,
        playbackState: PlaybackState.loading,
        errorMessage: null,
      );
      notifyListeners();

      final track = _playlist[index];
      var filePath = track.filePath;

      // ─── NAS 虚拟路径处理 ──────────────────────────────────────────────────
      if (filePath.startsWith('smb://')) {
        if (kDebugMode) print('📂 检测到 NAS 路径: $filePath');
        // 通过回调获取可播放的本地缓存路径
        if (onNasPathDetected != null) {
          try {
            final cachedPath = await onNasPathDetected!(track);
            if (cachedPath != null && cachedPath.isNotEmpty) {
              filePath = cachedPath;
              if (kDebugMode) print('✅ NAS 文件已缓存: $cachedPath');
            } else {
              throw Exception('无法获取 NAS 文件缓存路径');
            }
          } catch (e) {
            if (kDebugMode) print('❌ NAS 文件缓存失败: $e');
            _handleError('无法播放 NAS 文件: $e');
            return;
          }
        } else {
          _handleError('NAS 播放服务未初始化');
          return;
        }
      }
      // ────────────────────────────────────────────────────────────────────────

      // URL 为空时，尝试通过回调获取（如网易云API懒加载）
      if (filePath.isEmpty) {
        if (onUrlMissing != null) {
          try {
            final fetchedUrl = await onUrlMissing!(track.id);
            if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
              filePath = fetchedUrl;
              // 更新播放列表中该曲目的 URL
              _playlist[index] = track.copyWith(filePath: fetchedUrl);
              if (kDebugMode) print('🔗 懒加载URL成功: ${track.title}');
            }
          } catch (e) {
            if (kDebugMode) print('⚠️ 懒加载URL失败: $e');
          }
        }

        // 仍然为空则跳过
        if (filePath.isEmpty) {
          if (kDebugMode) print('⏩ 跳过空URL曲目: ${track.title}，尝试下一首');
          final nextIdx = (index + 1) % _playlist.length;
          if (nextIdx != index) {
            await _playAtIndex(nextIdx);
          }
          return;
        }
      }

      if (kDebugMode) {
        print('🎵 播放: ${track.title}');
        print('   原始路径: $filePath');
      }

      // 处理 content:// URI 转换为 file:// URI
      Uri audioUri;
      if (filePath.startsWith('content://')) {
        // Android MediaStore URI，转换为 file:// 路径
        // 尝试解析为真实文件路径
        if (filePath.contains('com.android.providers.media.documents')) {
          // MediaStore Documents Provider 格式
          // 需要从 document_id 解析真实路径
          audioUri = Uri.parse(filePath);
        } else {
          // 标准的 content://media/... URI
          // just_audio 可以直接使用 content:// URI
          audioUri = Uri.parse(filePath);
        }
        if (kDebugMode) print('   Content URI: $audioUri');
      } else if (filePath.startsWith('/')) {
        // 本地文件路径，转换为 file:// URI
        audioUri = Uri.file(filePath);
        if (kDebugMode) print('   文件 URI: $audioUri');
      } else {
        // 其他格式，直接使用
        audioUri = Uri.parse(filePath);
      }

      // 使用 AudioSource，设置优先使用 Android 的 MediaDataSource
      // albumArt 需转为 URI 字符串：本地路径 → file:// URI
      String? albumArtUri = track.albumArt;
      if (albumArtUri != null &&
          albumArtUri.isNotEmpty &&
          !albumArtUri.startsWith('http') &&
          !albumArtUri.startsWith('content://') &&
          !albumArtUri.startsWith('file://')) {
        albumArtUri = Uri.file(albumArtUri).toString();
      }

      final audioSource = AudioSource.uri(
        audioUri,
        tag: <String, dynamic>{
          'id': track.id,
          'title': track.title,
          'artist': track.artist,
          'album': track.album,
          'artUri': albumArtUri,
        },
      );

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      
      // 播放成功，重置完成处理标志
      _isHandlingCompletion = false;
    } catch (e) {
      final msg = '播放失败: ${_friendlyError(e)}';
      if (kDebugMode) print('❌ $msg');
      _isHandlingCompletion = false;
      _state = _state.copyWith(
        playbackState: PlaybackState.error,
        errorMessage: msg,
      );
      notifyListeners();
    }
  }

  /// 友好的错误信息
  String _friendlyError(Object e) {
    if (e is PlatformException) {
      final code = e.code;
      final msg = e.message ?? '';

      if (code == 'ERROR_IO' || msg.contains('No such file')) {
        return '文件不存在或无法访问';
      }
      if (code == 'ERROR_PERMISSION_DENIED' || msg.contains('permission')) {
        return '无播放权限，请检查存储权限';
      }
      if (code == 'ERROR_FORMAT_NOT_SUPPORTED' || msg.contains('unsupported')) {
        return '不支持的文件格式';
      }
      if (msg.contains('content://') || code == 'ERROR_DECODING') {
        return '文件无法解码，请尝试其他文件';
      }
      return msg.isNotEmpty ? msg : '未知错误 ($code)';
    }
    return e.toString();
  }

  Future<void> play() async {
    try {
      if (_playlist.isEmpty) {
        _handleError('播放列表为空，请先扫描音乐');
        return;
      }

      if (_state.playbackState == PlaybackState.paused) {
        await _audioPlayer.play();
      } else if (_state.playbackState == PlaybackState.idle ||
                 _state.playbackState == PlaybackState.stopped) {
        await _playAtIndex(_currentIndex >= 0 ? _currentIndex : 0);
      }
    } catch (e) {
      _handleError('播放失败: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
    } catch (e) {
      _handleError('暂停失败: $e');
    }
  }

  /// 切换播放/暂停状态
  Future<void> togglePlay() async {
    try {
      if (_state.isPlaying) {
        await pause();
      } else {
        await play();
      }
    } catch (e) {
      _handleError('切换播放状态失败: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _state = _state.copyWith(
        playbackState: PlaybackState.stopped,
        currentPosition: 0,
      );
      notifyListeners();
    } catch (e) {
      _handleError('停止失败: $e');
    }
  }

  Future<void> previous() async {
    try {
      if (kDebugMode) print('⏮️ 上一曲: currentIndex=$_currentIndex, playlistLength=${_playlist.length}, playMode=${_state.playMode}');
      
      // 手动切歌时重置完成标志
      _isHandlingCompletion = false;
      _lastCompletedPosition = -1;
      
      if (_playlist.isEmpty) {
        if (kDebugMode) print('⚠️ 播放列表为空');
        return;
      }
      
      if (_playlist.length == 1) {
        // 只有一个曲目，重新播放
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        return;
      }
      
      // 随机播放模式下，上一曲也是随机的（或者可以选择上一首播放历史）
      // 此处简化为随机选择
      switch (_state.playMode) {
        case PlayMode.shuffle:
          // 随机播放模式：随机选择一首不是当前的
          int nextIndex;
          do {
            nextIndex = _random.nextInt(_playlist.length);
          } while (nextIndex == _currentIndex);
          if (kDebugMode) print('🔀 随机上一曲: $nextIndex');
          await _playAtIndex(nextIndex);
          break;
          
        case PlayMode.loop:
          // 列表循环模式
          if (_currentIndex > 0) {
            await _playAtIndex(_currentIndex - 1);
          } else {
            await _playAtIndex(_playlist.length - 1);
          }
          break;
          
        case PlayMode.one:
          // 单曲循环模式：重新播放当前曲目
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
          break;
      }
    } catch (e) {
      _handleError('上一首失败: $e');
    }
  }

  Future<void> next() async {
    try {
      if (kDebugMode) print('⏭️ 下一曲: currentIndex=$_currentIndex, playlistLength=${_playlist.length}, playMode=${_state.playMode}');
      
      // 手动切歌时重置完成标志
      _isHandlingCompletion = false;
      _lastCompletedPosition = -1;
      
      if (_playlist.isEmpty) {
        if (kDebugMode) print('⚠️ 播放列表为空');
        _handleError('播放列表为空，请先选择歌曲播放');
        return;
      }
      
      if (_playlist.length == 1) {
        if (kDebugMode) print('⚠️ 播放列表只有一首，重新播放当前曲目');
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        return;
      }
      
      // 根据播放模式选择下一首
      int nextIndex;
      switch (_state.playMode) {
        case PlayMode.shuffle:
          // 随机播放模式：随机选择一首不是当前的
          do {
            nextIndex = _random.nextInt(_playlist.length);
          } while (nextIndex == _currentIndex);
          if (kDebugMode) print('🔀 随机下一曲: $nextIndex');
          await _playAtIndex(nextIndex);
          break;
          
        case PlayMode.loop:
          // 列表循环模式
          if (_currentIndex < _playlist.length - 1) {
            await _playAtIndex(_currentIndex + 1);
          } else {
            await _playAtIndex(0);
          }
          break;
          
        case PlayMode.one:
          // 单曲循环模式：重新播放当前曲目
          if (kDebugMode) print('🔂 单曲循环，重新播放');
          await _audioPlayer.seek(Duration.zero);
          await _audioPlayer.play();
          break;
      }
    } catch (e, stack) {
      if (kDebugMode) print('❌ 下一首失败: $e\n$stack');
      _handleError('下一首失败: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _handleError('跳转失败: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    try {
      final clampedVolume = volume.clamp(0.0, 1.0);
      await _audioPlayer.setVolume(clampedVolume);
    } catch (e) {
      _handleError('设置音量失败: $e');
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      final clampedSpeed = speed.clamp(0.5, 2.0);
      await _audioPlayer.setSpeed(clampedSpeed);
    } catch (e) {
      _handleError('设置播放速度失败: $e');
    }
  }

  void togglePlayMode() {
    final modes = [PlayMode.loop, PlayMode.one, PlayMode.shuffle];
    final currentModeIndex = modes.indexOf(_state.playMode);
    final nextModeIndex = (currentModeIndex + 1) % modes.length;
    
    final newMode = modes[nextModeIndex];
    if (kDebugMode) print('🔄 播放模式切换: ${_state.playMode} → $newMode');

    _state = _state.copyWith(playMode: newMode);
    notifyListeners();
  }

  void setPlayMode(PlayMode mode) {
    if (kDebugMode) print('📍 设置播放模式: $mode');
    _state = _state.copyWith(playMode: mode);
    notifyListeners();
  }

  /// 更新播放列表中指定 id 的 Track URL（供后台预取使用）
  void updateTrackUrl(String trackId, String newUrl) {
    final idx = _playlist.indexWhere((t) => t.id == trackId);
    if (idx < 0) return;
    final old = _playlist[idx];
    _playlist[idx] = Track(
      id: old.id,
      title: old.title,
      artist: old.artist,
      album: old.album,
      filePath: newUrl,
      duration: old.duration,
      albumArt: old.albumArt,
    );
    if (kDebugMode) print('🔗 已更新队列中 ${old.title} 的 URL');
    notifyListeners();
  }

  void _handleError(String message) {
    if (kDebugMode) {
      print('❌ AudioPlayerService Error: $message');
    }

    _state = _state.copyWith(
      playbackState: PlaybackState.error,
      errorMessage: message,
    );
    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(
      errorMessage: null,
      playbackState: PlaybackState.idle,
    );
    notifyListeners();
  }

  // ─── 频谱数据 ───────────────────────────────────────────────────────────────

  /// 启动频谱（播放时调用）
  /// 优先使用原生 Visualizer API 获取真实数据，失败则回退到模拟数据
  void _startSpectrumSimulation() async {
    // 尝试启动原生可视化器
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final visualizerService = AudioVisualizerService.instance;
        
        // 先尝试用 0（UNIVERSAL）启动，如果失败再尝试其他方式
        final success = await visualizerService.start();
        
        if (success) {
          // 监听真实频谱数据
          visualizerService.spectrumStream.listen((data) {
            if (!_spectrumController.isClosed) {
              _spectrumController.add(data);
            }
          });
          if (kDebugMode) print('✅ 原生可视化器已启动');
          return; // 原生启动成功，不使用模拟
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ 原生可视化器启动失败，使用模拟数据: $e');
      }
    }
    
    // 回退到模拟数据
    _spectrumTimer?.cancel();
    _spectrumTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!_spectrumController.isClosed) {
        _spectrumController.add(_generateSimulatedSpectrum());
      }
    });
  }

  /// 停止频谱
  void _stopSpectrumSimulation() async {
    // 停止模拟定时器
    _spectrumTimer?.cancel();
    _spectrumTimer = null;
    
    // 停止原生可视化器
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await AudioVisualizerService.instance.stop();
      } catch (e) {
        // 忽略
      }
    }
    
    // 发送静音频谱
    if (!_spectrumController.isClosed) {
      _spectrumController.add(List.filled(32, 0.0));
    }
  }

  /// 生成模拟频谱数据（32 个频带）
  /// 模拟真实音乐的频谱分布：低频能量高，高频能量低
  List<double> _generateSimulatedSpectrum() {
    final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
    const bandCount = 32;

    return List.generate(bandCount, (i) {
      // 基础频谱形状：低频高、高频低（对数分布）
      final baseLevel = exp(-i * 0.08) * 0.7;

      // 节拍模拟：低频周期性脉冲
      final beat = (i < 4)
          ? max(0.0, sin(t * 2.5 * pi) * 0.5)
          : 0.0;

      // 中频旋律线
      final melody = (i >= 4 && i < 16)
          ? max(0.0, sin(t * 1.8 * pi + i * 0.4) * 0.3)
          : 0.0;

      // 高频细节
      final detail = (i >= 16)
          ? max(0.0, sin(t * 3.2 * pi + i * 0.7) * 0.15)
          : 0.0;

      // 随机抖动
      final noise = _random.nextDouble() * 0.1;

      return (baseLevel + beat + melody + detail + noise).clamp(0.0, 1.0);
    });
  }

  @override
  Future<void> dispose() async {
    _spectrumTimer?.cancel();
    await _spectrumController.close();
    await _audioPlayer.dispose();
    super.dispose();
  }
}
