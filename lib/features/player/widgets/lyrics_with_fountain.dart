import 'dart:math';
import 'package:flutter/material.dart';

// ── 水粒子（水柱+水花+涟漪）──────────────────────────────────────────
class WaterParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  double maxLife;
  int barIndex;
  bool isSplash;
  bool isRipple;
  double rippleRadius;

  WaterParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.barIndex,
    this.life = 1.0,
    this.maxLife = 1.0,
    this.isSplash = false,
    this.isRipple = false,
    this.rippleRadius = 0,
  });

  void update(double dt) {
    if (isRipple) {
      rippleRadius += 80 * dt;
      life -= dt / maxLife;
      return;
    }
    x += vx * dt;
    y += vy * dt;
    if (!isSplash) {
      vy += 700 * dt; // 重力
    } else {
      vy += 400 * dt;
    }
    life -= dt / maxLife;
  }

  bool get isDead => life <= 0 || (isRipple ? rippleRadius > 120 : y < 0);
}

// ── 水柱段（连续几何水柱，由底部向上延伸）──────────────────────────
class _WaterJet {
  final double x;
  double height;
  double targetHeight;
  final Color color;
  final double width;
  final List<_WaterJetPoint> points;

  _WaterJet({
    required this.x,
    required this.height,
    required this.targetHeight,
    required this.color,
    required this.width,
    required this.points,
  });
}

class _WaterJetPoint {
  double x;
  double y;
  double vx;
  double vy;
  double life;

  _WaterJetPoint({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.life = 1.0,
  });
}

// ── 主组件 ────────────────────────────────────────────────────────────
class LyricsWithFountain extends StatefulWidget {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double fountainHeight;
  final Widget lyricsWidget;

  const LyricsWithFountain({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.fountainHeight = 220,
    required this.lyricsWidget,
  });

  @override
  State<LyricsWithFountain> createState() => _LyricsWithFountainState();
}

class _LyricsWithFountainState extends State<LyricsWithFountain>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<WaterParticle> _particles = [];
  final Random _random = Random();

  // 水柱目标高度（平滑）
  List<double> _barHeights = List.filled(16, 0.0);
  List<double> _barTargetHeights = List.filled(16, 0.0);

  // 水面波纹相位
  double _wavePhase = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_tick);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    const dt = 0.016;

    _wavePhase += dt * 2.5;
    _updateBarHeights();

    if (widget.isPlaying) {
      _emitJetParticles();
    }

    // 更新粒子
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.update(dt);

      // 水柱粒子落到水面时产生水花+涟漪
      if (!p.isSplash && !p.isRipple && p.vy > 0 &&
          p.y >= widget.fountainHeight - 18) {
        _createSplashAndRipple(p);
        _particles.removeAt(i);
      } else if (p.isDead) {
        _particles.removeAt(i);
      }
    }

    if (mounted) setState(() {});
  }

  void _updateBarHeights() {
    final data = widget.spectrumData;
    if (data.isEmpty) return;
    const barCount = 16;
    final step = data.length / barCount;
    for (int i = 0; i < barCount; i++) {
      final idx = (i * step).floor().clamp(0, data.length - 1);
      // 水柱最大高度 = fountainHeight * 0.85
      var targetHeight = data[idx] * widget.fountainHeight * 0.85;
      
      // 对高频部分（右边水柱）进行增益补偿
      if (i >= 10) {
        // 高频增益：12-15号水柱增益1.5倍，10-11号增益1.3倍
        final boost = i >= 12 ? 1.5 : 1.3;
        targetHeight = targetHeight * boost;
      }
      _barTargetHeights[i] = targetHeight.clamp(0.0, widget.fountainHeight * 0.85);
      
      // 上升快，下降慢（水柱特性）
      if (_barTargetHeights[i] > _barHeights[i]) {
        _barHeights[i] = _barHeights[i] * 0.5 + _barTargetHeights[i] * 0.5;
      } else {
        _barHeights[i] = _barHeights[i] * 0.85 + _barTargetHeights[i] * 0.15;
      }
    }
  }

  /// 从水柱顶端向上喷射水粒子
  void _emitJetParticles() {
    final width = MediaQuery.of(context).size.width;
    const barCount = 16;
    final slotWidth = width / barCount;

    for (int i = 0; i < barCount; i++) {
      final h = _barHeights[i];
      if (h < 5) continue;  // 降低阈值，让更多水柱能喷水

      final energy = (h / widget.fountainHeight).clamp(0.0, 1.0);
      final baseX = i * slotWidth + slotWidth / 2;
      final baseY = widget.fountainHeight - h; // 水柱顶端 y

      // 每帧喷射粒子数量
      final count = (energy * 4).ceil().clamp(1, 5);
      for (int j = 0; j < count; j++) {
        // 主水流：向上喷射，带轻微左右扩散
        final spreadAngle = (_random.nextDouble() - 0.5) * 0.4;
        final speed = 60 + energy * 180 + _random.nextDouble() * 40;
        _particles.add(WaterParticle(
          x: baseX + (_random.nextDouble() - 0.5) * slotWidth * 0.3,
          y: baseY,
          vx: sin(spreadAngle) * speed * 0.3,
          vy: -speed,
          size: 1.5 + energy * 2.0, // 更小的粒子
          color: _jetColor(energy),
          barIndex: i,
          life: 1.0,
          maxLife: 0.35 + energy * 0.35,
        ));
      }
    }
  }

  /// 水花 + 涟漪
  void _createSplashAndRipple(WaterParticle fallen) {
    // 涟漪
    _particles.add(WaterParticle(
      x: fallen.x, y: widget.fountainHeight - 15,
      vx: 0, vy: 0,
      size: 1, color: fallen.color,
      barIndex: fallen.barIndex,
      life: 1.0, maxLife: 0.6,
      isRipple: true, rippleRadius: 0,
    ));

    // 水花
    final splashCount = 4 + _random.nextInt(4);
    for (int i = 0; i < splashCount; i++) {
      final angle = -pi + _random.nextDouble() * pi; // 向上半圆
      final speed = 40 + _random.nextDouble() * 120;
      _particles.add(WaterParticle(
        x: fallen.x + (_random.nextDouble() - 0.5) * 6,
        y: widget.fountainHeight - 15,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed * 0.8 - 30,
        size: 1.0 + _random.nextDouble() * 1.5, // 更小的水花
        color: fallen.color.withValues(alpha: 0.5), // 更浅的颜色
        barIndex: fallen.barIndex,
        life: 1.0, maxLife: 0.25 + _random.nextDouble() * 0.2,
        isSplash: true,
      ));
    }
  }

  Color _jetColor(double energy) {
    // 低能量：浅蓝，高能量：混入主题色→白
    if (energy > 0.75) {
      return Color.lerp(widget.color, Colors.white, (energy - 0.75) * 1.8) ?? widget.color;
    } else if (energy > 0.4) {
      return Color.lerp(const Color(0xFF4FC3F7), widget.color, (energy - 0.4) / 0.35) ?? widget.color;
    }
    return const Color(0xFF81D4FA).withValues(alpha: 0.9);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 水柱喷泉层
        Positioned(
          left: 0, right: 0, bottom: 0,
          height: widget.fountainHeight,
          child: CustomPaint(
            size: Size(double.infinity, widget.fountainHeight),
            painter: _WaterJetPainter(
              particles: _particles,
              barHeights: _barHeights,
              color: widget.color,
              fountainHeight: widget.fountainHeight,
              wavePhase: _wavePhase,
            ),
          ),
        ),
        // 歌词层
        Positioned.fill(child: widget.lyricsWidget),
      ],
    );
  }
}

// ── 水柱绘制器 ───────────────────────────────────────────────────────
class _WaterJetPainter extends CustomPainter {
  final List<WaterParticle> particles;
  final List<double> barHeights;
  final Color color;
  final double fountainHeight;
  final double wavePhase;

  _WaterJetPainter({
    required this.particles,
    required this.barHeights,
    required this.color,
    required this.fountainHeight,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawWaterSurface(canvas, size);
    _drawWaterJets(canvas, size);
    _drawParticles(canvas, size);
  }

  /// 底部水面（波纹 + 倒影效果）
  void _drawWaterSurface(Canvas canvas, Size size) {
    final waterY = size.height - 20;

    // 水面渐变区域 - 更浅
    final surfacePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.06), // 更浅
          color.withValues(alpha: 0.12), // 更浅
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, waterY - 30, size.width, 50))
      ..style = PaintingStyle.fill;

    final surfacePath = Path();
    surfacePath.moveTo(0, waterY);
    for (double x = 0; x <= size.width; x += 4) {
      final y = waterY + sin(x * 0.04 + wavePhase) * 3 + sin(x * 0.08 - wavePhase * 1.3) * 1.5;
      surfacePath.lineTo(x, y);
    }
    surfacePath.lineTo(size.width, size.height);
    surfacePath.lineTo(0, size.height);
    surfacePath.close();
    canvas.drawPath(surfacePath, surfacePaint);

    // 水面高光线
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final linePath = Path();
    linePath.moveTo(0, waterY);
    for (double x = 0; x <= size.width; x += 4) {
      final y = waterY + sin(x * 0.04 + wavePhase) * 3 + sin(x * 0.08 - wavePhase * 1.3) * 1.5;
      linePath.lineTo(x, y);
    }
    canvas.drawPath(linePath, linePaint);
  }

  /// 水柱主体（梯形渐变柱）
  void _drawWaterJets(Canvas canvas, Size size) {
    const barCount = 16;
    final slotWidth = size.width / barCount;
    final bottomY = size.height - 20;

    for (int i = 0; i < barCount; i++) {
      final h = barHeights[i];
      if (h < 4) continue;

      final energy = (h / (size.height * 0.85)).clamp(0.0, 1.0);
      final centerX = i * slotWidth + slotWidth / 2;

      // 水柱宽度：底宽 > 顶宽（物理特性）- 更细
      final bottomWidth = slotWidth * (0.20 + energy * 0.15);
      final topWidth = bottomWidth * (0.5 + energy * 0.3);
      final topY = bottomY - h;

      // 水柱主体路径（梯形）
      final jetPath = Path();
      jetPath.moveTo(centerX - bottomWidth / 2, bottomY);
      // 底部圆弧
      jetPath.quadraticBezierTo(centerX, bottomY + 4, centerX + bottomWidth / 2, bottomY);
      // 右侧向上（轻微波动）
      final rightWave = sin(wavePhase * 2 + i * 0.5) * 2;
      jetPath.quadraticBezierTo(
        centerX + bottomWidth / 2 + rightWave, bottomY - h * 0.5,
        centerX + topWidth / 2, topY,
      );
      // 顶部圆弧
      jetPath.quadraticBezierTo(centerX, topY - topWidth * 0.4, centerX - topWidth / 2, topY);
      // 左侧向下
      final leftWave = sin(wavePhase * 2 + i * 0.5 + pi) * 2;
      jetPath.quadraticBezierTo(
        centerX - bottomWidth / 2 + leftWave, bottomY - h * 0.5,
        centerX - bottomWidth / 2, bottomY,
      );
      jetPath.close();

      // 水柱渐变：底部深色，中部透明蓝，顶部白色高光 - 更浅
      final jetPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            color.withValues(alpha: 0.15), // 更浅
            color.withValues(alpha: 0.35 + energy * 0.15), // 更浅
            Color.lerp(color, Colors.white, 0.5)!.withValues(alpha: 0.5), // 更浅
          ],
          stops: const [0.0, 0.6, 1.0],
        ).createShader(Rect.fromLTWH(centerX - bottomWidth, topY, bottomWidth * 2, h))
        ..style = PaintingStyle.fill;
      canvas.drawPath(jetPath, jetPaint);

      // 水柱边缘高光（左侧白色反光）
      final highlightPath = Path();
      highlightPath.moveTo(centerX - bottomWidth / 2 + 2, bottomY - 10);
      highlightPath.quadraticBezierTo(
        centerX - bottomWidth / 2 + 1, bottomY - h * 0.5,
        centerX - topWidth / 2 + 2, topY + 5,
      );
      final hlPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * energy)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawPath(highlightPath, hlPaint);

      // 顶部发光光晕
      if (energy > 0.3) {
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.7 * energy),
              color.withValues(alpha: 0.4 * energy),
              Colors.transparent,
            ],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Rect.fromCircle(
            center: Offset(centerX, topY),
            radius: topWidth * 2.5,
          ));
        canvas.drawCircle(Offset(centerX, topY), topWidth * 2.5, glowPaint);
      }
    }
  }

  /// 绘制水粒子（飞溅+涟漪）
  void _drawParticles(Canvas canvas, Size size) {
    for (final p in particles) {
      if (p.isRipple) {
        // 涟漪圆环
        final alpha = p.life.clamp(0.0, 1.0);
        final ripplePaint = Paint()
          ..color = p.color.withValues(alpha: alpha * 0.5)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(p.x, p.y), p.rippleRadius, ripplePaint);

        // 双层涟漪
        if (p.rippleRadius > 15) {
          final innerPaint = Paint()
            ..color = p.color.withValues(alpha: alpha * 0.3)
            ..strokeWidth = 1.0
            ..style = PaintingStyle.stroke;
          canvas.drawCircle(Offset(p.x, p.y), p.rippleRadius * 0.65, innerPaint);
        }
        continue;
      }

      final alpha = p.life.clamp(0.0, 1.0);

      // 发光
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(p.x, p.y), p.size * 1.6, glowPaint);

      // 水珠本体（径向渐变，模拟球形折射）- 更浅
      final dropPaint = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Colors.white.withValues(alpha: alpha * 0.6), // 更浅
            p.color.withValues(alpha: alpha * 0.45), // 更浅
            p.color.withValues(alpha: alpha * 0.2), // 更浅
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(p.x, p.y),
          radius: p.size,
        ))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, dropPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaterJetPainter oldDelegate) => true;
}
