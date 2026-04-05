import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

/// 音频可视化模式
enum AudioVisualizerMode {
  circular,      // 圆形频谱 (audify)
  bars,          // 条形频谱 (audify)
  waveform,      // 波形 (audio_flux)
  fft,           // FFT频谱 (audio_flux)
  fountain,      // 🎵 水柱喷射喷泉
  starry,        // 星空喷泉
  catEar,        // 环形频谱（无黑胶，纯频谱+中心封面）
  line,          // 五线谱样式
  vinyl,         // 黑胶唱片 + 线谱
  tiktok,        // 抖音双向镜像线谱
  neonPulse,     // 🌟 霓虹脉冲（多彩渐变发光条）
  waveRibbon,    // 🎀 波浪丝带（多层流动波）
  particle,      // ✨ 粒子爆发（频谱驱动粒子）
  crystalPrism,  // 💎 水晶棱镜（彩虹折射效果）
  ringPulse,     // 🔮 环形脉冲（同心圆扩散）
}

/// 统一的音频可视化组件 - 集成 audify 和 audio_flux
class AudioVisualizer extends StatefulWidget {
  final AudioVisualizerMode mode;
  final Color? color;
  final Gradient? gradient;
  final int barCount;
  final double barWidth;
  final double gap;
  final double smoothing;
  final bool mirror;
  final bool isPlaying;
  final double width;
  final double height;
  
  /// 外部频谱数据流（可选，优先于内部模拟）
  final Stream<List<double>>? spectrumStream;

  const AudioVisualizer({
    super.key,
    this.mode = AudioVisualizerMode.bars,
    this.color,
    this.gradient,
    this.barCount = 32,
    this.barWidth = 4.0,
    this.gap = 6.0,
    this.smoothing = 0.75,
    this.mirror = false,
    this.isPlaying = false,
    this.width = 300,
    this.height = 200,
    this.spectrumStream,
  });

  @override
  State<AudioVisualizer> createState() => _AudioVisualizerState();
}

class _AudioVisualizerState extends State<AudioVisualizer> {
  List<double> _simulatedData = [];
  Timer? _simulationTimer;
  double _phase = 0.0;
  
  // 外部数据流订阅
  StreamSubscription<List<double>>? _externalSubscription;
  
  // 需要动画的特效模式
  static const _animatedModes = {
    AudioVisualizerMode.neonPulse,
    AudioVisualizerMode.waveRibbon,
    AudioVisualizerMode.particle,
    AudioVisualizerMode.crystalPrism,
    AudioVisualizerMode.ringPulse,
  };

  @override
  void initState() {
    super.initState();
    _simulatedData = List.generate(widget.barCount, (_) => 0.0);
    _setupExternalStream();
    if (widget.isPlaying) {
      _startSimulation();
    }
  }
  
  void _setupExternalStream() {
    _externalSubscription?.cancel();
    if (widget.spectrumStream != null) {
      _externalSubscription = widget.spectrumStream!.listen((data) {
        // 严格检查 mounted 状态，防止 Widget dispose 后仍调用 setState
        if (!mounted) return;
        if (widget.isPlaying) {
          // 使用外部真实数据，跳过模拟
          setState(() {
            // 调整数据长度以匹配 barCount
            if (data.length != _simulatedData.length) {
              _simulatedData = _resampleData(data, widget.barCount);
            } else {
              _simulatedData = List.from(data);
            }
            _phase += 0.016; // 保持动画相位更新
          });
        }
      }, onError: (error) {
        // 忽略流错误，避免因为 Visualizer 初始化失败导致未处理异常
      });
    }
  }
  
  List<double> _resampleData(List<double> data, int targetLength) {
    if (data.isEmpty) return List.filled(targetLength, 0.0);
    if (data.length == targetLength) return List.from(data);
    
    // 简单的线性插值重采样
    final result = <double>[];
    for (int i = 0; i < targetLength; i++) {
      final sourceIndex = i * (data.length - 1) / (targetLength - 1);
      final lowerIndex = sourceIndex.floor();
      final upperIndex = lowerIndex + 1;
      if (upperIndex >= data.length) {
        result.add(data.last);
      } else {
        final fraction = sourceIndex - lowerIndex;
        result.add(data[lowerIndex] * (1 - fraction) + data[upperIndex] * fraction);
      }
    }
    return result;
  }

  @override
  void didUpdateWidget(AudioVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 外部数据流变化时重新订阅
    if (oldWidget.spectrumStream != widget.spectrumStream) {
      _setupExternalStream();
    }
    
    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _startSimulation();
      } else {
        _stopSimulation();
      }
    }
    
    // 如果 barCount 改变，重新生成数据
    if (oldWidget.barCount != widget.barCount) {
      _simulatedData = List.generate(widget.barCount, (_) => 0.0);
    }
  }

  void _startSimulation() {
    // 如果有外部数据流，不需要内部模拟定时器
    if (widget.spectrumStream != null) {
      return;
    }
    
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      setState(() {
        _phase += 0.016;
        _simulatedData = _generateSimulatedSpectrum();
      });
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    if (mounted) {
      setState(() {
        _simulatedData = List.generate(widget.barCount, (_) => 0.0);
      });
    }
  }

  List<double> _generateSimulatedSpectrum() {
    final t = _phase;
    return List.generate(widget.barCount, (i) {
      final freqRatio = i / widget.barCount;
      final beatPhase = (t * 2.0 * 3.14159) % (2 * 3.14159);
      
      double value;
      if (i < widget.barCount * 0.15) {
        // 低频 - 最强
        value = (0.7 + 0.3 * (beatPhase.sinApprox).abs()) * (1.0 - freqRatio * 0.3);
      } else if (i < widget.barCount * 0.4) {
        // 中低频
        value = (0.5 + 0.4 * ((beatPhase + i * 0.2).sinApprox)).abs() * (1.0 - freqRatio * 0.4);
      } else if (i < widget.barCount * 0.7) {
        // 中频
        value = (0.3 + 0.3 * ((beatPhase * 1.5 + i * 0.3).sinApprox)).abs() * (1.0 - freqRatio * 0.5);
      } else {
        // 高频 - 最弱
        value = (0.1 + 0.2 * ((beatPhase * 2 + i * 0.5).sinApprox)).abs() * 0.5;
      }
      
      return value.clamp(0.0, 1.0);
    });
  }

  @override
  void dispose() {
    _stopSimulation();
    _externalSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actualColor = widget.color ?? Theme.of(context).primaryColor;
    
    return SizedBox(
      width: widget.width == double.infinity ? null : widget.width,
      height: widget.height == double.infinity ? null : widget.height,
      child: _buildSimulatedVisualizer(actualColor),
    );
  }

  Widget _buildSimulatedVisualizer(Color color) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = widget.width == double.infinity ? constraints.maxWidth : widget.width;
        final height = widget.height == double.infinity ? constraints.maxHeight : widget.height;

        // ═══ 新特效模式 ═══════════════════════════════════════════════
        if (widget.mode == AudioVisualizerMode.neonPulse) {
          return CustomPaint(
            size: Size(width, height),
            painter: _NeonPulsePainter(
              data: _simulatedData,
              color: color,
              phase: _phase,
            ),
          );
        }

        if (widget.mode == AudioVisualizerMode.waveRibbon) {
          return CustomPaint(
            size: Size(width, height),
            painter: _WaveRibbonPainter(
              data: _simulatedData,
              color: color,
              phase: _phase,
            ),
          );
        }

        if (widget.mode == AudioVisualizerMode.particle) {
          return CustomPaint(
            size: Size(width, height),
            painter: _ParticlePainter(
              data: _simulatedData,
              color: color,
              phase: _phase,
            ),
          );
        }

        if (widget.mode == AudioVisualizerMode.crystalPrism) {
          return CustomPaint(
            size: Size(width, height),
            painter: _CrystalPrismPainter(
              data: _simulatedData,
              color: color,
              phase: _phase,
            ),
          );
        }

        if (widget.mode == AudioVisualizerMode.ringPulse) {
          return CustomPaint(
            size: Size(width, height),
            painter: _RingPulsePainter(
              data: _simulatedData,
              color: color,
              phase: _phase,
            ),
          );
        }
        // ═══════════════════════════════════════════════════════════

        if (widget.mode == AudioVisualizerMode.line) {
          return CustomPaint(
            size: Size(width, height),
            painter: _LineSpectrumPainter(
              data: _simulatedData,
              color: color,
              mirror: widget.mirror,
            ),
          );
        }

        // tiktok / waveform：painter 内部已自动检测容器方向并适配
        if (widget.mode == AudioVisualizerMode.tiktok) {
          return CustomPaint(
            size: Size(width, height),
            painter: _TikTokLinePainter(
              data: _simulatedData,
              color: color,
            ),
          );
        }

        if (widget.mode == AudioVisualizerMode.waveform) {
          return CustomPaint(
            size: Size(width, height),
            painter: _ThinLinePainter(
              data: _simulatedData,
              color: color,
            ),
          );
        }

        return CustomPaint(
          size: Size(width, height),
          painter: _SimulatedSpectrumPainter(
            data: _simulatedData,
            color: color,
            gradient: widget.gradient,
            barWidth: widget.barWidth,
            gap: widget.gap,
            mirror: widget.mirror,
          ),
        );
      },
    );
  }
}

/// 模拟频谱绘制器
class _SimulatedSpectrumPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final Gradient? gradient;
  final double barWidth;
  final double gap;
  final bool mirror;

  _SimulatedSpectrumPainter({
    required this.data,
    required this.color,
    this.gradient,
    required this.barWidth,
    required this.gap,
    required this.mirror,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // 根据画布宽度自动计算每条宽度和间距，均匀填满画布
    final totalBars = data.length;
    final slotWidth = size.width / totalBars;
    final actualBarWidth = slotWidth * 0.65;
    final startX = slotWidth * 0.175; // 居中对齐每个 slot

    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      
      final x = startX + i * slotWidth;
      
      // 根据频响强度选择颜色
      List<Color> gradientColors;
      if (value > 0.8) {
        gradientColors = [
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 1.0),
          Colors.white.withValues(alpha: 0.95),
        ];
      } else if (value > 0.6) {
        gradientColors = [
          color.withValues(alpha: 0.4),
          color.withValues(alpha: 0.9),
          Color.lerp(color, Colors.white, 0.3) ?? color,
        ];
      } else if (value > 0.4) {
        gradientColors = [
          color.withValues(alpha: 0.3),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 1.0),
        ];
      } else {
        gradientColors = [
          color.withValues(alpha: 0.15),
          color.withValues(alpha: 0.5),
          color.withValues(alpha: 0.7),
        ];
      }

      if (mirror) {
        // 镜像模式：从中心线分别向上下延伸，高度各为 barHeight/2
        final halfBarHeight = value * (size.height * 0.45);
        if (halfBarHeight < 1) continue;

        final centerY = size.height / 2;

        // 上半部分（从中心向上）
        final topRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY - halfBarHeight, actualBarWidth, halfBarHeight),
          Radius.circular(actualBarWidth / 2),
        );
        final topPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: gradientColors,
          ).createShader(Rect.fromLTWH(x, centerY - halfBarHeight, actualBarWidth, halfBarHeight))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(topRect, topPaint);

        // 下半部分（从中心向下，倒影，透明度减半）
        final bottomRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, centerY, actualBarWidth, halfBarHeight),
          Radius.circular(actualBarWidth / 2),
        );
        final bottomPaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradientColors.map((c) => c.withValues(alpha: c.a * 0.5)).toList(),
          ).createShader(Rect.fromLTWH(x, centerY, actualBarWidth, halfBarHeight))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(bottomRect, bottomPaint);

        // 发光效果
        if (value > 0.6) {
          final glowIntensity = (value - 0.6) / 0.4;
          final glowPaint = Paint()
            ..color = (value > 0.8 ? Colors.white : color).withValues(alpha: 0.35 * glowIntensity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * glowIntensity);
          canvas.drawRRect(topRect, glowPaint);
        }
      } else {
        // 普通模式：从底部向上生长
        final barHeight = value * size.height * 0.9;
        if (barHeight < 1) continue;
        final y = size.height - barHeight;

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, actualBarWidth, barHeight),
          Radius.circular(actualBarWidth / 2),
        );
        final paint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: gradientColors,
          ).createShader(Rect.fromLTWH(x, y, actualBarWidth, barHeight))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rect, paint);

        // 发光效果
        if (value > 0.6) {
          final glowIntensity = (value - 0.6) / 0.4;
          final glowPaint = Paint()
            ..color = (value > 0.8 ? Colors.white : color).withValues(alpha: 0.4 * glowIntensity)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * glowIntensity);
          canvas.drawRRect(rect, glowPaint);

          if (value > 0.75) {
            final highlightPaint = Paint()
              ..color = Colors.white.withValues(alpha: 0.6 * glowIntensity)
              ..style = PaintingStyle.fill;
            canvas.drawCircle(
              Offset(x + actualBarWidth / 2, y),
              actualBarWidth / 3,
              highlightPaint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SimulatedSpectrumPainter oldDelegate) {
    return data != oldDelegate.data ||
        color != oldDelegate.color ||
        mirror != oldDelegate.mirror;
  }
}

/// 扩展方法：自定义 sin 近似
extension on double {
  double get sinApprox => _sin(this);
}

double _sin(double x) {
  // 简单的正弦近似
  x = x % (2 * 3.141592653589793);
  if (x < 0) x += 2 * 3.141592653589793;
  return 2 * (x / 3.141592653589793 - 0.5).abs() - 1;
}

// ─────────────────────────────────────────────
/// 五线谱绘制器
/// 4条水平谱线 + 音波在谱线之间起伏 + 高亮音符点
// ─────────────────────────────────────────────
class _LineSpectrumPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool mirror;

  _LineSpectrumPainter({
    required this.data,
    required this.color,
    this.mirror = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    _drawStaff(canvas, size);
    _drawMelodyWave(canvas, size);
  }

  /// 绘制 4 条水平谱线
  void _drawStaff(Canvas canvas, Size size) {
    const lineCount = 4;
    final staffTop = size.height * 0.15;
    final staffBottom = size.height * 0.85;
    final lineSpacing = (staffBottom - staffTop) / (lineCount - 1);

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < lineCount; i++) {
      final y = staffTop + i * lineSpacing;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  /// 绘制音波（在谱线之间起伏）
  void _drawMelodyWave(Canvas canvas, Size size) {
    final n = data.length;
    if (n < 2) return;

    const lineCount = 4;
    final staffTop = size.height * 0.15;
    final staffBottom = size.height * 0.85;
    final staffRange = staffBottom - staffTop;

    // 音波中心线固定在谱线中心
    final baseLine = staffTop + staffRange * 0.5;
    // 音波幅度不超过谱线间距 * 1.5
    final maxAmplitude = staffRange * 0.45;

    // 生成波形点（倒置 y 轴，频谱高 = 波向上）
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = baseLine - data[i] * maxAmplitude;
      points.add(Offset(x, y));
    }

    final linePath = _buildSmoothPath(points);

    // 面积填充（谱线中心到波形）
    final fillPath = Path.from(linePath);
    fillPath.lineTo(size.width, baseLine);
    fillPath.lineTo(0, baseLine);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.50),
          color.withValues(alpha: 0.10),
        ],
      ).createShader(Rect.fromLTWH(0, staffTop, size.width, staffRange))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 发光外描边
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(linePath, glowPaint);

    // 主线（彩虹渐变）
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.85),
          Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: 1.0),
          color.withValues(alpha: 0.85),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 高点音符（椭圆形填充 = 四分音符头）
    _drawNoteHeads(canvas, points, staffTop, staffRange, lineCount);
  }

  /// 在幅值高处绘制椭圆音符头
  void _drawNoteHeads(Canvas canvas, List<Offset> points, double staffTop, double staffRange, int lineCount) {
    final spacing = staffRange / (lineCount - 1);
    for (int i = 0; i < points.length; i++) {
      final value = data[i];
      if (value < 0.65) continue;
      final intensity = (value - 0.65) / 0.35;
      final pt = points[i];

      // 椭圆音符头（宽>高，略斜）
      final noteRect = Rect.fromCenter(
        center: pt,
        width: 9.0 * intensity + 4,
        height: 6.0 * intensity + 3,
      );
      final notePaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: 0.9 * intensity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(pt.dx, pt.dy);
      canvas.rotate(-0.25); // 音符头倾斜
      canvas.translate(-pt.dx, -pt.dy);
      canvas.drawOval(noteRect, notePaint);
      canvas.restore();

      // 符干（向上的短竖线）
      if (intensity > 0.5) {
        final stemPaint = Paint()
          ..color = color.withValues(alpha: 0.7 * intensity)
          ..strokeWidth = 1.5;
        canvas.drawLine(
          Offset(pt.dx + noteRect.width / 2 - 1, pt.dy),
          Offset(pt.dx + noteRect.width / 2 - 1, pt.dy - spacing * 0.9),
          stemPaint,
        );
      }
    }
  }

  /// Catmull-Rom 生成平滑路径
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _LineSpectrumPainter oldDelegate) {
    return data != oldDelegate.data ||
        color != oldDelegate.color ||
        mirror != oldDelegate.mirror;
  }
}

// ─────────────────────────────────────────────
/// 抖音风格双向镜像线谱
/// 自动适配容器方向：
/// - 竖向容器（高>宽）：数据沿 Y 轴，振幅向左右扩散
/// - 横向容器（宽>高）：数据沿 X 轴，振幅向上下扩散（镜像）
// ─────────────────────────────────────────────
class _TikTokLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _TikTokLinePainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final isHorizontal = size.width > size.height;

    if (isHorizontal) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局（原逻辑）──────────────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final maxAmp = cx * 0.85;
    final n = data.length;

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final y = size.height * i / (n - 1);
      final amp = data[i] * maxAmp;
      leftPoints.add(Offset(cx - amp, y));
      rightPoints.add(Offset(cx + amp, y));
    }

    final leftPath = _buildSmoothPath(leftPoints);
    final rightPath = _buildSmoothPath(rightPoints);

    _drawFillV(canvas, size, leftPath, cx, true);
    _drawFillV(canvas, size, rightPath, cx, false);
    _drawGlowV(canvas, leftPath);
    _drawGlowV(canvas, rightPath);
    _drawLineV(canvas, size, leftPath, true);
    _drawLineV(canvas, size, rightPath, false);

    // 中心基线
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), basePaint);
  }

  void _drawFillV(Canvas canvas, Size size, Path path, double cx, bool isLeft) {
    final fillPath = Path.from(path);
    fillPath.lineTo(cx, size.height);
    fillPath.lineTo(cx, 0);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        end: Alignment.center,
        colors: [color.withValues(alpha: 0.45), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawGlowV(Canvas canvas, Path path) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
  }

  void _drawLineV(Canvas canvas, Size size, Path path, bool isLeft) {
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.75),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  // ── 横向布局（手机/TV横向容器专用）───────────────────────
  // 数据沿 X 轴（从左到右），振幅分上下两路向外辐射扩散
  void _paintHorizontal(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final maxAmp = cy * 0.85;
    final n = data.length;

    // 上半路径 & 下半路径（Y 值是镜像的）
    final topPoints = <Offset>[];
    final bottomPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final amp = data[i] * maxAmp;
      topPoints.add(Offset(x, cy - amp));   // 向上（向外）
      bottomPoints.add(Offset(x, cy + amp));  // 向下（向外）
    }

    final topPath = _buildSmoothPath(topPoints);
    final bottomPath = _buildSmoothPath(bottomPoints);

    // 面积填充：填充到中心线，渐变从中心向外扩散
    _drawFillH(canvas, size, topPath, cy, true);
    _drawFillH(canvas, size, bottomPath, cy, false);

    // 发光
    _drawGlowH(canvas, topPath);
    _drawGlowH(canvas, bottomPath);

    // 主线
    _drawLineH(canvas, size, topPath, true);
    _drawLineH(canvas, size, bottomPath, false);

    // 中心基线（水平细线）
    final basePaint = Paint()
      ..color = color.withValues(alpha: 0.30)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), basePaint);
  }

  void _drawFillH(Canvas canvas, Size size, Path path, double cy, bool isTop) {
    final fillPath = Path.from(path);
    // 填充到中心线（cy），而不是到边缘
    fillPath.lineTo(size.width, cy);
    fillPath.lineTo(0, cy);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.center,  // 中心最亮
        end: isTop ? Alignment.topCenter : Alignment.bottomCenter,  // 向外渐变透明
        colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, isTop ? 0 : cy, size.width, cy))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawGlowH(Canvas canvas, Path path) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.20)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
  }

  void _drawLineH(Canvas canvas, Size size, Path path, bool isTop) {
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.75),
          Colors.white.withValues(alpha: 0.95),
          color.withValues(alpha: 0.75),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  /// Catmull-Rom 平滑路径
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _TikTokLinePainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color;
  }
}

// ─────────────────────────────────────────────
/// 单线细线谱
/// 自动适配容器方向：
/// - 竖向容器：高>宽，数据沿 Y 轴，线从右侧向左生长
/// - 横向容器：宽>高，数据沿 X 轴，线从底部向上生长
// ─────────────────────────────────────────────
class _ThinLinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _ThinLinePainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (size.width > size.height) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局（原逻辑）──────────────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final n = data.length;
    final baseX = size.width;       // 基线在右侧
    final maxAmp = size.width * 0.85; // 最大振幅（向左）

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final y = size.height * i / (n - 1);
      final x = baseX - data[i] * maxAmp;
      points.add(Offset(x, y));
    }

    final path = _buildSmoothPath(points);
    _drawFillV(canvas, size, path, baseX);
    _drawGlowV(canvas, path);
    _drawLineV(canvas, size, path);
  }

  void _drawFillV(Canvas canvas, Size size, Path path, double baseX) {
    final fillPath = Path.from(path);
    fillPath.lineTo(baseX, size.height);
    fillPath.lineTo(baseX, 0);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawGlowV(Canvas canvas, Path path) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  void _drawLineV(Canvas canvas, Size size, Path path) {
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 1.0),
          color.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  // ── 横向布局：数据沿 X 轴，线从底部向上生长 ─────────────
  void _paintHorizontal(Canvas canvas, Size size) {
    final n = data.length;
    final baseY = size.height;       // 基线在底部
    final maxAmp = size.height * 0.85; // 最大振幅（向上）

    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = size.width * i / (n - 1);
      final y = baseY - data[i] * maxAmp;
      points.add(Offset(x, y));
    }

    final path = _buildSmoothPath(points);
    _drawFillH(canvas, size, path, baseY);
    _drawGlowH(canvas, path);
    _drawLineH(canvas, size, path);
  }

  void _drawFillH(Canvas canvas, Size size, Path path, double baseY) {
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, baseY);
    fillPath.lineTo(0, baseY);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawGlowH(Canvas canvas, Path path) {
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);
  }

  void _drawLineH(Canvas canvas, Size size, Path path) {
    final linePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 1.0),
          color.withValues(alpha: 0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);
  }

  /// Catmull-Rom 平滑路径
  Path _buildSmoothPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
      final cp1x = p1.dx + (p2.dx - p0.dx) / 6.0;
      final cp1y = p1.dy + (p2.dy - p0.dy) / 6.0;
      final cp2x = p2.dx - (p3.dx - p1.dx) / 6.0;
      final cp2y = p2.dy - (p3.dy - p1.dy) / 6.0;
      path.cubicTo(cp1x, cp1y, cp2x, cp2y, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant _ThinLinePainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 🌟 霓虹脉冲效果 - 多彩渐变发光条
// 支持横向/竖向容器自动适配
// ═══════════════════════════════════════════════════════════════════════
class _NeonPulsePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double phase;

  _NeonPulsePainter({
    required this.data,
    required this.color,
    this.phase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (size.width > size.height) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局：条形从底部向上 ─────────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final n = data.length;

    // 霓虹颜色数组
    final neonColors = [
      const Color(0xFFFF0080),
      const Color(0xFFFF8C00),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF00FFFF),
      const Color(0xFF0080FF),
      const Color(0xFF8000FF),
    ];

    for (int i = 0; i < n; i++) {
      final value = data[i];
      final colorIndex = (i * neonColors.length / n).floor() % neonColors.length;
      final barColor = neonColors[colorIndex];

      final slotWidth = size.width / n;
      final x = i * slotWidth + slotWidth / 2;

      final barHeight = value * size.height * 0.85;
      final y = size.height - barHeight;

      // 发光层
      for (int glow = 3; glow >= 0; glow--) {
        final glowAlpha = (0.3 - glow * 0.07).clamp(0.0, 1.0);
        final glowWidth = 4.0 + glow * 6;
        final glowPaint = Paint()
          ..color = barColor.withValues(alpha: glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowWidth);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - glowWidth / 2, y, glowWidth, barHeight),
            Radius.circular(glowWidth / 2),
          ),
          glowPaint,
        );
      }

      // 主条形
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 3, y, 6, barHeight),
        const Radius.circular(3),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [barColor, Colors.white.withValues(alpha: 0.9), barColor],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(x - 3, y, 6, barHeight));
      canvas.drawRRect(rect, paint);

      // 顶部高光点
      if (value > 0.5) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x, y), 3 + value * 2, highlightPaint);
      }
    }
  }

  // ── 横向布局：条形从底部向上 ─────────────────────
  void _paintHorizontal(Canvas canvas, Size size) {
    final n = data.length;

    // 霓虹颜色数组
    final neonColors = [
      const Color(0xFFFF0080),
      const Color(0xFFFF8C00),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF00FFFF),
      const Color(0xFF0080FF),
      const Color(0xFF8000FF),
    ];

    final totalBars = n;
    final slotWidth = size.width / totalBars;
    final actualBarWidth = slotWidth * 0.65;
    final startX = slotWidth * 0.175;

    for (int i = 0; i < n; i++) {
      final value = data[i];
      final colorIndex = (i * neonColors.length / n).floor() % neonColors.length;
      final barColor = neonColors[colorIndex];

      final x = startX + i * slotWidth;
      final barHeight = value * size.height * 0.85;
      final y = size.height - barHeight;

      // 发光层
      for (int glow = 3; glow >= 0; glow--) {
        final glowAlpha = (0.3 - glow * 0.07).clamp(0.0, 1.0);
        final glowExtra = glow * 4.0;
        final glowPaint = Paint()
          ..color = barColor.withValues(alpha: glowAlpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowExtra);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x - glowExtra / 2, y, actualBarWidth + glowExtra, barHeight),
            Radius.circular((actualBarWidth + glowExtra) / 2),
          ),
          glowPaint,
        );
      }

      // 主条形
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, actualBarWidth, barHeight),
        Radius.circular(actualBarWidth / 2),
      );
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [barColor, Colors.white.withValues(alpha: 0.9), barColor],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(x, y, actualBarWidth, barHeight));
      canvas.drawRRect(rect, paint);

      // 顶部高光点
      if (value > 0.5) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(x + actualBarWidth / 2, y), 3 + value * 2, highlightPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeonPulsePainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color || phase != oldDelegate.phase;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 🎀 波浪丝带效果 - 多层流动波浪
// 支持横向/竖向容器自动适配
// ═══════════════════════════════════════════════════════════════════════
class _WaveRibbonPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double phase;

  _WaveRibbonPainter({
    required this.data,
    required this.color,
    this.phase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (size.width > size.height) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局：波浪从左到右流动 ──────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final n = data.length;
    final ribbonCount = 5;

    for (int r = 0; r < ribbonCount; r++) {
      final ribbonPhase = phase + r * 0.5;
      final opacity = 0.6 - r * 0.1;
      final yOffset = size.height * (0.15 + r * 0.15);

      final points = <Offset>[];
      final fillPoints = <Offset>[];

      for (int i = 0; i < n; i++) {
        final x = size.width * i / (n - 1);
        final waveOffset = sin(ribbonPhase + i * 0.3 + r * 0.8) * 15;
        final y = yOffset + data[i] * size.height * 0.3 + waveOffset;
        points.add(Offset(x, y));
        fillPoints.add(Offset(x, size.height - yOffset));
      }

      // 填充区域
      final fillPath = Path()..moveTo(0, size.height);
      for (final p in fillPoints.reversed) {
        fillPath.lineTo(p.dx, p.dy);
      }
      fillPath.lineTo(size.width, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: opacity * 0.8),
            color.withValues(alpha: opacity * 0.2),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // 波峰线
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final cp = Offset(
          (points[i - 1].dx + points[i].dx) / 2,
          (points[i - 1].dy + points[i].dy) / 2,
        );
        linePath.quadraticBezierTo(
          points[i - 1].dx, points[i - 1].dy,
          cp.dx, cp.dy,
        );
      }
      linePath.lineTo(points.last.dx, points.last.dy);

      final linePaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 - r * 0.3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, linePaint);
    }
  }

  // ── 横向布局：波浪从底部向上流动 ─────────────────────────
  void _paintHorizontal(Canvas canvas, Size size) {
    final n = data.length;
    final ribbonCount = 5;

    for (int r = 0; r < ribbonCount; r++) {
      final ribbonPhase = phase + r * 0.5;
      final opacity = 0.6 - r * 0.1;

      final points = <Offset>[];

      for (int i = 0; i < n; i++) {
        final x = size.width * i / (n - 1);
        // 波浪高度随频谱数据变化，多层错开
        final waveOffset = sin(ribbonPhase + i * 0.3 + r * 0.8) * 12;
        final waveHeight = data[i] * size.height * (0.5 - r * 0.08);
        final y = size.height - waveHeight - r * size.height * 0.05 + waveOffset;
        points.add(Offset(x, y.clamp(0.0, size.height)));
      }

      // 构建平滑路径
      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        final cp = Offset(
          (points[i - 1].dx + points[i].dx) / 2,
          (points[i - 1].dy + points[i].dy) / 2,
        );
        linePath.quadraticBezierTo(
          points[i - 1].dx, points[i - 1].dy,
          cp.dx, cp.dy,
        );
      }
      linePath.lineTo(points.last.dx, points.last.dy);

      // 填充区域（波浪到底部）
      final fillPath = Path.from(linePath);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: opacity * 0.6),
            color.withValues(alpha: opacity * 0.1),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);

      // 波峰线
      final linePaint = Paint()
        ..color = Color.lerp(color, Colors.white, 0.3)!.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 - r * 0.3
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(linePath, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveRibbonPainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color || phase != oldDelegate.phase;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// ✨ 粒子爆发效果 - 频谱驱动粒子
// 支持横向/竖向容器自动适配
// ═══════════════════════════════════════════════════════════════════════
class _ParticlePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double phase;

  _ParticlePainter({
    required this.data,
    required this.color,
    this.phase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (size.width > size.height) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局：圆形放射 ─────────────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = min(size.width, size.height) * 0.45;

    final particleColors = [
      color,
      Color.lerp(color, Colors.white, 0.5)!,
      Color.lerp(color, const Color(0xFFFF00FF), 0.5)!,
    ];

    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      final angle = (i / data.length) * 2 * pi + phase;
      final radius = value * maxRadius;

      final x = centerX + cos(angle) * radius;
      final y = centerY + sin(angle) * radius;
      final particleSize = 2 + value * 8;

      // 发光
      final glowPaint = Paint()
        ..color = particleColors[i % particleColors.length].withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleSize * 2);
      canvas.drawCircle(Offset(x, y), particleSize * 2, glowPaint);

      // 粒子
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, particleColors[i % particleColors.length]],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: particleSize));
      canvas.drawCircle(Offset(x, y), particleSize, paint);

      // 拖尾
      if (value > 0.3) {
        for (int t = 1; t <= 5; t++) {
          final trailRadius = radius * (1 - t * 0.15);
          final trailX = centerX + cos(angle) * trailRadius;
          final trailY = centerY + sin(angle) * trailRadius;
          final trailPaint = Paint()
            ..color = particleColors[i % particleColors.length].withValues(alpha: 0.6 - t * 0.12)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(trailX, trailY), particleSize * (1 - t * 0.15), trailPaint);
        }
      }
    }

    // 中心光晕
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: maxRadius * 0.3));
    canvas.drawCircle(Offset(centerX, centerY), maxRadius * 0.3, centerGlow);
  }

  // ── 横向布局：椭圆形横向拉伸 ────────────────────────────
  void _paintHorizontal(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadiusX = size.width * 0.45;
    final maxRadiusY = size.height * 0.4;

    final particleColors = [
      color,
      Color.lerp(color, Colors.white, 0.5)!,
      Color.lerp(color, const Color(0xFFFF00FF), 0.5)!,
    ];

    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      final angle = (i / data.length) * 2 * pi + phase;
      final radiusX = value * maxRadiusX;
      final radiusY = value * maxRadiusY;

      // 椭圆路径上的粒子
      final x = centerX + cos(angle) * radiusX;
      final y = centerY + sin(angle) * radiusY;
      final particleSize = 2 + value * 6;

      // 发光
      final glowPaint = Paint()
        ..color = particleColors[i % particleColors.length].withValues(alpha: 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, particleSize * 2);
      canvas.drawCircle(Offset(x, y), particleSize * 2, glowPaint);

      // 粒子
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, particleColors[i % particleColors.length]],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: particleSize));
      canvas.drawCircle(Offset(x, y), particleSize, paint);

      // 拖尾
      if (value > 0.3) {
        for (int t = 1; t <= 5; t++) {
          final trailX = centerX + cos(angle) * radiusX * (1 - t * 0.12);
          final trailY = centerY + sin(angle) * radiusY * (1 - t * 0.12);
          final trailPaint = Paint()
            ..color = particleColors[i % particleColors.length].withValues(alpha: 0.5 - t * 0.1)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(Offset(trailX, trailY), particleSize * (1 - t * 0.15), trailPaint);
        }
      }
    }

    // 中心光晕
    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(centerX - maxRadiusX * 0.3, centerY - maxRadiusY * 0.3, maxRadiusX * 0.6, maxRadiusY * 0.6));
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX, centerY), width: maxRadiusX * 0.6, height: maxRadiusY * 0.6), centerGlow);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color || phase != oldDelegate.phase;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 💎 水晶棱镜效果 - 彩虹折射
// 支持横向/竖向容器自动适配
// ═══════════════════════════════════════════════════════════════════════
class _CrystalPrismPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double phase;

  _CrystalPrismPainter({
    required this.data,
    required this.color,
    this.phase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (size.width > size.height) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局：圆形水晶棱镜 ───────────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final n = data.length;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final rainbowColors = [
      const Color(0xFFFF0000),
      const Color(0xFFFF7F00),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF0000FF),
      const Color(0xFF4B0082),
      const Color(0xFF9400D3),
    ];

    for (int i = 0; i < n; i++) {
      final value = data[i];
      final angle = (i / n) * 2 * pi - pi / 2;

      final innerRadius = size.width * 0.2;
      final outerRadius = innerRadius + value * size.height * 0.7;

      final innerX = centerX + cos(angle) * innerRadius;
      final innerY = centerY + sin(angle) * innerRadius;
      final outerX = centerX + cos(angle) * outerRadius;
      final outerY = centerY + sin(angle) * outerRadius;

      final colorIndex = ((i / n) * rainbowColors.length + phase / (2 * pi)) % rainbowColors.length;
      final barColor = rainbowColors[colorIndex.floor() % rainbowColors.length];

      final barWidth = size.width / n * 0.6;
      final perpAngle = angle + pi / 2;

      final p1 = Offset(outerX + cos(perpAngle) * barWidth / 2, outerY + sin(perpAngle) * barWidth / 2);
      final p2 = Offset(outerX - cos(perpAngle) * barWidth / 2, outerY - sin(perpAngle) * barWidth / 2);
      final p3 = Offset(innerX - cos(perpAngle) * barWidth / 4, innerY - sin(perpAngle) * barWidth / 4);
      final p4 = Offset(innerX + cos(perpAngle) * barWidth / 4, innerY + sin(perpAngle) * barWidth / 4);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [barColor.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.7), barColor.withValues(alpha: 0.9)],
        ).createShader(Rect.fromPoints(p3, p1));
      canvas.drawPath(path, paint);

      if (value > 0.5) {
        final glowPaint = Paint()
          ..color = barColor.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(path, glowPaint);
      }

      if (value > 0.6) {
        final crystalPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(outerX, outerY), 2 + value * 3, crystalPaint);
      }
    }

    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, color.withValues(alpha: 0.5), Colors.transparent],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: size.width * 0.15));
    canvas.drawCircle(Offset(centerX, centerY), size.width * 0.15, centerPaint);
  }

  // ── 横向布局：水平椭圆水晶棱镜 ───────────────────────────
  void _paintHorizontal(Canvas canvas, Size size) {
    final n = data.length;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadiusX = size.width * 0.45;
    final maxRadiusY = size.height * 0.4;

    final rainbowColors = [
      const Color(0xFFFF0000),
      const Color(0xFFFF7F00),
      const Color(0xFFFFFF00),
      const Color(0xFF00FF00),
      const Color(0xFF0000FF),
      const Color(0xFF4B0082),
      const Color(0xFF9400D3),
    ];

    for (int i = 0; i < n; i++) {
      final value = data[i];
      final angle = (i / n) * 2 * pi - pi / 2;

      final innerRadiusX = size.width * 0.1;
      final innerRadiusY = size.height * 0.15;
      final outerRadiusX = innerRadiusX + value * maxRadiusX * 0.8;
      final outerRadiusY = innerRadiusY + value * maxRadiusY * 0.8;

      final innerX = centerX + cos(angle) * innerRadiusX;
      final innerY = centerY + sin(angle) * innerRadiusY;
      final outerX = centerX + cos(angle) * outerRadiusX;
      final outerY = centerY + sin(angle) * outerRadiusY;

      final colorIndex = ((i / n) * rainbowColors.length + phase / (2 * pi)) % rainbowColors.length;
      final barColor = rainbowColors[colorIndex.floor() % rainbowColors.length];

      final barHeight = size.height / n * 0.4;
      final perpAngle = angle + pi / 2;

      final p1 = Offset(outerX + cos(perpAngle) * barHeight / 2, outerY + sin(perpAngle) * barHeight / 2);
      final p2 = Offset(outerX - cos(perpAngle) * barHeight / 2, outerY - sin(perpAngle) * barHeight / 2);
      final p3 = Offset(innerX - cos(perpAngle) * barHeight / 4, innerY - sin(perpAngle) * barHeight / 4);
      final p4 = Offset(innerX + cos(perpAngle) * barHeight / 4, innerY + sin(perpAngle) * barHeight / 4);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..lineTo(p4.dx, p4.dy)
        ..close();

      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [barColor.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.7), barColor.withValues(alpha: 0.9)],
        ).createShader(Rect.fromPoints(p3, p1));
      canvas.drawPath(path, paint);

      if (value > 0.5) {
        final glowPaint = Paint()
          ..color = barColor.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawPath(path, glowPaint);
      }

      if (value > 0.6) {
        final crystalPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(outerX, outerY), 2 + value * 2, crystalPaint);
      }
    }

    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, color.withValues(alpha: 0.5), Colors.transparent],
      ).createShader(Rect.fromCenter(center: Offset(centerX, centerY), width: maxRadiusX * 0.3, height: maxRadiusY * 0.3));
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX, centerY), width: maxRadiusX * 0.3, height: maxRadiusY * 0.3), centerPaint);
  }

  @override
  bool shouldRepaint(covariant _CrystalPrismPainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color || phase != oldDelegate.phase;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 🔮 环形脉冲效果 - 同心圆扩散
// 支持横向/竖向容器自动适配
// ═══════════════════════════════════════════════════════════════════════
class _RingPulsePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double phase;

  _RingPulsePainter({
    required this.data,
    required this.color,
    this.phase = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    if (size.width > size.height) {
      _paintHorizontal(canvas, size);
    } else {
      _paintVertical(canvas, size);
    }
  }

  // ── 竖向布局：圆形同心圆 ────────────────────────────────
  void _paintVertical(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = min(size.width, size.height) * 0.45;

    final ringCount = 4;
    for (int ring = ringCount - 1; ring >= 0; ring--) {
      final ringPhase = phase + ring * 0.3;
      final ringRadius = maxRadius * (0.3 + ring * 0.2);

      final dataIndex = ((data.length * ring / ringCount) + (ringPhase * data.length / (2 * pi)).floor()) % data.length;
      final value = data[dataIndex.floor() % data.length];

      final pulseRadius = ringRadius + value * maxRadius * 0.3;

      final ringPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.6 + value * 0.4),
            Colors.white.withValues(alpha: 0.3 + value * 0.4),
            color.withValues(alpha: 0.6 + value * 0.4),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: pulseRadius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + ring * 2;

      canvas.drawCircle(Offset(centerX, centerY), pulseRadius, ringPaint);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawCircle(Offset(centerX, centerY), pulseRadius, glowPaint);
    }

    // 频谱点
    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      if (value < 0.5) continue;

      final angle = (i / data.length) * 2 * pi + phase;
      final radius = maxRadius * 0.5 + value * maxRadius * 0.4;

      final x = centerX + cos(angle) * radius;
      final y = centerY + sin(angle) * radius;

      final pointGlow = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), 4 + value * 4, pointGlow);

      final pointPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, color],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 3 + value * 3));
      canvas.drawCircle(Offset(x, y), 3 + value * 3, pointPaint);
    }

    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, color.withValues(alpha: 0.8), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(centerX, centerY), radius: maxRadius * 0.2));
    canvas.drawCircle(Offset(centerX, centerY), maxRadius * 0.2, centerGlow);
  }

  // ── 横向布局：椭圆横向拉伸 ──────────────────────────────
  void _paintHorizontal(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadiusX = size.width * 0.45;
    final maxRadiusY = size.height * 0.4;

    final ringCount = 4;
    for (int ring = ringCount - 1; ring >= 0; ring--) {
      final ringPhase = phase + ring * 0.3;
      final ringRadiusX = maxRadiusX * (0.3 + ring * 0.2);
      final ringRadiusY = maxRadiusY * (0.3 + ring * 0.2);

      final dataIndex = ((data.length * ring / ringCount) + (ringPhase * data.length / (2 * pi)).floor()) % data.length;
      final value = data[dataIndex.floor() % data.length];

      final pulseRadiusX = ringRadiusX + value * maxRadiusX * 0.3;
      final pulseRadiusY = ringRadiusY + value * maxRadiusY * 0.3;

      // 绘制椭圆环
      final ringRect = Rect.fromCenter(
        center: Offset(centerX, centerY),
        width: pulseRadiusX * 2,
        height: pulseRadiusY * 2,
      );

      final ringPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          colors: [
            color.withValues(alpha: 0.0),
            color.withValues(alpha: 0.6 + value * 0.4),
            Colors.white.withValues(alpha: 0.3 + value * 0.4),
            color.withValues(alpha: 0.6 + value * 0.4),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(ringRect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + ring * 2;

      canvas.drawOval(ringRect, ringPaint);

      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10);
      canvas.drawOval(ringRect, glowPaint);
    }

    // 频谱点（椭圆路径上）
    for (int i = 0; i < data.length; i++) {
      final value = data[i];
      if (value < 0.5) continue;

      final angle = (i / data.length) * 2 * pi + phase;
      final radiusX = maxRadiusX * 0.5 + value * maxRadiusX * 0.4;
      final radiusY = maxRadiusY * 0.5 + value * maxRadiusY * 0.4;

      final x = centerX + cos(angle) * radiusX;
      final y = centerY + sin(angle) * radiusY;

      final pointGlow = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), 4 + value * 4, pointGlow);

      final pointPaint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, color],
        ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 3 + value * 3));
      canvas.drawCircle(Offset(x, y), 3 + value * 3, pointPaint);
    }

    final centerGlow = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, color.withValues(alpha: 0.8), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCenter(center: Offset(centerX, centerY), width: maxRadiusX * 0.4, height: maxRadiusY * 0.4));
    canvas.drawOval(Rect.fromCenter(center: Offset(centerX, centerY), width: maxRadiusX * 0.4, height: maxRadiusY * 0.4), centerGlow);
  }

  @override
  bool shouldRepaint(covariant _RingPulsePainter oldDelegate) {
    return data != oldDelegate.data || color != oldDelegate.color || phase != oldDelegate.phase;
  }
}
