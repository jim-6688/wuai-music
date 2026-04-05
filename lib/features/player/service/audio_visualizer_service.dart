import 'dart:async';
import 'package:flutter/services.dart';

/// 音频可视化原生数据服务
/// 通过 Method Channel 与 Android 原生 Visualizer 通信
class AudioVisualizerService {
  static const _channel = MethodChannel('com.glassmusic/audio_visualizer');
  
  static AudioVisualizerService? _instance;
  static AudioVisualizerService get instance => _instance ??= AudioVisualizerService._();
  
  AudioVisualizerService._();
  
  final _spectrumController = StreamController<List<double>>.broadcast();
  bool _isActive = false;
  
  /// 频谱数据流（供 UI 订阅）
  Stream<List<double>> get spectrumStream => _spectrumController.stream;
  
  /// 是否正在运行
  bool get isActive => _isActive;
  
  /// 启动可视化
  Future<bool> start({int audioSessionId = 0}) async {
    if (_isActive) return true;
    
    try {
      // 设置回调监听
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onSpectrumData') {
          // 解析 arguments 中的 data 字段
          final args = call.arguments as Map<dynamic, dynamic>?;
          final data = args?['data'] as List<dynamic>?;
          if (data != null) {
            _spectrumController.add(data.map((e) => (e as num).toDouble()).toList());
          }
        }
      });
      
      final result = await _channel.invokeMethod<bool>('startVisualizer', {
        'audioSessionId': audioSessionId,
      });
      
      _isActive = result ?? false;
      return _isActive;
    } catch (e) {
      print('AudioVisualizerService: 启动失败 - $e');
      return false;
    }
  }
  
  /// 停止可视化
  Future<void> stop() async {
    if (!_isActive) return;
    
    try {
      await _channel.invokeMethod('stopVisualizer');
      _spectrumController.add(List.filled(32, 0.0)); // 发送静音频谱
    } catch (e) {
      print('AudioVisualizerService: 停止失败 - $e');
    } finally {
      _isActive = false;
    }
  }
  
  /// 设置音频会话 ID（用于关联特定音频流）
  Future<void> setAudioSessionId(int sessionId) async {
    try {
      await _channel.invokeMethod('setAudioSessionId', {
        'audioSessionId': sessionId,
      });
    } catch (e) {
      print('AudioVisualizerService: 设置音频会话失败 - $e');
    }
  }
  
  /// 释放资源
  void dispose() {
    stop();
    _spectrumController.close();
  }
}
