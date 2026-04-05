import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../shared/widgets/glass_widgets.dart';

class BlastParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  double maxLife;

  BlastParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    this.life = 1.0,
    this.maxLife = 1.0,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 150 * dt;
    life -= dt / maxLife;
  }

  bool get isDead => life <= 0;
}

class ParticleBlastButton extends StatefulWidget {
  final bool isPlaying;
  final List<double> spectrumData;
  final Color color;
  final VoidCallback onPressed;

  const ParticleBlastButton({
    super.key,
    required this.isPlaying,
    required this.spectrumData,
    required this.color,
    required this.onPressed,
  });

  @override
  State<ParticleBlastButton> createState() => _ParticleBlastButtonState();
}

class _ParticleBlastButtonState extends State<ParticleBlastButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<BlastParticle> _particles = [];
  final Random _random = Random();
  int _frameCount = 0;

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
      _particles[i].update(0.016);
      if (_particles[i].isDead) {
        _particles.removeAt(i);
      }
    }

    if (mounted) setState(() {});
  }

  void _generateParticles() {
    double avgEnergy = 0;
    if (widget.spectrumData.isNotEmpty) {
      avgEnergy = widget.spectrumData.reduce((a, b) => a + b) / widget.spectrumData.length;
    }
    
    final count = (avgEnergy * 3 + 1).toInt().clamp(1, 5);

    for (int i = 0; i < count; i++) {
      final speed = 80 + avgEnergy * 150 + _random.nextDouble() * 60;
      final angle = -pi / 2 + (_random.nextDouble() - 0.5) * 0.8;

      _particles.add(BlastParticle(
        x: 0,
        y: 0,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        size: 2 + _random.nextDouble() * 3,
        color: _getParticleColor(avgEnergy),
        maxLife: 0.4 + _random.nextDouble() * 0.4,
      ));
    }
  }

  Color _getParticleColor(double energy) {
    if (energy > 0.7) {
      return Color.lerp(widget.color, Colors.white, 0.5) ?? widget.color;
    } else if (energy > 0.4) {
      return widget.color;
    } else {
      return Color.lerp(widget.color, Colors.white, 0.3) ?? widget.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 粒子层 - 覆盖整个按钮区域
          if (_particles.isNotEmpty)
            Positioned.fill(
              child: CustomPaint(
                painter: _BlastPainter(particles: _particles),
              ),
            ),
          // 播放按钮
          GlassContainer(
            width: 64,
            height: 64,
            borderRadius: 32,
            blur: 15,
            backgroundColor: widget.color.withValues(alpha: 0.2),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: widget.onPressed,
              icon: Icon(
                widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
                color: widget.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlastPainter extends CustomPainter {
  final List<BlastParticle> particles;
  _BlastPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    // 按钮中心点
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (final p in particles) {
      final alpha = p.life.clamp(0.0, 1.0);

      // 外发光
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(cx + p.x, cy + p.y), p.size * 1.5, glowPaint);

      // 核心粒子
      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.8)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(cx + p.x, cy + p.y), p.size, paint);

      // 高光
      if (p.life > 0.5) {
        final hPaint = Paint()
          ..color = Colors.white.withValues(alpha: (p.life - 0.5) * 0.6);
        canvas.drawCircle(
          Offset(cx + p.x - p.size * 0.3, cy + p.y - p.size * 0.3),
          p.size * 0.3,
          hPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BlastPainter old) => true;
}
