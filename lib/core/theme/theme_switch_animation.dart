import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 暗色模式切换动画控制器
/// 提供圆形扩散（Ripple）过渡效果
class ThemeSwitchController {
  static final ThemeSwitchController _instance = ThemeSwitchController._();
  factory ThemeSwitchController() => _instance;
  ThemeSwitchController._();

  /// 全局 key，用于截图
  final GlobalKey repaintKey = GlobalKey();

  /// 动画状态通知
  final ValueNotifier<_ThemeSwitchState?> animationState =
      ValueNotifier(null);

  /// 触发主题切换动画
  /// [offset] 动画起始点（通常是切换按钮的中心位置）
  /// [toDark] 是否切换到暗色模式
  Future<void> trigger({
    required Offset offset,
    required bool toDark,
    required VoidCallback onSwitch,
  }) async {
    // 截取当前屏幕快照
    final boundary = repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      onSwitch();
      return;
    }

    final image = await boundary.toImage(pixelRatio: ui.PlatformDispatcher.instance.views.first.devicePixelRatio);

    animationState.value = _ThemeSwitchState(
      snapshot: image,
      origin: offset,
      toDark: toDark,
      onSwitch: onSwitch,
    );
  }

  void clear() {
    animationState.value = null;
  }
}

class _ThemeSwitchState {
  final ui.Image snapshot;
  final Offset origin;
  final bool toDark;
  final VoidCallback onSwitch;

  _ThemeSwitchState({
    required this.snapshot,
    required this.origin,
    required this.toDark,
    required this.onSwitch,
  });
}

/// 主题切换动画包装器
/// 包裹在 MaterialApp 的 home 外层
class ThemeSwitchWrapper extends StatefulWidget {
  final Widget child;

  const ThemeSwitchWrapper({super.key, required this.child});

  @override
  State<ThemeSwitchWrapper> createState() => _ThemeSwitchWrapperState();
}

class _ThemeSwitchWrapperState extends State<ThemeSwitchWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  _ThemeSwitchState? _state;
  bool _switched = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    ThemeSwitchController().animationState.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    ThemeSwitchController().animationState.removeListener(_onStateChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    final state = ThemeSwitchController().animationState.value;
    if (state == null) return;

    setState(() {
      _state = state;
      _switched = false;
    });

    _controller.forward(from: 0).then((_) {
      ThemeSwitchController().clear();
      setState(() {
        _state = null;
        _switched = false;
      });
    });

    // 在动画中途切换主题（约 30% 时）
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!_switched && mounted) {
        _switched = true;
        state.onSwitch();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: ThemeSwitchController().repaintKey,
      child: Stack(
        children: [
          widget.child,
          if (_state != null)
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RipplePainter(
                    snapshot: _state!.snapshot,
                    origin: _state!.origin,
                    progress: _animation.value,
                    toDark: _state!.toDark,
                  ),
                  size: Size.infinite,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// 圆形扩散绘制器
class _RipplePainter extends CustomPainter {
  final ui.Image snapshot;
  final Offset origin;
  final double progress;
  final bool toDark;

  _RipplePainter({
    required this.snapshot,
    required this.origin,
    required this.progress,
    required this.toDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 计算最大半径（覆盖整个屏幕所需）
    final maxRadius = _calcMaxRadius(size, origin);
    final currentRadius = maxRadius * progress;

    if (toDark) {
      // 亮→暗：先绘制旧截图，再用圆形裁剪区域显示新主题（黑色扩散）
      _drawSnapshot(canvas, size);
      canvas.save();
      final path = Path()
        ..addOval(Rect.fromCircle(center: origin, radius: currentRadius));
      canvas.clipPath(path);
      canvas.drawColor(Colors.transparent, BlendMode.clear);
      canvas.restore();
    } else {
      // 暗→亮：先绘制旧截图，圆形区域外保留快照，圆内透明（新主题透出）
      canvas.save();
      final fullPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final circlePath = Path()
        ..addOval(Rect.fromCircle(center: origin, radius: currentRadius));
      final clipPath = Path.combine(
        PathOperation.difference,
        fullPath,
        circlePath,
      );
      canvas.clipPath(clipPath);
      _drawSnapshot(canvas, size);
      canvas.restore();
    }
  }

  void _drawSnapshot(Canvas canvas, Size size) {
    final paint = Paint();
    final src = Rect.fromLTWH(
      0, 0,
      snapshot.width.toDouble(),
      snapshot.height.toDouble(),
    );
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(snapshot, src, dst, paint);
  }

  double _calcMaxRadius(Size size, Offset origin) {
    final corners = [
      Offset(0, 0),
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ];
    return corners
        .map((c) => (c - origin).distance)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
