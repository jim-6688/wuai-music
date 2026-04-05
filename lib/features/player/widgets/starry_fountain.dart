import 'dart:math';
import 'package:flutter/material.dart';

/// 星空粒子
class StarParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double brightness;
  double twinkle;
  double phase;
  double life;
  Color color;

  StarParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.brightness,
    required this.color,
    required this.twinkle,
    required this.phase,
    this.life = 1.0,
  });

  bool get isDead => life <= 0;
}

/// 星空喷泉效果
class StarryFountainVisualizer extends StatefulWidget {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double height;

  const StarryFountainVisualizer({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.height = 200,
  });

  @override
  State<StarryFountainVisualizer> createState() => _StarryFountainVisualizerState();
}

class _StarryFountainVisualizerState extends State<StarryFountainVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<StarParticle> _particles = [];
  final Random _random = Random();
  int _frameCount = 0;
  double _time = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;
    _frameCount++;
    _time += 0.016;

    if (widget.isPlaying) {
      if (_frameCount % 2 == 0) {
        _generateParticles();
      }
    } else {
      if (_frameCount % 4 == 0 && _particles.isNotEmpty) {
        _particles.removeLast();
      }
    }

    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * 0.016;
      p.y += p.vy * 0.016;
      p.vy += 50 * 0.016;
      p.phase += p.twinkle * 0.016;
      p.life -= 0.005;
      
      if (p.isDead) {
        _particles.removeAt(i);
      }
    }

    if (mounted) setState(() {});
  }

  void _generateParticles() {
    final data = widget.spectrumData;
    if (data.isEmpty) return;

    final width = MediaQuery.of(context).size.width;
    final centerX = width / 2;
    
    double avgEnergy = data.reduce((a, b) => a + b) / data.length;
    final count = (avgEnergy * 20 + 3).toInt().clamp(2, 15);

    for (int i = 0; i < count; i++) {
      final speed = 100 + avgEnergy * 300 + _random.nextDouble() * 100;
      final angle = -pi / 2 + (_random.nextDouble() - 0.5) * 1.0;
      
      final colorIndex = _random.nextInt(4);
      final colors = [
        Colors.white,
        Colors.cyan.shade200,
        widget.color,
        Colors.purple.shade200,
      ];

      _particles.add(StarParticle(
        x: centerX + (_random.nextDouble() - 0.5) * width * 0.6,
        y: widget.height,
        vx: cos(angle) * speed * 0.2,
        vy: sin(angle) * speed,
        size: 2 + _random.nextDouble() * 4,
        brightness: 0.5 + _random.nextDouble() * 0.5,
        color: colors[colorIndex],
        twinkle: 2 + _random.nextDouble() * 4,
        phase: _random.nextDouble() * 2 * pi,
        life: 1.0,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _StarryFountainPainter(
          particles: _particles,
          time: _time,
          color: widget.color,
        ),
      ),
    );
  }
}

class _StarryFountainPainter extends CustomPainter {
  final List<StarParticle> particles;
  final double time;
  final Color color;

  _StarryFountainPainter({
    required this.particles,
    required this.time,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawTrails(canvas, size);
    
    for (final p in particles) {
      final twinkle = 0.5 + 0.5 * sin(p.phase);
      final alpha = p.brightness * twinkle * p.life;
      
      if (alpha < 0.05) continue;
      
      // Glow
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * 2,
        Paint()..color = p.color.withAlpha((alpha * 100).toInt())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 2),
      );
      
      // Star core
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size,
        Paint()..color = p.color.withAlpha((alpha * 255).toInt()),
      );
      
      // Sparkle cross
      if (twinkle > 0.7 && p.size > 3) {
        final sp = (twinkle - 0.7) / 0.3;
        final starPaint = Paint()
          ..color = Colors.white.withAlpha((sp * alpha * 255).toInt())
          ..strokeWidth = 1;
        
        canvas.drawLine(
          Offset(p.x - p.size * 1.5, p.y),
          Offset(p.x + p.size * 1.5, p.y),
          starPaint,
        );
        canvas.drawLine(
          Offset(p.x, p.y - p.size * 1.5),
          Offset(p.x, p.y + p.size * 1.5),
          starPaint,
        );
      }
    }
    
    // Bottom glow
    final rect = Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3);
    canvas.drawOval(
      rect,
      Paint()..shader = RadialGradient(
        colors: [color.withAlpha(128), color.withAlpha(50), Colors.transparent],
      ).createShader(rect),
    );
  }

  void _drawBackground(Canvas canvas, Size size) {
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.indigo.shade900.withAlpha(77),
        Colors.purple.shade900.withAlpha(128),
        color.withAlpha(77),
      ],
    );
    
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      ),
    );
  }

  void _drawTrails(Canvas canvas, Size size) {
    for (final p in particles) {
      for (int i = 1; i <= 5; i++) {
        final trailY = p.y + i * 3;
        final trailAlpha = p.life * 0.3 * (1 - i / 5) * 0.3;
        
        canvas.drawCircle(
          Offset(p.x - p.vx * i * 0.3, trailY),
          p.size * (1 - i / 5) * 0.5,
          Paint()..color = p.color.withAlpha((trailAlpha * 255).toInt()),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StarryFountainPainter old) => true;
}
