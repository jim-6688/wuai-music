import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/beautify_provider.dart';
import '../../data/models/beautify_item.dart';
import '../../../extension_manager/providers/extension_manager_provider.dart';
import '../../../extension_manager/presentation/pages/extension_manager_page.dart';
import '../widgets/beautify_result_card.dart';
import '../widgets/beautify_config_sheet.dart';
import '../pages/subscription_page.dart';

/// 曲库美化中心主页
class BeautifyPage extends ConsumerStatefulWidget {
  const BeautifyPage({super.key});

  @override
  ConsumerState<BeautifyPage> createState() => _BeautifyPageState();
}

class _BeautifyPageState extends ConsumerState<BeautifyPage> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_initialized) {
        // 初始化订阅服务
        await ref.read(subscriptionServiceProvider.notifier).initialize();
        ref.read(beautifyProvider.notifier).reset();
        _initialized = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(beautifyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final extManager = ref.watch(extensionManagerProvider);
    
    // 检查元数据修复扩展是否已启用
    final isMetadataRepairEnabled = extManager.isExtensionEnabled('metadata_repair');
    
    // 如果扩展未启用，显示引导页面
    if (!isMetadataRepairEnabled) {
      return _buildExtensionRequiredPage(context, theme, isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '曲库美化中心',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (state.taskState == BeautifyTaskState.beautifying)
            IconButton(
              icon: Icon(
                state.isPaused ? Icons.play_arrow : Icons.pause,
                color: theme.primaryColor,
              ),
              onPressed: () {
                if (state.isPaused) {
                  ref.read(beautifyProvider.notifier).resume();
                } else {
                  ref.read(beautifyProvider.notifier).pause();
                }
              },
            ),
          if (state.taskState != BeautifyTaskState.idle)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.grey),
              onPressed: () => ref.read(beautifyProvider.notifier).reset(),
            ),
          IconButton(
            icon: Icon(Icons.tune, color: theme.primaryColor),
            onPressed: () => _showConfigSheet(context),
          ),
        ],
      ),
      body: _buildBody(context, state, theme, isDark),
      floatingActionButton: _buildFab(context, state, theme),
    );
  }

  Widget _buildBody(BuildContext context, BeautifyState state, ThemeData theme, bool isDark) {
    switch (state.taskState) {
      case BeautifyTaskState.idle:
        return _buildIdleState(context, theme, isDark);
      case BeautifyTaskState.scanning:
        return _buildScanningState(theme, isDark);
      case BeautifyTaskState.beautifying:
        return _buildBeautifyingState(context, state, theme, isDark);
      case BeautifyTaskState.paused:
        return _buildPausedState(state, theme, isDark);
      case BeautifyTaskState.completed:
        return _buildCompletedState(context, state, theme, isDark);
      case BeautifyTaskState.cancelled:
        return _buildCancelledState(theme, isDark);
    }
  }

  // ── 空状态 ──────────────────────────────────────────────────────────

  Widget _buildIdleState(BuildContext context, ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_fix_high, size: 56, color: theme.primaryColor),
            ),
            const SizedBox(height: 32),
            Text(
              '智能曲库美化',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '基于音频指纹识别，AI 自动修复元数据、歌词与封面',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _FeatureChip(Icons.fingerprint, '音频指纹识别'),
                _FeatureChip(Icons.album, '高清封面修复'),
                _FeatureChip(Icons.lyrics, 'AI 歌词增强'),
                _FeatureChip(Icons.translate, '歌词翻译美化'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 扫描中 ─────────────────────────────────────────────────────────

  Widget _buildScanningState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: theme.primaryColor),
          const SizedBox(height: 24),
          Text(
            '正在扫描本地音乐...',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ── 美化中 ──────────────────────────────────────────────────────────

  Widget _buildBeautifyingState(
    BuildContext context,
    BeautifyState state,
    ThemeData theme,
    bool isDark,
  ) {
    final current = state.currentIndex >= 0 && state.currentIndex < state.items.length
        ? state.items[state.currentIndex]
        : null;

    return Column(
      children: [
        // 进度区
        _ProgressHeader(state: state, theme: theme, isDark: isDark),

        // 当前处理项
        if (current != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _CurrentItemCard(item: current, theme: theme, isDark: isDark),
          ),

        const SizedBox(height: 16),

        // 结果列表（已完成项）
        Expanded(
          child: state.items.isEmpty
              ? const SizedBox()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final item = state.items[index];
                    if (item.status == BeautifyStatus.pending ||
                        item.status == BeautifyStatus.extracting ||
                        item.status == BeautifyStatus.recognizing ||
                        item.status == BeautifyStatus.enhancing) {
                      return _PendingItemTile(item: item, isDark: isDark);
                    }
                    return BeautifyResultCard(
                      item: item,
                      onApply: () => _applyResult(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── 暂停中 ──────────────────────────────────────────────────────────

  Widget _buildPausedState(BeautifyState state, ThemeData theme, bool isDark) {
    return Column(
      children: [
        _ProgressHeader(state: state, theme: theme, isDark: isDark),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              return BeautifyResultCard(
                item: state.items[index],
                onApply: () => _applyResult(context, state.items[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── 已完成 ──────────────────────────────────────────────────────────

  Widget _buildCompletedState(
    BuildContext context,
    BeautifyState state,
    ThemeData theme,
    bool isDark,
  ) {
    final stats = ref.watch(beautifyStatsProvider);

    return Column(
      children: [
        // 完成总结
        Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.primaryColor.withValues(alpha: 0.2),
                theme.primaryColor.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 12),
              Text(
                '美化完成！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatBadge('总计', stats.total.toString(), theme.primaryColor),
                  _StatBadge('成功', stats.completed.toString(), Colors.green),
                  _StatBadge('失败', stats.failed.toString(), Colors.red),
                ],
              ),
            ],
          ),
        ),

        // 可应用结果列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: state.items.length,
            itemBuilder: (context, index) {
              final item = state.items[index];
              if (item.status != BeautifyStatus.completed) return const SizedBox();
              return BeautifyResultCard(
                item: item,
                onApply: () => _applyResult(context, item),
                showApplyButton: true,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCancelledState(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cancel_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            '已取消',
            style: TextStyle(
              fontSize: 20,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────────

  Widget _buildFab(BuildContext context, BeautifyState state, ThemeData theme) {
    if (state.taskState == BeautifyTaskState.beautifying ||
        state.taskState == BeautifyTaskState.paused) {
      return FloatingActionButton.extended(
        heroTag: 'beautify_cancel',
        backgroundColor: Colors.red,
        onPressed: () => ref.read(beautifyProvider.notifier).cancel(),
        icon: const Icon(Icons.stop, color: Colors.white),
        label: const Text('停止', style: TextStyle(color: Colors.white)),
      );
    }

    if (state.taskState == BeautifyTaskState.completed) {
      return FloatingActionButton.extended(
        heroTag: 'beautify_done',
        backgroundColor: theme.primaryColor,
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('完成', style: TextStyle(color: Colors.white)),
      );
    }

    return FloatingActionButton.extended(
      heroTag: 'beautify_start',
      backgroundColor: theme.primaryColor,
      onPressed: () => _startBeautify(context),
      icon: const Icon(Icons.auto_fix_high, color: Colors.white),
      label: const Text('开始美化', style: TextStyle(color: Colors.white)),
    );
  }

  void _startBeautify(BuildContext context) async {
    // 检查订阅状态
    final subscription = ref.read(subscriptionServiceProvider);
    final (canAccess, reason) = subscription.canUsePremiumFeatures 
        ? (true, '') 
        : (subscription.isInTrial, subscription.isInTrial ? '试用期' : '请订阅');

    if (!canAccess) {
      // 显示付费引导
      final subscribed = await showDialog<bool>(
        context: context,
        builder: (context) => const SubscriptionDialog(
          featureName: '曲库美化',
        ),
      );
      if (subscribed != true) return;
    }

    // 如果是试用期，使用一次试用机会
    if (subscription.isInTrial) {
      await ref.read(subscriptionServiceProvider.notifier).useTrial();
    }

    // 从本地音乐页面传入待处理文件
    // 这里直接开始（后续从文件选择器获取文件列表）
    ref.read(beautifyProvider.notifier).startBeautify();
  }

  void _applyResult(BuildContext context, BeautifyItem item) {
    // 应用美化结果到实际曲目
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将美化结果应用到: ${item.matchedTitle ?? item.originalName}'),
        backgroundColor: Colors.green,
      ),
    );
    ref.read(beautifyProvider.notifier).updateItem(
      item.copyWith(status: BeautifyStatus.completed),
    );
  }

  void _showConfigSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BeautifyConfigSheet(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 子组件
// ═══════════════════════════════════════════════════════════════════

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.08),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final BeautifyState state;
  final ThemeData theme;
  final bool isDark;

  const _ProgressHeader({
    required this.state,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (state.isPaused)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.pause_circle, color: Colors.orange, size: 20),
                ),
              Expanded(
                child: Text(
                  state.currentOperation ?? '正在美化...',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${state.completedCount}/${state.totalCount}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 8,
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentItemCard extends StatelessWidget {
  final BeautifyItem item;
  final ThemeData theme;
  final bool isDark;

  const _CurrentItemCard({
    required this.item,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.music_note, color: theme.primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.matchedTitle ?? item.originalName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.matchedArtist != null)
                  Text(
                    item.matchedArtist!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingItemTile extends StatelessWidget {
  final BeautifyItem item;
  final bool isDark;

  const _PendingItemTile({required this.item, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.originalName,
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _statusText(item.status),
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(BeautifyStatus s) {
    switch (s) {
      case BeautifyStatus.pending:
        return '等待中';
      case BeautifyStatus.extracting:
        return '提取指纹';
      case BeautifyStatus.recognizing:
        return '识别中';
      case BeautifyStatus.enhancing:
        return '增强中';
      default:
        return '';
    }
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // ── 扩展未启用引导页面 ─────────────────────────────────────────────────

  Widget _buildExtensionRequiredPage(BuildContext context, ThemeData theme, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '曲库美化中心',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  size: 56,
                  color: Colors.purple,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                '功能扩展未启用',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '智能元数据修复是增值扩展功能\n需要在扩展管理中启用后使用',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white60 : Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ExtensionManagerPage(),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '前往扩展管理',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  '返回',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
