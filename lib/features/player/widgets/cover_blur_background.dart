import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 封面模糊背景组件 - 抖音风格
/// 将专辑封面进行高斯模糊后作为播放界面背景
class CoverBlurBackground extends StatelessWidget {
  /// 本地封面路径
  final String? localCoverPath;
  
  /// 网络封面字节
  final Uint8List? coverBytes;
  
  /// 模糊程度
  final double blurSigma;
  
  /// 混合颜色层透明度
  final double overlayOpacity;
  
  /// 是否为暗黑模式
  final bool isDarkMode;
  
  /// 暗色层颜色（可选，用于增强对比）
  final Color? overlayColor;

  const CoverBlurBackground({
    super.key,
    this.localCoverPath,
    this.coverBytes,
    this.blurSigma = 30.0,
    this.overlayOpacity = 0.4,
    this.isDarkMode = true,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. 底层渐变（作为 fallback 或基础色）
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDarkMode
                  ? [Colors.purple.shade900, Colors.blue.shade900, Colors.indigo.shade900]
                  : [Colors.blue.shade100, Colors.purple.shade100, Colors.indigo.shade50],
            ),
          ),
        ),
        
        // 2. 封面图片模糊层
        if (localCoverPath != null || coverBytes != null)
          _buildCoverBlur(),
        
        // 3. 颜色混合层（增加可读性）
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma * 0.3, sigmaY: blurSigma * 0.3),
          child: Container(
            color: overlayColor ?? (isDarkMode 
              ? Colors.black.withValues(alpha: overlayOpacity)
              : Colors.white.withValues(alpha: overlayOpacity * 0.8)),
          ),
        ),
        
        // 4. 顶层轻微模糊（增加梦幻感）
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  Widget _buildCoverBlur() {
    Widget coverWidget;
    
    if (coverBytes != null) {
      // 网络封面（字节）
      coverWidget = Image.memory(
        coverBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else if (localCoverPath != null) {
      // 本地封面文件
      coverWidget = Image.file(
        File(localCoverPath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
    } else {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 封面原图
        coverWidget,
        
        // 模糊效果
        BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }
}

/// 带动画的封面模糊背景（封面切换时有淡入效果）
class AnimatedCoverBlurBackground extends StatefulWidget {
  final String? localCoverPath;
  final Uint8List? coverBytes;
  final double blurSigma;
  final double overlayOpacity;
  final bool isDarkMode;
  final Color? overlayColor;

  const AnimatedCoverBlurBackground({
    super.key,
    this.localCoverPath,
    this.coverBytes,
    this.blurSigma = 30.0,
    this.overlayOpacity = 0.4,
    this.isDarkMode = true,
    this.overlayColor,
  });

  @override
  State<AnimatedCoverBlurBackground> createState() => _AnimatedCoverBlurBackgroundState();
}

class _AnimatedCoverBlurBackgroundState extends State<AnimatedCoverBlurBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  String? _previousPath;
  Uint8List? _previousBytes;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCoverBlurBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // 检测封面变化，触发动画
    final coverChanged = widget.localCoverPath != oldWidget.localCoverPath ||
        widget.coverBytes != oldWidget.coverBytes;
    
    if (coverChanged && (widget.localCoverPath != null || widget.coverBytes != null)) {
      _previousPath = oldWidget.localCoverPath;
      _previousBytes = oldWidget.coverBytes;
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CoverBlurBackground(
        localCoverPath: widget.localCoverPath,
        coverBytes: widget.coverBytes,
        blurSigma: widget.blurSigma,
        overlayOpacity: widget.overlayOpacity,
        isDarkMode: widget.isDarkMode,
        overlayColor: widget.overlayColor,
      ),
    );
  }
}