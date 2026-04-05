import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/tv_focus_manager.dart';
import '../../widgets/tv_screen_adapter.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import '../../../custom_source/services/custom_source_service.dart';
import '../../../custom_source/data/models/music_source.dart';
import 'tv_leaderboard_detail_page.dart';

/// TV版榜单页面
class TvLeaderboardPage extends ConsumerStatefulWidget {
  const TvLeaderboardPage({super.key});

  @override
  ConsumerState<TvLeaderboardPage> createState() => _TvLeaderboardPageState();
}

class _TvLeaderboardPageState extends ConsumerState<TvLeaderboardPage> {
  final _focusNode = FocusNode();
  List<UnifiedLeaderboard> _leaderboards = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLeaderboards();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final leaderboards = await ref.read(unifiedLeaderboardsProvider.future);
      setState(() {
        _leaderboards = leaderboards;
        _isLoading = false;
        if (leaderboards.isEmpty) {
          _errorMessage = '暂无榜单数据\n\n可能原因：\n• 网易云API不可用\n• 未导入JS音源\n• 网络连接问题\n\n请在设置中检查API配置或导入音源';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '加载失败: $e\n\n请检查网络连接或刷新重试';
      });
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

    // F5 刷新
    if (key == LogicalKeyboardKey.f5) {
      _loadLeaderboards();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
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
              colors: [
                const Color(0xFFE8F4FD),
                const Color(0xFFF0F9FF),
                const Color(0xFFF8FAFC),
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
                          Icons.leaderboard_rounded,
                          size: 56 * scale,
                          color: Colors.red,
                        ),
                      ),
                      SizedBox(width: 24 * scale),
                      Text(
                        '在线榜单',
                        style: TextStyle(
                          fontSize: 48 * scale,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      // 刷新按钮
                      TVFocusButton(
                        width: 64 * scale,
                        height: 64 * scale,
                        focusColor: Colors.blue,
                        onPressed: _loadLeaderboards,
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 32 * scale,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),

                // 内容区域
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 64 * scale,
                                height: 64 * scale,
                                child: CircularProgressIndicator(
                                  strokeWidth: 4,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 24 * scale),
                              Text(
                                '加载中...',
                                style: TextStyle(
                                  fontSize: 28 * scale,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 80 * scale,
                                    color: Colors.red.withValues(alpha: 0.7),
                                  ),
                                  SizedBox(height: 24 * scale),
                                  Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 28 * scale,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: 32 * scale),
                                  TVFocusButton(
                                    width: 200 * scale,
                                    height: 64 * scale,
                                    focusColor: Colors.blue,
                                    onPressed: _loadLeaderboards,
                                    child: Text(
                                      '重试',
                                      style: TextStyle(
                                        fontSize: 24 * scale,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildLeaderboardGrid(scale, isDark),
                ),

                // 底部提示
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
                        _buildControlHint(Icons.arrow_back_rounded, '返回', 24 * scale, isDark),
                        SizedBox(width: 48 * scale),
                        _buildControlHint(Icons.subdirectory_arrow_right_rounded, '进入', 24 * scale, isDark),
                        SizedBox(width: 48 * scale),
                        _buildControlHint(Icons.refresh_rounded, '刷新', 24 * scale, isDark),
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

  Widget _buildLeaderboardGrid(double scale, bool isDark) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 48 * scale),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 32 * scale,
        crossAxisSpacing: 32 * scale,
        childAspectRatio: 0.75,
      ),
      itemCount: _leaderboards.length,
      itemBuilder: (context, index) {
        final leaderboard = _leaderboards[index];
        final isNetease = leaderboard.sourceType == LeaderboardSourceType.netease;
        
        return _LeaderboardCard(
          leaderboard: leaderboard,
          scale: scale,
          isDark: isDark,
          onTap: () => _openLeaderboardDetail(leaderboard),
          color: isNetease ? Colors.red : Colors.purple,
        );
      },
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

  void _openLeaderboardDetail(UnifiedLeaderboard leaderboard) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TvLeaderboardDetailPage(leaderboard: leaderboard),
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final UnifiedLeaderboard leaderboard;
  final double scale;
  final bool isDark;
  final VoidCallback onTap;
  final Color color;

  const _LeaderboardCard({
    required this.leaderboard,
    required this.scale,
    required this.isDark,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isNetease = leaderboard.sourceType == LeaderboardSourceType.netease;
    
    return TVFocusCard(
      focusColor: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 封面
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16 * scale),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: Stack(
                children: [
                  if (leaderboard.coverUrl != null)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16 * scale),
                        child: Image.network(
                          leaderboard.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                        ),
                      ),
                    )
                  else
                    _buildPlaceholder(),
                  
                  // 数据源标识
                  Positioned(
                    top: 12 * scale,
                    left: 12 * scale,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12 * scale,
                        vertical: 6 * scale,
                      ),
                      decoration: BoxDecoration(
                        color: isNetease 
                            ? Colors.red.withValues(alpha: 0.9)
                            : Colors.purple.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8 * scale),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isNetease ? Icons.cloud_rounded : Icons.code_rounded,
                            size: 16 * scale,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4 * scale),
                          Text(
                            isNetease ? '网易云' : 'JS音源',
                            style: TextStyle(
                              fontSize: 14 * scale,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 12 * scale),
          
          // 标题
          Text(
            leaderboard.name,
            style: TextStyle(
              fontSize: 20 * scale,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          if (leaderboard.description != null) ...[
            SizedBox(height: 4 * scale),
            Text(
              leaderboard.description!,
              style: TextStyle(
                fontSize: 14 * scale,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.8),
            color.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16 * scale),
      ),
      child: Center(
        child: Icon(
          Icons.leaderboard_rounded,
          size: 64 * scale,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}
