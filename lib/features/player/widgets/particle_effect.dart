import 'dart:math';
import 'package:flutter/material.dart';

/// 粒子喷射效果 - 从播放键向外喷射
class ParticleEffect extends StatefulWidget {
  /// 是否播放中
  final bool isPlaying;
  
  /// 粒子数量
  final int particleCount;
  
  /// 粒子颜色
  final Color? color;
  
  /// 最大扩散半径
  final double maxRadius;
  
  /// 中心对齐位置
  final Alignment centerAlignment;
  
  /// 粒子大小
  final double particleSize;
  
  /// 喷射速度
  final double speed;

  const ParticleEffect({
    super.key,
    required this.isPlaying,
    this.particleCount = 50,
    this.color,
    this.maxRadius = 150,
    this.centerAlignment = Alignment.bottomCenter,
    this.particleSize = 4.0,
    this.speed = 1.0,
  });

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    
    _initParticles();
  }
  
  void _initParticles() {
    _particles.clear();
    for (int i = 0; i < widget.particleCount; i++) {
      _particles.add(_Particle(
        angle: _random.nextDouble() * pi * 2,
        speed: 0.5 + _random.nextDouble() * 0.5,
        size: widget.particleSize * (0.5 + _random.nextDouble() * 0.5),
        opacity: 0.3 + _random.nextDouble() * 0.7,
        delay: _random.nextDouble(),
      ));
    }
  }
  
  @override
  void didUpdateWidget(ParticleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.particleCount != widget.particleCount ||
        oldWidget.particleSize != widget.particleSize) {
      _initParticles();
    }
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPlaying) {
      return const SizedBox.shrink();
    }
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _ParticlePainter(
            particles: _particles,
            animationValue: _controller.value,
            color: widget.color ?? Theme.of(context).primaryColor,
            maxRadius: widget.maxRadius,
            centerAlignment: widget.centerAlignment,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double opacity;
  final double delay;
  
  _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.delay,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationValue;
  final Color color;
  final double maxRadius;
  final Alignment centerAlignment;
  
  _ParticlePainter({
    required this.particles,
    required this.animationValue,
    required this.color,
    required this.maxRadius,
    required this.centerAlignment,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 计算中心点位置
    final centerX = size.width / 2 + centerAlignment.x * size.width / 2;
    final centerY = size.height - 60; // 在底部留出播放键的空间
    
    for (final particle in particles) {
      // 计算粒子的生命周期 (0.0 - 1.0)
      final t = (animationValue + particle.delay) % 1.0;
      
      // 粒子从中心向外扩散
      final distance = t * maxRadius * particle.speed;
      
      // 添加一些波动
      final wobble = sin(t * pi * 4 + particle.angle) * 10;
      
      final x = centerX + cos(particle.angle) * distance + wobble * sin(particle.angle);
      final y = centerY + sin(particle.angle) * distance * 0.6; // 稍微压扁
      
      // 透明度随距离增加而减少
      final opacity = particle.opacity * (1.0 - t) * (1.0 - t);
      
      // 粒子大小随距离略微缩小
      final currentSize = particle.size * (1.0 - t * 0.5);
      
      if (opacity > 0.01) {
        final paint = Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.fill;
        
        // 绘制发光粒子
        canvas.drawCircle(
          Offset(x, y),
          currentSize,
          paint,
        );
        
        // 添加外发光效果
        final glowPaint = Paint()
          ..color = color.withValues(alpha: opacity * 0.3)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        
        canvas.drawCircle(
          Offset(x, y),
          currentSize * 1.5,
          glowPaint,
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return animationValue != oldDelegate.animationValue;
  }
}
