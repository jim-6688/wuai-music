import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV 焦点导航管理器
/// 
/// 新设计规范:
/// - 更大的缩放效果 (1.12)
/// - 更强的发光阴影
/// - 动态发光动画
/// - 超大字体和图标
class TVFocusManager {
  static const double focusScale = 1.12;          // 更大的缩放
  static const double focusBlur = 64.0;           // 更强的模糊
  static const double focusSpread = 16.0;         // 更大的扩散
  static const Duration focusAnimDuration = Duration(milliseconds: 300);
  static const Curve focusCurve = Curves.easeOutCubic;

  /// 焦点边框装饰 - 超强发光
  static BoxDecoration getFocusedDecoration({
    required Color color,
    required bool isFocused,
    required double borderRadius,
    bool enableGlow = true,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isFocused 
            ? color.withValues(alpha: 1.0)
            : Colors.white.withValues(alpha: 0.1),
        width: isFocused ? 6 : 2,
      ),
      boxShadow: isFocused && enableGlow
          ? [
              // 主发光
              BoxShadow(
                color: color.withValues(alpha: 0.6),
                blurRadius: focusBlur,
                spreadRadius: focusSpread,
              ),
              // 外发光
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 96,
                spreadRadius: 24,
              ),
              // 深度阴影
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
    );
  }

  /// 焦点背景颜色
  static Color getFocusedBackgroundColor({
    required Color color,
    required bool isFocused,
    required bool isDark,
  }) {
    if (isFocused) {
      return color.withValues(alpha: 0.25);
    }
    return isDark 
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.05);
  }

  /// 焦点文字颜色
  static Color getFocusedTextColor({
    required Color color,
    required bool isFocused,
    required bool isDark,
  }) {
    if (isFocused) {
      return color;
    }
    return isDark ? Colors.white : Colors.black87;
  }
}

/// TV 焦点卡片组件 - 超大尺寸
/// 
/// 支持焦点导航、高亮、动态发光效果的卡片
class TVFocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onFocus;
  final VoidCallback? onUnfocus;
  final Color focusColor;
  final double borderRadius;
  final double width;
  final double height;
  final bool autofocus;
  final bool enableGlow;

  const TVFocusCard({
    super.key,
    required this.child,
    this.onTap,
    this.onFocus,
    this.onUnfocus,
    this.focusColor = Colors.blue,
    this.borderRadius = 40,
    this.width = 380,
    this.height = 480,
    this.autofocus = false,
    this.enableGlow = true,
  });

  @override
  State<TVFocusCard> createState() => _TVFocusCardState();
}

class _TVFocusCardState extends State<TVFocusCard> 
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final focusedScale = _isFocused ? TVFocusManager.focusScale : 1.0;
    final focusedWidth = widget.width * focusedScale;
    final focusedHeight = widget.height * focusedScale;

    // 焦点时启动发光动画
    if (_isFocused && widget.enableGlow) {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
    }

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
        if (focused) {
          widget.onFocus?.call();
        } else {
          widget.onUnfocus?.call();
        }
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return AnimatedContainer(
              duration: TVFocusManager.focusAnimDuration,
              curve: TVFocusManager.focusCurve,
              width: focusedWidth,
              height: focusedHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: _isFocused 
                      ? widget.focusColor.withValues(alpha: 1.0)
                      : Colors.white.withValues(alpha: 0.1),
                  width: _isFocused ? 6 : 2,
                ),
                boxShadow: _isFocused && widget.enableGlow
                    ? [
                        BoxShadow(
                          color: widget.focusColor.withValues(alpha: _glowAnimation.value),
                          blurRadius: 64,
                          spreadRadius: 16,
                        ),
                        BoxShadow(
                          color: widget.focusColor.withValues(alpha: 0.3),
                          blurRadius: 96,
                          spreadRadius: 24,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  color: TVFocusManager.getFocusedBackgroundColor(
                    color: widget.focusColor,
                    isFocused: _isFocused,
                    isDark: isDark,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// TV 焦点按钮组件 - 超大尺寸
class TVFocusButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final Color focusColor;
  final double width;
  final double height;
  final bool autofocus;
  final bool enableGlow;

  const TVFocusButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.focusColor = Colors.blue,
    this.width = 160,
    this.height = 160,
    this.autofocus = false,
    this.enableGlow = true,
  });

  @override
  State<TVFocusButton> createState() => _TVFocusButtonState();
}

class _TVFocusButtonState extends State<TVFocusButton> 
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.4,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shouldGlow = _isFocused && widget.enableGlow;

    // 焦点时启动发光动画
    if (shouldGlow && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if (!shouldGlow && _glowController.isAnimating) {
      _glowController.stop();
    }

    return Focus(
      focusNode: _focusNode,
      onFocusChange: (focused) {
        setState(() => _isFocused = focused);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.gameButtonA ||
              event.logicalKey == LogicalKeyboardKey.select) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
              child: AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return AnimatedContainer(
              duration: TVFocusManager.focusAnimDuration,
              curve: TVFocusManager.focusCurve,
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isFocused 
                      ? widget.focusColor.withValues(alpha: 1.0)
                      : Colors.white.withValues(alpha: 0.1),
                  width: _isFocused ? 6 : 2,
                ),
                boxShadow: shouldGlow
                    ? [
                        BoxShadow(
                          color: widget.focusColor.withValues(alpha: _glowAnimation.value),
                          blurRadius: 64,
                          spreadRadius: 16,
                        ),
                        BoxShadow(
                          color: widget.focusColor.withValues(alpha: 0.3),
                          blurRadius: 96,
                          spreadRadius: 24,
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ]
                    : (_isFocused
                        ? [
                            BoxShadow(
                              color: widget.focusColor.withValues(alpha: 0.4),
                              blurRadius: 32,
                              spreadRadius: 8,
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ]),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TVFocusManager.getFocusedBackgroundColor(
                    color: widget.focusColor,
                    isFocused: _isFocused,
                    isDark: isDark,
                  ),
                ),
                child: Center(child: child),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// TV 焦点网格组件 - 超大间距
/// 
/// 支持方向键导航的网格布局
class TVFocusGrid extends StatefulWidget {
  final List<Widget> children;
  final int crossAxisCount;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final int initialFocusIndex;

  const TVFocusGrid({
    super.key,
    required this.children,
    this.crossAxisCount = 4,
    this.mainAxisSpacing = 64,
    this.crossAxisSpacing = 64,
    this.initialFocusIndex = 0,
  });

  @override
  State<TVFocusGrid> createState() => _TVFocusGridState();
}

class _TVFocusGridState extends State<TVFocusGrid> {
  late List<FocusNode> _focusNodes;
  int _currentFocusIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentFocusIndex = widget.initialFocusIndex.clamp(0, widget.children.length - 1);
    _focusNodes = List.generate(
      widget.children.length,
      (index) => FocusNode(),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[_currentFocusIndex].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _moveFocus(int direction) {
    int newIndex = _currentFocusIndex;
    
    switch (direction) {
      case 0: // 上
        newIndex = (_currentFocusIndex - widget.crossAxisCount).clamp(0, widget.children.length - 1);
        break;
      case 1: // 下
        newIndex = (_currentFocusIndex + widget.crossAxisCount).clamp(0, widget.children.length - 1);
        break;
      case 2: // 左
        if (_currentFocusIndex % widget.crossAxisCount > 0) {
          newIndex = _currentFocusIndex - 1;
        }
        break;
      case 3: // 右
        if (_currentFocusIndex % widget.crossAxisCount < widget.crossAxisCount - 1) {
          newIndex = _currentFocusIndex + 1;
        }
        break;
    }

    if (newIndex != _currentFocusIndex) {
      setState(() => _currentFocusIndex = newIndex);
      _focusNodes[newIndex].requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _moveFocus(0);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _moveFocus(1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _moveFocus(2);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _moveFocus(3);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GridView.count(
        crossAxisCount: widget.crossAxisCount,
        mainAxisSpacing: widget.mainAxisSpacing,
        crossAxisSpacing: widget.crossAxisSpacing,
        children: List.generate(
          widget.children.length,
          (index) => Focus(
            focusNode: _focusNodes[index],
            onFocusChange: (focused) {
              if (focused) {
                setState(() => _currentFocusIndex = index);
              }
            },
            child: widget.children[index],
          ),
        ),
      ),
    );
  }
}
