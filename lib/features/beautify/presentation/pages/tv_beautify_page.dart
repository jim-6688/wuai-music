import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/beautify_provider.dart';
import '../../data/models/beautify_item.dart';
import '../../../tv/widgets/tv_screen_adapter.dart';

/// TV 端曲库美化中心
///
/// 遥控器操作：
/// - 方向键网格导航结果列表
/// - 确认键弹出沉浸式封面+歌词全屏弹窗
/// - 返回键退出
class TvBeautifyPage extends ConsumerStatefulWidget {
  const TvBeautifyPage({super.key});

  @override
  ConsumerState<TvBeautifyPage> createState() => _TvBeautifyPageState();
}

class _TvBeautifyPageState extends ConsumerState<TvBeautifyPage> {
  final FocusNode _rootFocusNode = FocusNode();

  // 焦点位置：-1 = 空状态区域，其他 = items 列表索引
  int _focusIndex = -1;
  int _columns = 2; // 每行卡片数量

  // 沉浸式弹窗：当前展示的 item
  BeautifyItem? _immersiveItem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    final state = ref.read(beautifyProvider);

    // 返回
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      if (_immersiveItem != null) {
        setState(() => _immersiveItem = null);
        return;
      }
      Navigator.of(context).pop();
      return;
    }

    // 沉浸式弹窗内的操作
    if (_immersiveItem != null) return;

    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        _moveFocus(dy: -1);
        break;
      case LogicalKeyboardKey.arrowDown:
        _moveFocus(dy: 1);
        break;
      case LogicalKeyboardKey.arrowLeft:
        _moveFocus(dx: -1);
        break;
      case LogicalKeyboardKey.arrowRight:
        _moveFocus(dx: 1);
        break;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.gameButtonA:
        _handleConfirm(state);
        break;
      default:
        break;
    }
  }

  void _moveFocus({int dx = 0, int dy = 0}) {
    final state = ref.read(beautifyProvider);
    final items = state.items.where((i) => i.status == BeautifyStatus.completed).toList();
    if (items.isEmpty) return;

    final totalCols = _columns;
    final totalRows = (items.length / totalCols).ceil();

    if (_focusIndex < 0) {
      setState(() => _focusIndex = 0);
      return;
    }

    int row = _focusIndex ~/ totalCols;
    int col = _focusIndex % totalCols;

    if (dx != 0) {
      col = (col + dx).clamp(0, totalCols - 1);
      final newIdx = row * totalCols + col;
      if (newIdx < items.length) {
        setState(() => _focusIndex = newIdx);
      }
    } else if (dy != 0) {
      row = (row + dy).clamp(0, totalRows - 1);
      final newIdx = row * totalCols + col;
      setState(() => _focusIndex = newIdx.clamp(0, items.length - 1));
    }
  }

  void _handleConfirm(BeautifyState state) {
    final completedItems = state.items.where((i) => i.status == BeautifyStatus.completed).toList();
    if (_focusIndex < 0 || _focusIndex >= completedItems.length) return;

    final item = completedItems[_focusIndex];
    // 弹出沉浸式全屏弹窗
    setState(() => _immersiveItem = item);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(beautifyProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mainContent = Focus(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: (_, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F4FA),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(state, theme, isDark),
              Expanded(child: _buildBody(state, theme, isDark)),
            ],
          ),
        ),
      ),
    );

    // 沉浸式全屏弹窗覆盖层
    if (_immersiveItem != null) {
      return Stack(
        children: [
          mainContent,
          _ImmersiveOverlay(
            item: _immersiveItem!,
            onClose: () => setState(() => _immersiveItem = null),
            theme: theme,
            isDark: isDark,
          ),
        ],
      );
    }

    return mainContent;
  }

  Widget _buildHeader(BeautifyState state, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.auto_fix_high, size: 40, color: theme.primaryColor),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '曲库美化中心',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _headerSubtitle(state),
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark ? Colors.white54 : Colors.black45,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          _buildHeaderActions(state, theme, isDark),
        ],
      ),
    );
  }

  String _headerSubtitle(BeautifyState state) {
    switch (state.taskState) {
      case BeautifyTaskState.idle:
        return '基于音频指纹 · AI 智能美化';
      case BeautifyTaskState.beautifying:
        return '${state.currentOperation ?? "美化中"} · ${state.completedCount}/${state.totalCount}';
      case BeautifyTaskState.completed:
        return '完成 · 成功 ${state.completedCount} 首 · 失败 ${state.failedCount} 首';
      case BeautifyTaskState.paused:
        return '已暂停 · ${state.completedCount}/${state.totalCount}';
      default:
        return '';
    }
  }

  Widget _buildHeaderActions(BeautifyState state, ThemeData theme, bool isDark) {
    if (state.taskState == BeautifyTaskState.beautifying) {
      return Row(
        children: [
          _TvFocusButton(
            label: state.isPaused ? '继续' : '暂停',
            icon: state.isPaused ? Icons.play_arrow : Icons.pause,
            onTap: () {
              if (state.isPaused) {
                ref.read(beautifyProvider.notifier).resume();
              } else {
                ref.read(beautifyProvider.notifier).pause();
              }
            },
            isFocused: false,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: 12),
          _TvFocusButton(
            label: '停止',
            icon: Icons.stop,
            onTap: () => ref.read(beautifyProvider.notifier).cancel(),
            isFocused: false,
            theme: theme,
            isDark: isDark,
            color: Colors.red,
          ),
        ],
      );
    }

    if (state.taskState == BeautifyTaskState.completed) {
      return _TvFocusButton(
        label: '完成',
        icon: Icons.check,
        onTap: () => Navigator.pop(context),
        isFocused: false,
        theme: theme,
        isDark: isDark,
      );
    }

    return Row(
      children: [
        _TvFocusButton(
          label: '开始美化',
          icon: Icons.auto_fix_high,
          onTap: () => ref.read(beautifyProvider.notifier).startBeautify(),
          isFocused: false,
          theme: theme,
          isDark: isDark,
        ),
        const SizedBox(width: 12),
        _TvFocusButton(
          label: '重置',
          icon: Icons.refresh,
          onTap: () => ref.read(beautifyProvider.notifier).reset(),
          isFocused: false,
          theme: theme,
          isDark: isDark,
          isSecondary: true,
        ),
      ],
    );
  }

  Widget _buildBody(BeautifyState state, ThemeData theme, bool isDark) {
    switch (state.taskState) {
      case BeautifyTaskState.idle:
        return _buildIdleBody(theme, isDark);
      case BeautifyTaskState.beautifying:
      case BeautifyTaskState.paused:
        return _buildProcessingBody(state, theme, isDark);
      case BeautifyTaskState.completed:
        return _buildCompletedBody(state, theme, isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildIdleBody(ThemeData theme, bool isDark) {
    return Center(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.library_music,
              size: 80,
              color: theme.primaryColor.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 32),
            Text(
              '准备开始曲库美化',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '从本地音乐库选择要美化的曲目，开始自动识别并修复元数据、歌词与封面',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: isDark ? Colors.white54 : Colors.black45,
                height: 1.6,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 40),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _FeatureBadge(Icons.fingerprint, '音频指纹识别', theme.primaryColor),
                _FeatureBadge(Icons.album, '高清封面', Colors.blue),
                _FeatureBadge(Icons.lyrics, 'AI 歌词增强', Colors.purple),
                _FeatureBadge(Icons.translate, '歌词翻译', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingBody(BeautifyState state, ThemeData theme, bool isDark) {
    final current = state.currentIndex >= 0 && state.currentIndex < state.items.length
        ? state.items[state.currentIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度条
          _buildProgressBar(state, theme, isDark),
          const SizedBox(height: 32),

          // 当前处理项
          if (current != null) _CurrentProcessingCard(item: current, theme: theme, isDark: isDark),
          const SizedBox(height: 32),

          // 已有结果预览
          if (state.items.any((i) => i.status == BeautifyStatus.completed)) ...[
            Text(
              '已完成（确认键查看详情）',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _ResultGridView(
              items: state.items.where((i) => i.status == BeautifyStatus.completed).toList(),
              focusIndex: _focusIndex,
              onFocusChange: (idx) => setState(() => _focusIndex = idx),
              theme: theme,
              isDark: isDark,
              columns: _columns,
            )),
          ] else
            Expanded(
              child: Center(
                child: Text(
                  '正在识别中，请稍候...',
                  style: TextStyle(
                    fontSize: 20,
                    color: isDark ? Colors.white38 : Colors.black38,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCompletedBody(BeautifyState state, ThemeData theme, bool isDark) {
    final completedItems = state.items.where((i) => i.status == BeautifyStatus.completed).toList();

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProgressBar(state, theme, isDark),
          const SizedBox(height: 32),
          if (completedItems.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '没有找到可美化的曲目',
                  style: TextStyle(
                    fontSize: 20,
                    color: isDark ? Colors.white54 : Colors.black45,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _ResultGridView(
                items: completedItems,
                focusIndex: _focusIndex,
                onFocusChange: (idx) => setState(() => _focusIndex = idx),
                theme: theme,
                isDark: isDark,
                columns: _columns,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BeautifyState state, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (state.isPaused)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.pause_circle, color: Colors.orange, size: 20),
              ),
            Expanded(
              child: Text(
                state.currentOperation ?? '美化进度',
                style: TextStyle(
                  fontSize: 20,
                  color: isDark ? Colors.white70 : Colors.black54,
                  decoration: TextDecoration.none,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${state.completedCount}/${state.totalCount}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.primaryColor,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: state.progress,
            minHeight: 12,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            valueColor: AlwaysStoppedAnimation(state.isPaused ? Colors.orange : theme.primaryColor),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 子组件
// ═══════════════════════════════════════════════════════════════════

class _ResultGridView extends StatelessWidget {
  final List<BeautifyItem> items;
  final int focusIndex;
  final ValueChanged<int> onFocusChange;
  final ThemeData theme;
  final bool isDark;
  final int columns;

  const _ResultGridView({
    required this.items,
    required this.focusIndex,
    required this.onFocusChange,
    required this.theme,
    required this.isDark,
    required this.columns,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 1.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final isFocused = index == focusIndex;

        return _TvResultCard(
          item: item,
          isFocused: isFocused,
          theme: theme,
          isDark: isDark,
        );
      },
    );
  }
}

class _TvResultCard extends StatelessWidget {
  final BeautifyItem item;
  final bool isFocused;
  final ThemeData theme;
  final bool isDark;

  const _TvResultCard({
    required this.item,
    required this.isFocused,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFocused
              ? theme.primaryColor
              : Colors.transparent,
          width: isFocused ? 3 : 1,
        ),
        boxShadow: [
          if (isFocused)
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 16,
              spreadRadius: 2,
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // 封面
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: item.selectedCoverUrl != null || item.localCoverPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildCoverImage(),
                    )
                  : _coverPlaceholder(),
            ),
            const SizedBox(width: 16),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (item.matchedTitle != null) ...[
                    Text(
                      item.matchedTitle!,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    item.originalName,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white38 : Colors.black38,
                      decoration: item.matchedTitle != null
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.matchedArtist != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.matchedArtist!,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // 标签
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (item.matchedTitle != null)
                        const _Badge('元数据', Colors.green),
                      if (item.coverUrls.isNotEmpty || item.localCoverPath != null)
                        const _Badge('封面', Colors.blue),
                      if (item.lyrics != null)
                        const _Badge('歌词', Colors.purple),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    final String? imageSource = item.localCoverPath ?? item.selectedCoverUrl;
    if (imageSource == null) return _coverPlaceholder();

    final bool isLocal = item.localCoverPath != null;

    if (isLocal) {
      return Image.file(
        File(imageSource),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _coverPlaceholder(),
      );
    }
    return Image.network(
      imageSource,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _coverPlaceholder(),
    );
  }

  Widget _coverPlaceholder() {
    return Center(
      child: Icon(
        Icons.album,
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
        size: 36,
      ),
    );
  }
}

class _CurrentProcessingCard extends StatelessWidget {
  final BeautifyItem item;
  final ThemeData theme;
  final bool isDark;

  const _CurrentProcessingCard({
    required this.item,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(theme.primaryColor),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '正在处理',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.matchedTitle ?? item.originalName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.matchedArtist != null)
                  Text(
                    item.matchedArtist!,
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white60 : Colors.black54,
                      decoration: TextDecoration.none,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            _statusIcon(item.status),
            color: theme.primaryColor.withValues(alpha: 0.6),
            size: 28,
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(BeautifyStatus s) {
    switch (s) {
      case BeautifyStatus.extracting:
        return Icons.fingerprint;
      case BeautifyStatus.recognizing:
        return Icons.search;
      case BeautifyStatus.enhancing:
        return Icons.auto_awesome;
      default:
        return Icons.music_note;
    }
  }
}

class _FeatureBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeatureBadge(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600, decoration: TextDecoration.none),
      ),
    );
  }
}

class _TvFocusButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isFocused;
  final ThemeData theme;
  final bool isDark;
  final Color? color;
  final bool isSecondary;

  const _TvFocusButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isFocused,
    required this.theme,
    required this.isDark,
    this.color,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.primaryColor;
    return Material(
      color: isFocused ? c.withValues(alpha: 0.15) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFocused ? c : (isDark ? Colors.white24 : Colors.black12),
              width: isFocused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isFocused ? c : (isDark ? Colors.white54 : Colors.black45),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isFocused ? FontWeight.bold : FontWeight.normal,
                  color: isFocused ? c : (isDark ? Colors.white70 : Colors.black54),
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 沉浸式全屏弹窗 — 封面 + 歌词
// ═══════════════════════════════════════════════════════════════════

class _ImmersiveOverlay extends StatefulWidget {
  final BeautifyItem item;
  final VoidCallback onClose;
  final ThemeData theme;
  final bool isDark;

  const _ImmersiveOverlay({
    required this.item,
    required this.onClose,
    required this.theme,
    required this.isDark,
  });

  @override
  State<_ImmersiveOverlay> createState() => _ImmersiveOverlayState();
}

class _ImmersiveOverlayState extends State<_ImmersiveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  final ScrollController _lyricsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 从封面URL提取主色调（简化处理，用主色）
    final accentColor = widget.theme.primaryColor;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              // 背景使用封面模糊 + 深色遮罩
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  (widget.isDark ? const Color(0xFF0D1117) : const Color(0xFF1A1A2E)).withValues(alpha: 0.92),
                  (widget.isDark ? const Color(0xFF0A0E14) : const Color(0xFF16213E)).withValues(alpha: 0.98),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // 顶部信息栏
                  _buildTopBar(accentColor),
                  // 主体：封面 + 歌词
                  Expanded(
                    child: _buildContent(accentColor),
                  ),
                  // 底部提示
                  _buildBottomHint(accentColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
      child: Row(
        children: [
          // 返回按钮
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white70, size: 28),
          ),
          const SizedBox(width: 24),
          // 歌曲信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.matchedTitle ?? widget.item.originalName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.item.matchedArtist != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.item.matchedArtist!,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white60,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (widget.item.matchedAlbum != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.item.matchedAlbum!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white38,
                      decoration: TextDecoration.none,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          // 标签
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (widget.item.matchedTitle != null)
                _ImmersiveBadge('元数据', Colors.green),
              if (widget.item.coverUrls.isNotEmpty || widget.item.localCoverPath != null)
                _ImmersiveBadge('封面', Colors.blue),
              if (widget.item.lyrics != null)
                _ImmersiveBadge('歌词', Colors.purple),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Color accentColor) {
    final hasCover = widget.item.localCoverPath != null || widget.item.selectedCoverUrl != null;
    final hasLyrics = widget.item.lyrics != null && widget.item.lyrics!.isNotEmpty;

    if (!hasCover && !hasLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_note,
              size: 80,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 24),
            const Text(
              '暂无封面和歌词',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white38,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      );
    }

    if (hasCover && hasLyrics) {
      // 封面 + 歌词并排
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
        child: Row(
          children: [
            // 左侧：大封面
            Expanded(
              flex: 2,
              child: _buildCoverSection(),
            ),
            const SizedBox(width: 48),
            // 右侧：歌词滚动
            Expanded(
              flex: 3,
              child: _buildLyricsSection(),
            ),
          ],
        ),
      );
    }

    if (hasCover) {
      return Center(
        child: SizedBox(
          width: 480,
          height: 480,
          child: _buildCoverSection(),
        ),
      );
    }

    // 只有歌词
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 16),
      child: _buildLyricsSection(),
    );
  }

  Widget _buildCoverSection() {
    final String? imageSource = widget.item.localCoverPath ?? widget.item.selectedCoverUrl;
    if (imageSource == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(
          child: Icon(Icons.album, size: 120, color: Colors.white24),
        ),
      );
    }

    final bool isLocal = widget.item.localCoverPath != null;
    final image = isLocal
        ? Image.file(File(imageSource), fit: BoxFit.cover)
        : Image.network(imageSource, fit: BoxFit.cover);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: image,
      ),
    );
  }

  Widget _buildLyricsSection() {
    final lyricsText = widget.item.lyrics ?? '';
    final lines = lyricsText.split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lyrics, color: Colors.purple, size: 24),
              SizedBox(width: 10),
              Text(
                '歌词',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Scrollbar(
              controller: _lyricsScrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _lyricsScrollController,
                padding: const EdgeInsets.only(right: 8),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index];
                  // 去除时间标签
                  final cleanLine = line
                      .replaceFirst(RegExp(r'\[\d{2}:\d{2}[.:]\d{2,3}\]'), '')
                      .replaceFirst(RegExp(r'\[\d{2}:\d{2}\]'), '')
                      .trim();
                  if (cleanLine.isEmpty) return const SizedBox(height: 12);

                  final isTimestamp = line.trim().startsWith('[') && cleanLine.isEmpty;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: isTimestamp
                        ? const SizedBox.shrink()
                        : Text(
                            cleanLine,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.8,
                              color: Colors.white70,
                              decoration: TextDecoration.none,
                            ),
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomHint(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.keyboard_return, color: Colors.white.withValues(alpha: 0.3), size: 20),
          const SizedBox(width: 8),
          const Text(
            '按返回键关闭',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white38,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImmersiveBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ImmersiveBadge(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: color,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
