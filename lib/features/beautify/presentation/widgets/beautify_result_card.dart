import 'package:flutter/material.dart';
import '../../data/models/beautify_item.dart';

/// 美化结果卡片 - 显示单个曲目的美化结果，支持预览和确认应用
class BeautifyResultCard extends StatelessWidget {
  final BeautifyItem item;
  final VoidCallback? onApply;
  final bool showApplyButton;

  const BeautifyResultCard({
    super.key,
    required this.item,
    this.onApply,
    this.showApplyButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasMatch = item.matchedTitle != null;
    final hasCover = item.coverUrls.isNotEmpty || item.localCoverPath != null;
    final hasLyrics = item.lyrics != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF161B22)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头部：封面预览 + 曲目信息
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 封面
                _CoverPreview(
                  coverUrl: item.selectedCoverUrl ?? item.coverUrls.firstOrNull,
                  localPath: item.localCoverPath,
                  size: 72,
                ),
                const SizedBox(width: 16),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 原名
                      Text(
                        item.originalName,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                          decoration: hasMatch ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (hasMatch) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.matchedTitle!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (item.matchedArtist != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.matchedArtist!,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),
                      // 标签
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (hasMatch)
                            _Tag(
                              icon: Icons.check_circle,
                              label: '元数据',
                              color: Colors.green,
                            ),
                          if (hasCover)
                            _Tag(
                              icon: Icons.image,
                              label: '封面',
                              color: Colors.blue,
                            ),
                          if (hasLyrics)
                            _Tag(
                              icon: Icons.lyrics,
                              label: item.enhancedLyrics != null ? '歌词+' : '歌词',
                              color: Colors.purple,
                            ),
                          if (item.confidence > 0)
                            _Tag(
                              icon: Icons.analytics,
                              label: '${(item.confidence * 100).toInt()}%',
                              color: Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 详情行（展开区域）
          if (hasMatch || hasLyrics) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 元数据详情
                  if (hasMatch) ...[
                    _DetailRow('歌名', item.matchedTitle!, isDark),
                    if (item.matchedAlbum != null)
                      _DetailRow('专辑', item.matchedAlbum!, isDark),
                  ],
                  // 歌词预览
                  if (hasLyrics && item.lyrics != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '歌词预览',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _previewLyrics(item.lyrics!, 4),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                  // AI 增强标记
                  if (item.enhancedLyrics != null && item.enhancedLyrics != item.lyrics) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: Colors.purple),
                          SizedBox(width: 4),
                          Text(
                            'AI 增强版歌词可用',
                            style: TextStyle(fontSize: 12, color: Colors.purple),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // 底部操作
          if (showApplyButton && (hasMatch || hasCover || hasLyrics))
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('跳过'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onApply,
                      icon: const Icon(Icons.check, size: 18, color: Colors.white),
                      label: const Text('应用', style: TextStyle(color: Colors.white)),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _previewLyrics(String lrc, int maxLines) {
    final lines = lrc.split('\n')
        .where((l) => l.contains(']'))
        .map((l) => l.replaceFirst(RegExp(r'\[\d{2}:\d{2}[.:]\d{2,3}]'), ''))
        .where((l) => l.trim().isNotEmpty)
        .take(maxLines)
        .toList();
    return lines.join('\n');
  }
}

class _CoverPreview extends StatelessWidget {
  final String? coverUrl;
  final String? localPath;
  final double size;

  const _CoverPreview({
    this.coverUrl,
    this.localPath,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: coverUrl != null
          ? Image.network(
              coverUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : (localPath != null
              ? Image.asset(
                  localPath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder(),
                )
              : _placeholder()),
    );
  }

  Widget _placeholder() {
    return Icon(
      Icons.album,
      color: Colors.grey.withValues(alpha: 0.5),
      size: size * 0.5,
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Tag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow(this.label, this.value, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
