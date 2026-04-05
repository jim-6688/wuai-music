import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_switch_animation.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/generate_theme.dart';
import 'shared/navigation/navigation_provider.dart';
import 'features/player/presentation/pages/player_page.dart';
import 'features/files/presentation/pages/local_music_page.dart';
import 'features/nas/presentation/pages/nas_devices_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/playlist/presentation/pages/meting_playlist_page.dart';
import 'features/tv/presentation/pages/tv_home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 禁用 Flutter 默认的焦点高亮下划线（TV 端由 TVFocusCard 自定义高亮）
  // Android TV 上每个 Focus 节点默认会画黄色双横线，此处全局关闭
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;

  // 全局错误处理 - 防止未捕获异常导致红屏崩溃
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack: ${details.stack}');
  };
  
  // 捕获异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Async Error: $error');
    debugPrint('Stack: $stack');
    return true; // 返回 true 表示已处理，不崩溃
  };

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: WuaiMusicApp()));
}

class WuaiMusicApp extends ConsumerWidget {
  const WuaiMusicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeConfig = ref.watch(themeProvider);
    final themeMode = ref.watch(themeProvider.notifier).getMaterialThemeMode();

    // 使用 Builder 获取正确的 context 来检测亮度
    return Builder(
      builder: (context) {
        // 根据主题模式判断是否为深色模式
        final isDark = themeMode == ThemeMode.dark || 
            (themeMode == ThemeMode.system && 
             MediaQuery.platformBrightnessOf(context) == Brightness.dark);
        
        // 获取当前配色方案 - 使用watch监听变化
        final colorScheme = ref.watch(currentColorSchemeProvider(context));
        
        final theme = isDark 
            ? DynamicThemeGenerator.generateDarkTheme(colorScheme)
            : DynamicThemeGenerator.generateLightTheme(colorScheme);

        return MaterialApp(
          title: '吾爱Music',
          debugShowCheckedModeBanner: false,
          theme: theme,
          darkTheme: DynamicThemeGenerator.generateDarkTheme(colorScheme),
          themeMode: themeMode,
          builder: (context, child) {
            if (child == null) return const SizedBox.shrink();
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(themeConfig.textScaleFactor),
              ),
              child: child,
            );
          },
          home: const ThemeSwitchWrapper(child: AppRoot()),
        );
      },
    );
  }
}

/// 根据设备类型选择 TV 界面或手机界面
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  bool _isTV = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initDeviceType();
  }

  Future<void> _initDeviceType() async {
    // Android TV 检测
    bool isTV = false;
    if (Platform.isAndroid) {
      try {
        final prop = await Process.run(
          'getprop', ['ro.product.model'],
          runInShell: true,
        );
        final model = prop.stdout.toString().toLowerCase();
        final brandProp = await Process.run(
          'getprop', ['ro.product.brand'],
          runInShell: true,
        );
        final brand = brandProp.stdout.toString().toLowerCase();
        // 获取更多设备属性用于检测
        String device = '';
        String manufacturer = '';
        String characteristics = '';
        try {
          final deviceProp = await Process.run('getprop', ['ro.product.device'], runInShell: true);
          device = deviceProp.stdout.toString().toLowerCase();
          final mfgProp = await Process.run('getprop', ['ro.product.manufacturer'], runInShell: true);
          manufacturer = mfgProp.stdout.toString().toLowerCase();
          final charProp = await Process.run('getprop', ['ro.build.characteristics'], runInShell: true);
          characteristics = charProp.stdout.toString().toLowerCase();
        } catch (_) {}

        // 先检测是否为手机（排除法）
        final isPhone = characteristics.contains('phone') || 
                        characteristics.contains('mobile') ||
                        model.contains('phone') ||
                        device.contains('phone');
        
        // 如果明确是手机，直接判定非 TV
        if (isPhone) {
          isTV = false;
        } else {
          // ========== TV 品牌型号库 ==========
          // 仅 TV 设备的品牌（不含也做手机的厂商如华为、小米、荣耀）
          const tvOnlyBrands = [
            'skyworth',    // 创维
            'coocaa',      // 酷开（创维子品牌）
            'hisense',     // 海信（电视为主）
            'tcl',         // TCL（电视为主）
            'changhong',   // 长虹
            'konka',       // 康佳
            'sharp',       // 夏普
            'sony',        // 索尼（电视）
            'samsung',     // 三星（电视）
            'philips',     // 飞利浦
            'toshiba',     // 东芝
            'lg',          // LG（电视）
            'vizio',       // Vizio
            'chromecast',  // Chromecast
            'nvidia',      // NVIDIA Shield TV
            'mecool',      // Mecool TV Box
            'beelink',     // Beelink Box
          ];

          // 型号关键词（ro.product.model / ro.product.device）
          const tvModelKeywords = [
            'tv',          // 通用 TV 型号
            'atv',         // Android TV
            'box',         // 电视盒子
            'shield',      // NVIDIA Shield
            'smarttv',     // 智能电视
            'smart_tv',    // 智能电视
            'androidtv',   // Android TV
            'projector',   // 投影仪
            'laser',       // 激光电视
            'wisdom',      // 智慧屏（华为）
            'vision',      // 华为 Vision
          ];

          // 检测逻辑
          // 1. 品牌/厂商匹配（仅限 TV 专属品牌）
          for (final b in tvOnlyBrands) {
            if (brand.contains(b) || manufacturer.contains(b)) {
              isTV = true;
              break;
            }
          }

          // 2. 型号关键词匹配
          if (!isTV) {
            for (final kw in tvModelKeywords) {
              if (model.contains(kw) || device.contains(kw)) {
                isTV = true;
                break;
              }
            }
          }

          // 3. 特定型号精确匹配（创维等特殊型号）
          if (!isTV) {
            const specificModels = ['s81', '9ta', 'q5', 'q6', 'a5d', 'a3d', 'g5', 'w82', 'honor screen'];
            for (final sm in specificModels) {
              if (model.contains(sm)) {
                isTV = true;
                break;
              }
            }
          }

          // 4. 额外检测：Leanback launcher 支持
          if (!isTV) {
            try {
              final leanback = await Process.run(
                'getprop', ['ro.app.launcher.mode'],
                runInShell: true,
              );
              if (leanback.stdout.toString().contains('leanback')) isTV = true;
            } catch (_) {}
          }

          // 5. 检测 characteristics 含 tv
          if (!isTV && characteristics.contains('tv')) {
            isTV = true;
          }
        }
      } catch (_) {
        // 检测失败，尝试 fallback
        try {
          final sysProp = await Process.run(
            'getprop', ['sys.tv.version'],
            runInShell: true,
          );
          if (sysProp.stdout.toString().trim().isNotEmpty) isTV = true;
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _isTV = isTV;
        _initialized = true;
      });
      // 更新应用名称（TV端使用TV后缀）
      if (isTV) {
        // 强制 TV 模式使用浅色主题
        ref.read(themeProvider.notifier).forceTVLightMode();
        
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _isTV ? const _TVRoot() : const MainShell();
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final List<Widget> _pages = const [
    LocalMusicPage(),
    MetingPlaylistPage(),
    PlayerPage(),
    NasDevicesPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationControllerProvider);

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
            ? Colors.black.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false, // 只保留底部安全区
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.music_note_rounded,
                  label: '音乐',
                  isSelected: currentIndex == 0,
                  onTap: () => ref.read(navigationControllerProvider.notifier).goToLocalMusic(),
                ),
                _NavItem(
                  icon: Icons.queue_music_rounded,
                  label: '歌单',
                  isSelected: currentIndex == 1,
                  onTap: () => ref.read(navigationControllerProvider.notifier).goToMetingPlaylist(),
                ),
                _NavItem(
                  icon: Icons.play_circle_rounded,
                  label: '播放',
                  isSelected: currentIndex == 2,
                  onTap: () => ref.read(navigationControllerProvider.notifier).goToPlayer(),
                ),
                _NavItem(
                  icon: Icons.cloud_rounded,
                  label: 'NAS',
                  isSelected: currentIndex == 3,
                  onTap: () => ref.read(navigationControllerProvider.notifier).goToNas(),
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  label: '设置',
                  isSelected: currentIndex == 4,
                  onTap: () => ref.read(navigationControllerProvider.notifier).goToSettings(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected 
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected 
                ? Theme.of(context).primaryColor
                : (isDark ? Colors.white54 : Colors.grey),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                  ? Theme.of(context).primaryColor
                  : (isDark ? Colors.white54 : Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全局文字缩放包裹器
class _TextScaleWrapper extends StatelessWidget {
  final double textScaleFactor;
  final Widget child;

  const _TextScaleWrapper({
    required this.textScaleFactor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScaleFactor),
      ),
      child: child,
    );
  }
}

/// TV 根节点 — 全局隐藏 Android 系统默认的黄色焦点下划线
/// TV 端使用 TVFocusCard 自定义焦点高亮，不需要系统默认的文字下划线
class _TVRoot extends StatelessWidget {
  const _TVRoot();

  @override
  Widget build(BuildContext context) {
    // 使用 SelectionContainer.disabled + Focus 的 canRequestFocus: false
    // 来阻止 Flutter 在 Android TV 上绘制默认焦点下划线
    return SelectionContainer.disabled(
      child: TvHomePage(),
    );
  }
}
