import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/custom_source_service.dart';
import '../../data/models/music_source.dart';
import '../../../playlist/providers/netease_leaderboard_provider.dart';
import 'unified_leaderboard_detail_page.dart';

/// 排行榜页面 - 显示所有榜单数据（整合网易云API和JS音源）
class LeaderboardPage extends ConsumerStatefulWidget {
  const LeaderboardPage({super.key});

  @override
  ConsumerState<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends ConsumerState<LeaderboardPage> {
  List<UnifiedLeaderboard> _allLeaderboards = [];
  List<UnifiedLeaderboard> _displayLeaderboards = []; // 实际显示的榜单
  bool _isLoading = true;
  String? _errorMessage;

  // 初始显示类型：all（全部榜单）或 favorite（收藏榜单）
  String _displayType = 'all';

  @override
  void initState() {
    super.initState();
    _loadLeaderboards();
  }

  Future<void> _loadLeaderboards() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 使用统一榜单Provider
      final unifiedLeaderboards = await ref.read(unifiedLeaderboardsProvider.future);

      // 同时获取收藏的JS榜单
      final customService = ref.read(customSourceServiceProvider.notifier);

      if (mounted) {
        setState(() {
          _allLeaderboards = unifiedLeaderboards;
          _displayLeaderboards = unifiedLeaderboards; // 默认显示全部榜单
          _isLoading = false;

          if (unifiedLeaderboards.isEmpty) {
            _errorMessage = '暂无可用榜单，请检查音源是否支持';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '加载失败: $e';
        });
      }
    }
  }

  /// 切换显示类型：全部榜单 或 收藏榜单
  void _toggleDisplayType() {
    setState(() {
      if (_displayType == 'all') {
        _displayType = 'favorite';
        // 获取收藏的榜单（只显示JS音源的收藏）
        final service = ref.read(customSourceServiceProvider.notifier);
        final favoriteIds = service.favoriteLeaderboards
            .map((f) => '${f.leaderboard.sourceId}_${f.leaderboard.id}')
            .toSet();
        
        _displayLeaderboards = _allLeaderboards
            .where((lb) => favoriteIds.contains('${lb.sourceId}_${lb.id}'))
            .toList();
      } else {
        _displayType = 'all';
        _displayLeaderboards = _allLeaderboards;
      }
    });
  }

  /// 获取平台中文名称
  String _getPlatformName(String platform) {
    switch (platform.toLowerCase()) {
      case 'kw':
        return '酷我音乐';
      case 'kg':
        return '酷狗音乐';
      case 'tx':
        return 'QQ音乐';
      case 'wy':
        return '网易云音乐';
      case 'mg':
        return '咪咕音乐';
      default:
        return platform;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLeaderboards,
              child: CustomScrollView(
                slivers: [
                  // 顶部标题栏
                  SliverAppBar(
                    floating: true,
                    snap: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    title: const Text(
                      '排行榜',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        // 强制使用深色文字
                        color: Colors.black87,
                      ),
                    ),
                    actions: [
                      // 切换按钮：全部 / 收藏
                      Container(
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: isDarkMode
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            // 全部榜单按钮
                            Material(
                              color: _displayType == 'all'
                                  ? Colors.blue.withAlpha(60)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  setState(() {
                                    _displayType = 'all';
                                    _displayLeaderboards = _allLeaderboards;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '全部',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _displayType == 'all'
                                          ? Colors.blue
                                          : Colors.black54,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // 收藏榜单按钮
                            Material(
                              color: _displayType == 'favorite'
                                  ? Colors.red.withAlpha(60)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: _toggleDisplayType,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _displayType == 'favorite'
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        size: 16,
                                        color: _displayType == 'favorite'
                                            ? Colors.red
                                            : Colors.black54,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '收藏',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _displayType == 'favorite'
                                              ? Colors.red
                                              : Colors.black54,
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
                    ],
                  ),

                  // 错误提示
                  if (_errorMessage != null && _displayLeaderboards.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 60,
                              color: isDarkMode ? Colors.white24 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white54 : Colors.black45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _loadLeaderboards,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('重试'),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 空状态
                  if (_displayLeaderboards.isEmpty && _errorMessage == null)
                    SliverToBoxAdapter(
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _displayType == 'favorite'
                                  ? Icons.favorite_border_rounded
                                  : Icons.library_music_rounded,
                              size: 80,
                              color: isDarkMode ? Colors.white24 : Colors.black12,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _displayType == 'favorite'
                                  ? '还没有收藏的榜单\n点击榜单卡片上的❤️即可收藏'
                                  : '暂无可用榜单，请检查音源是否支持',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDarkMode ? Colors.white54 : Colors.black45,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 榜单网格
                  if (_displayLeaderboards.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) =>
                              _buildLeaderboardCard(_displayLeaderboards[index], isDarkMode),
                          childCount: _displayLeaderboards.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }



  Widget _buildLeaderboardCard(UnifiedLeaderboard leaderboard, bool isDarkMode) {
    final service = ref.read(customSourceServiceProvider.notifier);
    // 转换为JS榜单格式检查收藏状态
    final jsLeaderboard = LeaderboardInfo(
      id: leaderboard.id,
      name: leaderboard.name,
      source: leaderboard.source,
      sourceId: leaderboard.sourceId,
      img: leaderboard.coverUrl,
      description: leaderboard.description,
    );
    final isFavorite = service.isLeaderboardFavorite(jsLeaderboard);
    final isNetease = leaderboard.sourceType == LeaderboardSourceType.netease;

    return GlassCard(
      onTap: () => _openLeaderboardDetail(leaderboard),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withAlpha(20)
                        : Colors.black.withAlpha(10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      // 封面图片
                      if (leaderboard.coverUrl != null)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              leaderboard.coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildPlaceholderGradient(leaderboard);
                              },
                            ),
                          ),
                        )
                      else
                        _buildPlaceholderGradient(leaderboard),

                      // 数据源标识
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isNetease 
                                ? Colors.red.withAlpha(200)
                                : leaderboard.sourceType == LeaderboardSourceType.qq
                                    ? Colors.green.withAlpha(200)
                                    : Colors.black.withAlpha(100),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isNetease ? Icons.cloud_rounded 
                                    : leaderboard.sourceType == LeaderboardSourceType.qq
                                        ? Icons.music_note_rounded
                                        : Icons.code_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isNetease ? '网易云' 
                                    : leaderboard.sourceType == LeaderboardSourceType.qq
                                        ? 'QQ音乐'
                                        : _getSourceLabel(leaderboard.source),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
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

              const SizedBox(height: 12),

              // 榜单名称
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  leaderboard.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    // 强制使用深色文字确保可见
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // 描述
              if (leaderboard.description != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    leaderboard.description!,
                    style: TextStyle(
                      fontSize: 12,
                      // 强制使用深色文字确保可见
                      color: Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),

          // 收藏按钮（JS音源才显示收藏）
          if (!isNetease)
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _toggleFavorite(jsLeaderboard),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(80),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderGradient(UnifiedLeaderboard leaderboard) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getSourceColor(leaderboard.source),
            _getSourceColor(leaderboard.source).withAlpha(150),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Icon(
          Icons.leaderboard_rounded,
          size: 48,
          color: Colors.white.withAlpha(150),
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(LeaderboardInfo leaderboard) async {
    final service = ref.read(customSourceServiceProvider.notifier);
    await service.toggleFavoriteLeaderboard(leaderboard);

    // 触发UI刷新
    setState(() {});

    // 显示提示
    if (mounted) {
      final isFavorite = service.isLeaderboardFavorite(leaderboard);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFavorite ? '已收藏: ${leaderboard.name}' : '已取消收藏: ${leaderboard.name}',
          ),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Color _getSourceColor(String source) {
    switch (source.toLowerCase()) {
      case 'kw':
        return Colors.orange;
      case 'kg':
        return Colors.blue;
      case 'tx':
        return Colors.green;
      case 'wy':
        return Colors.red;
      case 'mg':
        return Colors.pink;
      default:
        return Colors.purple;
    }
  }

  String _getSourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'kw':
        return '酷我';
      case 'kg':
        return '酷狗';
      case 'tx':
        return 'QQ';
      case 'wy':
        return '网易';
      case 'mg':
        return '咪咕';
      default:
        return source.toUpperCase();
    }
  }

  void _openLeaderboardDetail(UnifiedLeaderboard leaderboard) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnifiedLeaderboardDetailPage(
          leaderboard: leaderboard,
        ),
      ),
    );
  }
}
