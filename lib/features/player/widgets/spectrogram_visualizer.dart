import 'dart:math';
import 'package:flutter/material.dart';

/// 频谱图数据
class SpectrogramData {
  final List<List<double>> data; // 时间 x 频率
  final int maxFrames;
  
  SpectrogramData({this.maxFrames = 50}) : data = [];
  
  void addFrame(List<double> fftData) {
    data.add(List.from(fftData));
    if (data.length > maxFrames) {
      data.removeAt(0);
    }
  }
  
  void clear() {
    data.clear();
  }
}

/// MATLAB风格频谱图可视化
class SpectrogramVisualizer extends StatefulWidget {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double height;

  const SpectrogramVisualizer({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.height = 200,
  });

  @override
  State<SpectrogramVisualizer> createState() => _SpectrogramVisualizerState();
}

class _SpectrogramVisualizerState extends State<SpectrogramVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final SpectrogramData _spectrogramData = SpectrogramData(maxFrames: 60);
  final Random _random = Random();
  double _phase = 0.0;
  List<double> _currentFft = [];

  @override
  void initState() {
    super.initState();
    _currentFft = List.generate(64, (_) => 0.0);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateSpectrogram);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateSpectrogram() {
    if (!mounted) return;
    
    setState(() {
      if (widget.isPlaying) {
        _phase += 0.05;
        _currentFft = _generateFft();
        _spectrogramData.addFrame(_currentFft);
      } else {
        if (_spectrogramData.data.isNotEmpty) {
          // 淡出
          for (int i = _spectrogramData.data.length - 1; i >= 0; i--) {
            for (int j = 0; j < _spectrogramData.data[i].length; j++) {
              _spectrogramData.data[i][j] *= 0.9;
            }
          }
          _spectrogramData.data.removeWhere((frame) => 
            frame.every((v) => v < 0.01));
        }
      }
    });
  }

  // 生成类似MATLAB的频谱数据
  List<double> _generateFft() {
    final t = _phase;
    return List.generate(64, (i) {
      final freq = i / 64.0;
      
      // 低频强，中频适中，高频弱 - 类似真实音乐
      double value;
      if (i < 16) {
        // 低频 - 能量高
        value = (0.5 + 0.3 * _sin(t * 1.5 + i * 0.2).abs()) * (1 - freq * 0.5);
      } else if (i < 40) {
        // 中频
        value = (0.3 + 0.25 * _sin(t * 2.5 + i * 0.3).abs()) * (1 - freq * 0.3);
      } else {
        // 高频 - 能量低
        value = (0.1 + 0.15 * _sin(t * 4 + i * 0.5).abs()) * 0.5;
      }
      
      // 添加随机变化模拟真实音频
      value += (_random.nextDouble() - 0.5) * 0.1;
      
      return value.clamp(0.0, 1.0);
    });
  }

  double _sin(double x) {
    x = x % (2 * pi);
    if (x < 0) x += 2 * pi;
    return 2 * (x / pi - 0.5).abs() - 1;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _SpectrogramPainter(
          spectrogramData: _spectrogramData,
          color: widget.color,
        ),
      ),
    );
  }
}

/// MATLAB jet 颜色映射
Color jetColorMap(double value) {
  value = value.clamp(0.0, 1.0);
  
  double r, g, b;
  
  if (value < 0.25) {
    r = 0;
    g = 4 * value;
    b = 1;
  } else if (value < 0.5) {
    r = 0;
    g = 1;
    b = 1 - 4 * (value - 0.25);
  } else if (value < 0.75) {
    r = 4 * (value - 0.5);
    g = 1;
    b = 0;
  } else {
    r = 1;
    g = 1 - 4 * (value - 0.75);
    b = 0;
  }
  
  return Color.fromARGB(
    255,
    (r * 255).round(),
    (g * 255).round(),
    (b * 255).round(),
  );
}

class _SpectrogramPainter extends CustomPainter {
  final SpectrogramData spectrogramData;
  final Color color;

  _SpectrogramPainter({
    required this.spectrogramData,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final data = spectrogramData.data;
    if (data.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    final rows = data.length;
    final cols = data[0].length;
    
    final cellWidth = size.width / cols;
    final cellHeight = size.height / rows;

    // 绘制频谱图 - 类似 MATLAB imagesc
    for (int t = 0; t < rows; t++) {
      for (int f = 0; f < cols; f++) {
        final magnitude = data[t][f];
        if (magnitude < 0.01) continue;
        
        final c = jetColorMap(magnitude);
        final paint = Paint()
          ..color = c.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        
        canvas.drawRect(
          Rect.fromLTWH(
            f * cellWidth,
            size.height - (t + 1) * cellHeight, // 从下往上
            cellWidth + 0.5,
            cellHeight + 0.5,
          ),
          paint,
        );
      }
    }

    // 绘制频率轴（左侧）
    _drawFrequencyAxis(canvas, size, cols);
  }

  void _drawFrequencyAxis(Canvas canvas, Size size, int freqBins) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;
    
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 频率标签
    final freqLabels = ['高', '', '', '', '中', '', '', '', '低'];
    for (int i = 0; i < freqLabels.length && i < freqBins; i++) {
      final y = size.height - (i / freqLabels.length) * size.height;
      
      // 画刻度线
      canvas.drawLine(
        Offset(0, y),
        Offset(8, y),
        paint,
      );
      
      // 画标签
      if (freqLabels[i].isNotEmpty) {
        textPainter.text = TextSpan(
          text: freqLabels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 8,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(10, y - 4));
      }
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SpectrogramPainter oldDelegate) => true;
}
