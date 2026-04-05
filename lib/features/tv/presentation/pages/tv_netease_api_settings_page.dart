import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../playlist/services/netease_leaderboard_service.dart';
import '../../../playlist/providers/netease_provider.dart';
import '../../../player/presentation/providers/lyrics_provider.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';

/// TV版网易云API设置页面
class TvNeteaseApiSettingsPage extends ConsumerStatefulWidget {
  const TvNeteaseApiSettingsPage({super.key});

  @override
  ConsumerState<TvNeteaseApiSettingsPage> createState() => _TvNeteaseApiSettingsPageState();
}

class _TvNeteaseApiSettingsPageState extends ConsumerState<TvNeteaseApiSettingsPage> {
  final _focusNode = FocusNode();
  final _urlController = TextEditingController();
  bool _isLoading = true;
  bool _isTesting = false;
  bool? _testResult;
  String? _currentUrl;
  // focusIndex: 0~3 = 操作按钮(保存/测试/重置/返回)
  int _focusIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUrl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadCurrentUrl() async {
    final service = NeteaseLeaderboardService.instance;
    final config = await service.getConfig();
    setState(() {
      _currentUrl = config.apiBaseUrl;
      _urlController.text = _currentUrl ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    final service = NeteaseLeaderboardService.instance;
    await service.updateConfig(apiBaseUrl: url);
    // 同步更新 NeteaseApiService 的 base URL
    final apiService = ref.read(neteaseApiServiceProvider);
    await apiService.updateBaseUrl(url);
    // 同步更新歌词服务
    final lyricsService = ref.read(lyricsServiceProvider);
    lyricsService.setNeteaseApiService(apiService);

    setState(() {
      _currentUrl = url;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API地址已保存')),
      );
    }
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = false;
        _isTesting = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      final service = NeteaseLeaderboardService.instance;
      final originalUrl = service.baseUrl;
      await service.updateBaseUrl(url);
      final success = await service.testConnection();

      if (!success) {
        // 恢复原始 URL
        await service.updateBaseUrl(originalUrl);
      }

      setState(() {
        _testResult = success;
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _testResult = false;
        _isTesting = false;
      });
    }
  }

  Future<void> _resetToDefault() async {
    final service = NeteaseLeaderboardService.instance;
    await service.resetConfig();
    await _loadCurrentUrl();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置为默认API地址')),
      );
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;

    final key = event.logicalKey;

    // 返回键
    if (key == LogicalKeyboardKey.escape || 
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.of(context).pop();
      return;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      if (_focusIndex > 0) {
        setState(() => _focusIndex--);
      }
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      if (_focusIndex < 3) {
        setState(() => _focusIndex++);
      }
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      _activateButton(_focusIndex);
      return;
    }
  }

  void _activateButton(int index) {
    switch (index) {
      case 0:
        _saveUrl();
        break;
      case 1:
        _testConnection();
        break;
      case 2:
        _resetToDefault();
        break;
      case 3:
        Navigator.of(context).pop();
        break;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final scale = TvScreenAdapter.of(context).scale;

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
        child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop();
        },
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1A2E).withValues(alpha: 0.8), const Color(0xFF16213E).withValues(alpha: 0.8)]
                    : [Colors.red.shade50.withValues(alpha: 0.5), Colors.blue.shade50.withValues(alpha: 0.5)],
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
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 48 * scale,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      SizedBox(width: 24 * scale),
                      Container(
                        padding: EdgeInsets.all(16 * scale),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.cloud_rounded,
                          size: 56 * scale,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(width: 24 * scale),
                      Text(
                        '网易云API设置',
                        style: TextStyle(
                          fontSize: 48 * scale,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),

                // 内容区域
                Expanded(
                  child: Center(
                    child: Container(
                      width: 800 * scale,
                      padding: EdgeInsets.all(48 * scale),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(32 * scale),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // API地址输入
                          Text(
                            'API地址',
                            style: TextStyle(
                              fontSize: 28 * scale,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          SizedBox(height: 16 * scale),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 24 * scale),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16 * scale),
                              border: Border.all(
                                color: _focusIndex == -1 
                                    ? Colors.blue 
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: TextField(
                              controller: _urlController,
                              style: TextStyle(
                                fontSize: 24 * scale,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'http://localhost:3000',
                                hintStyle: TextStyle(
                                  fontSize: 24 * scale,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          
                          SizedBox(height: 16 * scale),
                          
                          // 当前地址提示
                          if (_currentUrl != null) ...[
                            Text(
                              '当前地址: $_currentUrl',
                              style: TextStyle(
                                fontSize: 18 * scale,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                          ],

                          SizedBox(height: 16 * scale),

                          // 连接测试结果
                          if (_testResult != null) ...[
                            Container(
                              padding: EdgeInsets.all(16 * scale),
                              decoration: BoxDecoration(
                                color: _testResult! 
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12 * scale),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _testResult! ? Icons.check_circle : Icons.error,
                                    color: _testResult! ? Colors.green : Colors.red,
                                    size: 32 * scale,
                                  ),
                                  SizedBox(width: 12 * scale),
                                  Text(
                                    _testResult! ? '连接成功' : '连接失败',
                                    style: TextStyle(
                                      fontSize: 24 * scale,
                                      color: _testResult! ? Colors.green : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 32 * scale),
                          ],

                          // 按钮列表
                          _buildButton('保存', Icons.save_rounded, 0, scale, isDark),
                          SizedBox(height: 16 * scale),
                          _buildButton(
                            _isTesting ? '测试连接中...' : '测试连接', 
                            Icons.wifi_tethering_rounded, 
                            1, 
                            scale, 
                            isDark,
                            isLoading: _isTesting,
                          ),
                          SizedBox(height: 16 * scale),
                          _buildButton('重置为默认', Icons.restore_rounded, 2, scale, isDark),
                          SizedBox(height: 32 * scale),
                          _buildButton('返回', Icons.arrow_back_rounded, 3, scale, isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildButton(String text, IconData icon, int index, double scale, bool isDark, {bool isLoading = false}) {
    final isFocused = _focusIndex == index;
    
    return TVFocusCard(
      width: double.infinity,
      height: 80 * scale,
      focusColor: Colors.blue,
      autofocus: index == 0,
      onTap: isLoading ? null : () => _activateButton(index),
      onFocus: () => setState(() => _focusIndex = index),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * scale),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 32 * scale,
                height: 32 * scale,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: isFocused ? Colors.blue : (isDark ? Colors.white70 : Colors.black54),
                ),
              )
            else
              Icon(
                icon,
                size: 32 * scale,
                color: isFocused ? Colors.blue : (isDark ? Colors.white70 : Colors.black54),
              ),
            SizedBox(width: 16 * scale),
            Text(
              text,
              style: TextStyle(
                fontSize: 28 * scale,
                fontWeight: FontWeight.w600,
                color: isFocused ? Colors.blue : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
