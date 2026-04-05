import 'dart:io';
import 'package:flutter/foundation.dart';

/// 设备工具类
class DeviceUtils {
  /// 检测是否为Android TV
  static Future<bool> isAndroidTV() async {
    if (!Platform.isAndroid) return false;

    try {
      // 检查 TV 特性文件
      for (final f in [
        '/system/etc/permissions/android.hardware.type.television.xml',
        '/system/etc/permissions/android.software.leanback.xml',
      ]) {
        if (await File(f).exists()) return true;
      }

      // 检查 build.prop
      final bp = File('/system/build.prop');
      if (await bp.exists()) {
        final content = await bp.readAsString();
        if (content.contains('ro.build.characteristics=tv') ||
            content.contains('android.hardware.type.television')) {
          return true;
        }
      }

      // 检查设备型号和品牌
      try {
        final modelResult = await Process.run(
          'getprop',
          ['ro.product.model'],
          runInShell: true,
        );
        final model = modelResult.stdout.toString().toLowerCase();
        if (model.contains('tv') ||
            model.contains('atv') ||
            model.contains('box') ||
            model.contains('chromecast')) {
          return true;
        }
      } catch (_) {}
    } catch (_) {}

    return false;
  }

  /// 获取应用名称
  static Future<String> getApplicationName() async {
    final isTV = await isAndroidTV();
    return isTV ? '吾爱musicTV' : '吾爱music';
  }

  /// 缓存的 TV 检测结果（性能优化）
  static bool? _cachedIsTV;

  /// 快速检查是否为TV（使用缓存）
  static Future<bool> isAndroidTVCached() async {
    _cachedIsTV ??= await isAndroidTV();
    return _cachedIsTV!;
  }
}
