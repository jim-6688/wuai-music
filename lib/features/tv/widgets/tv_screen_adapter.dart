import 'package:flutter/widgets.dart';

/// TV 屏幕分辨率自适应工具类
///
/// 支持 720p / 1080p / 2K / 4K / 8K 及任意分辨率自动适配。
/// 设计基准为 1920×1080（1080p），其他分辨率等比缩放。
///
/// 使用方式:
/// ```dart
/// final adapter = TvScreenAdapter.of(context);
/// adapter.scale       // 统一缩放系数 (1080p = 1.0, 4K ≈ 2.0)
/// adapter.sp(24)      // 缩放后的字体大小
/// adapter.size(64)    // 缩放后的尺寸 (图标、宽高等)
/// adapter.spacing(32) // 缩放后的间距
/// ```
class TvScreenAdapter {
  /// 基准设计分辨率宽度
  static const double baseWidth = 1920.0;

  /// 缩放系数下限（防止极小屏幕上元素过小）
  static const double minScale = 0.6;

  /// 缩放系数上限（支持 8K: 3840/1920 = 2.0, 7680/1920 = 4.0）
  /// 设为 4.0 以完全支持 8K 分辨率
  static const double maxScale = 4.0;

  /// 原始屏幕宽度
  final double screenWidth;

  /// 原始屏幕高度
  final double screenHeight;

  /// 缩放系数，基于屏幕宽度相对于 1920 的比值
  final double scale;

  TvScreenAdapter._({
    required this.screenWidth,
    required this.screenHeight,
    required this.scale,
  });

  /// 从 BuildContext 创建适配器
  factory TvScreenAdapter.of(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return TvScreenAdapter.fromSize(size);
  }

  /// 从 Size 创建适配器
  factory TvScreenAdapter.fromSize(Size size) {
    final rawScale = size.width / baseWidth;
    final clampedScale = rawScale.clamp(minScale, maxScale);
    return TvScreenAdapter._(
      screenWidth: size.width,
      screenHeight: size.height,
      scale: clampedScale,
    );
  }

  /// 缩放后的字体大小
  double sp(double baseFontSize) => baseFontSize * scale;

  /// 缩放后的尺寸 (图标、宽高等)
  double size(double baseSize) => baseSize * scale;

  /// 缩放后的间距
  double spacing(double baseSpacing) => baseSpacing * scale;

  /// 缩放后的圆角
  double radius(double baseRadius) => baseRadius * scale;

  /// 缩放后的内边距
  EdgeInsets padding(double all) => EdgeInsets.all(all * scale);

  /// 缩放后的水平+垂直内边距
  EdgeInsets paddingSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) => EdgeInsets.symmetric(
        horizontal: horizontal * scale,
        vertical: vertical * scale,
      );

  /// 缩放后的仅水平内边距
  EdgeInsets paddingOnly({
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) => EdgeInsets.only(
        left: left * scale,
        right: right * scale,
        top: top * scale,
        bottom: bottom * scale,
      );

  /// 获取分辨率级别描述
  String get resolutionLabel {
    if (screenWidth >= 7680) return '8K UHD';
    if (screenWidth >= 3840) return '4K UHD';
    if (screenWidth >= 2560) return '2K QHD';
    if (screenWidth >= 1920) return '1080p FHD';
    if (screenWidth >= 1280) return '720p HD';
    return '${screenWidth.round()}p';
  }

  /// 获取分辨率级别的对角线英寸数估算（基于 16:9）
  String get estimatedDiagonal {
    // 16:9 比例下，像素尺寸转 PPI 需要屏幕物理尺寸
    // 这里只返回分辨率信息
    return resolutionLabel;
  }

  @override
  String toString() =>
      'TvScreenAdapter(${screenWidth.round()}×${screenHeight.round()}, '
      'scale: ${scale.toStringAsFixed(2)}, $resolutionLabel)';
}
