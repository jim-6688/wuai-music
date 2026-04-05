import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:ui' as ui;

double? _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

/// 音频频谱可视化器 - 液态玻璃风格
class SpectrumVisualizer extends StatefulWidget {
  final Stream<List<double>>? spectrumStream;
  final SpectrumMode mode;
  final int barCount;
  final double width;
  final double height;
  final Color? color;
  final Gradient? gradient;
  final bool isPlaying;

  const SpectrumVisualizer({
    super.key,
    this.spectrumStream,
    this.mode = SpectrumMode.bars,
    this.barCount = 32,
    this.width = 300,
    this.height = 200,
    this.color,
    this.gradient,
    this.isPlaying = false,
  });

  @override
  State<SpectrumVisualizer> createState() => _SpectrumVisualizerState();
}

class _SpectrumVisualizerState extends State<SpectrumVisualizer>
    with TickerProviderStateMixin {
  List<double> _spectrumData = [];
  List<double> _previousData = [];
  
  double _phase = 0.0;
  bool _isStreaming = false;
  StreamSubscription? _spectrumSubscription;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    
    _spectrumData = List.generate(widget.barCount, (_) => 0.0);
    _previousData = List.generate(widget.barCount, (_) => 0.0);
    
    _spectrumSubscription = widget.spectrumStream?.listen((data) {
      _isStreaming = true;
      _updateSpectrumData(data);
    });
    
    _startTicker();
  }

  @override
  void didUpdateWidget(SpectrumVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _startTicker();
      } else {
        _stopTicker();
        setState(() {
          _spectrumData = List.generate(widget.barCount, (_) => 0.0);
          _previousData = List.generate(widget.barCount, (_) => 0.0);
        });
      }
    }
  }

  void _startTicker() {
    _ticker?.dispose();
    _ticker = createTicker((elapsed) {
      if (!mounted) return;
      setState(() {
        // 每帧更新相位，约 60 FPS
        _phase += 0.016;
        if (!_isStreaming) {
          _spectrumData = _generateMusicSpectrum();
        }
      });
    });
    _ticker?.start();
  }

  void _stopTicker() {
    _ticker?.stop();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _spectrumSubscription?.cancel();
    super.dispose();
  }

  void _updateSpectrumData(List<double> data) {
    if (!mounted) return;
    
    _previousData = List.from(_spectrumData);
    final normalized = _normalizeData(data);
    
    // 平滑过渡
    setState(() {
      _spectrumData = List.generate(widget.barCount, (i) {
        final prev = i < _previousData.length ? _previousData[i] : 0.0;
        final target = i < normalized.length ? normalized[i] : 0.0;
        return _lerpDouble(prev, target, 0.3) ?? target;
      });
    });
  }

  List<double> _normalizeData(List<double> data) {
    if (data.isEmpty) return List.generate(widget.barCount, (_) => 0.0);
    final maxVal = data.reduce(max);
    if (maxVal == 0) return List.generate(widget.barCount, (_) => 0.0);
    return data.map((v) => (v / maxVal).clamp(0.0, 1.0)).toList();
  }

  /// 生成模拟频谱数据
  List<double> _generateMusicSpectrum() {
    final t = _phase;
    final bandCount = widget.barCount;
    final random = Random();
    
    return List.generate(bandCount, (i) {
      // 模拟 120 BPM 的节奏
      final beatFreq = 2.0;
      final beatPhase = (t * beatFreq * pi) % (2 * pi);
      
      // 频率分布：低频更强，高频较弱
      final freqRatio = i / bandCount;
      
      double value;
      if (i < 8) {
        // 低频（60-250Hz）- 最强，节奏感强
        final beatPulse = pow(max(0.0, sin(beatPhase)), 2.5);
        value = beatPulse * 0.9 + max(0.0, sin(beatPhase + pi / 3)) * 0.3;
      } else if (i < (bandCount * 0.35).toInt()) {
        // 中低频（250-1000Hz）
        value = max(0.0, sin(beatPhase * 0.8 + i * 0.15)) * 0.6 + 
                max(0.0, cos(beatPhase * 1.2 + i * 0.1)) * 0.3;
      } else if (i < (bandCount * 0.65).toInt()) {
        // 中频（1000-4000Hz）
        value = max(0.0, sin(beatPhase * 1.5 + i * 0.2)) * 0.5 + 
                max(0.0, sin(beatPhase * 0.7 + i * 0.25)) * 0.3;
      } else if (i < (bandCount * 0.85).toInt()) {
        // 中高频（4000-8000Hz）
        value = max(0.0, sin(beatPhase * 2.5 + i * 0.3)) * 0.4 + 
                max(0.0, cos(beatPhase * 1.8 + i * 0.2)) * 0.2;
      } else {
        // 高频（8000Hz+）- 最弱
        value = max(0.0, sin(beatPhase * 4 + i * 0.4)) * 0.25 + 
                max(0.0, sin(beatPhase * 3 + i * 0.3)) * 0.15;
      }
      
      // 添加随机波动，增加动态感
      value += (random.nextDouble() - 0.5) * 0.08;
      
      // 衰减处理，使频谱更平滑
      value = value * (1.0 - freqRatio * 0.3);
      
      return value.clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = widget.width == double.infinity 
            ? constraints.maxWidth 
            : widget.width;
        final actualHeight = widget.height == double.infinity 
            ? constraints.maxHeight 
            : widget.height;

        return CustomPaint(
          size: Size(actualWidth, actualHeight),
          painter: _SpectrumPainter(
            spectrumData: _spectrumData,
            mode: widget.mode,
            color: widget.color ?? Theme.of(context).primaryColor,
          ),
        );
      },
    );
  }
}

class _SpectrumPainter extends CustomPainter {
  final List<double> spectrumData;
  final SpectrumMode mode;
  final Color color;

  _SpectrumPainter({
    required this.spectrumData,
    required this.mode,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (mode) {
      case SpectrumMode.bars:
        _drawBars(canvas, size);
        break;
      case SpectrumMode.wave:
        _drawWave(canvas, size);
        break;
      case SpectrumMode.circular:
        _drawCircular(canvas, size);
        break;
      case SpectrumMode.static:
        _drawStatic(canvas, size);
        break;
      case SpectrumMode.dynamic:
        _drawDynamic(canvas, size);
        break;
      case SpectrumMode.mel:
        _drawMel(canvas, size);
        break;
      case SpectrumMode.psd:
        _drawPSD(canvas, size);
        break;
      case SpectrumMode.line:
        _drawLine(canvas, size);
        break;
    }
  }

  void _drawBars(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final barWidth = size.width / spectrumData.length;
    final barSpacing = barWidth * 0.15;
    final actualBarWidth = barWidth - barSpacing;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final value = spectrumData[i];
      final enhancedValue = pow(value, 0.7).toDouble();
      final barHeight = enhancedValue * size.height;
      final x = i * barWidth + barSpacing / 2;
      final y = size.height - barHeight;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, size.height),
          Offset(x, y),
          [
            color.withValues(alpha: 0.2),
            Color.lerp(color, Colors.white, value * 0.3) ?? color.withValues(alpha: 0.3 + value * 0.5),
          ],
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(rect, paint);
      
      if (value > 0.3) {
        final highlightPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, y),
            Offset(x, y + barHeight * 0.4),
            [
              Colors.white.withValues(alpha: value * 0.4),
              Colors.white.withValues(alpha: 0.0),
            ],
          )
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rect, highlightPaint);
      }
      
      if (value > 0.6) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: value * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - 2, size.height - 4, actualBarWidth + 4, 8),
            Radius.circular(4),
          ),
          glowPaint,
        );
      }
    }
  }

  void _drawWave(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final path = Path();
    final stepX = size.width / (spectrumData.length - 1);
    
    path.moveTo(0, size.height);
    
    for (int i = 0; i < spectrumData.length; i++) {
      final x = i * stepX;
      final enhancedValue = pow(spectrumData[i], 0.8).toDouble();
      final y = size.height - enhancedValue * size.height * 0.9;
      
      if (i == 0) {
        path.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevEnhanced = pow(spectrumData[i - 1], 0.8).toDouble();
        final prevY = size.height - prevEnhanced * size.height * 0.9;
        final controlX = (prevX + x) / 2;
        path.quadraticBezierTo(controlX, prevY, x, y);
      }
    }
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          color.withValues(alpha: 0.7),
          color.withValues(alpha: 0.1),
        ],
      )
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(path, fillPaint);
    
    final linePath = Path();
    for (int i = 0; i < spectrumData.length; i++) {
      final x = i * stepX;
      final enhancedValue = pow(spectrumData[i], 0.8).toDouble();
      final y = size.height - enhancedValue * size.height * 0.9;
      
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);
    
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, strokePaint);
  }

  void _drawCircular(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final center = Offset(size.width / 2, size.height);
    final baseRadius = size.width * 0.15;
    final maxBarHeight = size.width * 0.35;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final angle = pi + (i / spectrumData.length) * pi;
      final barHeight = spectrumData[i] * maxBarHeight;
      
      final x1 = center.dx + baseRadius * cos(angle);
      final y1 = center.dy + baseRadius * sin(angle);
      final x2 = center.dx + (baseRadius + barHeight) * cos(angle);
      final y2 = center.dy + (baseRadius + barHeight) * sin(angle);
      
      final barPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x1, y1),
          Offset(x2, y2),
          [
            color.withValues(alpha: 0.3),
            color.withValues(alpha: 0.9),
          ],
        )
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), barPaint);
      
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), glowPaint);
    }
    
    final centerPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 0.5, centerPaint);
  }

  void _drawStatic(Canvas canvas, Size size) {
    // 静态频谱也使用传入的数据，只是变化幅度较小
    if (spectrumData.isEmpty) return;
    
    final barWidth = size.width / spectrumData.length;
    final barSpacing = barWidth * 0.15;
    final actualBarWidth = barWidth - barSpacing;
    final random = Random(42); // 固定种子保持稳定
    
    for (int i = 0; i < spectrumData.length; i++) {
      // 使用传入数据作为基础，加上小幅波动
      final baseValue = spectrumData[i] * 0.7;
      final waveOffset = sin(i * 0.5 + 1.0) * 0.1;
      final value = (baseValue + waveOffset + 0.1).clamp(0.0, 0.8);
      
      final barHeight = value * size.height * 0.8;
      final x = i * barWidth + barSpacing / 2;
      final y = size.height - barHeight;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, size.height),
          Offset(x, y),
          [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.5),
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
    }
  }

  void _drawDynamic(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final barWidth = size.width / spectrumData.length;
    final barSpacing = barWidth * 0.1;
    final actualBarWidth = barWidth - barSpacing;
    
    // 添加时间脉冲效果
    final pulse = sin(DateTime.now().millisecondsSinceEpoch / 500.0 * pi) * 0.1 + 1.0;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final value = spectrumData[i];
      final barHeight = value * size.height * 0.85 * pulse;
      final x = i * barWidth + barSpacing / 2;
      final y = size.height - barHeight;
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 2, y - 2, actualBarWidth + 4, barHeight + 4),
          Radius.circular(actualBarWidth / 2),
        ),
        glowPaint,
      );
      
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, size.height),
          Offset(x, y),
          [
            color.withValues(alpha: 0.4),
            color,
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
    }
  }

  void _drawMel(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final melPos = i / spectrumData.length;
      final freq = 700 * (pow(10, melPos / 2.5) - 1) / 1000;
      final normalizedFreq = freq.clamp(0.0, 1.0);
      
      final barHeight = spectrumData[i] * size.height * 0.9;
      final energy = pow(spectrumData[i], 0.7);
      final barWidth = (size.width / spectrumData.length) * (0.5 + normalizedFreq * 0.5);
      final x = i * (size.width / spectrumData.length) * 0.8;
      final y = size.height - barHeight * energy;
      
      final hue = 200 + (1 - normalizedFreq) * 60;
      final barColor = HSVColor.fromAHSV(1.0, hue, 0.7, 0.9).toColor();
      
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight * energy),
        Radius.circular(barWidth / 2),
      );
      
      paint.shader = ui.Gradient.linear(
        Offset(x, size.height),
        Offset(x, y),
        [
          barColor.withValues(alpha: 0.3),
          barColor.withValues(alpha: 0.8),
        ],
      );
      canvas.drawRRect(rect, paint);
    }
  }

  void _drawPSD(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final barWidth = size.width / spectrumData.length;
    final barSpacing = barWidth * 0.1;
    final actualBarWidth = barWidth - barSpacing;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final dbValue = spectrumData[i] > 0 ? 20 * log(spectrumData[i]) / ln10 : -60.0;
      final normalizedDb = ((dbValue + 60) / 60).clamp(0.0, 1.0);
      
      final barHeight = normalizedDb * size.height * 0.95;
      final x = i * barWidth + barSpacing / 2;
      final y = size.height - barHeight;
      
      final intensity = normalizedDb;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, size.height),
          Offset(x, y),
          [
            Colors.black.withValues(alpha: 0.3),
            Color.lerp(color, Colors.white, intensity) ?? color,
          ],
        )
        ..style = PaintingStyle.fill;
      canvas.drawRRect(rect, paint);
      
      if (spectrumData[i] > 0.7) {
        final peakPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(x + actualBarWidth / 2, y),
          3,
          peakPaint,
        );
      }
    }
  }

  void _drawLine(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final stepX = size.width / (spectrumData.length - 1);
    
    final linePath = Path();
    for (int i = 0; i < spectrumData.length; i++) {
      final x = i * stepX;
      final y = size.height - spectrumData[i] * size.height * 0.85;
      
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);
    
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);
    
    for (int i = 0; i < spectrumData.length; i++) {
      final x = i * stepX;
      final y = size.height - spectrumData[i] * size.height * 0.85;
      
      final outerPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 6, outerPaint);
      
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3, innerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return spectrumData != oldDelegate.spectrumData;
  }
}

enum SpectrumMode {
  bars,
  wave,
  circular,
  static,
  dynamic,
  mel,
  psd,
  line,
}
