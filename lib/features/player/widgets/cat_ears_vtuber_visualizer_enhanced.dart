import 'dart:math';
import 'package:flutter/material.dart';

/// 🐱 VTuber 风格猫耳音频频谱可视化器 (增强版)
/// 
/// 效果特点:
/// - 左右猫耳跟随音乐节拍跳动
/// - 3D立体猫耳效果,带阴影和高光
/// - 猫耳外围圆形频谱特效
/// - 猫耳发光效果随节拍增强
/// - 频谱位置上调
/// 
/// 参考:B站 VTuber 直播猫耳特效
class VtuberCatEarsVisualizerEnhanced extends StatefulWidget {
  /// 频谱数据 (0-1)
  final List<double> spectrumData;
  
  /// 是否播放中
  final bool isPlaying;
  
  /// 主色调
  final Color color;
  
  /// 背景颜色
  final Color? backgroundColor;
  
  /// 组件高度
  final double height;
  
  /// 猫耳灵敏度 (0-1)
  final double sensitivity;
  
  /// 是否显示粒子效果
  final bool showParticles;
  
  /// 粒子类型: 'hearts' | 'stars' | 'both'
  final String particleType;

  const VtuberCatEarsVisualizerEnhanced({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.backgroundColor,
    this.height = 300,
    this.sensitivity = 1.0,
    this.showParticles = true,
    this.particleType = 'hearts',
  });

  @override
  State<VtuberCatEarsVisualizerEnhanced> createState() => _VtuberCatEarsVisualizerEnhancedState();
}

class _VtuberCatEarsVisualizerEnhancedState extends State<VtuberCatEarsVisualizerEnhanced>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _particleController;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  
  // 能量值（平滑处理）
  double _leftEarEnergy = 0;
  double _rightEarEnergy = 0;
  double _glowIntensity = 0;
  double _faceGlow = 0;

  @override
  void initState() {
    super.initState();
    
    // 弹跳动画控制器
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateEnergies);
    _bounceController.repeat();
    
    // 粒子动画控制器
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 50),
    )..addListener(_updateParticles);
    _particleController.repeat();
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _updateEnergies() {
    if (!widget.isPlaying || widget.spectrumData.isEmpty) {
      // 停止时缓慢衰减
      _leftEarEnergy = max(0, _leftEarEnergy - 0.05);
      _rightEarEnergy = max(0, _rightEarEnergy - 0.05);
      _glowIntensity = max(0, _glowIntensity - 0.03);
      _faceGlow = max(0, _faceGlow - 0.02);
      if (mounted) setState(() {});
      return;
    }

    // 计算左右耳能量（取频谱的不同部分）
    final len = widget.spectrumData.length;
    final half = len ~/ 2;
    
    double leftSum = 0;
    for (int i = 0; i < half ~/ 2; i++) {
      leftSum += widget.spectrumData[i];
    }
    _leftEarEnergy = (leftSum / (half ~/ 2)) * widget.sensitivity;
    
    double rightSum = 0;
    for (int i = len - half ~/ 2; i < len; i++) {
      rightSum += widget.spectrumData[i];
    }
    _rightEarEnergy = (rightSum / (half ~/ 2)) * widget.sensitivity;
    
    // 总能量用于发光
    double totalEnergy = 0;
    for (int i = 0; i < len; i++) {
      totalEnergy += widget.spectrumData[i];
    }
    _glowIntensity = (totalEnergy / len) * widget.sensitivity;
    
    // 脸部发光
    _faceGlow = (_leftEarEnergy + _rightEarEnergy) / 2;
    
    // 生成粒子
    if (widget.showParticles && _particles.length < 30) {
      if (_random.nextDouble() < _glowIntensity * 0.5) {
        _spawnParticle();
      }
    }
    
    if (mounted) setState(() {});
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.update();
    }
    _particles.removeWhere((p) => p.isDead);
  }

  void _spawnParticle() {
    final w = context.size?.width ?? 300;
    final particle = _Particle(
      x: w / 2 + (_random.nextDouble() - 0.5) * 100,
      y: 80 + _random.nextDouble() * 40,
      type: widget.particleType == 'both' 
          ? (_random.nextBool() ? 'heart' : 'star')
          : widget.particleType == 'stars' ? 'star' : 'heart',
      color: widget.color,
      energy: _glowIntensity,
    );
    _particles.add(particle);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          // 背景光晕
          if (_glowIntensity > 0.1)
            Center(
              child: Container(
                width: 150 + _glowIntensity * 50,
                height: 100 + _glowIntensity * 30,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      widget.color.withValues(alpha: _glowIntensity * 0.3),
                      widget.color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          
          // 猫耳和脸部
          CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _VtuberCatEarsPainterEnhanced(
              leftEarEnergy: _leftEarEnergy,
              rightEarEnergy: _rightEarEnergy,
              glowIntensity: _glowIntensity,
              faceGlow: _faceGlow,
              color: widget.color,
              spectrumData: widget.spectrumData,
            ),
          ),
          
          // 粒子层
          ..._particles.map((p) => Positioned(
            left: p.x - 10,
            top: p.y - 10,
            child: p.buildWidget(),
          )),
        ],
      ),
    );
  }
}

/// 粒子类
class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double size;
  String type;
  Color color;
  double energy;

  _Particle({
    required this.x,
    required this.y,
    required this.type,
    required this.color,
    required this.energy,
    this.vx = 0,
    this.vy = -2,
    this.life = 1.0,
    this.size = 20,
  }) {
    vx = (Random().nextDouble() - 0.5) * 3;
    vy = -Random().nextDouble() * 4 - 2;
    size = 15 + Random().nextDouble() * 15;
  }

  void update() {
    x += vx;
    y += vy;
    vy += 0.1; // 轻微重力
    life -= 0.02;
  }

  bool get isDead => life <= 0;

  Widget buildWidget() {
    return Opacity(
      opacity: life,
      child: Transform.scale(
        scale: size / 20,
        child: type == 'heart'
            ? Icon(Icons.favorite, color: color, size: 20)
            : Icon(Icons.star, color: color, size: 20),
      ),
    );
  }
}

/// VTuber 猫耳绘制器 (增强版)
class _VtuberCatEarsPainterEnhanced extends CustomPainter {
  final double leftEarEnergy;
  final double rightEarEnergy;
  final double glowIntensity;
  final double faceGlow;
  final Color color;
  final List<double> spectrumData;

  _VtuberCatEarsPainterEnhanced({
    required this.leftEarEnergy,
    required this.rightEarEnergy,
    required this.glowIntensity,
    required this.faceGlow,
    required this.color,
    required this.spectrumData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    
    // 绘制外围圆形频谱 (上调位置)
    _drawCircularSpectrum(canvas, size);
    
    // 绘制猫耳 (上调位置)
    _drawEar(canvas, cx - w * 0.3, h * 0.15, leftEarEnergy, isLeft: true);
    _drawEar(canvas, cx + w * 0.3, h * 0.15, rightEarEnergy, isLeft: false);
    
    // 绘制脸部
    _drawFace(canvas, size);
  }

  /// 绘制外围圆形频谱
  void _drawCircularSpectrum(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.35; // 圆形频谱中心位置 (上调)
    final baseRadius = 100.0; // 基础半径
    
    final bars = min(spectrumData.length, 32);
    
    for (int i = 0; i < bars; i++) {
      final angle = (i / bars) * 2 * pi - pi / 2; // 从顶部开始
      final idx = (spectrumData.length * i / bars).round().clamp(0, spectrumData.length - 1);
      final e = spectrumData[idx];
      final barLength = e * 40; // 频谱条长度
      
      if (barLength < 2) continue;
      
      // 计算起点和终点
      final startX = cx + cos(angle) * baseRadius;
      final startY = cy + sin(angle) * baseRadius;
      final endX = cx + cos(angle) * (baseRadius + barLength);
      final endY = cy + sin(angle) * (baseRadius + barLength);
      
      // 绘制频谱条
      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            color.withValues(alpha: 0.6),
            color,
            Colors.yellow,
          ],
        ).createShader(Rect.fromLTWH(
          min(startX, endX),
          min(startY, endY),
          (endX - startX).abs(),
          (endY - startY).abs(),
        ))
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        barPaint,
      );
      
      // 顶部发光点
      if (e > 0.5) {
        final glowPaint = Paint()
          ..color = Colors.white.withValues(alpha: e * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(endX, endY), 3, glowPaint);
      }
    }
  }

  void _drawEar(Canvas canvas, double x, double y, double energy, {required bool isLeft}) {
    final earW = 45 + energy * 20;
    final earH = 55 + energy * 25;
    
    // 耳朵跳动偏移
    final bounce = sin(energy * pi) * 3;
    final offsetY = isLeft ? -bounce : -bounce;
    
    // 外耳
    final earPath = Path();
    if (isLeft) {
      earPath.moveTo(x - earW / 2, y + 20 + offsetY);
      earPath.lineTo(x, y - earH + offsetY);
      earPath.lineTo(x + earW / 2, y + 20 + offsetY);
    } else {
      earPath.moveTo(x - earW / 2, y + 20 + offsetY);
      earPath.lineTo(x, y - earH + offsetY);
      earPath.lineTo(x + earW / 2, y + 20 + offsetY);
    }
    earPath.close();
    
    // 3D阴影层 (底部)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(
      earPath.shift(Offset(4, 4)),
      shadowPaint,
    );
    
    // 渐变填充 - 3D立体效果
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          Color.lerp(color, Colors.pink, 0.3) ?? color,
          Color.lerp(color, Colors.pink.shade700 ?? Colors.pink, 0.5) ?? color, // 底部加深
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(x - earW / 2, y - earH, earW, earH + 20));
    canvas.drawPath(earPath, gradientPaint);
    
    // 3D高光边缘 (左侧高光)
    final highlightPath = Path();
    if (isLeft) {
      highlightPath.moveTo(x - earW / 2 + 5, y + 15 + offsetY);
      highlightPath.lineTo(x - 3, y - earH + 10 + offsetY);
      highlightPath.lineTo(x - earW / 4, y + 15 + offsetY);
    } else {
      highlightPath.moveTo(x + earW / 2 - 5, y + 15 + offsetY);
      highlightPath.lineTo(x + 3, y - earH + 10 + offsetY);
      highlightPath.lineTo(x + earW / 4, y + 15 + offsetY);
    }
    highlightPath.close();
    canvas.drawPath(
      highlightPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.4),
            Colors.white.withValues(alpha: 0.1),
          ],
        ).createShader(Rect.fromLTWH(x - earW / 2, y - earH, earW, earH + 20)),
    );
    
    // 内耳
    final innerW = earW * 0.5;
    final innerH = earH * 0.5;
    final innerPath = Path();
    if (isLeft) {
      innerPath.moveTo(x - innerW / 2, y + 15 + offsetY);
      innerPath.lineTo(x, y - innerH + offsetY);
      innerPath.lineTo(x + innerW / 2, y + 15 + offsetY);
    } else {
      innerPath.moveTo(x - innerW / 2, y + 15 + offsetY);
      innerPath.lineTo(x, y - innerH + offsetY);
      innerPath.lineTo(x + innerW / 2, y + 15 + offsetY);
    }
    innerPath.close();
    
    // 内耳渐变
    canvas.drawPath(
      innerPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.pink.shade100 ?? Colors.pink[100]!,
            Colors.pink.shade200 ?? Colors.pink[200]!,
          ],
        ).createShader(Rect.fromLTWH(x - innerW / 2, y - innerH, innerW, innerH + 15)),
    );
    
    // 发光效果
    if (energy > 0.3) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: energy * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * energy);
      canvas.drawPath(earPath, glowPaint);
      
      // 高光
      final highlightPaint = Paint()
        ..color = Colors.white.withValues(alpha: energy * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5);
      canvas.drawCircle(
        Offset(x - (isLeft ? 5 : -5), y - earH * 0.7 + offsetY),
        8 * energy,
        highlightPaint,
      );
    }
  }

  void _drawFace(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final faceY = h * 0.5;
    final faceW = w * 0.45;
    final faceH = h * 0.4;
    
    // 脸部背景
    final faceBg = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        colors: [
          Colors.white,
          Color.lerp(Colors.pink.shade50 ?? Colors.pink[50]!, Colors.white, 0.5) ?? Colors.white,
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, faceY),
        width: faceW,
        height: faceH,
      ));
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, faceY), width: faceW, height: faceH),
      faceBg,
    );
    
    // 脸部发光
    if (faceGlow > 0.2) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: faceGlow * 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * faceGlow);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, faceY), width: faceW, height: faceH),
        glowPaint,
      );
    }
    
    // 腮红
    final blushPaint = Paint()
      ..color = Colors.pink.shade200?.withValues(alpha: 0.4 + faceGlow * 0.3) ?? Colors.pink.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - faceW * 0.25, faceY + faceH * 0.15), width: faceW * 0.2, height: faceH * 0.15),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + faceW * 0.25, faceY + faceH * 0.15), width: faceW * 0.2, height: faceH * 0.15),
      blushPaint,
    );
    
    // 眼睛
    final eyeY = faceY - faceH * 0.1;
    final eyeSpacing = faceW * 0.2;
    
    // 左眼
    _drawEye(canvas, Offset(cx - eyeSpacing, eyeY), faceGlow);
    // 右眼
    _drawEye(canvas, Offset(cx + eyeSpacing, eyeY), faceGlow);
    
    // 鼻子
    final nosePaint = Paint()..color = Colors.pink.shade300 ?? Colors.pink;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, faceY + faceH * 0.15), width: 8, height: 6),
      nosePaint,
    );
    
    // 嘴巴
    final mouthPath = Path();
    mouthPath.moveTo(cx - 15, faceY + faceH * 0.25);
    mouthPath.quadraticBezierTo(cx, faceY + faceH * 0.35, cx + 15, faceY + faceH * 0.25);
    canvas.drawPath(mouthPath, Paint()
      ..color = Colors.pink.shade300 ?? Colors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
    
    // 猫须
    final pupilPaint = Paint()..color = Colors.grey.shade800 ?? Colors.black;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, faceY + faceH * 0.08), width: 6, height: 8),
      pupilPaint,
    );
  }

  void _drawEye(Canvas canvas, Offset center, double energy) {
    // 眼睛高光
    final eyeBg = Paint()..color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 25, height: 20),
      eyeBg,
    );
    
    // 瞳孔（根据能量变化）
    final pupilSize = 8 + energy * 4;
    final pupilPaint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: pupilSize, height: pupilSize + 4),
      pupilPaint,
    );
    
    // 眼睛高光点
    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(center.dx - 4, center.dy - 4), 3, highlightPaint);
  }

  @override
  bool shouldRepaint(_VtuberCatEarsPainterEnhanced old) => true;
}
