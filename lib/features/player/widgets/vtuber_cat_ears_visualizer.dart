import 'dart:math';
import 'package:flutter/material.dart';

/// ð VTuber é£æ ¼ç«è³é³é¢é¢è°±å¯è§åå?/// 
/// ææç¹ç¹ï¼?/// - å·¦å³ç«è³è·éé³ä¹èå¥è·³å?/// - ç«è³ååææéèæå¢å¼º
/// - è¸é¨è£é¥°éªç
/// - å¯éï¼å¤´é¡¶ç±å¿/ææç²å­
/// 
/// åèï¼Bç«?VTuber ç´æ­ç«è³ç¹æ?class VtuberCatEarsVisualizer extends StatefulWidget {
  /// é¢è°±æ°æ® (0-1)
  final List<double> spectrumData;
  
  /// æ¯å¦æ­æ¾ä¸?  final bool isPlaying;
  
  /// ä¸»è²è°?  final Color color;
  
  /// èæ¯é¢è²
  final Color? backgroundColor;
  
  /// ç»ä»¶é«åº¦
  final double height;
  
  /// ç«è³çµæåº¦ (0-1)
  final double sensitivity;
  
  /// æ¯å¦æ¾ç¤ºç²å­ææ
  final bool showParticles;
  
  /// ç²å­ç±»å: 'hearts' | 'stars' | 'both'
  final String particleType;

  const VtuberCatEarsVisualizer({
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
  State<VtuberCatEarsVisualizer> createState() => _VtuberCatEarsVisualizerState();
}

class _VtuberCatEarsVisualizerState extends State<VtuberCatEarsVisualizer>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late AnimationController _particleController;
  final List<_Particle> _particles = [];
  final Random _random = Random();
  
  // è½éå¼ï¼å¹³æ»å¤çï¼?  double _leftEarEnergy = 0;
  double _rightEarEnergy = 0;
  double _glowIntensity = 0;
  double _faceGlow = 0;

  @override
  void initState() {
    super.initState();
    
    // å¼¹è·³å¨ç»æ§å¶å?    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateEnergies);
    _bounceController.repeat();
    
    // ç²å­å¨ç»æ§å¶å?    _particleController = AnimationController(
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
      // åæ­¢æ¶ç¼æ¢è¡°å?      _leftEarEnergy = max(0, _leftEarEnergy - 0.05);
      _rightEarEnergy = max(0, _rightEarEnergy - 0.05);
      _glowIntensity = max(0, _glowIntensity - 0.03);
      _faceGlow = max(0, _faceGlow - 0.02);
      if (mounted) setState(() {});
      return;
    }

    // è®¡ç®å·¦å³è³è½éï¼åé¢è°±çä¸åé¨åï¼?    final len = widget.spectrumData.length;
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
    
    // æ»è½éç¨äºåå?    double totalEnergy = 0;
    for (int i = 0; i < len; i++) {
      totalEnergy += widget.spectrumData[i];
    }
    _glowIntensity = (totalEnergy / len) * widget.sensitivity;
    
    // è¸é¨åå
    _faceGlow = (_leftEarEnergy + _rightEarEnergy) / 2;
    
    // çæç²å­
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
          // èæ¯åæ
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
          
          // ç«è³åè¸é¨
          CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _VtuberCatEarsPainter(
              leftEarEnergy: _leftEarEnergy,
              rightEarEnergy: _rightEarEnergy,
              glowIntensity: _glowIntensity,
              faceGlow: _faceGlow,
              color: widget.color,
            ),
          ),
          
          // ç²å­å±?          ..._particles.map((p) => Positioned(
            left: p.x - 10,
            top: p.y - 10,
            child: p.buildWidget(),
          )),
        ],
      ),
    );
  }
}

/// ç²å­ç±?class _Particle {
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
    vy += 0.1; // è½»å¾®éå
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

/// VTuber ç«è³ç»å¶å¨
class _VtuberCatEarsPainter extends CustomPainter {
  final double leftEarEnergy;
  final double rightEarEnergy;
  final double glowIntensity;
  final double faceGlow;
  final Color color;

  _VtuberCatEarsPainter({
    required this.leftEarEnergy,
    required this.rightEarEnergy,
    required this.glowIntensity,
    required this.faceGlow,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    
    // ç»å¶ç«è?    _drawEar(canvas, cx - w * 0.3, h * 0.25, leftEarEnergy, isLeft: true);
    _drawEar(canvas, cx + w * 0.3, h * 0.25, rightEarEnergy, isLeft: false);
    
    // ç»å¶è¸é¨
    _drawFace(canvas, size);
    
    // ç»å¶é¢è°±æ?    _drawSpectrum(canvas, size);
  }

  void _drawEar(Canvas canvas, double x, double y, double energy, {required bool isLeft}) {
    final earW = 45 + energy * 20;
    final earH = 55 + energy * 25;
    
    // è³æµè·³å¨åç§»
    final bounce = sin(energy * pi) * 3;
    final offsetY = isLeft ? -bounce : -bounce;
    
    // å¤è?    final earPath = Path();
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
    
    // æ¸åå¡«å
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color,
          Color.lerp(color, Colors.pink, 0.3) ?? color,
        ],
      ).createShader(Rect.fromLTWH(x - earW / 2, y - earH, earW, earH + 20));
    canvas.drawPath(earPath, gradientPaint);
    
    // åè?    final innerW = earW * 0.5;
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
    canvas.drawPath(innerPath, Paint()..color = Colors.pink.shade100);
    
    // ååææ
    if (energy > 0.3) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: energy * 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * energy);
      canvas.drawPath(earPath, glowPaint);
      
      // é«å
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
    
    // è¸é¨èæ¯
    final faceBg = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.3),
        colors: [
          Colors.white,
          Color.lerp(Colors.pink.shade50, Colors.white, 0.5) ?? Colors.white,
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
    
    // è¸é¨åå
    if (faceGlow > 0.2) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: faceGlow * 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * faceGlow);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, faceY), width: faceW, height: faceH),
        glowPaint,
      );
    }
    
    // è®çº¢
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
    
    // ç¼ç
    final eyeY = faceY - faceH * 0.1;
    final eyeSpacing = faceW * 0.2;
    
    // å·¦ç¼
    _drawEye(canvas, Offset(cx - eyeSpacing, eyeY), faceGlow);
    // å³ç¼
    _drawEye(canvas, Offset(cx + eyeSpacing, eyeY), faceGlow);
    
    // é¼»å­
    final nosePaint = Paint()..color = Colors.pink.shade300 ?? Colors.pink;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, faceY + faceH * 0.15), width: 8, height: 6),
      nosePaint,
    );
    
    // å´å·´
    final mouthPath = Path();
    mouthPath.moveTo(cx - 15, faceY + faceH * 0.25);
    mouthPath.quadraticBezierTo(cx, faceY + faceH * 0.35, cx + 15, faceY + faceH * 0.25);
    canvas.drawPath(mouthPath, Paint()
      ..color = Colors.pink.shade300 ?? Colors.pink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
    
    // ç«ç³
    final pupilPaint = Paint()..color = Colors.grey.shade800 ?? Colors.black;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, faceY + faceH * 0.08), width: 6, height: 8),
      pupilPaint,
    );
  }

  void _drawEye(Canvas canvas, Offset center, double energy) {
    // ç¼çé«å
    final eyeBg = Paint()..color = Colors.white;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 25, height: 20),
      eyeBg,
    );
    
    // ç³å­ï¼æ ¹æ®è½éååï¼
    final pupilSize = 8 + energy * 4;
    final pupilPaint = Paint()..color = color;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: pupilSize, height: pupilSize + 4),
      pupilPaint,
    );
    
    // ç¼çé«åç?    final highlightPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(center.dx - 4, center.dy - 4), 3, highlightPaint);
  }

  void _drawSpectrum(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final bars = min(spectrumData.length, 20);
    final half = bars ~/ 2;
    
    for (int i = 0; i < half; i++) {
      final idx = (spectrumData.length * i / half).round().clamp(0, spectrumData.length - 1);
      final e = spectrumData[idx];
      final barH = e * h * 0.25;
      
      // å·¦è³å¤ä¾§é¢è°?      final leftX = cx - 60 - (half - i) * 6;
      _drawSpectrumBar(canvas, leftX, h * 0.7, 5, barH, e);
      
      // å³è³å¤ä¾§é¢è°?      final rightX = cx + 60 + (half - i) * 6;
      _drawSpectrumBar(canvas, rightX, h * 0.7, 5, barH, e);
    }
  }

  // è¿ä¸ªæ¹æ³éè¦è®¿é?spectrumDataï¼ä½æä»¬ä¸å¨ painter é?  List<double> get spectrumData => [];

  void _drawSpectrumBar(Canvas canvas, double x, double baseY, double width, double height, double energy) {
    if (height < 2) return;
    
    final barRect = Rect.fromLTWH(x, baseY - height, width, height);
    
    // æ¸åæ?    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color,
          Color.lerp(color, Colors.yellow, 0.5) ?? color,
          Colors.white,
        ],
      ).createShader(barRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, Radius.circular(width / 2)),
      barPaint,
    );
    
    // é¡¶é¨åå
    if (energy > 0.5) {
      final tipGlow = Paint()
        ..color = Colors.white.withValues(alpha: energy * 0.7)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(x + width / 2, baseY - height), width / 2 + 2, tipGlow);
    }
  }

  @override
  bool shouldRepaint(_VtuberCatEarsPainter old) => true;
}

/// ðµ ç®åçç«è³é¢è°±ï¼è½»éçº§ï¼
class SimpleCatEarsVisualizer extends StatelessWidget {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;
  final double height;

  const SimpleCatEarsVisualizer({
    super.key,
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
    this.height = 150,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _SimpleCatEarsPainter(
          spectrumData: spectrumData,
          isPlaying: isPlaying,
          color: color,
        ),
      ),
    );
  }
}

class _SimpleCatEarsPainter extends CustomPainter {
  final List<double> spectrumData;
  final bool isPlaying;
  final Color color;

  _SimpleCatEarsPainter({
    required this.spectrumData,
    required this.isPlaying,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    
    // è®¡ç®è½é
    double energy = 0;
    if (spectrumData.isNotEmpty) {
      for (var e in spectrumData) {
        energy += e;
      }
      energy /= spectrumData.length;
    }
    
    // ç«è³å¼¹è·?    final bounce = isPlaying ? sin(energy * pi * 2) * 5 : 0;
    
    // ç»å¶é¢è°±
    if (spectrumData.isNotEmpty) {
      final barCount = 8;
      final barWidth = 4.0;
      final gap = 3.0;
      
      for (int i = 0; i < barCount; i++) {
        final idx = (spectrumData.length * i / barCount).round().clamp(0, spectrumData.length - 1);
        final e = spectrumData[idx];
        final barH = e * h * 0.35;
        
        // å·¦ä¾§
        final leftX = cx - 30 - (barCount - i) * (barWidth + gap);
        _drawMiniBar(canvas, leftX, h * 0.85 - bounce, barWidth, barH, e);
        
        // å³ä¾§
        final rightX = cx + 30 + (barCount - i) * (barWidth + gap);
        _drawMiniBar(canvas, rightX, h * 0.85 - bounce, barWidth, barH, e);
      }
    }
    
    // ç»å¶ç«è?    _drawMiniEar(canvas, cx - w * 0.25, h * 0.35 - bounce, energy, true);
    _drawMiniEar(canvas, cx + w * 0.25, h * 0.35 - bounce, energy, false);
    
    // ç»å¶è¸é¨
    _drawMiniFace(canvas, size, energy, bounce);
  }

  void _drawMiniEar(Canvas canvas, double x, double y, double energy, bool isLeft) {
    final earW = 30 + energy * 10;
    final earH = 40 + energy * 15;
    
    final path = Path();
    path.moveTo(x - earW / 2, y + 15);
    path.lineTo(x, y - earH);
    path.lineTo(x + earW / 2, y + 15);
    path.close();
    
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color, Colors.pink.shade300 ?? color],
      ).createShader(Rect.fromLTWH(x - earW / 2, y - earH, earW, earH + 15)));
    
    // åè?    final inner = Path();
    inner.moveTo(x - earW * 0.3, y + 8);
    inner.lineTo(x, y - earH * 0.5);
    inner.lineTo(x + earW * 0.3, y + 8);
    inner.close();
    canvas.drawPath(inner, Paint()..color = Colors.pink.shade100);
    
    // åå
    if (energy > 0.4) {
      canvas.drawPath(path, Paint()
        ..color = color.withValues(alpha: energy * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * energy));
    }
  }

  void _drawMiniFace(Canvas canvas, Size size, double energy, double bounce) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final faceY = h * 0.55 + bounce * 0.5;
    
    // è¸é¨
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, faceY), width: w * 0.4, height: h * 0.35),
      Paint()..shader = RadialGradient(
        colors: [Colors.white, Colors.pink.shade50 ?? Colors.pink],
      ).createShader(Rect.fromCenter(center: Offset(cx, faceY), width: w * 0.4, height: h * 0.35)),
    );
    
    // è®çº¢
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.12, faceY + h * 0.05), width: w * 0.08, height: h * 0.06),
      Paint()..color = Colors.pink.shade200?.withValues(alpha: 0.5) ?? Colors.pink.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.12, faceY + h * 0.05), width: w * 0.08, height: h * 0.06),
      Paint()..color = Colors.pink.shade200?.withValues(alpha: 0.5) ?? Colors.pink.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    
    // ç¼ç
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - w * 0.08, faceY - h * 0.05), width: 12, height: 10),
      Paint()..color = color,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + w * 0.08, faceY - h * 0.05), width: 12, height: 10),
      Paint()..color = color,
    );
    
    // é«å
    canvas.drawCircle(Offset(cx - w * 0.09, faceY - h * 0.07), 2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(cx + w * 0.07, faceY - h * 0.07), 2, Paint()..color = Colors.white);
    
    // å´å·´
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, faceY + h * 0.08), width: 20, height: 12),
      0, pi, true,
      Paint()..color = Colors.pink.shade300 ?? Colors.pink,
    );
  }

  void _drawMiniBar(Canvas canvas, double x, double baseY, double width, double height, double energy) {
    if (height < 1) return;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, baseY - height, width, height),
        Radius.circular(width / 2),
      ),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [color, Colors.yellow, Colors.white],
        ).createShader(Rect.fromLTWH(x, baseY - height, width, height)),
    );
    
    // é¡¶é¨åç¹
    if (energy > 0.5) {
      canvas.drawCircle(
        Offset(x + width / 2, baseY - height),
        width * 0.6,
        Paint()..color = Colors.white.withValues(alpha: energy * 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SimpleCatEarsPainter old) => true;
}

