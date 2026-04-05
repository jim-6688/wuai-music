import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import '../../../files/service/file_service.dart';
import '../../../files/presentation/providers/file_provider.dart';
import '../../../../core/providers/unified_tracks_provider.dart';
import '../../../../core/providers/player_integration_provider.dart';
import 'tv_local_music_page.dart';
import '../../../player/service/audio_player_service.dart';

/// TV 文件浏览器 - 支持遥控器操作
/// 
/// 功能：
/// - 方向键导航文件列表
/// - 确认键进入文件夹或选择文件
/// - 返回键返回上级目录
/// - 选择文件夹后自动扫描
class TVFileBrowser extends ConsumerStatefulWidget {
  const TVFileBrowser({super.key});

  @override
  ConsumerState<TVFileBrowser> createState() => _TVFileBrowserState();
}

class _TVFileBrowserState extends ConsumerState<TVFileBrowser> {
  String _currentPath = '/storage';
  List<FileSystemEntity> _items = [];
  int _focusIndex = 0;
  bool _isLoading = false;
  final FocusNode _rootFocusNode = FocusNode();
  static const List<String> _tvRootPaths = [
    '/storage',
    '/mnt/media_rw',
    '/mnt/usb',
    '/mnt/usb_storage',
    '/mnt/sdcard',
    '/mnt/external_sd',
    '/mnt/extSdCard',
    '/mnt/sda1',
    '/mnt/sdb1',
    '/mnt/sdc1',
    '/mnt/udisk',
    '/mnt/usbdisk',
    '/mnt/usbhost',
    '/mnt/usbhost1',
    '/mnt/usbhost2',
    '/mnt/usbhost3',
    '/storage/usbdisk',
    '/storage/udisk',
    '/storage/external',
    '/storage/sdcard1',
  ];

  @override
  void initState() {
    super.initState();
    // TV端优先使用外部存储路径
    _initTVPaths();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
    });
  }

  Future<void> _initTVPaths() async {
    // 检查哪些TV路径可用
    for (final root in _tvRootPaths) {
      if (await Directory(root).exists()) {
        _currentPath = root;
        _loadDirectory(root);
        if (kDebugMode) print('📺 TV root: $root');
        break;
      }
    }
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory(String path) async {
    setState(() => _isLoading = true);
    
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        setState(() {
          _isLoading = false;
          _items = [];
        });
        return;
      }

      final entities = await dir.list().toList();
      entities.sort((a, b) {
        // 文件夹优先
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p.basename(a.path).compareTo(p.basename(b.path));
      });

      setState(() {
        _currentPath = path;
        _items = entities;
        _focusIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法访问目录: $e')),
        );
      }
    }
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    if (kDebugMode) print('🎮 TV按键: ${key}');

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex = _focusIndex - 1);
      }
    } else if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < _items.length - 1) {
        setState(() => _focusIndex = _focusIndex + 1);
      }
    } else if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.gameButtonA) {
      _activateItem(_focusIndex);
    } else if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      _goBack();
    } else if (key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.gameButtonY) {
      // 菜单键/Y键 - 扫描当前文件夹
      _scanCurrentFolder();
    }
  }

  void _activateItem(int index) {
    if (index < 0 || index >= _items.length) return;

    final entity = _items[index];
    if (entity is Directory) {
      _loadDirectory(entity.path);
    } else {
      // 选中的是文件，扫描其所在文件夹
      _selectFolderAndScan(p.dirname(entity.path));
    }
  }

  /// 扫描当前显示的文件夹
  void _scanCurrentFolder() async {
    if (_currentPath.isEmpty) return;
    
    final scale = TvScreenAdapter.of(context).scale;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('扫描当前文件夹', style: TextStyle(fontSize: 28 * scale)),
        content: Text(
          '确认扫描该文件夹中的所有音乐文件？\n$_currentPath',
          style: TextStyle(fontSize: 24 * scale),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(fontSize: 22 * scale)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认扫描', style: TextStyle(fontSize: 22 * scale)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 显示扫描中提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在扫描: $_currentPath', style: TextStyle(fontSize: 20 * scale)),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // 开始扫描
      final fileService = ref.read(fileServiceProvider);
      await fileService.scanLocalMusic(paths: [_currentPath]);
      
      if (mounted) {
        // 扫描完成后跳转到音乐列表页面
        final tracks = ref.read(unifiedTracksProvider);
        if (tracks.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TVLocalMusicPage()),
          );
        } else {
          // 没有扫描到音乐，显示提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('未找到音乐文件', 
                style: TextStyle(fontSize: 20 * scale)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  void _goBack() {
    if (_currentPath == '/storage' || _currentPath == '/') {
      Navigator.of(context).pop();
    } else {
      _loadDirectory(p.dirname(_currentPath));
    }
  }

  void _selectFolderAndScan(String folderPath) async {
    final scale = TvScreenAdapter.of(context).scale;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('扫描文件夹', style: TextStyle(fontSize: 28 * scale)),
        content: Text(
          '确认扫描该文件夹中的音乐文件？\n$folderPath',
          style: TextStyle(fontSize: 24 * scale),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消', style: TextStyle(fontSize: 22 * scale)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确认扫描', style: TextStyle(fontSize: 22 * scale)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // 显示扫描中提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('正在扫描...', style: TextStyle(fontSize: 20 * scale)),
          duration: const Duration(seconds: 2),
        ),
      );
      
      // 开始扫描
      final fileService = ref.read(fileServiceProvider);
      await fileService.scanLocalMusic(paths: [folderPath]);
      
      if (mounted) {
        // 扫描完成后跳转到音乐列表页面
        final tracks = ref.read(unifiedTracksProvider);
        if (tracks.isNotEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const TVLocalMusicPage()),
          );
        } else {
          // 没有扫描到音乐，显示提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('未找到音乐文件', 
                style: TextStyle(fontSize: 20 * scale)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = TvScreenAdapter.of(context).scale;

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _goBack();
        },
        child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.grey[100],
        body: SafeArea(
          child: Column(
            children: [
              // === 顶部导航栏 ==========================================================
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * scale,
                  vertical: 20 * scale,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // 返回按钮
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goBack,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.all(8 * scale),
                          child: Icon(
                            Icons.arrow_back,
                            size: 28 * scale,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12 * scale),
                    // 文件夹图标
                    Icon(
                      Icons.folder_rounded,
                      size: 28 * scale,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                    SizedBox(width: 8 * scale),
                    // 路径文字
                    Expanded(
                      child: Text(
                        _currentPath,
                        style: TextStyle(
                          fontSize: 28 * scale,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 加载指示器
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12 * scale),
                        child: SizedBox(
                          width: 24 * scale,
                          height: 24 * scale,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    // 扫描当前文件夹按钮
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _scanCurrentFolder,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: EdgeInsets.all(8 * scale),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.scanner_rounded,
                                size: 24 * scale,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                              SizedBox(width: 4 * scale),
                              Text(
                                '扫描',
                                style: TextStyle(
                                  fontSize: 22 * scale,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // === 文件列表 ============================================================
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.folder_off_rounded,
                                  size: 160 * scale,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                ),
                                const SizedBox(height: 24),
                                                               Text(
                                    '文件夹为空',
                                    style: TextStyle(
                                      fontSize: 42 * scale,
                                      color: isDark ? Colors.white54 : Colors.black45,
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(32 * scale),
                            itemCount: _items.length,
                            itemExtent: 100 * scale,
                            itemBuilder: (context, index) {
                              final entity = _items[index];
                              final isFocused = index == _focusIndex;
                              final isDirectory = entity is Directory;
                              final name = p.basename(entity.path);

                              return Container(
                                margin: EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: isFocused
                                      ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.15))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isFocused ? Colors.blue.withValues(alpha: 1.0) : Colors.transparent,
                                    width: 4,
                                  ),
                                  boxShadow: isFocused
                                      ? [
                                          BoxShadow(
                                            color: Colors.blue.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            spreadRadius: 4,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16 * scale,
                                    vertical: 8 * scale,
                                  ),
                                  leading: Icon(
                                    isDirectory ? Icons.folder_rounded : Icons.audiotrack_rounded,
                                    size: 36 * scale,
                                    color: isDirectory
                                        ? (isFocused ? Colors.orange.shade400 : Colors.orange.shade300)
                                        : (isFocused ? Colors.blue : Colors.blue.withValues(alpha: 0.5)),
                                  ),
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 32 * scale,
                                      fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: isDirectory
                                      ? null
                                      : Text(
                                          p.extension(entity.path).toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 24 * scale,
                                            color: isDark ? Colors.white54 : Colors.black45,
                                          ),
                                        ),
                                  trailing: isFocused
                                      ? Icon(
                                          Icons.arrow_forward_ios,
                                          size: 20 * scale,
                                          color: Colors.blue,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
              ),

              // === 底部提示 ============================================================
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * scale,
                  vertical: 16 * scale,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _KeyHint(icon: Icons.arrow_upward, label: '上下移动', isDark: isDark, scale: scale),
                    SizedBox(width: 24 * scale),
                    _KeyHint(icon: Icons.check_circle, label: '确认进入', isDark: isDark, scale: scale),
                    SizedBox(width: 24 * scale),
                    _KeyHint(icon: Icons.menu, label: '菜单扫描', isDark: isDark, scale: scale),
                    SizedBox(width: 24 * scale),
                    _KeyHint(icon: Icons.arrow_back, label: '返回上级', isDark: isDark, scale: scale),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _KeyHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final double scale;

  const _KeyHint({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 24 * scale,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        SizedBox(width: 8 * scale),
        Text(
          label,
          style: TextStyle(
            fontSize: 22 * scale,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}
