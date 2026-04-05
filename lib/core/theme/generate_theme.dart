import 'package:flutter/material.dart';
import 'custom_color_schemes.dart';

/// 动态主题生成器
class DynamicThemeGenerator {
  /// 生成浅色主题
  static ThemeData generateLightTheme(ThemeColorScheme colorScheme) {
    const isDark = false;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: colorScheme.primaryColor,
      scaffoldBackgroundColor: colorScheme.backgroundColor,
      focusColor: Colors.transparent, // 移除焦点黄色下划线
      highlightColor: Colors.transparent, // 移除高亮效果
      splashColor: Colors.transparent, // 移除水波纹
      hoverColor: Colors.transparent, // 移除悬停效果
      canvasColor: Colors.transparent, // TV遥控器焦点下划线
      colorScheme: ColorScheme.light(
        primary: colorScheme.primaryColor,
        secondary: colorScheme.secondaryColor,
        surface: colorScheme.surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.primaryColor),
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceColor.withValues(alpha: 0.9),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primaryColor,
        ),
      ),
      // 全局文本主题 - 禁用装饰（TV焦点下划线）
      textTheme: TextTheme(
        bodyLarge: TextStyle(decoration: TextDecoration.none),
        bodyMedium: TextStyle(decoration: TextDecoration.none),
        bodySmall: TextStyle(decoration: TextDecoration.none),
        displayLarge: TextStyle(decoration: TextDecoration.none),
        displayMedium: TextStyle(decoration: TextDecoration.none),
        displaySmall: TextStyle(decoration: TextDecoration.none),
        headlineLarge: TextStyle(decoration: TextDecoration.none),
        headlineMedium: TextStyle(decoration: TextDecoration.none),
        headlineSmall: TextStyle(decoration: TextDecoration.none),
        labelLarge: TextStyle(decoration: TextDecoration.none),
        labelMedium: TextStyle(decoration: TextDecoration.none),
        labelSmall: TextStyle(decoration: TextDecoration.none),
        titleLarge: TextStyle(decoration: TextDecoration.none),
        titleMedium: TextStyle(decoration: TextDecoration.none),
        titleSmall: TextStyle(decoration: TextDecoration.none),
      ),
      iconTheme: IconThemeData(
        color: colorScheme.primaryColor,
        size: 24,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primaryColor,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: colorScheme.primaryColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryColor.withValues(alpha: 0.2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primaryColor,
        thumbColor: colorScheme.primaryColor,
        inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryColor.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// 生成深色主题
  static ThemeData generateDarkTheme(ThemeColorScheme colorScheme) {
    const isDark = true;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: colorScheme.primaryColor,
      scaffoldBackgroundColor: colorScheme.backgroundColor,
      focusColor: Colors.transparent, // 移除焦点黄色下划线
      highlightColor: Colors.transparent, // 移除高亮效果
      splashColor: Colors.transparent, // 移除水波纹
      hoverColor: Colors.transparent, // 移除悬停效果
      canvasColor: Colors.transparent, // TV遥控器焦点下划线
      colorScheme: ColorScheme.dark(
        primary: colorScheme.primaryColor,
        secondary: colorScheme.secondaryColor,
        surface: colorScheme.surfaceColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.backgroundColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceColor.withValues(alpha: 0.7),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primaryColor,
        ),
      ),
      // 全局文本主题 - 禁用装饰（TV焦点下划线）
      textTheme: TextTheme(
        bodyLarge: TextStyle(decoration: TextDecoration.none, color: Colors.white),
        bodyMedium: TextStyle(decoration: TextDecoration.none, color: Colors.white70),
        bodySmall: TextStyle(decoration: TextDecoration.none, color: Colors.white60),
        displayLarge: TextStyle(decoration: TextDecoration.none),
        displayMedium: TextStyle(decoration: TextDecoration.none),
        displaySmall: TextStyle(decoration: TextDecoration.none),
        headlineLarge: TextStyle(decoration: TextDecoration.none),
        headlineMedium: TextStyle(decoration: TextDecoration.none),
        headlineSmall: TextStyle(decoration: TextDecoration.none),
        labelLarge: TextStyle(decoration: TextDecoration.none),
        labelMedium: TextStyle(decoration: TextDecoration.none),
        labelSmall: TextStyle(decoration: TextDecoration.none),
        titleLarge: TextStyle(decoration: TextDecoration.none),
        titleMedium: TextStyle(decoration: TextDecoration.none),
        titleSmall: TextStyle(decoration: TextDecoration.none),
      ),
      iconTheme: IconThemeData(
        color: colorScheme.primaryColor,
        size: 24,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primaryColor,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: colorScheme.primaryColor,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: colorScheme.primaryColor,
        unselectedItemColor: Colors.grey,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryColor.withValues(alpha: 0.3),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primaryColor,
        thumbColor: colorScheme.primaryColor,
        inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryColor;
          }
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primaryColor.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceColor,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primaryColor, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
