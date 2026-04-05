import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 歌词配色方案
class LyricsColorScheme {
  final String name;
  final Color primaryColor;      // 主色
  final Color secondaryColor;   // 副色
  final Color backgroundColor; // 背景色
  final Color textColor;       // 文字色
  final Color highlightColor;  // 高亮色
  final Gradient? gradient;     // 渐变

  const LyricsColorScheme({
    required this.name,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    required this.textColor,
    required this.highlightColor,
    this.gradient,
  });
}

/// 预设的歌词配色方案
class LyricsColorSchemes {
  static const List<LyricsColorScheme> schemes = [
    // 默认蓝色
    LyricsColorScheme(
      name: '💙 海洋蓝',
      primaryColor: Color(0xFF2196F3),
      secondaryColor: Color(0xFF64B5F6),
      backgroundColor: Color(0xFF0D47A1),
      textColor: Colors.white,
      highlightColor: Color(0xFFBBDEFB),
    ),
    // 紫色
    LyricsColorScheme(
      name: '💜 浪漫紫',
      primaryColor: Color(0xFF9C27B0),
      secondaryColor: Color(0xFFCE93D8),
      backgroundColor: Color(0xFF4A148C),
      textColor: Colors.white,
      highlightColor: Color(0xFFF3E5F5),
    ),
    // 青色
    LyricsColorScheme(
      name: '💚 清新青',
      primaryColor: Color(0xFF00BCD4),
      secondaryColor: Color(0xFF80DEEA),
      backgroundColor: Color(0xFF006064),
      textColor: Colors.white,
      highlightColor: Color(0xFFE0F7FA),
    ),
    // 橙色
    LyricsColorScheme(
      name: '🧡 活力橙',
      primaryColor: Color(0xFFFF9800),
      secondaryColor: Color(0xFFFFCC80),
      backgroundColor: Color(0xFFE65100),
      textColor: Colors.white,
      highlightColor: Color(0xFFFFF3E0),
    ),
    // 粉色
    LyricsColorScheme(
      name: '💗 少女粉',
      primaryColor: Color(0xFFE91E63),
      secondaryColor: Color(0xFFF48FB1),
      backgroundColor: Color(0xFF880E4F),
      textColor: Colors.white,
      highlightColor: Color(0xFFFCE4EC),
    ),
    // 绿色
    LyricsColorScheme(
      name: '💚 自然绿',
      primaryColor: Color(0xFF4CAF50),
      secondaryColor: Color(0xFF81C784),
      backgroundColor: Color(0xFF1B5E20),
      textColor: Colors.white,
      highlightColor: Color(0xFFE8F5E9),
    ),
    // 红色
    LyricsColorScheme(
      name: '❤️ 热情红',
      primaryColor: Color(0xFFF44336),
      secondaryColor: Color(0xFFEF9A9A),
      backgroundColor: Color(0xFFB71C1C),
      textColor: Colors.white,
      highlightColor: Color(0xFFFFEBEE),
    ),
    // 金色
    LyricsColorScheme(
      name: '✨ 金色典',
      primaryColor: Color(0xFFFFD700),
      secondaryColor: Color(0xFFFFE082),
      backgroundColor: Color(0xFF5D4037),
      textColor: Colors.white,
      highlightColor: Color(0xFFFFF8E1),
    ),
    // 彩虹渐变
    LyricsColorScheme(
      name: '🌈 彩虹',
      primaryColor: Color(0xFFFF0000),
      secondaryColor: Color(0xFF00FF00),
      backgroundColor: Color(0xFF1A1A2E),
      textColor: Colors.white,
      highlightColor: Colors.white,
      gradient: const LinearGradient(
        colors: [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple],
      ),
    ),
    // 极光
    LyricsColorScheme(
      name: '🌌 极光',
      primaryColor: Color(0xFF00FF88),
      secondaryColor: Color(0xFF00BFFF),
      backgroundColor: Color(0xFF0A0A1A),
      textColor: Colors.white,
      highlightColor: Color(0xFFE0FFFF),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00FF88), Color(0xFF00BFFF), Color(0xFF8A2BE2)],
      ),
    ),
  ];
}

/// 歌词配色Provider
class LyricsColorSchemeNotifier extends StateNotifier<int> {
  LyricsColorSchemeNotifier() : super(0);

  void setScheme(int index) {
    if (index >= 0 && index < LyricsColorSchemes.schemes.length) {
      state = index;
    }
  }

  void nextScheme() {
    state = (state + 1) % LyricsColorSchemes.schemes.length;
  }

  LyricsColorScheme get currentScheme => LyricsColorSchemes.schemes[state];
}

final lyricsColorSchemeProvider =
    StateNotifierProvider<LyricsColorSchemeNotifier, int>((ref) {
  return LyricsColorSchemeNotifier();
});
