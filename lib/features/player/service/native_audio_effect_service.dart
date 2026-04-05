import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生音效引擎桥接服务
///
/// 通过 MethodChannel 调用 Android 原生 AudioEffect API：
/// - Equalizer（10段均衡器）
/// - BassBoost（低音增强）
/// - Virtualizer（虚拟环绕声）
/// - EnvironmentalReverb（环境混响）
/// - LoudnessEnhancer（响度增强）
/// - 杜比全景声 / 杜比视界检测
class NativeAudioEffectService {
  static const MethodChannel _channel =
      MethodChannel('com.glassmusic/audio_effects');

  /// 音效是否已初始化
  bool _initialized = false;
  bool get initialized => _initialized;

  /// 均衡器频段数量
  int _numBands = 0;
  int get numBands => _numBands;

  /// 均衡器各频段的中心频率 (Hz)
  List<int> _bandFrequencies = [];
  List<int> get bandFrequencies => _bandFrequencies;

  /// 均衡器增益范围 (mB)
  List<int> _levelRange = [-1500, 1500];
  List<int> get levelRange => _levelRange;

  /// 均衡器预设列表
  List<Map<String, String>> _presets = [];
  List<Map<String, String>> get presets => _presets;

  /// 低音增强最大值
  int _bassBoostMax = 1000;
  int get bassBoostMax => _bassBoostMax;

  /// 虚拟环绕声最大值
  int _virtualizerMax = 1000;
  int get virtualizerMax => _virtualizerMax;

  /// 响度增强最大增益 (mB)
  int _loudnessMax = 3000;
  int get loudnessMax => _loudnessMax;

  /// 杜比能力
  bool _dolbyAtmosAvailable = false;
  bool get dolbyAtmosAvailable => _dolbyAtmosAvailable;

  bool _dolbyVisionAvailable = false;
  bool get dolbyVisionAvailable => _dolbyVisionAvailable;

  bool _dolbyDigitalAvailable = false;
  bool get dolbyDigitalAvailable => _dolbyDigitalAvailable;

  bool _spatialAudioAvailable = false;
  bool get spatialAudioAvailable => _spatialAudioAvailable;

  /// 初始化原生音效引擎
  Future<bool> initialize({int audioSessionId = 0}) async {
    if (!Platform.isAndroid) {
      if (kDebugMode) print('⚠️ Native audio effects only supported on Android');
      return false;
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'initAudioEffects',
        {'audioSessionId': audioSessionId},
      );
      _initialized = result ?? false;

      if (_initialized) {
        await _loadCapabilities();
      }

      if (kDebugMode) {
        print('✅ 原生音效引擎初始化: $_initialized');
        print('   均衡器频段: $_numBands');
        print('   增益范围: $_levelRange mB');
        print('   预设数量: ${_presets.length}');
        print('   杜比全景声: $_dolbyAtmosAvailable');
        print('   杜比视界: $_dolbyVisionAvailable');
      }

      return _initialized;
    } catch (e) {
      if (kDebugMode) print('❌ 初始化音效引擎失败: $e');
      return false;
    }
  }

  /// 加载音效能力信息
  Future<void> _loadCapabilities() async {
    try {
      final caps = await _channel
          .invokeMethod<Map>('getAudioEffectCapabilities');
      if (caps == null) return;

      // 均衡器信息
      final eqInfo = caps['equalizer'];
      if (eqInfo is Map) {
        _numBands = eqInfo['numBands'] as int? ?? 0;
        _presets = (eqInfo['presets'] as List?)
                ?.map((e) => Map<String, String>.from(e as Map))
                .toList() ??
            [];
        final bands = (eqInfo['bands'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _bandFrequencies = bands
            .map((b) => b['frequency'] as int? ?? 0)
            .toList();
        final range = (eqInfo['levelRange'] as List?)?.cast<int>() ?? [-1500, 1500];
        _levelRange = range;
      }

      // 低音增强
      final bbInfo = caps['bassBoost'];
      if (bbInfo is Map) {
        _bassBoostMax = bbInfo['maxStrength'] as int? ?? 1000;
      }

      // 虚拟环绕声
      final vzInfo = caps['virtualizer'];
      if (vzInfo is Map) {
        _virtualizerMax = vzInfo['maxStrength'] as int? ?? 1000;
      }

      // 响度增强
      final leInfo = caps['loudnessEnhancer'];
      if (leInfo is Map) {
        _loudnessMax = leInfo['maxGain'] as int? ?? 3000;
      }

      // 杜比能力
      final dolby = caps['dolby'];
      if (dolby is Map) {
        _dolbyAtmosAvailable = dolby['dolbyAtmos'] as bool? ?? false;
        _dolbyVisionAvailable = dolby['dolbyVision'] as bool? ?? false;
        _dolbyDigitalAvailable = dolby['dolbyDigital'] as bool? ?? false;
        _spatialAudioAvailable = dolby['spatialAudio'] as bool? ?? false;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 加载音效能力失败: $e');
    }
  }

  /// 释放音效资源
  Future<void> release() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('releaseAudioEffects');
      _initialized = false;
      if (kDebugMode) print('🔇 音效引擎已释放');
    } catch (e) {
      if (kDebugMode) print('⚠️ 释放音效引擎失败: $e');
    }
  }

  /// 启用/禁用所有音效
  Future<bool> setEnabled(bool enabled) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setEqualizerEnabled', {'enabled': enabled});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置音效开关失败: $e');
      return false;
    }
  }

  /// 获取各频段当前增益值 (mB)
  Future<List<int>> getBandLevels() async {
    if (!_initialized) return [];
    try {
      final levels = await _channel.invokeMethod<List>('getEqualizerBandLevels');
      return levels?.cast<int>() ?? [];
    } catch (e) {
      if (kDebugMode) print('❌ 获取频段值失败: $e');
      return [];
    }
  }

  /// 设置指定频段的增益值 (mB)
  Future<bool> setBandLevel(int band, int levelMb) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setEqualizerBandLevel', {
        'band': band,
        'level': levelMb,
      });
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置频段增益失败: $e');
      return false;
    }
  }

  /// 设置均衡器预设
  Future<bool> setPreset(int presetIndex) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setEqualizerPreset', {'preset': presetIndex});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置预设失败: $e');
      return false;
    }
  }

  /// 设置低音增强强度 (0 ~ 1000)
  Future<bool> setBassBoost(int strength) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setBassBoost', {'strength': strength});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置低音增强失败: $e');
      return false;
    }
  }

  /// 设置虚拟环绕声强度 (0 ~ 1000)
  Future<bool> setVirtualizer(int strength) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setVirtualizer', {'strength': strength});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置虚拟环绕声失败: $e');
      return false;
    }
  }

  /// 设置混响强度 (0 ~ 1000)
  Future<bool> setReverb(int sendLevel) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setReverb', {'sendLevel': sendLevel});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置混响失败: $e');
      return false;
    }
  }

  /// 设置响度增强增益 (mB, 0 ~ 3000)
  Future<bool> setLoudnessEnhancer(int gainMb) async {
    if (!_initialized) return false;
    try {
      await _channel.invokeMethod('setLoudnessEnhancer', {'gain': gainMb});
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 设置响度增强失败: $e');
      return false;
    }
  }

  /// 将 Flutter 层的增益值 (-12 ~ +12 dB) 转换为原生 mB 值
  int dBtoMB(double dB) {
    return (dB * 100).round().clamp(_levelRange[0], _levelRange[1]);
  }

  /// 将原生 mB 值转换为 Flutter 层的 dB 值
  double mBtoDB(int mB) {
    return mB / 100.0;
  }
}
