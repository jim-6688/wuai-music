import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../nas/service/nas_service.dart';
import '../../../nas/presentation/providers/nas_provider.dart';
import '../../../files/data/models/track.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';

/// TV NAS 设备页面 - 支持遥控器操作
/// 
/// 功能：
/// - 方向键导航设备列表
/// - 确认键连接/浏览设备
/// - 返回键返回主页
class TVNasPage extends ConsumerStatefulWidget {
  const TVNasPage({super.key});

  @override
  ConsumerState<TVNasPage> createState() => _TVNasPageState();
}

class _TVNasPageState extends ConsumerState<TVNasPage> {
  int _focusIndex = 0;
  final FocusNode _rootFocusNode = FocusNode();
  bool _isLoading = false;
  String? _lastBrowseError;

  static const _audioExts = {
    '.mp3', '.m4a', '.aac', '.flac', '.wav', '.wma', '.ogg', '.opus',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
      _refreshDevices();
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  Future<void> _refreshDevices() async {
    final nasService = ref.read(nasServiceProvider);
    await nasService.refreshDevices();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;
    final devices = ref.read(nasDevicesProvider);

    // 上下导航
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex--);
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < devices.length - 1) {
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
      if (devices.isNotEmpty && _focusIndex < devices.length) {
        _onDeviceTap(devices[_focusIndex]);
      }
      return;
    }
  }

  Future<void> _onDeviceTap(NasDevice device) async {
    if (device.isConnected) {
      await _browseDevice(device);
      return;
    }

    // 未连接，显示认证对话框
    final authResult = await _showAuthDialog(device);
    if (authResult == null) return;

    setState(() => _isLoading = true);
    final nasService = ref.read(nasServiceProvider);
    
    final deviceWithAuth = device.copyWith(
      username: authResult['username'],
      password: authResult['password'],
    );

    final ok = await nasService.connect(deviceWithAuth);
    setState(() => _isLoading = false);

    if (ok && mounted) {
      await _browseDevice(nasService.connectedDevice ?? deviceWithAuth);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nasService.errorMessage ?? '连接失败'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Future<Map<String, String>?> _showAuthDialog(NasDevice device) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('连接到 ${device.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '输入用户名',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '输入密码',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, {
                'username': usernameController.text,
                'password': passwordController.text,
              });
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  Future<void> _browseDevice(NasDevice device) async {
    // TODO: 打开 TV 文件浏览器浏览 NAS 文件
    if (kDebugMode) print('浏览设备: ${device.name}');
  }

  bool _isAudioFile(String name) {
    final ext = name.toLowerCase();
    return _audioExts.any((e) => ext.endsWith(e));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scale = TvScreenAdapter.of(context).scale;
    final devices = ref.watch(nasDevicesProvider);

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
        child: LiquidBackground(
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
                        Icons.cloud_rounded, 
                        size: 56 * scale,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    SizedBox(width: 24 * scale),
                    Text(
                      'NAS 设备',
                      style: TextStyle(
                        fontSize: 56 * scale,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading)
                      SizedBox(
                        width: 48 * scale,
                        height: 48 * scale,
                        child: CircularProgressIndicator(
                          strokeWidth: 4 * scale,
                        ),
                      )
                    else
                      TVFocusButton(
                        width: 120 * scale,
                        height: 120 * scale,
                        onPressed: _refreshDevices,
                        focusColor: Colors.teal,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 56 * scale,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),

              // 设备列表
              Expanded(
                child: devices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 120 * scale,
                              color: isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.3),
                            ),
                            SizedBox(height: 24 * scale),
                            Text(
                              '未发现 NAS 设备',
                              style: TextStyle(
                                fontSize: 32 * scale,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                            Text(
                              '请确保 NAS 设备与电视在同一局域网',
                              style: TextStyle(
                                fontSize: 24 * scale,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 48 * scale),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          final isFocused = index == _focusIndex;
                          
                          return Padding(
                            padding: EdgeInsets.only(bottom: 24 * scale),
                            child: TVFocusCard(
                              width: double.infinity,
                              height: 140 * scale,
                              focusColor: Colors.teal,
                              autofocus: index == 0,
                              onTap: () => _onDeviceTap(device),
                              onFocus: () => setState(() => _focusIndex = index),
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32 * scale),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 80 * scale,
                                      height: 80 * scale,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: device.isConnected
                                            ? Colors.green.withValues(alpha: 0.2)
                                            : (isDark 
                                                ? Colors.white.withValues(alpha: 0.1)
                                                : Colors.black.withValues(alpha: 0.05)),
                                      ),
                                      child: Icon(
                                        device.isConnected
                                            ? Icons.cloud_done_rounded
                                            : Icons.cloud_off_rounded,
                                        size: 40 * scale,
                                        color: device.isConnected
                                            ? Colors.green
                                            : (isDark ? Colors.white54 : Colors.black54),
                                      ),
                                    ),
                                    SizedBox(width: 24 * scale),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device.name,
                                            style: TextStyle(
                                              fontSize: 32 * scale,
                                              fontWeight: FontWeight.w600,
                                              color: isFocused
                                                  ? Colors.teal
                                                  : (isDark ? Colors.white : Colors.black87),
                                            ),
                                          ),
                                          SizedBox(height: 4 * scale),
                                          Text(
                                            '${device.ip} · ${device.isConnected ? '已连接' : '未连接'}',
                                            style: TextStyle(
                                              fontSize: 24 * scale,
                                              color: isFocused
                                                  ? Colors.teal.withValues(alpha: 0.8)
                                                  : (isDark ? Colors.white54 : Colors.black54),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 48 * scale,
                                      color: isFocused 
                                          ? Colors.teal 
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
                        '确认连接',
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
            color: isDark 
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
          child: Icon(
            icon,
            size: 28,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize.clamp(16.0, 24.0),
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}
