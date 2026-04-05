import 'dart:math';
import 'package:flutter/material.dart';

/// 猫耳频谱可视化
class CatEarVisualizer extends StatefulWidget {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double height;

  const CatEarVisualizer({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.height = 200,
  });

  @override
  State<CatEarVisualizer> createState() => _CatEarVisualizerState();
}

class _CatEarVisualizerState extends State<CatEarVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(() {
      if (widget.isPlaying) {
        setState(() => _time += 0.05);
      }
    });
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _CatEarPainter(
          spectrumData: widget.spectrumData,
          color: widget.color,
          time: _time,
        ),
      ),
    );
  }
}

class _CatEarPainter extends CustomPainter {
  final List<double> spectrumData;
  final Color color;
  final double time;

  _CatEarPainter({
    required this.spectrumData,
    required this.color,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawEars(canvas, size);
    _drawSpectrum(canvas, size);
    _drawFace(canvas, size);
  }

  void _drawEars(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    
    double energy = 0;
    if (spectrumData.isNotEmpty) {
      energy = spectrumData.reduce((a, b) => a + b) / spectrumData.length;
    }
    
    final pulse = 1.0 + energy * 0.15;
    
    _drawEar(canvas, cx - w * 0.28, h * 0.35, w * 0.18 * pulse, energy);
    _drawEar(canvas, cx + w * 0.28, h * 0.35, w * 0.18 * pulse, energy);
  }

  void _drawEar(Canvas canvas, double x, double y, double w, double energy) {
    final earH = w * 1.2;
    
    final path = Path();
    path.moveTo(x - w, y);
    path.lineTo(x, y - earH);
    path.lineTo(x + w, y);
    path.close();
    
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, Colors.pink.shade300 ?? color],
      ).createShader(Rect.fromCenter(
        center: Offset(x, y - earH * 0.5),
        width: w * 2.5,
        height: earH * 1.5,
      ));
    canvas.drawPath(path, paint);
    
    // Inner ear
    final inner = Path();
    inner.moveTo(x - w * 0.4, y - earH * 0.1);
    inner.lineTo(x, y - earH * 0.7);
    inner.lineTo(x + w * 0.4, y - earH * 0.1);
    inner.close();
    canvas.drawPath(inner, Paint()..color = Colors.pink.shade100 ?? Colors.white);
    
    if (energy > 0.3) {
      canvas.drawPath(path, Paint()
        ..color = Color.lerp(color, Colors.white, energy * 0.5) ?? color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * energy));
    }
  }

  void _drawFace(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final headY = h * 0.55;
    
    final headPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.pink.shade100 ?? Colors.white, Color.lerp(color, Colors.pink, 0.5) ?? color],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, headY),
        width: w * 0.5,
        height: h * 0.4,
      ));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headY), width: w * 0.5, height: h * 0.35),
      headPaint,
    );
    
    // Blush
    final blush = Paint()
      ..color = (Colors.pink.shade200 ?? Colors.pink).withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.15, headY + h * 0.05), width: w * 0.08, height: h * 0.05), blush);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + w * 0.15, headY + h * 0.05), width: w * 0.08, height: h * 0.05), blush);
    
    // Nose
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, headY + h * 0.08), width: w * 0.04, height: h * 0.03),
      Paint()..color = Colors.pink.shade300 ?? Colors.pink,
    );
    
    // Whiskers
    final whisker = Paint()
      ..color = Colors.white.withAlpha(120)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    
    for (int i = -1; i <= 1; i++) {
      final yOff = i * h * 0.04;
      canvas.drawLine(Offset(cx - w * 0.08, headY + yOff), Offset(cx - w * 0.25, headY + yOff - h * 0.02), whisker);
      canvas.drawLine(Offset(cx + w * 0.08, headY + yOff), Offset(cx + w * 0.25, headY + yOff - h * 0.02), whisker);
    }
  }

  void _drawSpectrum(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final bars = spectrumData.length;
    final half = bars ~/ 2;
    
    for (int i = 0; i < half; i++) {
      final e = spectrumData[i];
      final barH = e * h * 0.45;
      final x = cx - 20 - (half - i) * 5;
      _drawBar(canvas, x, h - barH, 4, barH, e);
      
      final e2 = spectrumData[bars - 1 - i];
      final barH2 = e2 * h * 0.45;
      final x2 = cx + 20 + (half - i) * 5;
      _drawBar(canvas, x2, h - barH2, 4, barH2, e2);
    }
  }

  void _drawBar(Canvas canvas, double x, double y, double bw, double bh, double e) {
    if (bh < 2) return;
    
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [color, Colors.cyan, Colors.white],
      ).createShader(Rect.fromLTWH(x, y, bw, bh));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), Radius.circular(bw / 2)),
      paint,
    );
    
    if (e > 0.3) {
      canvas.drawCircle(
        Offset(x + bw / 2, y),
        bw * 0.7,
        Paint()
          ..color = Colors.white.withAlpha((e * 150).toInt())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_CatEarPainter old) => true;
}
