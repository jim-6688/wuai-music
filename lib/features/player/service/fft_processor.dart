import 'dart:math';

/// FFT (快速傅里叶变换) 处理器
/// 用于将音频时域数据转换为频域数据
class FFTProcessor {
  /// FFT 窗口大小（必须是 2 的幂次）
  final int windowSize;
  
  /// 采样率
  final int sampleRate;
  
  /// 汉宁窗（用于减少频谱泄漏）
  late final List<double> _hannWindow;
  
  /// 复数缓冲区
  late final List<_Complex> _complexBuffer;
  
  FFTProcessor({
    this.windowSize = 1024,
    this.sampleRate = 44100,
  }) {
    assert(_isPowerOfTwo(windowSize), 'Window size must be power of 2');
    
    _hannWindow = _generateHannWindow();
    _complexBuffer = List.generate(windowSize, (_) => _Complex(0, 0));
  }
  
  /// 检查是否为 2 的幂次
  bool _isPowerOfTwo(int n) {
    return n > 0 && (n & (n - 1)) == 0;
  }
  
  /// 生成汉宁窗
  List<double> _generateHannWindow() {
    return List.generate(
      windowSize,
      (i) => 0.5 * (1 - cos(2 * pi * i / (windowSize - 1))),
    );
  }
  
  /// 执行 FFT 变换
  /// 
  /// [audioData] - 音频 PCM 数据（-1.0 到 1.0）
  /// 返回频谱数据（幅度谱，长度为 windowSize / 2）
  List<double> process(List<double> audioData) {
    if (audioData.length < windowSize) {
      // 如果数据不足，补零
      audioData = [...audioData, ...List.filled(windowSize - audioData.length, 0.0)];
    }
    
    // 应用汉宁窗
    for (int i = 0; i < windowSize; i++) {
      _complexBuffer[i] = _Complex(
        audioData[i] * _hannWindow[i],
        0,
      );
    }
    
    // 执行 FFT
    _fft(_complexBuffer);
    
    // 计算幅度谱（只取前一半，因为 FFT 结果是对称的）
    final spectrum = <double>[];
    for (int i = 0; i < windowSize ~/ 2; i++) {
      final magnitude = sqrt(
        _complexBuffer[i].real * _complexBuffer[i].real +
        _complexBuffer[i].imag * _complexBuffer[i].imag,
      );
      spectrum.add(magnitude / windowSize); // 归一化
    }
    
    return spectrum;
  }
  
  /// Cooley-Tukey FFT 算法（递归实现）
  void _fft(List<_Complex> x) {
    final n = x.length;
    
    if (n <= 1) return;
    
    // 分离奇偶索引
    final even = <_Complex>[];
    final odd = <_Complex>[];
    
    for (int i = 0; i < n; i += 2) {
      even.add(x[i]);
      if (i + 1 < n) {
        odd.add(x[i + 1]);
      }
    }
    
    // 递归处理
    _fft(even);
    _fft(odd);
    
    // 合并结果
    for (int k = 0; k < n ~/ 2; k++) {
      final t = _exp(-2 * pi * k / n) * odd[k];
      x[k] = even[k] + t;
      x[k + n ~/ 2] = even[k] - t;
    }
  }
  
  /// 计算复数指数 e^(iθ)
  _Complex _exp(double theta) {
    return _Complex(cos(theta), sin(theta));
  }
  
  /// 将频谱数据压缩到指定数量的频带
  /// 
  /// [spectrum] - 原始频谱数据
  /// [bandCount] - 目标频带数量
  /// 返回压缩后的频谱数据
  List<double> compressToBands(List<double> spectrum, int bandCount) {
    if (spectrum.isEmpty || bandCount <= 0) return [];
    
    final bandSize = spectrum.length / bandCount;
    final compressed = <double>[];
    
    for (int i = 0; i < bandCount; i++) {
      final start = (i * bandSize).floor();
      final end = ((i + 1) * bandSize).floor();
      
      double sum = 0;
      int count = 0;
      
      for (int j = start; j < end && j < spectrum.length; j++) {
        sum += spectrum[j];
        count++;
      }
      
      compressed.add(count > 0 ? sum / count : 0);
    }
    
    return compressed;
  }
  
  /// 获取频率对应的频谱索引
  int getFrequencyIndex(double frequency) {
    return (frequency * windowSize / sampleRate).floor().clamp(0, windowSize ~/ 2 - 1);
  }
  
  /// 获取频谱索引对应的频率
  double getFrequency(int index) {
    return index * sampleRate / windowSize;
  }
  
  /// 预加重滤波器（增强高频）
  List<double> preEmphasis(List<double> spectrum, double coefficient) {
    return spectrum.asMap().entries.map((entry) {
      final index = entry.key;
      final value = entry.value;
      // 高频增强
      return value * (1 + coefficient * index / spectrum.length);
    }).toList();
  }
  
  /// 平滑处理（减少频谱抖动）
  List<double> smooth(List<double> spectrum, int windowLength) {
    if (spectrum.length < windowLength) return spectrum;
    
    final smoothed = <double>[];
    final halfWindow = windowLength ~/ 2;
    
    for (int i = 0; i < spectrum.length; i++) {
      double sum = 0;
      int count = 0;
      
      for (int j = -halfWindow; j <= halfWindow; j++) {
        final index = i + j;
        if (index >= 0 && index < spectrum.length) {
          sum += spectrum[index];
          count++;
        }
      }
      
      smoothed.add(sum / count);
    }
    
    return smoothed;
  }
  
  /// 对数缩放（增强低幅值区域）
  List<double> logScale(List<double> spectrum) {
    return spectrum.map((v) {
      if (v <= 0) return 0.0;
      return 20 * log(v) / ln10; // dB
    }).toList();
  }
}

/// 复数类
class _Complex {
  final double real;
  final double imag;
  
  const _Complex(this.real, this.imag);
  
  _Complex operator +(_Complex other) {
    return _Complex(real + other.real, imag + other.imag);
  }
  
  _Complex operator -(_Complex other) {
    return _Complex(real - other.real, imag - other.imag);
  }
  
  _Complex operator *(_Complex other) {
    return _Complex(
      real * other.real - imag * other.imag,
      real * other.imag + imag * other.real,
    );
  }
  
  @override
  String toString() => '$real + ${imag}i';
}
