import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// 吾爱玻璃容器组件
/// 提供毛玻璃背景和液态动效
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final double blur;
  final Color? backgroundColor;
  final double opacity;
  final Border? border;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.blur = 20.0,
    this.backgroundColor,
    this.opacity = 0.7,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradient,
              color: backgroundColor ??
                  (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: opacity)),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// 液态背景组件 - 带流动动画
class LiquidBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? colors;

  const LiquidBackground({
    super.key,
    required this.child,
    this.colors,
  });

  @override
  State<LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colors = widget.colors ??
        (isDark
            ? [
                const Color(0xFF2C2C2E),
                const Color(0xFF1C1C1E),
                const Color(0xFF3A3A3C),
              ]
            : [
                const Color(0xFFE8F4FD),
                const Color(0xFFF5F0FF),
                const Color(0xFFE8FEF5),
              ]);

    return Stack(
      children: [
        // Animated gradient background
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                  transform: GradientRotation(_controller.value * 0.5),
                ),
              ),
            );
          },
        ),
        // Floating orbs for liquid effect
        ...List.generate(
            3,
            (index) => _FloatingOrb(
                  index: index,
                  controller: _controller,
                  isDark: isDark,
                )),
        // Main content
        widget.child,
      ],
    );
  }
}

class _FloatingOrb extends StatelessWidget {
  final int index;
  final AnimationController controller;
  final bool isDark;

  const _FloatingOrb({
    required this.index,
    required this.controller,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final positions = [
      const Offset(0.2, 0.3),
      const Offset(0.8, 0.2),
      const Offset(0.5, 0.7),
    ];

    final sizes = [80.0, 120.0, 60.0];
    final colors = isDark
        ? [
            Colors.blue.withValues(alpha: 0.05),
            Colors.purple.withValues(alpha: 0.05),
            Colors.green.withValues(alpha: 0.05),
          ]
        : [
            Colors.blue.withValues(alpha: 0.1),
            Colors.purple.withValues(alpha: 0.1),
            Colors.green.withValues(alpha: 0.1),
          ];

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value + (index * 0.33);
        final yOffset = (progress % 1.0) * 0.2 - 0.1;

        return Positioned(
          left: MediaQuery.of(context).size.width * positions[index].dx,
          top: MediaQuery.of(context).size.height *
              (positions[index].dy + yOffset),
          child: Transform.scale(
            scale: 1 + (progress % 1.0) * 0.2,
            child: Container(
              width: sizes[index],
              height: sizes[index],
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors[index],
                    colors[index].withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// 动态玻璃按钮
/// - 按下时：缩放 + 涟漪光波效果
/// - 常态：流动光晕（光线在玻璃表面扫过）
/// - 毛玻璃背景 + 半透明边框
// ─────────────────────────────────────────────────────────────────────────────
class GlassButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double borderRadius;
  final EdgeInsets? padding;
  final Color? backgroundColor;

  const GlassButton({
    super.key,
    this.onPressed,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.backgroundColor,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with TickerProviderStateMixin {
  // 按压缩放动画
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  // 流动光晕动画（常态）
  late AnimationController _shineController;
  late Animation<double> _shineAnimation;

  // 涟漪动画（按下瞬间）
  late AnimationController _rippleController;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();

    // 按压动画
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    // 流动光晕（4秒循环）
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();
    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.linear),
    );

    // 涟漪动画
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rippleScale = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _shineController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _isPressed = true;
    _pressController.forward();
    _rippleController.forward(from: 0);
  }

  void _onTapUp(TapUpDetails details) {
    _isPressed = false;
    _pressController.reverse();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    _isPressed = false;
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.70));

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleAnimation,
          _shineAnimation,
          _rippleScale,
          _rippleOpacity,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // ── 基础毛玻璃层 ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: widget.padding ??
                          const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius:
                            BorderRadius.circular(widget.borderRadius),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.55),
                          width: 1.0,
                        ),
                      ),
                      child: widget.child,
                    ),
                  ),
                ),

                // ── 流动光晕扫描线 ────────────────────────────────────────
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ShineLinePainter(
                          progress: _shineAnimation.value,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── 涟漪波纹（按下时） ────────────────────────────────────
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _RipplePainter(
                          scale: _rippleScale.value,
                          opacity: _rippleOpacity.value,
                          color: isDark ? Colors.white : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 流动光晕扫描线绘制器
class _ShineLinePainter extends CustomPainter {
  final double progress; // -1.0 to 2.0
  final bool isDark;

  _ShineLinePainter({required this.progress, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    // 只在特定进度区间绘制光晕，其余时间不可见
    if (progress < -0.2 || progress > 1.2) return;

    final x = size.width * progress;
    final shineWidth = size.width * 0.35;

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
          Colors.white.withValues(alpha: isDark ? 0.10 : 0.25),
          Colors.white.withValues(alpha: isDark ? 0.06 : 0.18),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(x - shineWidth / 2, 0, shineWidth, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(x - shineWidth / 2, 0, shineWidth, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ShineLinePainter oldDelegate) =>
      progress != oldDelegate.progress;
}

/// 涟漪波纹绘制器
class _RipplePainter extends CustomPainter {
  final double scale;
  final double opacity;
  final Color color;

  _RipplePainter({
    required this.scale,
    required this.opacity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius * scale, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      scale != oldDelegate.scale || opacity != oldDelegate.opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
/// 动态玻璃卡片
/// - 点击时有缩放 + 涟漪效果
/// - 顶部有细微高光边框
/// - 内置微弱光晕扫描动效
// ─────────────────────────────────────────────────────────────────────────────
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  late AnimationController _rippleController;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  // 光晕流动（每张卡片用不同初始相位避免同步）
  late AnimationController _shineController;
  late Animation<double> _shineAnimation;

  @override
  void initState() {
    super.initState();

    final random = Random(hashCode);

    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _rippleScale = Tween<double>(begin: 0.0, end: 1.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
    _rippleOpacity = Tween<double>(begin: 0.3, end: 0.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    _shineController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 5000 + random.nextInt(2000)),
    )..repeat();
    _shineAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shineController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    _rippleController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) {
        _pressController.forward();
        _rippleController.forward(from: 0);
      },
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _scaleAnimation,
          _shineAnimation,
          _rippleScale,
          _rippleOpacity,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: widget.margin,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ── 基础毛玻璃层 ──────────────────────────────────────
                  ClipRRect(
                    borderRadius:
                        BorderRadius.circular(widget.borderRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: widget.padding ??
                            const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          // 渐变玻璃背景（顶部更亮）
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.white.withValues(alpha: 0.06),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.75),
                                    Colors.white.withValues(alpha: 0.50),
                                  ],
                          ),
                          borderRadius:
                              BorderRadius.circular(widget.borderRadius),
                          // 顶部细亮边框（玻璃棱角高光）
                          border: Border(
                            top: BorderSide(
                              color: Colors.white
                                  .withValues(alpha: isDark ? 0.25 : 0.60),
                              width: 1.0,
                            ),
                            left: BorderSide(
                              color: Colors.white
                                  .withValues(alpha: isDark ? 0.12 : 0.35),
                              width: 0.5,
                            ),
                            right: BorderSide(
                              color: Colors.white
                                  .withValues(alpha: isDark ? 0.05 : 0.15),
                              width: 0.5,
                            ),
                            bottom: BorderSide(
                              color: Colors.white
                                  .withValues(alpha: isDark ? 0.05 : 0.15),
                              width: 0.5,
                            ),
                          ),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ),

                  // ── 流动光晕 ─────────────────────────────────────────
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(widget.borderRadius),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ShineLinePainter(
                            progress: _shineAnimation.value,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── 涟漪波纹 ─────────────────────────────────────────
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.circular(widget.borderRadius),
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _RipplePainter(
                            scale: _rippleScale.value,
                            opacity: _rippleOpacity.value,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// 动态底部菜单容器（带呼吸光晕 + 顶部高光边框）
/// 用于 showModalBottomSheet 的内容容器
// ─────────────────────────────────────────────────────────────────────────────
class GlassBottomSheet extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double topRadius;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.padding,
    this.topRadius = 24.0,
  });

  @override
  State<GlassBottomSheet> createState() => _GlassBottomSheetState();
}

class _GlassBottomSheetState extends State<GlassBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _breatheAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, child) {
        final breatheAlpha = 0.08 + _breatheAnimation.value * 0.05;

        return ClipRRect(
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(widget.topRadius)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Colors.white.withValues(alpha: breatheAlpha + 0.04),
                          Colors.white.withValues(alpha: 0.06),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.85),
                          Colors.white.withValues(alpha: 0.70),
                        ],
                ),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(widget.topRadius)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white
                        .withValues(alpha: isDark ? 0.20 : 0.60),
                    width: 1.0,
                  ),
                  left: BorderSide(
                    color: Colors.white
                        .withValues(alpha: isDark ? 0.08 : 0.25),
                    width: 0.5,
                  ),
                  right: BorderSide(
                    color: Colors.white
                        .withValues(alpha: isDark ? 0.08 : 0.25),
                    width: 0.5,
                  ),
                ),
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
