import 'package:flutter/services.dart';

/// Android 端音频指纹提取服务（Platform Channel 封装）
class AudioFingerprintService {
  static const _channel = MethodChannel('com.glassmusic/audio_fingerprint');

  /// 提取音频指纹
  /// 返回 {fingerprint, duration, sampleRate, rawLength}
  Future<Map<String, dynamic>> extractFingerprint(String filePath) async {
    try {
      final result = await _channel.invokeMethod('extractFingerprint', {
        'filePath': filePath,
      });
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (e) {
      throw FingerprintException('提取指纹失败: ${e.message}');
    }
  }

  /// 提取波形数据
  /// [samples] 目标采样点数，默认 200
  Future<List<double>> extractWaveform(String filePath, {int samples = 200}) async {
    try {
      final result = await _channel.invokeMethod('extractWaveform', {
        'filePath': filePath,
        'samples': samples,
      });
      final data = Map<String, dynamic>.from(result);
      final waveform = data['waveform'];
      if (waveform is List) {
        return waveform.map((e) => (e as num).toDouble()).toList();
      }
      return [];
    } on PlatformException catch (e) {
      throw FingerprintException('提取波形失败: ${e.message}');
    }
  }

  /// 验证平台支持
  Future<bool> isSupported() async {
    try {
      // 平台检查 - Android 原生支持
      return true;
    } catch (_) {
      return false;
    }
  }
}

class FingerprintException implements Exception {
  final String message;
  FingerprintException(this.message);
  @override
  String toString() => 'FingerprintException: $message';
}
