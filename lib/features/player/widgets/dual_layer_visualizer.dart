import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;

// 引入歌词颜色 Provider
import '../providers/lyrics_color_provider.dart';

double? _lerpDouble(double a, double b, double t) {
  return a + (b - a) * t;
}

/// 双层叠加音频可视化 - 频谱柱 + 波形曲线
/// 对应抖音视频效果：上层频谱柱 + 下层波形曲线
/// 颜色随歌词颜色动态变换
class DualLayerVisualizer extends ConsumerStatefulWidget {
  final Stream<List<double>>? spectrumStream;
  final int barCount;
  final double width;
  final double height;
  final bool isPlaying;
  
  /// 频谱柱高度占比 (0.0-1.0)
  final double barHeightRatio;
  
  /// 波形曲线高度占比 (0.0-1.0)
  final double waveHeightRatio;
  
  /// 是否使用歌词颜色（默认 true）
  final bool useLyricsColor;

  const DualLayerVisualizer({
    super.key,
    this.spectrumStream,
    this.barCount = 48,
    this.width = double.infinity,
    this.height = 120,
    this.isPlaying = false,
    this.barHeightRatio = 0.65,  // 频谱柱占上层 65%
    this.waveHeightRatio = 0.30, // 波形占下层 30%
    this.useLyricsColor = true,
  });

  @override
  ConsumerState<DualLayerVisualizer> createState() => _DualLayerVisualizerState();
}

class _DualLayerVisualizerState extends ConsumerState<DualLayerVisualizer>
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
  void didUpdateWidget(DualLayerVisualizer oldWidget) {
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

  /// 生成模拟音乐频谱 - 适配 Reggae/Funk 风格
  List<double> _generateMusicSpectrum() {
    final t = _phase;
    final bandCount = widget.barCount;
    final random = Random();
    
    // Reggae/Funk 节奏特点：80-95 BPM，中速 groove
    final beatFreq = 1.6; 
    final beatPhase = (t * beatFreq * pi) % (2 * pi);
    
    return List.generate(bandCount, (i) {
      final freqRatio = i / bandCount;
      
      double value;
      if (i < 10) {
        // 低频 Bass - Reggae Slap Bass 风格
        final beatPulse = pow(max(0.0, sin(beatPhase)), 2.0);
        value = beatPulse * 0.85 + max(0.0, sin(beatPhase + pi / 4)) * 0.4;
      } else if (i < (bandCount * 0.4).toInt()) {
        // 中低频 - Funk groove
        value = max(0.0, sin(beatPhase * 0.7 + i * 0.12)) * 0.6 + 
                max(0.0, cos(beatPhase * 1.1 + i * 0.08)) * 0.35;
      } else if (i < (bandCount * 0.7).toInt()) {
        // 中频 - Reggae off-beat guitar
        value = max(0.0, sin(beatPhase * 1.3 + i * 0.18)) * 0.5 + 
                max(0.0, sin(beatPhase * 0.6 + i * 0.22)) * 0.3;
      } else {
        // 高频 - 轻快节奏
        value = max(0.0, sin(beatPhase * 2.2 + i * 0.28)) * 0.35 + 
                max(0.0, sin(beatPhase * 2.8 + i * 0.35)) * 0.2;
      }
      
      // 添加随机波动
      value += (random.nextDouble() - 0.5) * 0.08;
      value = value * (1.0 - freqRatio * 0.25);
      
      return value.clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前歌词颜色方案
    Color barColor;
    Color waveColor;
    
    if (widget.useLyricsColor) {
      final schemeIndex = ref.watch(lyricsColorSchemeProvider);
      final scheme = LyricsColorSchemes.schemes[schemeIndex];
      barColor = scheme.primaryColor;
      waveColor = scheme.secondaryColor;
    } else {
      barColor = Colors.white.withValues(alpha: 0.8);
      waveColor = Colors.white.withValues(alpha: 0.6);
    }
    
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: _DualLayerPainter(
          spectrumData: _spectrumData,
          barColor: barColor,
          waveColor: waveColor,
          barHeightRatio: widget.barHeightRatio,
          waveHeightRatio: widget.waveHeightRatio,
        ),
      ),
    );
  }
}

class _DualLayerPainter extends CustomPainter {
  final List<double> spectrumData;
  final Color barColor;
  final Color waveColor;
  final double barHeightRatio;
  final double waveHeightRatio;

  _DualLayerPainter({
    required this.spectrumData,
    required this.barColor,
    required this.waveColor,
    required this.barHeightRatio,
    required this.waveHeightRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    // 计算上下层区域
    final barZoneHeight = size.height * barHeightRatio;
    final waveZoneHeight = size.height * waveHeightRatio;
    final waveZoneTop = size.height - waveZoneHeight;
    
    // ====== 绘制下层：波形曲线 ======
    _drawWave(canvas, Size(size.width, waveZoneHeight), waveZoneTop);
    
    // ====== 绘制上层：频谱柱状图 ======
    _drawBars(canvas, Size(size.width, barZoneHeight));
  }
  
  void _drawBars(Canvas canvas, Size size) {
    final barWidth = size.width / spectrumData.length;
    final barSpacing = barWidth * 0.12;
    final actualBarWidth = barWidth - barSpacing;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final value = spectrumData[i];
      final enhancedValue = pow(value, 0.75).toDouble();
      final barHeight = enhancedValue * size.height * 0.9;
      final x = i * barWidth + barSpacing / 2;
      final y = size.height - barHeight;
      
      // 频谱柱
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(x, size.height),
          Offset(x, y),
          [
            barColor.withValues(alpha: 0.15),
            barColor.withValues(alpha: 0.5 + value * 0.4),
          ],
        )
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(rect, paint);
      
      // 高亮顶部
      if (value > 0.4) {
        final highlightPaint = Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, y),
            Offset(x, y + barHeight * 0.3),
            [
              Colors.white.withValues(alpha: value * 0.5),
              Colors.white.withValues(alpha: 0.0),
            ],
          )
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rect, highlightPaint);
      }
    }
  }
  
  void _drawWave(Canvas canvas, Size size, double topOffset) {
    final stepX = size.width / (spectrumData.length - 1);
    
    // 绘制波形填充区域
    final fillPath = Path();
    fillPath.moveTo(0, size.height);
    
    for (int i = 0; i < spectrumData.length; i++) {
      final x = i * stepX;
      // 波形幅度较小，更平缓
      final enhancedValue = pow(spectrumData[i], 0.85).toDouble();
      final y = size.height - enhancedValue * size.height * 0.6;
      
      if (i == 0) {
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevEnhanced = pow(spectrumData[i - 1], 0.85).toDouble();
        final prevY = size.height - prevEnhanced * size.height * 0.6;
        final controlX = (prevX + x) / 2;
        fillPath.quadraticBezierTo(controlX, prevY, x, y);
      }
    }
    
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    
    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          waveColor.withValues(alpha: 0.4),
          waveColor.withValues(alpha: 0.08),
        ],
      )
      ..style = PaintingStyle.fill;
    
    canvas.save();
    canvas.translate(0, topOffset);
    canvas.drawPath(fillPath, fillPaint);
    
    // 绘制波形线条
    final linePath = Path();
    for (int i = 0; i < spectrumData.length; i++) {
      final x = i * stepX;
      final enhancedValue = pow(spectrumData[i], 0.85).toDouble();
      final y = size.height - enhancedValue * size.height * 0.6;
      
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }
    
    // 发光效果
    final glowPaint = Paint()
      ..color = waveColor.withValues(alpha: 0.35)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(linePath, glowPaint);
    
    // 主线条
    final strokePaint = Paint()
      ..color = waveColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, strokePaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DualLayerPainter oldDelegate) {
    return spectrumData != oldDelegate.spectrumData;
  }
}
