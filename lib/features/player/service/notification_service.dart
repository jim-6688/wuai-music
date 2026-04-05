import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart' as audio_service;
import '../service/audio_player_service.dart';

/// 通知栏服务
/// 
/// 负责管理通知栏和锁屏控件，包括：
/// - MediaSession 配置
/// - 通知栏显示和控制
/// - 后台播放支持
/// - 锁屏控件
class NotificationService extends ChangeNotifier {
  /// 音频处理器
  late final audio_service.AudioHandler _audioHandler;
  
  /// 播放器服务引用
  AudioPlayerService? _playerService;
  
  /// 是否已初始化
  bool _isInitialized = false;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 构造函数
  NotificationService();

  /// 初始化通知栏服务
  /// 
  /// 配置 MediaSession 并连接到音频服务
  Future<void> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) {
        print('⚠️ NotificationService 已初始化，跳过');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('🔔 初始化通知栏服务...');
      }

      // 创建自定义音频处理器
      _audioHandler = await audio_service.AudioService.init(
        builder: () => WuaiMusicAudioHandler(),
        config: const audio_service.AudioServiceConfig(
          // Android 配置
          androidNotificationChannelId: 'com.wuaimusic.player.audio',
          androidNotificationChannelName: '吾爱Music 播放',
          androidNotificationChannelDescription: '音乐播放器通知',
          androidNotificationOngoing: true,
          androidNotificationIcon: 'drawable/ic_notification',
          
          // 任务配置
          androidStopForegroundOnPause: true,
        ),
      );

      _isInitialized = true;
      
      if (kDebugMode) {
        print('✅ 通知栏服务初始化完成');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 通知栏服务初始化失败: $e');
      }
      rethrow;
    }
  }

  /// 连接到播放器服务
  void connectToPlayer(AudioPlayerService playerService) {
    _playerService = playerService;
    
    // 监听播放器状态变化
    playerService.addListener(_onPlayerStateChanged);
  }

  /// 断开播放器连接
  void disconnect() {
    if (_playerService != null) {
      _playerService!.removeListener(_onPlayerStateChanged);
      _playerService = null;
    }
  }

  /// 播放器状态变化回调
  void _onPlayerStateChanged() {
    if (_playerService == null || !_isInitialized) return;

    // _playerService!.state;
    // 更新 MediaSession 状态
    // 注意：由于使用了自定义 AudioHandler，
    // 状态更新会自动通过 AudioHandler 处理
  }

  /// 更新通知栏显示
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [album] 专辑
  /// [isPlaying] 是否正在播放
  Future<void> updateNotification({
    required String title,
    required String artist,
    required String album,
    required bool isPlaying,
  }) async {
    if (!_isInitialized) {
      if (kDebugMode) {
        print('⚠️ 通知栏服务未初始化');
      }
      return;
    }

    try {
      // 更新播放状态
      if (isPlaying) {
        await _audioHandler.play();
      } else {
        await _audioHandler.pause();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 更新通知栏失败: $e');
      }
    }
  }

  /// 显示通知栏
  Future<void> showNotification() async {
    if (!_isInitialized) return;
    
    try {
      await _audioHandler.customAction('show');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 显示通知栏失败: $e');
      }
    }
  }

  /// 隐藏通知栏
  Future<void> hideNotification() async {
    if (!_isInitialized) return;
    
    try {
      await _audioHandler.customAction('hide');
    } catch (e) {
      if (kDebugMode) {
        print('❌ 隐藏通知栏失败: $e');
      }
    }
  }

  /// 释放资源
  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// 自定义音频处理器
/// 
/// 实现音频播放和通知栏控制
class WuaiMusicAudioHandler extends audio_service.BaseAudioHandler with audio_service.SeekHandler {
  /// just_audio 播放器
  final AudioPlayer _player = AudioPlayer();

  /// 当前播放的媒体项
  audio_service.MediaItem? _currentItem;

  /// 播放队列
  final List<audio_service.MediaItem> _queue = [];

  /// 构造函数
  WuaiMusicAudioHandler() {
    // 监听播放状态
    _player.playbackEventStream.listen((event) {
      _broadcastState();
    });

    // 监听播放任务完成
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // 播放完成
        if (_hasNext()) {
          skipToNext();
        } else {
          // 停止播放
          stop();
        }
      }
    });
  }

  /// 播放
  @override
  Future<void> play() async {
    await _player.play();
  }

  /// 暂停
  @override
  Future<void> pause() async {
    await _player.pause();
  }

  /// 停止
  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// 跳转到指定位置
  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// 上一首
  @override
  Future<void> skipToPrevious() async {
    // 实现上一首逻辑
    // 目前简化处理，直接跳到开头
    await _player.seek(Duration.zero);
  }

  /// 下一首
  @override
  Future<void> skipToNext() async {
    // 实现下一首逻辑
    // 需要从队列中获取下一首
    if (_hasNext()) {
      final index = _queue.indexOf(_currentItem!);
      if (index < _queue.length - 1) {
        await _setMediaItem(_queue[index + 1]);
        await play();
      }
    }
  }

  /// 设置媒体项
  @override
  Future<void> updateMediaItem(audio_service.MediaItem item) async {
    await _setMediaItem(item);
  }

  /// 设置媒体项并开始播放
  Future<void> _setMediaItem(audio_service.MediaItem item) async {
    _currentItem = item;
    
    // 更新队列中的当前项
    if (!_queue.contains(item)) {
      _queue.add(item);
    }
    
    // 设置媒体项
    mediaItem.add(item);
    
    // 设置播放源
    // 注意：实际项目中需要根据 item.id 获取音频文件路径
    // 这里简化处理
    // await _player.setUrl(item.id);
  }

  /// 设置队列
  @override
  Future<void> updateQueue(List<audio_service.MediaItem> newQueue) async {
    _queue.clear();
    _queue.addAll(newQueue);
    
    // 更新队列
    queue.add(newQueue);
    
    if (newQueue.isNotEmpty) {
      await _setMediaItem(newQueue.first);
    }
  }

  /// 添加到队列
  @override
  Future<void> addQueueItem(audio_service.MediaItem item) async {
    _queue.add(item);
    // 更新队列
    queue.add(_queue.toList());
  }

  /// 从队列移除
  Future<void> removeQueueItem(audio_service.MediaItem item) async {
    _queue.remove(item);
    // 更新队列
    queue.add(_queue.toList());
  }

  /// 是否有下一首
  bool _hasNext() {
    if (_currentItem == null || _queue.isEmpty) return false;
    final index = _queue.indexOf(_currentItem!);
    return index < _queue.length - 1;
  }

  /// 广播播放状态
  void _broadcastState() {
    // 使用 audio_service 的 PlaybackState
    playbackState.add(audio_service.PlaybackState(
      controls: [
        audio_service.MediaControl.skipToPrevious,
        _player.playing ? audio_service.MediaControl.pause : audio_service.MediaControl.play,
        audio_service.MediaControl.skipToNext,
        audio_service.MediaControl.stop,
      ],
      systemActions: const {
        audio_service.MediaAction.seek,
        audio_service.MediaAction.seekForward,
        audio_service.MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _getProcessingState(),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _currentItem != null ? _queue.indexOf(_currentItem!) : 0,
    ));
  }

  /// 获取处理状态
  audio_service.AudioProcessingState _getProcessingState() {
    switch (_player.processingState) {
      case ProcessingState.idle:
        return audio_service.AudioProcessingState.idle;
      case ProcessingState.loading:
        return audio_service.AudioProcessingState.loading;
      case ProcessingState.buffering:
        return audio_service.AudioProcessingState.buffering;
      case ProcessingState.ready:
        return audio_service.AudioProcessingState.ready;
      case ProcessingState.completed:
        return audio_service.AudioProcessingState.completed;
    }
  }
}
