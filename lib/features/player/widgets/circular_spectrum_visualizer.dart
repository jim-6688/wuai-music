import 'dart:math';
import 'package:flutter/material.dart';

/// 环形频谱可视化
/// 音频频谱条呈圆形放射状排列，从中心向外延伸
class CircularSpectrumVisualizer extends StatefulWidget {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double size;

  const CircularSpectrumVisualizer({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.size = 300,
  });

  @override
  State<CircularSpectrumVisualizer> createState() => _CircularSpectrumVisualizerState();
}

class _CircularSpectrumVisualizerState extends State<CircularSpectrumVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _smoothedData = [];
  final int _barCount = 64; // 环形频谱条数量

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
    )..addListener(() {
        if (widget.isPlaying) {
          setState(() {
            _smoothData();
          });
        }
      });
    _controller.repeat();
  }

  void _smoothData() {
    if (widget.spectrumData.isEmpty) {
      _smoothedData.clear();
      return;
    }

    // 初始化平滑数据
    if (_smoothedData.length != _barCount) {
      _smoothedData.clear();
      for (int i = 0; i < _barCount; i++) {
        _smoothedData.add(0);
      }
    }

    // 将频谱数据映射到条数
    final srcLen = widget.spectrumData.length;
    for (int i = 0; i < _barCount; i++) {
      // 映射索引
      final srcIdx = (i * srcLen / _barCount).floor();
      final targetValue = srcIdx < srcLen ? widget.spectrumData[srcIdx] : 0.0;
      
      // 平滑过渡
      _smoothedData[i] = _smoothedData[i] * 0.6 + targetValue * 0.4;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _CircularSpectrumPainter(
          spectrumData: List.from(_smoothedData),
          color: widget.color,
          isPlaying: widget.isPlaying,
        ),
      ),
    );
  }
}

class _CircularSpectrumPainter extends CustomPainter {
  final List<double> spectrumData;
  final Color color;
  final bool isPlaying;

  _CircularSpectrumPainter({
    required this.spectrumData,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width * 0.25; // 内圈半径
    final maxBarHeight = size.width * 0.2; // 最大条高度

    // 绘制内圈光晕
    _drawInnerGlow(canvas, center, baseRadius);

    // 绘制频谱条
    _drawSpectrumBars(canvas, center, baseRadius, maxBarHeight);

    // 绘制中心圆
    _drawCenterCircle(canvas, center, baseRadius * 0.6);
  }

  void _drawInnerGlow(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha(30),
          color.withAlpha(10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5));
    
    canvas.drawCircle(center, radius * 1.5, paint);
  }

  void _drawCenterCircle(Canvas canvas, Offset center, double radius) {
    // 外圈边框
    final borderPaint = Paint()
      ..color = color.withAlpha(100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawCircle(center, radius, borderPaint);

    // 内部填充
    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withAlpha(40),
          color.withAlpha(20),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    
    canvas.drawCircle(center, radius, fillPaint);
  }

  void _drawSpectrumBars(Canvas canvas, Offset center, double baseRadius, double maxBarHeight) {
    if (spectrumData.isEmpty) return;

    final barCount = spectrumData.length;
    final angleStep = 2 * pi / barCount;

    for (int i = 0; i < barCount; i++) {
      final value = spectrumData[i];
      if (value < 0.01) continue; // 跳过几乎为零的条

      final barHeight = value * maxBarHeight;
      final angle = i * angleStep - pi / 2; // 从顶部开始

      // 计算条的起点和终点
      final startX = center.dx + cos(angle) * baseRadius;
      final startY = center.dy + sin(angle) * baseRadius;
      final endX = center.dx + cos(angle) * (baseRadius + barHeight);
      final endY = center.dy + sin(angle) * (baseRadius + barHeight);

      // 条的宽度随位置变化
      final barWidth = 2.5 + value * 2;

      // 创建条形
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withAlpha(150),
            color,
            color.withAlpha(200),
          ],
        ).createShader(Rect.fromPoints(
          Offset(startX, startY),
          Offset(endX, endY),
        ))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = barWidth
        ..style = PaintingStyle.stroke;

      // 绘制条形线
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        paint,
      );

      // 高能量时添加发光效果
      if (value > 0.5) {
        final glowPaint = Paint()
          ..color = color.withAlpha((value * 100).toInt())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + value * 3)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = barWidth * 1.5
          ..style = PaintingStyle.stroke;
        
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          glowPaint,
        );
      }

      // 末端小圆点
      if (value > 0.3) {
        canvas.drawCircle(
          Offset(endX, endY),
          barWidth * 0.8,
          Paint()..color = Colors.white.withAlpha((value * 180).toInt()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CircularSpectrumPainter old) {
    return isPlaying || old.isPlaying;
  }
}
