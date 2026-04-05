import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../custom_source/services/custom_source_service.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';

/// TV版自定义源导入页面
class TvCustomSourceImportPage extends ConsumerStatefulWidget {
  const TvCustomSourceImportPage({super.key});

  @override
  ConsumerState<TvCustomSourceImportPage> createState() => _TvCustomSourceImportPageState();
}

class _TvCustomSourceImportPageState extends ConsumerState<TvCustomSourceImportPage> {
  final _focusNode = FocusNode();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  bool _isImporting = false;
  List<String> _importedSources = [];
  int _focusIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadImportedSources();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadImportedSources() async {
    setState(() => _isLoading = true);
    try {
      final sources = ref.read(customSourceServiceProvider);
      setState(() {
        _importedSources = sources.map((s) => s.name).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importSource() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入JS音源URL')),
      );
      return;
    }

    setState(() => _isImporting = true);
    
    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      await service.importFromUrl(url);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导入成功')),
        );
        _urlController.clear();
        _loadImportedSources();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _refreshSources() async {
    await _loadImportedSources();
    // 同时刷新榜单
    ref.invalidate(unifiedLeaderboardsProvider);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('刷新完成')),
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

    // 上下导航
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusIndex = (_focusIndex - 1).clamp(0, 2);
      });
      return;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusIndex = (_focusIndex + 1).clamp(0, 2);
      });
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
        _importSource();
        break;
      case 1:
        _refreshSources();
        break;
      case 2:
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.purple.shade800.withValues(alpha: 0.3), Colors.blue.shade900.withValues(alpha: 0.3)]
                  : [Colors.purple.shade100.withValues(alpha: 0.3), Colors.blue.shade100.withValues(alpha: 0.3)],
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
                          color: Colors.purple.withValues(alpha: 0.2),
                        ),
                        child: Icon(
                          Icons.file_download_rounded,
                          size: 56 * scale,
                          color: Colors.purple,
                        ),
                      ),
                      SizedBox(width: 24 * scale),
                      Text(
                        '自定义源导入',
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
                          // JS音源URL输入
                          Text(
                            'JS音源URL',
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
                            ),
                            child: TextField(
                              controller: _urlController,
                              style: TextStyle(
                                fontSize: 24 * scale,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '输入JS音源URL地址...',
                                hintStyle: TextStyle(
                                  fontSize: 24 * scale,
                                  color: isDark ? Colors.white38 : Colors.black38,
                                ),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16 * scale),
                          
                          // 提示文字
                          Text(
                            '支持导入洛雪音乐、六音等JS音源',
                            style: TextStyle(
                              fontSize: 18 * scale,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                          
                          SizedBox(height: 32 * scale),

                          // 按钮列表
                          _buildButton(
                            _isImporting ? '导入中...' : '导入', 
                            Icons.download_rounded, 
                            0, 
                            scale, 
                            isDark,
                            isLoading: _isImporting,
                          ),
                          SizedBox(height: 16 * scale),
                          _buildButton('刷新榜单', Icons.refresh_rounded, 1, scale, isDark),
                          SizedBox(height: 32 * scale),
                          _buildButton('返回', Icons.arrow_back_rounded, 2, scale, isDark),
                          
                          SizedBox(height: 32 * scale),
                          
                          // 已导入的音源列表
                          if (_importedSources.isNotEmpty) ...[
                            Text(
                              '已导入的音源 (${_importedSources.length})',
                              style: TextStyle(
                                fontSize: 24 * scale,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            SizedBox(height: 16 * scale),
                            Container(
                              constraints: BoxConstraints(maxHeight: 150 * scale),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _importedSources.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 8 * scale),
                                    child: Container(
                                      padding: EdgeInsets.all(12 * scale),
                                      decoration: BoxDecoration(
                                        color: isDark 
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.black.withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(8 * scale),
                                      ),
                                      child: Text(
                                        _importedSources[index],
                                        style: TextStyle(
                                          fontSize: 18 * scale,
                                          color: isDark ? Colors.white54 : Colors.black45,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildButton(String text, IconData icon, int index, double scale, bool isDark, {bool isLoading = false}) {
    final isFocused = _focusIndex == index;
    
    return TVFocusCard(
      width: double.infinity,
      height: 80 * scale,
      focusColor: Colors.purple,
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
                  color: isFocused ? Colors.purple : (isDark ? Colors.white70 : Colors.black54),
                ),
              )
            else
              Icon(
                icon,
                size: 32 * scale,
                color: isFocused ? Colors.purple : (isDark ? Colors.white70 : Colors.black54),
              ),
            SizedBox(width: 16 * scale),
            Text(
              text,
              style: TextStyle(
                fontSize: 28 * scale,
                fontWeight: FontWeight.w600,
                color: isFocused ? Colors.purple : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
