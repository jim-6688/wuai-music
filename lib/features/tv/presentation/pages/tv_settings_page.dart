import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/theme/custom_color_schemes.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import '../../../playlist/services/qq_music_leaderboard_service.dart';
import '../../../nas/presentation/pages/tv_config_scanner_page.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import 'tv_netease_api_settings_page.dart';
import 'tv_equalizer_page.dart';

/// 设置项类型
enum _SettingType {
  toggle,
  action,
  navigate,
}

/// 设置项数据模型
class _SettingItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final _SettingType type;
  final String? route;

  _SettingItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.type,
    this.route,
  });
}

/// TV 设置页面 - 支持遥控器操作
/// 
/// 功能：
/// - 方向键导航设置项
/// - 确认键切换开关或进入子页面
/// - 返回键返回主页
class TVSettingsPage extends ConsumerStatefulWidget {
  const TVSettingsPage({super.key});

  @override
  ConsumerState<TVSettingsPage> createState() => _TVSettingsPageState();
}

class _TVSettingsPageState extends ConsumerState<TVSettingsPage> {
  int _focusIndex = 0;
  final FocusNode _rootFocusNode = FocusNode();
  bool _isSettingsInitialized = false;
  
  // 设置项列表
  late final List<_SettingItem> _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
      // 在 postFrameCallback 中初始化设置项，此时 context 可用
      _initSettings(isDark: Theme.of(context).brightness == Brightness.dark);
      setState(() {
        _isSettingsInitialized = true;
      }); // 触发重建以显示设置项
    });
  }

  void _initSettings({required bool isDark}) {
    final themeConfig = ref.read(themeProvider);
    // 查找当前配色名称（根据当前深色/浅色模式查找对应的配色）
    final schemes = isDark ? AppColorSchemes.darkSchemes : AppColorSchemes.lightSchemes;
    String schemeName = '默认';
    for (final s in schemes) {
      if (s.id == themeConfig.colorSchemeId) {
        schemeName = s.name;
        break;
      }
    }
    // 如果在当前模式找不到，尝试在另一模式找
    if (schemeName == '默认') {
      final otherSchemes = isDark ? AppColorSchemes.lightSchemes : AppColorSchemes.darkSchemes;
      for (final s in otherSchemes) {
        if (s.id == themeConfig.colorSchemeId) {
          schemeName = s.name;
          break;
        }
      }
    }
    _settings = [
      _SettingItem(
        icon: Icons.cloud_rounded,
        title: '网易云API',
        subtitle: '更换榜单API接口地址',
        type: _SettingType.navigate,
        route: 'neteaseApi',
      ),
      _SettingItem(
        icon: Icons.music_note_rounded,
        title: 'QQ音乐榜单',
        subtitle: ref.watch(qqMusicSyncEnabledProvider) ? '已开启' : '已关闭',
        type: _SettingType.toggle,
        route: 'qqMusicSync',
      ),
      _SettingItem(
        icon: Icons.qr_code_scanner_rounded,
        title: '同步手机配置',
        subtitle: '扫描手机端二维码导入 NAS 配置',
        type: _SettingType.navigate,
        route: 'syncPhoneConfig',
      ),
      _SettingItem(
        icon: Icons.equalizer_rounded,
        title: '均衡器',
        subtitle: '调整音频频段和音效',
        type: _SettingType.navigate,
        route: 'equalizer',
      ),
      _SettingItem(
        icon: Icons.dark_mode_rounded,
        title: '深色模式',
        subtitle: '切换应用主题',
        type: _SettingType.toggle,
      ),
      _SettingItem(
        icon: Icons.color_lens_rounded,
        title: '主题颜色',
        subtitle: '配色: $schemeName',
        type: _SettingType.action,
      ),
      _SettingItem(
        icon: Icons.text_fields_rounded,
        title: '文字大小',
        subtitle: '当前: ${themeConfig.textSizeLevelName}',
        type: _SettingType.action,
      ),
      _SettingItem(
        icon: Icons.storage_rounded,
        title: '缓存管理',
        subtitle: '清理歌词和封面缓存',
        type: _SettingType.action,
      ),
      _SettingItem(
        icon: Icons.info_rounded,
        title: '关于',
        subtitle: '版本信息和致谢',
        type: _SettingType.action,
      ),
    ];
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    // 上下导航
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex--);
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < _settings.length - 1) {
        setState(() => _focusIndex++);
      }
      return;
    }

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.of(context).pop();
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      _activateSetting(_focusIndex);
      return;
    }
  }

  void _activateSetting(int index) {
    final setting = _settings[index];
    
    // 导航类设置
    if (setting.type == _SettingType.navigate) {
      switch (setting.route) {
        case 'neteaseApi':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TvNeteaseApiSettingsPage()),
          );
          break;
        case 'equalizer':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TvEqualizerPage()),
          );
          break;
        case 'syncPhoneConfig':
          _showSyncConfigDialog();
          break;
      }
      return;
    }
    
      switch (setting.title) {
        case 'QQ音乐榜单':
          // 切换 QQ 音乐榜单同步
          ref.read(qqMusicSyncEnabledProvider.notifier).setEnabled(
            !ref.read(qqMusicSyncEnabledProvider),
          );
          setState(() {
            _initSettings(isDark: ref.read(themeProvider.notifier).isDarkMode(context));
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(qqMusicSyncEnabledProvider) ? 'QQ音乐榜单已开启' : 'QQ音乐榜单已关闭'),
              duration: const Duration(seconds: 1),
            ),
          );
          break;
        case '深色模式':
        // 切换主题模式
        ref.read(themeProvider.notifier).toggleThemeMode();
        // 刷新设置列表显示，确保 UI 重建
        setState(() {
          // 重新获取当前主题状态
          final isDark = ref.read(themeProvider.notifier).isDarkMode(context);
          _initSettings(isDark: isDark);
        });
        break;
      case '主题颜色':
        _showThemeColorDialog();
        break;
      case '文字大小':
        _showTextSizeDialog();
        break;
      case '缓存管理':
        _showClearCacheDialog();
        break;
      case '关于':
        _showAboutDialog();
        break;
    }
  }

  void _showSyncConfigDialog() {
    final scale = TvScreenAdapter.of(context).scale;
    
    showDialog(
      context: context,
      builder: (dialogContext) => _SyncConfigDialog(
        scale: scale,
        onClosed: () {
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理缓存'),
        content: const Text('确定要清理所有缓存数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 清理缓存
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('缓存已清理')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('关于吾爱Music'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本: 吾爱musicTV 1.0'),
            SizedBox(height: 8),
            Text('一个精致的液态玻璃风格音乐播放器'),
            SizedBox(height: 8),
            Text('支持本地音乐、NAS、在线音源'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showThemeColorDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scale = TvScreenAdapter.of(context).scale;
    
    showDialog(
      context: context,
      builder: (context) => _ThemeColorDialog(
        scale: scale,
        isDark: isDark,
        onSettingsChanged: () {
          // 刷新设置项显示
          setState(() {
            _initSettings(isDark: isDark);
          });
        },
      ),
    );
  }

  void _showTextSizeDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scale = TvScreenAdapter.of(context).scale;
    
    showDialog(
      context: context,
      builder: (context) => _TextSizeDialog(
        scale: scale,
        isDark: isDark,
        onSettingsChanged: () {
          // 刷新设置项显示
          setState(() {
            _initSettings(isDark: isDark);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scale = TvScreenAdapter.of(context).scale;
    final themeConfig = ref.watch(themeProvider);

    // 如果设置项尚未初始化，显示加载指示器
    if (!_isSettingsInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop();
        },
        child: Container(
          // 浅色模式：使用清晰明亮的固定浅色背景
          // 不依赖主题色，避免深色主题色导致看不清
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                      const Color(0xFF0F0F23),
                    ],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE8F4FD), // 浅蓝灰 - 顶部
                      const Color(0xFFF0F9FF), // 更浅蓝 - 中部
                      const Color(0xFFF8FAFC), // 接近白色 - 底部
                    ],
                  ),
          ),
          child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              Padding(
                padding: EdgeInsets.all(48 * scale),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(16 * scale),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                      child: Icon(
                        Icons.settings_rounded, 
                        size: 56 * scale,
                        // TV 模式强制使用深色
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(width: 24 * scale),
                    Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 56 * scale,
                        fontWeight: FontWeight.bold,
                        // TV 模式强制使用深色
                        color: Colors.black87,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),

              // 设置列表
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 48 * scale),
                  itemCount: _settings.length,
                  itemBuilder: (context, index) {
                    final setting = _settings[index];
                    final isFocused = index == _focusIndex;
                    
                    // 在 itemBuilder 顶部统一获取 primaryColor，避免嵌套 context 陷阱导致 TV 红屏
                    final itemPrimaryColor = Theme.of(context).primaryColor;
                    
                    return Padding(
                      padding: EdgeInsets.only(bottom: 24 * scale),
                      child: TVFocusCard(
                        width: double.infinity,
                        height: 120 * scale,
                        focusColor: Colors.blue,
                        autofocus: index == 0,
                        onTap: () => _activateSetting(index),
                        onFocus: () => setState(() => _focusIndex = index),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32 * scale),
                          child: Row(
                            children: [
                              Icon(
                                setting.icon,
                                size: 48 * scale,
                                // TV 模式强制使用深色文字，确保在浅色背景上可见
                                color: isFocused 
                                    ? itemPrimaryColor
                                    : Colors.black54,
                              ),
                              SizedBox(width: 24 * scale),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      setting.title,
                                      style: TextStyle(
                                        fontSize: 32 * scale,
                                        fontWeight: FontWeight.w600,
                                        // TV 模式强制使用深色文字
                                        color: isFocused
                                            ? itemPrimaryColor
                                            : Colors.black87,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    SizedBox(height: 4 * scale),
                                    Text(
                                      setting.subtitle,
                                      style: TextStyle(
                                        fontSize: 24 * scale,
                                        // TV 模式强制使用深色文字
                                        color: isFocused
                                            ? itemPrimaryColor.withValues(alpha: 0.8)
                                            : Colors.black54,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (setting.type == _SettingType.toggle)
                                Switch(
                                  value: ref.watch(themeProvider).themeMode == AppThemeMode.dark,
                                  activeColor: itemPrimaryColor,
                                  onChanged: (value) {
                                    ref.read(themeProvider.notifier).toggleThemeMode();
                                    // 强制重建 UI
                                    setState(() {});
                                  },
                                )
                              else
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 40 * scale,
                                  color: isFocused 
                                      ? itemPrimaryColor
                                      : (isDark ? Colors.white38 : Colors.black38),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 底部操作提示
              Padding(
                padding: EdgeInsets.all(48 * scale),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 40 * scale,
                    vertical: 24 * scale,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    color: isDark 
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlHint(
                        Icons.arrow_upward_rounded, 
                        '上下切换',
                        24 * scale,
                        isDark,
                      ),
                      SizedBox(width: 48 * scale),
                      _buildControlHint(
                        Icons.subdirectory_arrow_right_rounded, 
                        '确认',
                        24 * scale,
                        isDark,
                      ),
                      SizedBox(width: 48 * scale),
                      _buildControlHint(
                        Icons.arrow_back_rounded, 
                        '返回',
                        24 * scale,
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildControlHint(IconData icon, String label, double fontSize, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // TV 模式强制使用深色背景
            color: Colors.black.withValues(alpha: 0.05),
          ),
          child: Icon(
            icon,
            size: 28,
            // TV 模式强制使用深色图标
            color: Colors.black45,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize.clamp(16.0, 24.0),
            fontWeight: FontWeight.w500,
            // TV 模式强制使用深色文字
            color: Colors.black45,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

/// 主题颜色和文字大小设置对话框
class _ThemeColorTextSizeDialog extends ConsumerStatefulWidget {
  final double scale;
  final bool isDark;
  final VoidCallback onSettingsChanged;

  const _ThemeColorTextSizeDialog({
    required this.scale,
    required this.isDark,
    required this.onSettingsChanged,
  });

  @override
  ConsumerState<_ThemeColorTextSizeDialog> createState() => _ThemeColorTextSizeDialogState();
}

class _ThemeColorTextSizeDialogState extends ConsumerState<_ThemeColorTextSizeDialog> {
  int _colorFocusIndex = 0;
  int _textSizeFocusIndex = 0;
  int _buttonFocusIndex = 0; // 0=无, 1=确定, 2=取消
  bool _isColorSection = true;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    // 获取所有配色方案（浅色+深色，去重）
    final allSchemes = [
      ...AppColorSchemes.lightSchemes,
      ...AppColorSchemes.darkSchemes,
    ];
    final seenIds = <String>{};
    final uniqueSchemes = <ThemeColorScheme>[];
    for (final s in allSchemes) {
      if (seenIds.add(s.id)) uniqueSchemes.add(s);
    }
    final colorSchemes = uniqueSchemes;
    final textSizeLevels = TextSizeLevel.values;

    // 左右切换区域
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _isColorSection = !_isColorSection;
        _buttonFocusIndex = 0;
      });
      return;
    }

    // 上下导航
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_buttonFocusIndex > 0) {
        setState(() => _buttonFocusIndex = 0);
      } else if (_isColorSection) {
        if (_colorFocusIndex > 0) {
          setState(() => _colorFocusIndex--);
        }
      } else {
        if (_textSizeFocusIndex > 0) {
          setState(() => _textSizeFocusIndex--);
        }
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_isColorSection) {
        if (_colorFocusIndex < colorSchemes.length - 1) {
          setState(() => _colorFocusIndex++);
        } else {
          setState(() => _buttonFocusIndex = 1);
        }
      } else {
        if (_textSizeFocusIndex < textSizeLevels.length - 1) {
          setState(() => _textSizeFocusIndex++);
        } else {
          setState(() => _buttonFocusIndex = 1);
        }
      }
      return;
    }

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_buttonFocusIndex == 1) {
        // 确定
        _applySettings();
      } else if (_buttonFocusIndex == 2) {
        // 取消
        Navigator.pop(context);
      } else if (_isColorSection) {
        _selectColor(colorSchemes[_colorFocusIndex]);
      } else {
        _selectTextSize(textSizeLevels[_textSizeFocusIndex]);
      }
      return;
    }
  }

  void _selectColor(ThemeColorScheme scheme) {
    ref.read(themeProvider.notifier).setColorScheme(scheme.id);
  }

  void _selectTextSize(TextSizeLevel level) {
    ref.read(themeProvider.notifier).setTextSizeLevel(level);
  }

  void _applySettings() {
    // 获取所有配色方案（浅色+深色，去重）
    final allSchemes = [
      ...AppColorSchemes.lightSchemes,
      ...AppColorSchemes.darkSchemes,
    ];
    final seenIds = <String>{};
    final uniqueSchemes = <ThemeColorScheme>[];
    for (final s in allSchemes) {
      if (seenIds.add(s.id)) uniqueSchemes.add(s);
    }
    final textSizeLevels = TextSizeLevel.values;
    
    // 安全索引
    final colorIndex = _colorFocusIndex.clamp(0, uniqueSchemes.length - 1);
    final textIndex = _textSizeFocusIndex.clamp(0, textSizeLevels.length - 1);
    
    ref.read(themeProvider.notifier).setColorScheme(uniqueSchemes[colorIndex].id);
    ref.read(themeProvider.notifier).setTextSizeLevel(textSizeLevels[textIndex]);
    
    widget.onSettingsChanged();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final allSchemes = [
      ...AppColorSchemes.lightSchemes,
      ...AppColorSchemes.darkSchemes,
    ];
    // 去重（按 id）
    final seenIds = <String>{};
    final uniqueSchemes = <ThemeColorScheme>[];
    for (final s in allSchemes) {
      if (seenIds.add(s.id)) uniqueSchemes.add(s);
    }
    final colorSchemes = uniqueSchemes;
    final textSizeLevels = TextSizeLevel.values;
    final currentConfig = ref.watch(themeProvider);
    
    // 注意：不要在 build 中重置焦点位置，否则用户无法移动焦点
    
    // 在 build 顶部统一获取 primaryColor，避免嵌套 itemBuilder 中 context 陷阱导致 TV 红屏
    final primaryColor = Theme.of(context).primaryColor;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: Text(
          '主题颜色与文字大小',
          style: TextStyle(
            fontSize: 32 * widget.scale,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: SizedBox(
          width: 800 * widget.scale,
          height: 500 * widget.scale,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：主题颜色选择
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '主题颜色',
                      style: TextStyle(
                        fontSize: 24 * widget.scale,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    SizedBox(height: 16 * widget.scale),
                    Expanded(
                      child: ListView.builder(
                        itemCount: colorSchemes.length,
                        itemBuilder: (context, index) {
                          final scheme = colorSchemes[index];
                          final isFocused = _isColorSection && index == _colorFocusIndex;
                          final isSelected = scheme.id == currentConfig.colorSchemeId;
                          
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8 * widget.scale),
                            child: TVFocusCard(
                              focusColor: scheme.primaryColor,
                              borderRadius: 12 * widget.scale,
                              width: double.infinity,
                              height: 56 * widget.scale,
                              onTap: () => _selectColor(scheme),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16 * widget.scale,
                                  vertical: 12 * widget.scale,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12 * widget.scale),
                                  color: Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32 * widget.scale,
                                      height: 32 * widget.scale,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: scheme.gradient ?? LinearGradient(
                                          colors: [scheme.primaryColor, scheme.secondaryColor],
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 12 * widget.scale),
                                    Text(
                                      '${scheme.emoji} ${scheme.name}',
                                      style: TextStyle(
                                        fontSize: 22 * widget.scale,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const Spacer(),
                                      Icon(
                                        Icons.check_circle,
                                        color: scheme.primaryColor,
                                        size: 24 * widget.scale,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 32 * widget.scale),
              // 右侧：文字大小选择
              SizedBox(
                width: 200 * widget.scale,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '文字大小',
                      style: TextStyle(
                        fontSize: 24 * widget.scale,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    SizedBox(height: 16 * widget.scale),
                    ...textSizeLevels.asMap().entries.map((entry) {
                      final index = entry.key;
                      final level = entry.value;
                      final isFocused = !_isColorSection && index == _textSizeFocusIndex;
                      final isSelected = level == currentConfig.textSizeLevel;
                      
                      String levelName;
                      double previewSize;
                      switch (level) {
                        case TextSizeLevel.small:
                          levelName = '小';
                          previewSize = 18;
                          break;
                        case TextSizeLevel.normal:
                          levelName = '正常';
                          previewSize = 22;
                          break;
                        case TextSizeLevel.large:
                          levelName = '大';
                          previewSize = 26;
                          break;
                        case TextSizeLevel.extraLarge:
                          levelName = '特大';
                          previewSize = 30;
                          break;
                      }
                      
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12 * widget.scale),
                        child: TVFocusCard(
                          focusColor: primaryColor,
                          borderRadius: 12 * widget.scale,
                          width: double.infinity,
                          height: 56 * widget.scale,
                          onTap: () => _selectTextSize(level),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: 16 * widget.scale,
                              vertical: 14 * widget.scale,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12 * widget.scale),
                              color: Colors.transparent,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  levelName,
                                  style: TextStyle(
                                    fontSize: 22 * widget.scale,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                    color: widget.isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Aa',
                                  style: TextStyle(
                                    fontSize: previewSize * widget.scale,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected 
                                        ? primaryColor
                                        : (widget.isDark ? Colors.white54 : Colors.black45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: 24 * widget.scale,
                vertical: 12 * widget.scale,
              ),
              backgroundColor: _buttonFocusIndex == 2 
                  ? primaryColor.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 22 * widget.scale,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          TextButton(
            onPressed: _applySettings,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: 24 * widget.scale,
                vertical: 12 * widget.scale,
              ),
              backgroundColor: _buttonFocusIndex == 1 
                  ? primaryColor.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
            child: Text(
              '确定',
              style: TextStyle(
                fontSize: 22 * widget.scale,
                fontWeight: FontWeight.w600,
                color: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 主题颜色选择对话框
class _ThemeColorDialog extends ConsumerStatefulWidget {
  final double scale;
  final bool isDark;
  final VoidCallback onSettingsChanged;

  const _ThemeColorDialog({
    required this.scale,
    required this.isDark,
    required this.onSettingsChanged,
  });

  @override
  ConsumerState<_ThemeColorDialog> createState() => _ThemeColorDialogState();
}

class _ThemeColorDialogState extends ConsumerState<_ThemeColorDialog> {
  int _colorFocusIndex = 0;
  int _buttonFocusIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;
    final colorSchemes = _getUniqueSchemes();
    const crossAxisCount = 4; // GridView 列数

    // 网格导航 - 上下左右
    if (_buttonFocusIndex == 0) {
      // 在颜色网格中
      if (key == LogicalKeyboardKey.arrowUp) {
        if (_colorFocusIndex >= crossAxisCount) {
          setState(() => _colorFocusIndex -= crossAxisCount);
        }
        return;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        if (_colorFocusIndex + crossAxisCount < colorSchemes.length) {
          setState(() => _colorFocusIndex += crossAxisCount);
        } else if (_colorFocusIndex < colorSchemes.length - 1) {
          // 最后一行，移动到最后一个
          setState(() => _colorFocusIndex = colorSchemes.length - 1);
        } else {
          // 已经是最后一个，移动到关闭按钮
          setState(() => _buttonFocusIndex = 1);
        }
        return;
      }
      if (key == LogicalKeyboardKey.arrowLeft) {
        if (_colorFocusIndex % crossAxisCount > 0) {
          setState(() => _colorFocusIndex--);
        }
        return;
      }
      if (key == LogicalKeyboardKey.arrowRight) {
        if (_colorFocusIndex % crossAxisCount < crossAxisCount - 1 && 
            _colorFocusIndex < colorSchemes.length - 1) {
          setState(() => _colorFocusIndex++);
        }
        return;
      }
    }

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_buttonFocusIndex == 1) {
        Navigator.pop(context);
      } else {
        _selectColor(colorSchemes[_colorFocusIndex]);
      }
      return;
    }
  }

  List<ThemeColorScheme> _getUniqueSchemes() {
    final allSchemes = [
      ...AppColorSchemes.lightSchemes,
      ...AppColorSchemes.darkSchemes,
    ];
    final seenIds = <String>{};
    final uniqueSchemes = <ThemeColorScheme>[];
    for (final s in allSchemes) {
      if (seenIds.add(s.id)) uniqueSchemes.add(s);
    }
    return uniqueSchemes;
  }

  void _selectColor(ThemeColorScheme scheme) {
    ref.read(themeProvider.notifier).setColorScheme(scheme.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorSchemes = _getUniqueSchemes();
    final currentConfig = ref.watch(themeProvider);
    
    // 注意：不要在 build 中重置焦点位置，否则用户无法移动焦点
    
    // 在 GridView.itemBuilder 外部获取 primaryColor，避免 context 陷阱导致 TV 红屏
    final dialogPrimaryColor = Theme.of(context).primaryColor;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: Text(
          '选择主题颜色',
          style: TextStyle(
            fontSize: 32 * widget.scale,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: SizedBox(
          width: 600 * widget.scale,
          height: 400 * widget.scale,
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12 * widget.scale,
              mainAxisSpacing: 12 * widget.scale,
              childAspectRatio: 1.2,
            ),
            itemCount: colorSchemes.length,
            itemBuilder: (context, index) {
              final scheme = colorSchemes[index];
              final isFocused = index == _colorFocusIndex;
              final isSelected = scheme.id == currentConfig.colorSchemeId;
              
              return InkWell(
                onTap: () => _selectColor(scheme),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12 * widget.scale),
                    border: Border.all(
                      color: isFocused 
                          ? dialogPrimaryColor
                          : (isSelected ? scheme.primaryColor : Colors.transparent),
                      width: isFocused ? 3 : 2,
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primaryColor, scheme.secondaryColor],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        scheme.emoji,
                        style: TextStyle(fontSize: 24 * widget.scale),
                      ),
                      SizedBox(height: 4 * widget.scale),
                      Text(
                        scheme.name,
                        style: TextStyle(
                          fontSize: 14 * widget.scale,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 20 * widget.scale,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '关闭',
              style: TextStyle(
                fontSize: 22 * widget.scale,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 文字大小选择对话框
class _TextSizeDialog extends ConsumerStatefulWidget {
  final double scale;
  final bool isDark;
  final VoidCallback onSettingsChanged;

  const _TextSizeDialog({
    required this.scale,
    required this.isDark,
    required this.onSettingsChanged,
  });

  @override
  ConsumerState<_TextSizeDialog> createState() => _TextSizeDialogState();
}

class _TextSizeDialogState extends ConsumerState<_TextSizeDialog> {
  int _textSizeFocusIndex = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;
    final textSizeLevels = TextSizeLevel.values;

    // 上下导航
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_textSizeFocusIndex > 0) {
        setState(() => _textSizeFocusIndex--);
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_textSizeFocusIndex < textSizeLevels.length - 1) {
        setState(() => _textSizeFocusIndex++);
      }
      return;
    }

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack) {
      Navigator.pop(context);
      return;
    }

    // 确认键 - 直接应用并关闭
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select) {
      ref.read(themeProvider.notifier).setTextSizeLevel(textSizeLevels[_textSizeFocusIndex]);
      widget.onSettingsChanged();
      Navigator.pop(context);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textSizeLevels = TextSizeLevel.values;
    final currentConfig = ref.watch(themeProvider);
    
    // 注意：不要在 build 中重置焦点位置，否则用户无法移动焦点
    
    // 在 build 顶部统一获取 primaryColor，避免嵌套闭包中 context 陷阱导致 TV 红屏
    final primaryColor = Theme.of(context).primaryColor;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1A1A2E) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.text_fields_rounded,
              size: 32 * widget.scale,
              color: primaryColor,
            ),
            SizedBox(width: 12 * widget.scale),
            Text(
              '选择文字大小',
              style: TextStyle(
                fontSize: 32 * widget.scale,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400 * widget.scale,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: textSizeLevels.asMap().entries.map((entry) {
              final index = entry.key;
              final level = entry.value;
              final isFocused = index == _textSizeFocusIndex;
              final isSelected = level == currentConfig.textSizeLevel;
              
              String levelName;
              double previewSize;
              switch (level) {
                case TextSizeLevel.small:
                  levelName = '小';
                  previewSize = 18;
                  break;
                case TextSizeLevel.normal:
                  levelName = '正常';
                  previewSize = 22;
                  break;
                case TextSizeLevel.large:
                  levelName = '大';
                  previewSize = 26;
                  break;
                case TextSizeLevel.extraLarge:
                  levelName = '特大';
                  previewSize = 30;
                  break;
              }
              
              return Padding(
                padding: EdgeInsets.only(bottom: 16 * widget.scale),
                child: InkWell(
                  onTap: () {
                    ref.read(themeProvider.notifier).setTextSizeLevel(level);
                    widget.onSettingsChanged();
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24 * widget.scale,
                      vertical: 20 * widget.scale,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16 * widget.scale),
                      border: Border.all(
                        color: isFocused || isSelected
                            ? primaryColor
                            : Colors.transparent,
                        width: isFocused ? 3 : 2,
                      ),
                      color: isFocused 
                          ? primaryColor.withValues(alpha: 0.15)
                          : (isSelected 
                              ? primaryColor.withValues(alpha: 0.1)
                              : (widget.isDark 
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSelected ? Icons.check_circle : Icons.circle_outlined,
                              color: isFocused || isSelected
                                  ? primaryColor
                                  : (widget.isDark ? Colors.white54 : Colors.black38),
                              size: 28 * widget.scale,
                            ),
                            SizedBox(width: 16 * widget.scale),
                            Text(
                              levelName,
                              style: TextStyle(
                                fontSize: 26 * widget.scale,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: widget.isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Aa',
                          style: TextStyle(
                            fontSize: previewSize * widget.scale,
                            fontWeight: FontWeight.bold,
                            color: isFocused || isSelected 
                                ? primaryColor
                                : (widget.isDark ? Colors.white54 : Colors.black45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 22 * widget.scale,
                color: widget.isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 扫码同步配置弹窗
class _SyncConfigDialog extends ConsumerStatefulWidget {
  final double scale;
  final VoidCallback onClosed;

  const _SyncConfigDialog({
    required this.scale,
    required this.onClosed,
  });

  @override
  ConsumerState<_SyncConfigDialog> createState() => _SyncConfigDialogState();
}

class _SyncConfigDialogState extends ConsumerState<_SyncConfigDialog> {
  final FocusNode _focusNode = FocusNode();
  int _focusIndex = 0; // 0=关闭, 1=手动输入

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      widget.onClosed();
      return;
    }

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      setState(() {
        _focusIndex = _focusIndex == 0 ? 1 : 0;
      });
      return;
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (_focusIndex == 0) {
        widget.onClosed();
      } else {
        _showManualInputDialog();
      }
    }
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动输入配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('粘贴从手机端分享的配置 JSON：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '粘贴配置 JSON...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context, controller.text);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Dialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24 * scale),
        ),
        child: Container(
          width: 480 * scale,
          padding: EdgeInsets.all(32 * scale),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 二维码图标
              Container(
                width: 120 * scale,
                height: 120 * scale,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20 * scale),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.qr_code_rounded,
                  size: 64 * scale,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              SizedBox(height: 24 * scale),
              Text(
                '同步手机配置',
                style: TextStyle(
                  fontSize: 32 * scale,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 12 * scale),
              Text(
                '打开手机端吾爱Music → 设置 → 分享配置\n将手机屏幕对准 TV 摄像头扫描二维码',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20 * scale,
                  color: Colors.white54,
                  height: 1.6,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: 32 * scale),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildButton('关闭', Icons.close_rounded, 0),
                  SizedBox(width: 24 * scale),
                  _buildButton('手动输入', Icons.edit_rounded, 1),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String label, IconData icon, int index) {
    final scale = widget.scale;
    final isFocused = _focusIndex == index;

    return GestureDetector(
      onTap: () {
        if (index == 0) {
          widget.onClosed();
        } else {
          _showManualInputDialog();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: 28 * scale,
          vertical: 16 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16 * scale),
          color: isFocused
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isFocused
                ? Colors.blue
                : Colors.white.withValues(alpha: 0.15),
            width: isFocused ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24 * scale,
              color: isFocused ? Colors.blue : Colors.white54,
            ),
            SizedBox(width: 12 * scale),
            Text(
              label,
              style: TextStyle(
                fontSize: 22 * scale,
                fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                color: isFocused ? Colors.blue : Colors.white70,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

