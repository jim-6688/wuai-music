import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_audio_effect_service.dart';

/// 高级音频均衡器服务
/// 
/// 负责音频均衡器的管理和控制，包括：
/// - 10段均衡器控制（原生 Android AudioEffect）
/// - 预设均衡器模式
/// - 自定义均衡器设置
/// - 音效增强（虚拟低音、环绕声、混响、响度增强）
/// - 杜比全景声/杜比视界检测
class AudioEqualizerService extends ChangeNotifier {
  /// SharedPreferences
  SharedPreferences? _prefs;
  
  /// 原生音效引擎
  final NativeAudioEffectService _nativeEffect = NativeAudioEffectService();
  
  /// 原生音效是否可用
  bool get isNativeEffectAvailable => _nativeEffect.initialized;
  
  /// 杜比全景声是否可用
  bool get dolbyAtmosAvailable => _nativeEffect.dolbyAtmosAvailable;
  
  /// 杜比视界是否可用
  bool get dolbyVisionAvailable => _nativeEffect.dolbyVisionAvailable;
  
  /// 空间音频是否可用
  bool get spatialAudioAvailable => _nativeEffect.spatialAudioAvailable;
  
  /// 均衡器段数
  static const int bandCount = 10;
  
  /// 频率列表 (Hz)
  static const List<double> frequencies = [
    32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000
  ];
  
  /// 频率标签
  static const List<String> frequencyLabels = [
    '32Hz', '64Hz', '125Hz', '250Hz', '500Hz', 
    '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'
  ];
  
  /// 均衡器启用状态
  bool _enabled = false;
  
  /// 当前预设
  String _currentPreset = EqualizerPreset.flat.id;
  
  /// 均衡器频段增益值 (dB)
  /// 范围: -12dB 到 +12dB
  final List<double> _bandGains = List.filled(bandCount, 0.0);
  
  /// 虚拟低音增强 (0 ~ 12)
  double _bassBoost = 0.0;
  
  /// 虚拟环绕声 (0 ~ 12)
  double _surround = 0.0;
  
  /// 混响强度 (0 ~ 12)
  double _reverb = 0.0;
  
  /// 响度补偿 (0 ~ 12)
  double _loudness = 0.0;
  
  /// 自动音量控制
  bool _autoVolume = false;
  
  /// 预设列表
  final List<EqualizerPreset> _presets = EqualizerPreset.presets;
  
  /// 自定义预设列表
  final List<CustomEqualizerPreset> _customPresets = [];

  AudioEqualizerService();

  /// 初始化服务
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();
    
    // 初始化原生音效引擎
    if (Platform.isAndroid) {
      await _nativeEffect.initialize();
      
      // 如果原生音效可用且均衡器已启用，同步设置到原生层
      if (_nativeEffect.initialized && _enabled) {
        await _syncToNative();
      }
    }
    
    if (kDebugMode) {
      print('✅ 音频均衡器服务初始化完成');
      print('🎚️ 均衡器段数: $bandCount');
      print('📊 频率范围: ${frequencies.first}Hz - ${frequencies.last}Hz');
      print('🔊 当前预设: $_currentPreset');
      print('🎛️ 原生音效: ${_nativeEffect.initialized ? "已连接" : "不可用"}');
      print('🆕 杜比全景声: ${_nativeEffect.dolbyAtmosAvailable}');
    }
  }

  /// 同步均衡器设置到原生层
  Future<void> _syncToNative() async {
    if (!_nativeEffect.initialized) return;
    
    try {
      // 同频段增益
      for (int i = 0; i < bandCount; i++) {
        await _nativeEffect.setBandLevel(
          i,
          _nativeEffect.dBtoMB(_bandGains[i]),
        );
      }
      
      // 同音效增强
      final bbStrength = (_bassBoost / 12 * _nativeEffect.bassBoostMax).round();
      await _nativeEffect.setBassBoost(bbStrength);
      
      final vzStrength = (_surround / 12 * _nativeEffect.virtualizerMax).round();
      await _nativeEffect.setVirtualizer(vzStrength);
      
      final rvLevel = (_reverb / 12 * 1000).round();
      await _nativeEffect.setReverb(rvLevel);
      
      final ldGain = (_loudness / 12 * _nativeEffect.loudnessMax).round();
      await _nativeEffect.setLoudnessEnhancer(ldGain);
      
      // 启用
      await _nativeEffect.setEnabled(true);
    } catch (e) {
      if (kDebugMode) print('⚠️ 同步原生音效失败: $e');
    }
  }

  /// 获取是否启用
  bool get enabled => _enabled;

  /// 设置是否启用
  set enabled(bool value) {
    _enabled = value;
    _saveSettings();
    // 同步到原生层
    if (_nativeEffect.initialized) {
      if (value) {
        _syncToNative();
      } else {
        _nativeEffect.setEnabled(false);
      }
    }
    _notifyChange();
  }

  /// 获取当前预设
  String get currentPreset => _currentPreset;

  /// 获取均衡器启用状态
  bool isEnabled() => _enabled;

  /// 获取指定频段的增益值
  double getBandGain(int band) {
    if (band < 0 || band >= bandCount) return 0.0;
    return _bandGains[band];
  }

  /// 设置指定频段的增益值
  void setBandGain(int band, double gain) {
    if (band < 0 || band >= bandCount) return;
    
    // 限制范围: -12dB 到 +12dB
    _bandGains[band] = gain.clamp(-12.0, 12.0);
    
    // 标记为自定义设置
    _currentPreset = EqualizerPreset.custom.id;
    
    // 同步到原生层
    if (_nativeEffect.initialized && _enabled) {
      _nativeEffect.setBandLevel(band, _nativeEffect.dBtoMB(gain));
    }
    
    _saveSettings();
    _notifyChange();
  }

  /// 获取所有频段的增益值
  List<double> getAllBandGains() => List.from(_bandGains);

  /// 设置所有频段的增益值
  void setAllBandGains(List<double> gains) {
    if (gains.length != bandCount) return;
    
    for (int i = 0; i < bandCount; i++) {
      _bandGains[i] = gains[i].clamp(-12.0, 12.0);
    }
    
    _currentPreset = EqualizerPreset.custom.id;
    _saveSettings();
    _notifyChange();
  }

  /// 重置均衡器
  void reset() {
    for (int i = 0; i < bandCount; i++) {
      _bandGains[i] = 0.0;
    }
    _currentPreset = EqualizerPreset.flat.id;
    _bassBoost = 0.0;
    _surround = 0.0;
    _reverb = 0.0;
    _loudness = 0.0;
    _autoVolume = false;
    
    _saveSettings();
    _notifyChange();
    
    if (kDebugMode) {
      print('🔄 均衡器已重置');
    }
  }

  /// 应用预设
  void applyPreset(String presetId) {
    final preset = _presets.firstWhere(
      (p) => p.id == presetId,
      orElse: () => _presets.first,
    );
    
    if (preset.bandGains != null) {
      setAllBandGains(preset.bandGains!);
    }
    
    _currentPreset = presetId;
    _bassBoost = preset.bassBoost;
    _surround = preset.surround;
    _reverb = preset.reverb;
    
    // 同步到原生层
    if (_nativeEffect.initialized && _enabled) {
      _syncToNative();
    }
    
    _saveSettings();
    _notifyChange();
    
    if (kDebugMode) {
      print('🎵 均衡器预设已应用: ${preset.name}');
    }
  }

  /// 获取预设列表
  List<EqualizerPreset> getPresets() => _presets;

  /// 获取自定义预设列表
  List<CustomEqualizerPreset> getCustomPresets() => _customPresets;

  /// 保存自定义预设
  Future<void> saveCustomPreset(String name) async {
    final preset = CustomEqualizerPreset(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      bandGains: List.from(_bandGains),
      bassBoost: _bassBoost,
      surround: _surround,
      reverb: _reverb,
      createdAt: DateTime.now(),
    );
    
    _customPresets.add(preset);
    _currentPreset = preset.id;
    await _saveCustomPresets();
    _notifyChange();
    
    if (kDebugMode) {
      print('💾 自定义预设已保存: $name');
    }
  }

  /// 删除自定义预设
  Future<void> deleteCustomPreset(String presetId) async {
    _customPresets.removeWhere((p) => p.id == presetId);
    await _saveCustomPresets();
    _notifyChange();
  }

  /// 获取虚拟低音增强
  double get bassBoost => _bassBoost;

  /// 设置虚拟低音增强
  set bassBoost(double value) {
    _bassBoost = value.clamp(0.0, 12.0);
    // 同步到原生层
    if (_nativeEffect.initialized && _enabled) {
      final strength = (value / 12 * _nativeEffect.bassBoostMax).round();
      _nativeEffect.setBassBoost(strength);
    }
    _saveSettings();
    _notifyChange();
  }

  /// 获取虚拟环绕声
  double get surround => _surround;

  /// 设置虚拟环绕声
  set surround(double value) {
    _surround = value.clamp(0.0, 12.0);
    // 同步到原生层
    if (_nativeEffect.initialized && _enabled) {
      final strength = (value / 12 * _nativeEffect.virtualizerMax).round();
      _nativeEffect.setVirtualizer(strength);
    }
    _saveSettings();
    _notifyChange();
  }

  /// 获取混响强度
  double get reverb => _reverb;

  /// 设置混响强度
  set reverb(double value) {
    _reverb = value.clamp(0.0, 12.0);
    // 同步到原生层
    if (_nativeEffect.initialized && _enabled) {
      final level = (value / 12 * 1000).round();
      _nativeEffect.setReverb(level);
    }
    _saveSettings();
    _notifyChange();
  }

  /// 获取响度补偿
  double get loudness => _loudness;

  /// 设置响度补偿
  set loudness(double value) {
    _loudness = value.clamp(0.0, 12.0);
    // 同步到原生层
    if (_nativeEffect.initialized && _enabled) {
      final gain = (value / 12 * _nativeEffect.loudnessMax).round();
      _nativeEffect.setLoudnessEnhancer(gain);
    }
    _saveSettings();
    _notifyChange();
  }

  /// 获取自动音量控制
  bool get autoVolume => _autoVolume;

  /// 设置自动音量控制
  set autoVolume(bool value) {
    _autoVolume = value;
    _saveSettings();
    _notifyChange();
  }

  /// 获取均衡器参数（用于音频处理器）
  EqualizerParams getEqualizerParams() {
    return EqualizerParams(
      enabled: _enabled,
      bandCount: bandCount,
      frequencies: frequencies,
      bandGains: List.from(_bandGains),
      bassBoost: _bassBoost,
      surround: _surround,
      reverb: _reverb,
      loudness: _loudness,
      autoVolume: _autoVolume,
    );
  }

  /// 加载设置
  Future<void> _loadSettings() async {
    if (_prefs == null) return;
    
    _enabled = _prefs!.getBool('eq_enabled') ?? false;
    _currentPreset = _prefs!.getString('eq_preset') ?? EqualizerPreset.flat.id;
    
    // 加载频段增益
    final savedGains = _prefs!.getStringList('eq_band_gains');
    if (savedGains != null && savedGains.length == bandCount) {
      for (int i = 0; i < bandCount; i++) {
        _bandGains[i] = double.tryParse(savedGains[i]) ?? 0.0;
      }
    }
    
    _bassBoost = _prefs!.getDouble('eq_bass_boost') ?? 0.0;
    _surround = _prefs!.getDouble('eq_surround') ?? 0.0;
    _reverb = _prefs!.getDouble('eq_reverb') ?? 0.0;
    _loudness = _prefs!.getDouble('eq_loudness') ?? 0.0;
    _autoVolume = _prefs!.getBool('eq_auto_volume') ?? false;
    
    // 加载自定义预设
    await _loadCustomPresets();
  }

  /// 保存设置
  Future<void> _saveSettings() async {
    if (_prefs == null) return;
    
    await _prefs!.setBool('eq_enabled', _enabled);
    await _prefs!.setString('eq_preset', _currentPreset);
    await _prefs!.setStringList('eq_band_gains', 
      _bandGains.map((g) => g.toString()).toList());
    await _prefs!.setDouble('eq_bass_boost', _bassBoost);
    await _prefs!.setDouble('eq_surround', _surround);
    await _prefs!.setDouble('eq_reverb', _reverb);
    await _prefs!.setDouble('eq_loudness', _loudness);
    await _prefs!.setBool('eq_auto_volume', _autoVolume);
  }

  /// 加载自定义预设
  Future<void> _loadCustomPresets() async {
    if (_prefs == null) return;
    
    final savedPresets = _prefs!.getString('eq_custom_presets');
    if (savedPresets != null) {
      try {
        // 简化实现，实际需要 JSON 解析
        _customPresets.clear();
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 加载自定义预设失败: $e');
        }
      }
    }
  }

  /// 保存自定义预设
  Future<void> _saveCustomPresets() async {
    if (_prefs == null) return;
    
    // 简化实现，实际需要 JSON 编码
    await _prefs!.setString('eq_custom_presets', '[]');
  }

  /// 通知变更
  void _notifyChange() {
    notifyListeners();
  }

  /// 获取频段标签
  static String getFrequencyLabel(int band) {
    if (band < 0 || band >= bandCount) return '';
    return frequencyLabels[band];
  }

  /// 获取频率值
  static double getFrequency(int band) {
    if (band < 0 || band >= bandCount) return 0;
    return frequencies[band];
  }
}

/// 均衡器预设
class EqualizerPreset {
  /// 预设 ID
  final String id;
  
  /// 预设名称
  final String name;
  
  /// 预设图标
  final String icon;
  
  /// 频段增益值
  final List<double>? bandGains;
  
  /// 虚拟低音增强
  final double bassBoost;
  
  /// 虚拟环绕声
  final double surround;
  
  /// 混响强度
  final double reverb;

  const EqualizerPreset({
    required this.id,
    required this.name,
    this.icon = '🎵',
    this.bandGains,
    this.bassBoost = 0,
    this.surround = 0,
    this.reverb = 0,
  });

  /// 预设列表
  static const List<EqualizerPreset> presets = [
    flat,
    bass,
    treble,
    rock,
    pop,
    jazz,
    classical,
    dance,
    electronic,
    vocal,
    hiphop,
    acoustic,
    custom,
  ];

  /// 平坦
  static const flat = EqualizerPreset(
    id: 'flat',
    name: '平坦',
    icon: '➖',
    bandGains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  );

  /// 低音增强
  static const bass = EqualizerPreset(
    id: 'bass',
    name: '低音增强',
    icon: '🔊',
    bandGains: [8, 6, 4, 2, 0, 0, 0, 0, 0, 0],
    bassBoost: 6,
  );

  /// 高音增强
  static const treble = EqualizerPreset(
    id: 'treble',
    name: '高音增强',
    icon: '🎶',
    bandGains: [0, 0, 0, 0, 0, 2, 4, 6, 8, 10],
  );

  /// 摇滚
  static const rock = EqualizerPreset(
    id: 'rock',
    name: '摇滚',
    icon: '🎸',
    bandGains: [6, 5, 4, 2, -1, -1, 2, 4, 5, 6],
  );

  /// 流行
  static const pop = EqualizerPreset(
    id: 'pop',
    name: '流行',
    icon: '🎤',
    bandGains: [-1, 1, 4, 5, 4, 1, -1, -2, 2, 3],
  );

  /// 爵士
  static const jazz = EqualizerPreset(
    id: 'jazz',
    name: '爵士',
    icon: '🎷',
    bandGains: [4, 3, 1, 2, -2, -2, 0, 2, 3, 4],
  );

  /// 古典
  static const classical = EqualizerPreset(
    id: 'classical',
    name: '古典',
    icon: '🎻',
    bandGains: [5, 4, 3, 2, -1, -1, 0, 3, 4, 5],
  );

  /// 舞曲
  static const dance = EqualizerPreset(
    id: 'dance',
    name: '舞曲',
    icon: '💃',
    bandGains: [6, 5, 2, 0, -2, -1, 2, 4, 5, 6],
    bassBoost: 8,
    surround: 4,
  );

  /// 电子
  static const electronic = EqualizerPreset(
    id: 'electronic',
    name: '电子',
    icon: '🎹',
    bandGains: [6, 5, 1, 0, -2, 1, 2, 4, 6, 7],
    bassBoost: 6,
    surround: 3,
  );

  /// 人声
  static const vocal = EqualizerPreset(
    id: 'vocal',
    name: '人声',
    icon: '🎤',
    bandGains: [-2, -1, 0, 3, 5, 5, 3, 1, 0, -1],
  );

  /// 嘻哈
  static const hiphop = EqualizerPreset(
    id: 'hiphop',
    name: '嘻哈',
    icon: '🎧',
    bandGains: [7, 6, 3, 1, -1, 0, 1, 2, 3, 4],
    bassBoost: 10,
  );

  /// 原声
  static const acoustic = EqualizerPreset(
    id: 'acoustic',
    name: '原声',
    icon: '🎸',
    bandGains: [5, 4, 2, 1, 0, 0, 1, 2, 3, 4],
  );

  /// 自定义
  static const custom = EqualizerPreset(
    id: 'custom',
    name: '自定义',
    icon: '✨',
  );
}

/// 自定义均衡器预设
class CustomEqualizerPreset {
  /// 预设 ID
  final String id;
  
  /// 预设名称
  final String name;
  
  /// 频段增益值
  final List<double> bandGains;
  
  /// 虚拟低音增强
  final double bassBoost;
  
  /// 虚拟环绕声
  final double surround;
  
  /// 混响强度
  final double reverb;
  
  /// 创建时间
  final DateTime createdAt;

  CustomEqualizerPreset({
    required this.id,
    required this.name,
    required this.bandGains,
    this.bassBoost = 0,
    this.surround = 0,
    this.reverb = 0,
    required this.createdAt,
  });
}

/// 均衡器参数
class EqualizerParams {
  /// 是否启用
  final bool enabled;
  
  /// 频段数量
  final int bandCount;
  
  /// 频率列表
  final List<double> frequencies;
  
  /// 频段增益值
  final List<double> bandGains;
  
  /// 虚拟低音增强
  final double bassBoost;
  
  /// 虚拟环绕声
  final double surround;
  
  /// 混响强度
  final double reverb;
  
  /// 响度补偿
  final double loudness;
  
  /// 自动音量控制
  final bool autoVolume;

  EqualizerParams({
    required this.enabled,
    required this.bandCount,
    required this.frequencies,
    required this.bandGains,
    required this.bassBoost,
    required this.surround,
    required this.reverb,
    required this.loudness,
    required this.autoVolume,
  });

  /// 创建空的均衡器参数
  factory EqualizerParams.empty() => EqualizerParams(
    enabled: false,
    bandCount: 10,
    frequencies: AudioEqualizerService.frequencies,
    bandGains: List.filled(10, 0.0),
    bassBoost: 0,
    surround: 0,
    reverb: 0,
    loudness: 0,
    autoVolume: false,
  );
}
