import 'dart:math';
import 'package:flutter/material.dart';

/// 音乐喷泉粒子
class FountainParticle {
  double x;           // 水平位置
  double y;           // 垂直位置
  double velocityX;   // 水平速度
  double velocityY;   // 垂直速度（向上为负）
  double size;        // 粒子大小
  Color color;        // 粒子颜色
  double life;        // 生命周期 (0-1)
  double maxLife;     // 最大生命周期

  FountainParticle({
    required this.x,
    required this.y,
    required this.velocityX,
    required this.velocityY,
    required this.size,
    required this.color,
    this.life = 1.0,
    this.maxLife = 1.0,
  });

  void update(double dt) {
    x += velocityX * dt;
    y += velocityY * dt;
    velocityY += 980 * dt; // 重力加速度
    life -= dt / maxLife;
  }

  bool get isDead => life <= 0;
}

/// 音乐喷泉可视化组件
/// 
/// 在歌词上方显示喷泉效果，模拟水柱从频谱柱顶向上喷出
class MusicFountainVisualizer extends StatefulWidget {
  final List<double> spectrumData;  // 频谱数据 (0-1)
  final Color color;                // 主色调
  final double height;              // 组件高度
  final double barWidth;            // 频谱柱宽度
  final double gap;                 // 频谱柱间距
  final int particleCount;          // 每个柱的粒子数

  const MusicFountainVisualizer({
    super.key,
    required this.spectrumData,
    required this.color,
    this.height = 150,
    this.barWidth = 6,
    this.gap = 4,
    this.particleCount = 15,
  });

  @override
  State<MusicFountainVisualizer> createState() => _MusicFountainVisualizerState();
}

class _MusicFountainVisualizerState extends State<MusicFountainVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<FountainParticle> _particles = [];
  final Random _random = Random();
  
  // 上一帧的数据，用于检测变化
  List<double> _lastData = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps
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

    // 检测频谱数据变化
    bool dataChanged = _lastData.length != widget.spectrumData.length;
    if (!dataChanged) {
      for (int i = 0; i < widget.spectrumData.length; i++) {
        if ((_lastData[i] - widget.spectrumData[i]).abs() > 0.01) {
          dataChanged = true;
          break;
        }
      }
    }
    _lastData = List.from(widget.spectrumData);

    final dt = 0.016; // 16ms

    // 更新现有粒子
    for (int i = _particles.length - 1; i >= 0; i--) {
      _particles[i].update(dt);
      if (_particles[i].isDead) {
        _particles.removeAt(i);
      }
    }

    // 根据频谱数据生成新粒子
    if (dataChanged) {
      _generateParticles();
    }
  }

  void _generateParticles() {
    final barCount = widget.spectrumData.length;
    if (barCount == 0) return;

    final totalWidth = context.size?.width ?? 300;
    final barSpacing = (totalWidth - barCount * widget.barWidth) / (barCount + 1);

    for (int i = 0; i < barCount; i++) {
      final value = widget.spectrumData[i];
      if (value < 0.1) continue;

      // 计算柱顶位置
      final barHeight = value * (widget.height * 0.6); // 柱高占60%
      final barX = barSpacing + i * (widget.barWidth + (totalWidth - barCount * widget.barWidth - 2 * barSpacing) / (barCount - 1));
      final barTopY = widget.height - barHeight;

      // 根据能量生成粒子
      final particleCount = (value * widget.particleCount).toInt();
      for (int j = 0; j < particleCount; j++) {
        // 喷出速度：中间快，两边慢
        final centerOffset = (i - barCount / 2).abs() / (barCount / 2);
        final speedFactor = 1.0 - centerOffset * 0.5;
        
        final speed = 200 + value * 400 * speedFactor;
        final angle = -pi / 2 + (_random.nextDouble() - 0.5) * 0.8; // 向上喷，稍微分散

        _particles.add(FountainParticle(
          x: barX + widget.barWidth / 2,
          y: barTopY,
          velocityX: cos(angle) * speed * 0.3,
          velocityY: sin(angle) * speed,
          size: 2 + _random.nextDouble() * 3 * value,
          color: _getParticleColor(value, j / particleCount),
          maxLife: 0.5 + _random.nextDouble() * 0.5,
        ));
      }
    }
  }

  Color _getParticleColor(double value, double progress) {
    // 颜色渐变：底部蓝色 -> 绿色 -> 顶部白色
    final baseColor = Color.lerp(
      Colors.cyan,
      widget.color,
      progress,
    ) ?? widget.color;
    
    // 高能量时更亮
    if (value > 0.7) {
      return Color.lerp(baseColor, Colors.white, (value - 0.7) / 0.3) ?? baseColor;
    }
    return baseColor;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: CustomPaint(
        size: Size(double.infinity, widget.height),
        painter: _FountainPainter(
          particles: _particles,
          spectrumData: widget.spectrumData,
          color: widget.color,
          barWidth: widget.barWidth,
        ),
      ),
    );
  }
}

/// 喷泉绘制器
class _FountainPainter extends CustomPainter {
  final List<FountainParticle> particles;
  final List<double> spectrumData;
  final Color color;
  final double barWidth;

  _FountainPainter({
    required this.particles,
    required this.spectrumData,
    required this.color,
    required this.barWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;

    final barCount = spectrumData.length;
    final barSpacing = (size.width - barCount * barWidth) / (barCount + 1);

    // 绘制频谱柱
    for (int i = 0; i < barCount; i++) {
      final value = spectrumData[i];
      final barHeight = value * size.height * 0.6;
      final x = barSpacing + i * (barWidth + (size.width - barCount * barWidth - 2 * barSpacing) / (barCount - 1));

      // 柱身渐变
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.8),
          Color.lerp(Colors.cyan, Colors.white, value * 0.5) ?? color,
        ],
      );

      final paint = Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight))
        ..style = PaintingStyle.fill;

      // 圆角矩形
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, paint);

      // 顶部发光效果
      if (value > 0.3) {
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: value * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * value);
        canvas.drawCircle(
          Offset(x + barWidth / 2, size.height - barHeight),
          barWidth * 0.8,
          glowPaint,
        );
      }
    }

    // 绘制粒子
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withValues(alpha: particle.life.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      // 粒子大小随生命周期减小
      final size = particle.size * (0.5 + particle.life * 0.5);
      
      // 外发光
      final glowPaint = Paint()
        ..color = particle.color.withValues(alpha: particle.life * 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        size * 1.5,
        glowPaint,
      );

      // 核心粒子
      canvas.drawCircle(
        Offset(particle.x, particle.y),
        size,
        paint,
      );

      // 高光
      if (particle.life > 0.5) {
        final highlightPaint = Paint()
          ..color = Colors.white.withValues(alpha: (particle.life - 0.5) * 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(particle.x - size * 0.3, particle.y - size * 0.3),
          size * 0.3,
          highlightPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FountainPainter oldDelegate) => true;
}

/// 集成喷泉的播放器歌词区域
/// 
/// 歌词在中上位置，喷泉在歌词下方向上喷
class FountainLyricsView extends StatefulWidget {
  final List<String> lyrics;           // 歌词列表
  final int currentIndex;              // 当前歌词索引
  final Duration currentPosition;      // 当前播放位置
  final bool isDarkMode;               // 是否深色模式
  final Color primaryColor;            // 主色调

  const FountainLyricsView({
    super.key,
    required this.lyrics,
    required this.currentIndex,
    required this.currentPosition,
    required this.isDarkMode,
    required this.primaryColor,
  });

  @override
  State<FountainLyricsView> createState() => _FountainLyricsViewState();
}

class _FountainLyricsViewState extends State<FountainLyricsView>
    with TickerProviderStateMixin {
  late AnimationController _spectrumController;
  List<double> _spectrumData = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _spectrumData = List.generate(48, (_) => 0.0);
    _spectrumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateSpectrum);
    _spectrumController.repeat();
  }

  @override
  void dispose() {
    _spectrumController.dispose();
    super.dispose();
  }

  void _updateSpectrum() {
    if (!mounted) return;
    
    setState(() {
      // 生成模拟频谱数据
      _spectrumData = List.generate(48, (i) {
        // 模拟音乐节奏
        final base = 0.3 + _random.nextDouble() * 0.4;
        final beat = (DateTime.now().millisecondsSinceEpoch % 500) / 500;
        final modulation = (beat * 2 * pi).abs() * 0.3;
        
        double value = base + modulation * (1.0 - (i / 48));
        if (i < 12) value *= 1.2; // 低频增强
        if (i > 36) value *= 0.6; // 高频减弱
        
        return value.clamp(0.0, 1.0);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final lyricsHeight = screenHeight * 0.45; // 歌词占45%高度
    final fountainHeight = screenHeight * 0.25; // 喷泉占25%高度

    return SizedBox(
      height: lyricsHeight + fountainHeight,
      child: Column(
        children: [
          // ─── 歌词区域（中上位置）──────────────────────────────────────
          SizedBox(
            height: lyricsHeight,
            child: _buildLyricsView(),
          ),
          
          // ─── 音乐喷泉（歌词下方）──────────────────────────────────────
          SizedBox(
            height: fountainHeight,
            child: MusicFountainVisualizer(
              spectrumData: _spectrumData,
              color: widget.primaryColor,
              height: fountainHeight,
              barWidth: 6,
              particleCount: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView() {
    if (widget.lyrics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_note_rounded,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无歌词',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      itemCount: widget.lyrics.length,
      itemBuilder: (context, index) {
        final isCurrent = index == widget.currentIndex;
        final isPast = index < widget.currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            widget.lyrics[index],
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCurrent ? 26 : 18,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
              color: isCurrent
                  ? (widget.isDarkMode ? Colors.white : Colors.black87)
                  : (isPast
                      ? (widget.isDarkMode ? Colors.white38 : Colors.black38)
                      : (widget.isDarkMode ? Colors.white24 : Colors.black26)),
              shadows: isCurrent
                  ? [
                      Shadow(
                        color: widget.primaryColor.withValues(alpha: 0.5),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      },
    );
  }
}