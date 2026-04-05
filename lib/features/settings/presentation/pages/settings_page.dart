import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../core/theme/theme_switch_animation.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import '../../../playlist/services/qq_music_leaderboard_service.dart';
import '../../../extension_manager/presentation/pages/extension_manager_page.dart';
import 'theme_picker_page.dart';
import 'netease_api_settings_page.dart';
import 'equalizer_page.dart';

// ─── Providers ───────────────────────────────────────────────────────────────

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>((ref) {
  return DarkModeNotifier();
});

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _loadDarkMode();
  }

  Future<void> _loadDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('dark_mode') ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', state);
  }
}

final themeModeProvider = Provider<ThemeMode>((ref) {
  final isDark = ref.watch(darkModeProvider);
  return isDark ? ThemeMode.dark : ThemeMode.light;
});

// ─── SettingsPage ─────────────────────────────────────────────────────────────

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  void _triggerThemeSwitch(BuildContext context, bool isDarkMode) {
    final size = MediaQuery.of(context).size;
    ThemeSwitchController().trigger(
      offset: Offset(size.width / 2, size.height * 0.2),
      toDark: !isDarkMode,
      onSwitch: () => ref.read(darkModeProvider.notifier).toggle(),
    );
  }

  void _triggerThemeSwitchAt(bool isDarkMode, Offset offset) {
    ThemeSwitchController().trigger(
      offset: offset,
      toDark: !isDarkMode,
      onSwitch: () => ref.read(darkModeProvider.notifier).toggle(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(themeProvider);
    final isDarkMode = themeConfig.themeMode == AppThemeMode.dark;

    return LiquidBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 顶部标题
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '设置',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 外观设置
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '外观',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    
                    // 主题模式选择
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '主题模式',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildThemeModeButton(
                                AppThemeMode.light,
                                '浅色',
                                Icons.light_mode_rounded,
                                Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              _buildThemeModeButton(
                                AppThemeMode.dark,
                                '深色',
                                Icons.dark_mode_rounded,
                                Colors.indigo,
                              ),
                              const SizedBox(width: 12),
                              _buildThemeModeButton(
                                AppThemeMode.system,
                                '跟随系统',
                                Icons.settings_suggest_rounded,
                                Colors.teal,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 主题配色
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '主题配色',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ThemePickerPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.palette_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('主题配色选择'),
                                SizedBox(height: 2),
                                Text(
                                  '20+ 预设配色 + 自定义颜色',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 播放设置
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '播放',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    // 均衡器
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EqualizerPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.equalizer_rounded,
                              color: Colors.teal.shade400,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('均衡器'),
                                const SizedBox(height: 2),
                                Text(
                                  '调整音频频段，选择预设音效',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('自动扫描音乐已开启')),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('自动扫描音乐'),
                          Switch(value: true, onChanged: (v) {}),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('显示歌词已开启')),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('显示歌词'),
                          Switch(value: true, onChanged: (v) {}),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 在线音源
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '在线音源',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    // 网易云API
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NeteaseApiSettingsPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.cloud_rounded,
                              color: Colors.red,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('网易云API'),
                                SizedBox(height: 2),
                                Text(
                                  '配置网易云音乐API接口',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // QQ音乐榜单同步
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.music_note_rounded,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('QQ音乐榜单'),
                                const SizedBox(height: 2),
                                Text(
                                  '同步QQ音乐官方榜单数据',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: ref.watch(qqMusicSyncEnabledProvider),
                            activeColor: Colors.green,
                            onChanged: (v) async {
                              if (v) {
                                // 开启前先测试连接
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('正在连接QQ音乐...')),
                                );
                                final service = QQMusicLeaderboardService.instance;
                                await service.initialize();
                                final success = await service.testConnection();
                                if (!success) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('QQ音乐连接失败，请检查网络')),
                                    );
                                  }
                                  return;
                                }
                              }
                              await ref.read(qqMusicSyncEnabledProvider.notifier).setEnabled(v);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(v ? 'QQ音乐榜单已开启' : 'QQ音乐榜单已关闭')),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 扩展功能
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '扩展功能',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    // 扩展功能管理入口
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ExtensionManagerPage(),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.purple, Colors.deepPurple],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.extension_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('功能扩展管理'),
                                SizedBox(height: 2),
                                Text(
                                  '元数据修复、歌词增强、AI翻译等增值功能',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 关于
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '关于',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('应用版本'),
                              Text(
                                '2.2.3',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('构建号'),
                              Text(
                                '3',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 底部按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    GlassButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('缓存已清除')),
                          );
                        }
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('清除缓存'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GlassButton(
                      onPressed: () {
                        showAboutDialog(
                          context: context,
                          applicationName: '吾爱Music',
                          applicationVersion: '2.2.3',
                          applicationLegalese: '© 2024 吾爱Music',
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('关于应用'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeModeButton(
    AppThemeMode mode,
    String label,
    IconData icon,
    Color color,
  ) {
    final themeConfig = ref.watch(themeProvider);
    final isSelected = themeConfig.themeMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(themeProvider.notifier).setThemeMode(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _AnimatedThemeSwitch ─────────────────────────────────────────────────────

class _AnimatedThemeSwitch extends StatefulWidget {
  final bool value;
  final void Function(Offset offset) onChanged;

  const _AnimatedThemeSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  State<_AnimatedThemeSwitch> createState() => _AnimatedThemeSwitchState();
}

class _AnimatedThemeSwitchState extends State<_AnimatedThemeSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnim;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _positionAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    if (widget.value) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedThemeSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      final center = pos + Offset(box.size.width / 2, box.size.height / 2);
      widget.onChanged(center);
    } else {
      widget.onChanged(Offset.zero);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _positionAnim.value;
          final glow = _glowAnim.value;

          final trackColor = Color.lerp(
            Colors.grey.shade300,
            isDark ? const Color(0xFF5856D6) : const Color(0xFF1C1C1E),
            progress,
          )!;

          final thumbLeft = 2.0 + progress * 22.0;

          final glowColor = Color.lerp(
            Colors.transparent,
            (isDark ? const Color(0xFF5856D6) : Colors.amber)
                .withValues(alpha: 0.4),
            glow,
          )!;

          return Container(
            width: 52,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: trackColor,
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 12 * glow,
                        spreadRadius: 2 * glow,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  left: thumbLeft,
                  top: 2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          widget.value
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          key: ValueKey(widget.value),
                          size: 14,
                          color: isDark
                              ? const Color(0xFF5856D6)
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
