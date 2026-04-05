import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'custom_color_schemes.dart';

/// 主题模式
enum AppThemeMode {
  light, // 浅色模式
  dark, // 深色模式
  system, // 跟随系统
}

/// 文字大小级别
enum TextSizeLevel {
  small, // 小
  normal, // 正常
  large, // 大
  extraLarge, // 特大
}

/// 主题配置
class ThemeConfig {
  final AppThemeMode themeMode;
  final String colorSchemeId;
  final bool useCustomColor;
  final Color? customPrimaryColor;
  final Color? customSecondaryColor;
  final TextSizeLevel textSizeLevel;
  final bool isTVMode; // TV 模式标记，强制浅色主题

  const ThemeConfig({
    this.themeMode = AppThemeMode.light, // 默认浅色主题
    this.colorSchemeId = 'apple_blue',
    this.useCustomColor = false,
    this.customPrimaryColor,
    this.customSecondaryColor,
    this.textSizeLevel = TextSizeLevel.normal,
    this.isTVMode = false, // 默认非 TV 模式
  });

  ThemeConfig copyWith({
    AppThemeMode? themeMode,
    String? colorSchemeId,
    bool? useCustomColor,
    Color? customPrimaryColor,
    Color? customSecondaryColor,
    TextSizeLevel? textSizeLevel,
    bool? isTVMode,
  }) {
    return ThemeConfig(
      themeMode: themeMode ?? this.themeMode,
      colorSchemeId: colorSchemeId ?? this.colorSchemeId,
      useCustomColor: useCustomColor ?? this.useCustomColor,
      customPrimaryColor: customPrimaryColor ?? this.customPrimaryColor,
      customSecondaryColor: customSecondaryColor ?? this.customSecondaryColor,
      textSizeLevel: textSizeLevel ?? this.textSizeLevel,
      isTVMode: isTVMode ?? this.isTVMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode.index,
      'colorSchemeId': colorSchemeId,
      'useCustomColor': useCustomColor,
      'customPrimaryColor': customPrimaryColor?.value,
      'customSecondaryColor': customSecondaryColor?.value,
      'textSizeLevel': textSizeLevel.index,
      'isTVMode': isTVMode,
    };
  }

  factory ThemeConfig.fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      themeMode: AppThemeMode.values[json['themeMode'] as int? ?? 0],
      colorSchemeId: json['colorSchemeId'] as String? ?? 'apple_blue',
      useCustomColor: json['useCustomColor'] as bool? ?? false,
      customPrimaryColor: json['customPrimaryColor'] != null
          ? Color(json['customPrimaryColor'] as int)
          : null,
      customSecondaryColor: json['customSecondaryColor'] != null
          ? Color(json['customSecondaryColor'] as int)
          : null,
      textSizeLevel: TextSizeLevel.values[json['textSizeLevel'] as int? ?? 1],
      isTVMode: json['isTVMode'] as bool? ?? false,
    );
  }

  /// 获取文字大小缩放比例
  double get textScaleFactor {
    switch (textSizeLevel) {
      case TextSizeLevel.small:
        return 0.85;
      case TextSizeLevel.normal:
        return 1.0;
      case TextSizeLevel.large:
        return 1.15;
      case TextSizeLevel.extraLarge:
        return 1.3;
    }
  }

  /// 获取文字大小级别名称
  String get textSizeLevelName {
    switch (textSizeLevel) {
      case TextSizeLevel.small:
        return '小';
      case TextSizeLevel.normal:
        return '正常';
      case TextSizeLevel.large:
        return '大';
      case TextSizeLevel.extraLarge:
        return '特大';
    }
  }
}

/// 主题管理器
class ThemeNotifier extends StateNotifier<ThemeConfig> {
  ThemeNotifier() : super(const ThemeConfig()) {
    _loadThemeConfig();
  }

  Future<void> _loadThemeConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configJson = prefs.getString('theme_config');
      if (configJson != null) {
        final json = jsonDecode(configJson) as Map<String, dynamic>;
        state = ThemeConfig.fromJson(json);
      }
      // 如果是 TV 模式，强制使用浅色主题
      if (state.isTVMode && state.themeMode != AppThemeMode.light) {
        state = state.copyWith(themeMode: AppThemeMode.light);
        await _saveThemeConfig();
      }
    } catch (e) {
      debugPrint('加载主题配置失败: $e');
    }
  }

  Future<void> _saveThemeConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_config', jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('保存主题配置失败: $e');
    }
  }

  /// 切换主题模式
  Future<void> setThemeMode(AppThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _saveThemeConfig();
  }

  /// 切换主题模式（在 light/dark 之间切换）
  Future<void> toggleThemeMode() async {
    final newMode = state.themeMode == AppThemeMode.dark
        ? AppThemeMode.light
        : AppThemeMode.dark;
    state = state.copyWith(themeMode: newMode);
    await _saveThemeConfig();
  }

  /// 设置配色方案
  Future<void> setColorScheme(String schemeId) async {
    state = state.copyWith(
      colorSchemeId: schemeId,
      useCustomColor: false,
    );
    await _saveThemeConfig();
  }

  /// 设置自定义颜色
  Future<void> setCustomColors({
    required Color primaryColor,
    required Color secondaryColor,
  }) async {
    state = state.copyWith(
      useCustomColor: true,
      customPrimaryColor: primaryColor,
      customSecondaryColor: secondaryColor,
    );
    await _saveThemeConfig();
  }

  /// 获取当前配色方案
  ThemeColorScheme getCurrentColorScheme(BuildContext context) {
    final isDark = isDarkMode(context);

    if (state.useCustomColor && state.customPrimaryColor != null) {
      // 使用自定义颜色
      return ThemeColorScheme(
        id: 'custom',
        name: '自定义',
        emoji: '🎨',
        primaryColor: state.customPrimaryColor!,
        secondaryColor: state.customSecondaryColor ?? state.customPrimaryColor!,
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F7FA),
        surfaceColor: isDark ? const Color(0xFF16213E) : const Color(0xFFFFFFFF),
      );
    }

    // 使用预设配色 - 先尝试获取对应模式的配色，如果不存在则使用另一模式的配色
    ThemeColorScheme? scheme = AppColorSchemes.getSchemeById(state.colorSchemeId, isDark: isDark);
    if (scheme == null) {
      // 如果在当前模式下找不到，尝试在另一模式下找
      scheme = AppColorSchemes.getSchemeById(state.colorSchemeId, isDark: !isDark);
    }
    return scheme ?? AppColorSchemes.getDefaultScheme(isDark: isDark);
  }

  /// 判断当前是否为深色模式（公开方法）
  bool isDarkMode(BuildContext context) {
    switch (state.themeMode) {
      case AppThemeMode.light:
        return false;
      case AppThemeMode.dark:
        return true;
      case AppThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  /// 获取ThemeMode
  ThemeMode getMaterialThemeMode() {
    switch (state.themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// 设置文字大小级别
  Future<void> setTextSizeLevel(TextSizeLevel level) async {
    state = state.copyWith(textSizeLevel: level);
    await _saveThemeConfig();
  }

  /// 强制 TV 模式使用浅色主题（持久化标记）
  /// 强制 TV 模式使用浅色主题（同步更新状态，后台持久化）
  Future<void> forceTVLightMode() async {
    // 同步更新状态，确保 UI 立即反映浅色主题
    state = state.copyWith(
      isTVMode: true,
      themeMode: AppThemeMode.light,
    );
    // 后台保存配置（不阻塞 UI）
    _saveThemeConfig();
  }
}

/// Provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeConfig>((ref) {
  return ThemeNotifier();
});

/// 便捷访问当前配色方案的Provider - 实时监听主题变化
final currentColorSchemeProvider = Provider.family<ThemeColorScheme, BuildContext>((ref, context) {
  // 监听主题配置的所有变化
  final themeConfig = ref.watch(themeProvider);
  final themeNotifier = ref.watch(themeProvider.notifier);
  
  // 根据当前主题模式判断是否为深色模式
  final isDark = themeNotifier.isDarkMode(context);
  
  if (themeConfig.useCustomColor && themeConfig.customPrimaryColor != null) {
    // 使用自定义颜色
    return ThemeColorScheme(
      id: 'custom',
      name: '自定义',
      emoji: '🎨',
      primaryColor: themeConfig.customPrimaryColor!,
      secondaryColor: themeConfig.customSecondaryColor ?? themeConfig.customPrimaryColor!,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : const Color(0xFFF5F7FA),
      surfaceColor: isDark ? const Color(0xFF16213E) : const Color(0xFFFFFFFF),
    );
  }

  // 使用预设配色 - 先尝试获取对应模式的配色，如果不存在则使用另一模式的配色
  ThemeColorScheme? scheme = AppColorSchemes.getSchemeById(themeConfig.colorSchemeId, isDark: isDark);
  if (scheme == null) {
    // 如果在当前模式下找不到，尝试在另一模式下找
    scheme = AppColorSchemes.getSchemeById(themeConfig.colorSchemeId, isDark: !isDark);
  }
  return scheme ?? AppColorSchemes.getDefaultScheme(isDark: isDark);
});
