import 'package:flutter/material.dart';

/// 主题配色方案
class ThemeColorScheme {
  final String id;
  final String name;
  final String emoji;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final Color surfaceColor;
  final Gradient? gradient;

  const ThemeColorScheme({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.surfaceColor,
    this.gradient,
  });
}

/// 预设主题配色方案集合
class AppColorSchemes {
  static const List<ThemeColorScheme> lightSchemes = [
    // ========== 经典系列 ==========
    ThemeColorScheme(
      id: 'apple_blue',
      name: '苹果蓝',
      emoji: '💙',
      primaryColor: Color(0xFF007AFF),
      secondaryColor: Color(0xFF5856D6),
      backgroundColor: Color(0xFFF5F7FA),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'ocean_blue',
      name: '海洋蓝',
      emoji: '🌊',
      primaryColor: Color(0xFF2196F3),
      secondaryColor: Color(0xFF03A9F4),
      backgroundColor: Color(0xFFE3F2FD),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'sky_blue',
      name: '天空蓝',
      emoji: '☁️',
      primaryColor: Color(0xFF00BCD4),
      secondaryColor: Color(0xFF00ACC1),
      backgroundColor: Color(0xFFE0F7FA),
      surfaceColor: Color(0xFFFFFFFF),
    ),

    // ========== 温暖系列 ==========
    ThemeColorScheme(
      id: 'sunset_orange',
      name: '日落橙',
      emoji: '🌅',
      primaryColor: Color(0xFFFF9800),
      secondaryColor: Color(0xFFFF5722),
      backgroundColor: Color(0xFFFFF3E0),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'coral_pink',
      name: '珊瑚粉',
      emoji: '🌸',
      primaryColor: Color(0xFFFF6B6B),
      secondaryColor: Color(0xFFEE5A6F),
      backgroundColor: Color(0xFFFFEBEE),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'peach',
      name: '蜜桃粉',
      emoji: '🍑',
      primaryColor: Color(0xFFFFAB91),
      secondaryColor: Color(0xFFFF8A65),
      backgroundColor: Color(0xFFFBE9E7),
      surfaceColor: Color(0xFFFFFFFF),
    ),

    // ========== 自然系列 ==========
    ThemeColorScheme(
      id: 'forest_green',
      name: '森林绿',
      emoji: '🌲',
      primaryColor: Color(0xFF4CAF50),
      secondaryColor: Color(0xFF388E3C),
      backgroundColor: Color(0xFFE8F5E9),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'mint_green',
      name: '薄荷绿',
      emoji: '🍃',
      primaryColor: Color(0xFF26A69A),
      secondaryColor: Color(0xFF00897B),
      backgroundColor: Color(0xFFE0F2F1),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'olive',
      name: '橄榄绿',
      emoji: '🌿',
      primaryColor: Color(0xFF8BC34A),
      secondaryColor: Color(0xFF689F38),
      backgroundColor: Color(0xFFF1F8E9),
      surfaceColor: Color(0xFFFFFFFF),
    ),

    // ========== 浪漫系列 ==========
    ThemeColorScheme(
      id: 'rose_pink',
      name: '玫瑰粉',
      emoji: '🌹',
      primaryColor: Color(0xFFE91E63),
      secondaryColor: Color(0xFFEC407A),
      backgroundColor: Color(0xFFFCE4EC),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'lavender',
      name: '薰衣草',
      emoji: '💜',
      primaryColor: Color(0xFF9C27B0),
      secondaryColor: Color(0xFFAB47BC),
      backgroundColor: Color(0xFFF3E5F5),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'orchid',
      name: '兰花紫',
      emoji: '🪻',
      primaryColor: Color(0xFFBA68C8),
      secondaryColor: Color(0xFF9C27B0),
      backgroundColor: Color(0xFFF3E5F5),
      surfaceColor: Color(0xFFFFFFFF),
    ),

    // ========== 活力系列 ==========
    ThemeColorScheme(
      id: 'cherry_red',
      name: '樱桃红',
      emoji: '🍒',
      primaryColor: Color(0xFFF44336),
      secondaryColor: Color(0xFFE53935),
      backgroundColor: Color(0xFFFFEBEE),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'lemon_yellow',
      name: '柠檬黄',
      emoji: '🍋',
      primaryColor: Color(0xFFFFEB3B),
      secondaryColor: Color(0xFFFDD835),
      backgroundColor: Color(0xFFFFFDE7),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'amber',
      name: '琥珀橙',
      emoji: '🧡',
      primaryColor: Color(0xFFFFC107),
      secondaryColor: Color(0xFFFFB300),
      backgroundColor: Color(0xFFFFF8E1),
      surfaceColor: Color(0xFFFFFFFF),
    ),

    // ========== 高级系列 ==========
    ThemeColorScheme(
      id: 'gold',
      name: '金色典',
      emoji: '✨',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFFFFA000),
      backgroundColor: Color(0xFFFFF8E1),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'silver',
      name: '银色',
      emoji: '🪙',
      primaryColor: Color(0xFF9E9E9E),
      secondaryColor: Color(0xFF757575),
      backgroundColor: Color(0xFFFAFAFA),
      surfaceColor: Color(0xFFFFFFFF),
    ),
    ThemeColorScheme(
      id: 'bronze',
      name: '青铜',
      emoji: '🏺',
      primaryColor: Color(0xFF8D6E63),
      secondaryColor: Color(0xFF6D4C41),
      backgroundColor: Color(0xFFEFEBE9),
      surfaceColor: Color(0xFFFFFFFF),
    ),

    // ========== 渐变系列 ==========
    ThemeColorScheme(
      id: 'sunset_gradient',
      name: '日落渐变',
      emoji: '🌅',
      primaryColor: Color(0xFFFF6B6B),
      secondaryColor: Color(0xFFFFE66D),
      backgroundColor: Color(0xFFFFF5F5),
      surfaceColor: Color(0xFFFFFFFF),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
      ),
    ),
    ThemeColorScheme(
      id: 'ocean_gradient',
      name: '海洋渐变',
      emoji: '🌊',
      primaryColor: Color(0xFF00BCD4),
      secondaryColor: Color(0xFF2196F3),
      backgroundColor: Color(0xFFE0F7FA),
      surfaceColor: Color(0xFFFFFFFF),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00BCD4), Color(0xFF2196F3)],
      ),
    ),
    ThemeColorScheme(
      id: 'aurora_gradient',
      name: '极光渐变',
      emoji: '🌌',
      primaryColor: Color(0xFF00FF88),
      secondaryColor: Color(0xFF00BFFF),
      backgroundColor: Color(0xFFE0FFFF),
      surfaceColor: Color(0xFFFFFFFF),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00FF88), Color(0xFF00BFFF), Color(0xFF8A2BE2)],
      ),
    ),
    ThemeColorScheme(
      id: 'rainbow_gradient',
      name: '彩虹渐变',
      emoji: '🌈',
      primaryColor: Color(0xFFFF6B6B),
      secondaryColor: Color(0xFF4ECDC4),
      backgroundColor: Color(0xFFFFF5F5),
      surfaceColor: Color(0xFFFFFFFF),
      gradient: LinearGradient(
        colors: [
          Colors.red,
          Colors.orange,
          Colors.yellow,
          Colors.green,
          Colors.blue,
          Colors.purple,
        ],
      ),
    ),
  ];

  static const List<ThemeColorScheme> darkSchemes = [
    // ========== 深色系列 ==========
    ThemeColorScheme(
      id: 'dark_purple',
      name: '暗夜紫',
      emoji: '🌙',
      primaryColor: Color(0xFF9C27B0),
      secondaryColor: Color(0xFF7B1FA2),
      backgroundColor: Color(0xFF1A1A2E),
      surfaceColor: Color(0xFF16213E),
    ),
    ThemeColorScheme(
      id: 'dark_blue',
      name: '深空蓝',
      emoji: '🌌',
      primaryColor: Color(0xFF2196F3),
      secondaryColor: Color(0xFF1976D2),
      backgroundColor: Color(0xFF0A0E21),
      surfaceColor: Color(0xFF1A1F3D),
    ),
    ThemeColorScheme(
      id: 'dark_teal',
      name: '深青色',
      emoji: '🌊',
      primaryColor: Color(0xFF00BCD4),
      secondaryColor: Color(0xFF0097A7),
      backgroundColor: Color(0xFF001F24),
      surfaceColor: Color(0xFF00252B),
    ),

    // ========== 霓虹系列 ==========
    ThemeColorScheme(
      id: 'neon_pink',
      name: '霓虹粉',
      emoji: '💗',
      primaryColor: Color(0xFFFF1493),
      secondaryColor: Color(0xFFFF69B4),
      backgroundColor: Color(0xFF0A0A1A),
      surfaceColor: Color(0xFF1A1A2E),
    ),
    ThemeColorScheme(
      id: 'neon_green',
      name: '霓虹绿',
      emoji: '💚',
      primaryColor: Color(0xFF39FF14),
      secondaryColor: Color(0xFF00FF7F),
      backgroundColor: Color(0xFF0A0A0A),
      surfaceColor: Color(0xFF1A1A1A),
    ),
    ThemeColorScheme(
      id: 'neon_cyan',
      name: '霓虹青',
      emoji: '💙',
      primaryColor: Color(0xFF00FFFF),
      secondaryColor: Color(0xFF00CED1),
      backgroundColor: Color(0xFF001A1A),
      surfaceColor: Color(0xFF002626),
    ),

    // ========== AMOLED 黑色系列 ==========
    ThemeColorScheme(
      id: 'amoled_black',
      name: 'AMOLED黑',
      emoji: '⬛',
      primaryColor: Color(0xFF2196F3),
      secondaryColor: Color(0xFF1976D2),
      backgroundColor: Color(0xFF000000),
      surfaceColor: Color(0xFF0A0A0A),
    ),
    ThemeColorScheme(
      id: 'amoled_purple',
      name: 'AMOLED紫',
      emoji: '💜',
      primaryColor: Color(0xFF9C27B0),
      secondaryColor: Color(0xFF7B1FA2),
      backgroundColor: Color(0xFF000000),
      surfaceColor: Color(0xFF0A0A0A),
    ),
    ThemeColorScheme(
      id: 'amoled_green',
      name: 'AMOLED绿',
      emoji: '💚',
      primaryColor: Color(0xFF4CAF50),
      secondaryColor: Color(0xFF388E3C),
      backgroundColor: Color(0xFF000000),
      surfaceColor: Color(0xFF0A0A0A),
    ),

    // ========== 渐变深色系列 ==========
    ThemeColorScheme(
      id: 'midnight_gradient',
      name: '午夜渐变',
      emoji: '🌃',
      primaryColor: Color(0xFF6A5ACD),
      secondaryColor: Color(0xFF483D8B),
      backgroundColor: Color(0xFF0A0A1A),
      surfaceColor: Color(0xFF1A1A2E),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6A5ACD), Color(0xFF483D8B)],
      ),
    ),
    ThemeColorScheme(
      id: 'cosmic_gradient',
      name: '宇宙渐变',
      emoji: '🌌',
      primaryColor: Color(0xFF8A2BE2),
      secondaryColor: Color(0xFF4B0082),
      backgroundColor: Color(0xFF0A0A1A),
      surfaceColor: Color(0xFF1A1A2E),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8A2BE2), Color(0xFF4B0082), Color(0xFF000000)],
      ),
    ),
    ThemeColorScheme(
      id: 'cyberpunk_gradient',
      name: '赛博朋克',
      emoji: '🤖',
      primaryColor: Color(0xFFFF00FF),
      secondaryColor: Color(0xFF00FFFF),
      backgroundColor: Color(0xFF0A0A1A),
      surfaceColor: Color(0xFF1A1A2E),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFF00FF), Color(0xFF00FFFF)],
      ),
    ),
  ];

  /// 根据ID获取配色方案
  static ThemeColorScheme? getSchemeById(String id, {bool isDark = false}) {
    final schemes = isDark ? darkSchemes : lightSchemes;
    for (final scheme in schemes) {
      if (scheme.id == id) {
        return scheme;
      }
    }
    return null;
  }

  /// 获取默认配色方案
  static ThemeColorScheme getDefaultScheme({bool isDark = false}) {
    return isDark ? darkSchemes.first : lightSchemes.first;
  }
}
