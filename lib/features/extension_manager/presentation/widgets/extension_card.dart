import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/extension.dart';
import '../../providers/extension_manager_provider.dart';

// 启用/禁用提示文案
String _enableTip(String extensionId) {
  switch (extensionId) {
    case 'metadata_repair':
      return '✅ 元数据修复已启用 — 前往「曲库美化」开始修复';
    case 'lyrics_enhance':
      return '✅ 歌词增强已启用 — 播放时自动拉取优化歌词';
    case 'cover_repair':
      return '✅ 封面修复已启用 — 美化时自动下载高清封面';
    case 'ai_translate':
      return '✅ AI 翻译已启用 — 支持外语歌词自动翻译为中文';
    default:
      return '✅ 扩展已启用';
  }
}

String _disableTip(String extensionId) {
  switch (extensionId) {
    case 'metadata_repair':
      return '元数据修复已关闭';
    default:
      return '扩展已禁用';
  }
}

/// 扩展功能卡片
class ExtensionCard extends ConsumerWidget {
  final Extension extension;

  const ExtensionCard({
    super.key,
    required this.extension,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _getTypeColor(extension.type).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getIconData(extension.icon),
                    color: _getTypeColor(extension.type),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // 名称和描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              extension.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          // 状态标签
                          _buildStatusBadge(extension, isDark),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        extension.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 底部：价格和操作
            Row(
              children: [
                // 价格
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: extension.pricingModel == PricingModel.free
                        ? Colors.green.withValues(alpha: 0.1)
                        : primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    extension.priceDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: extension.pricingModel == PricingModel.free
                          ? Colors.green
                          : primaryColor,
                    ),
                  ),
                ),
                if (extension.isInTrial) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '试用剩 ${extension.trialDaysRemaining} 天',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // 操作按钮
                _buildActionButton(context, ref),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Extension ext, bool isDark) {
    Color color;
    String text;

    switch (ext.status) {
      case ExtensionStatus.enabled:
        color = Colors.green;
        text = '已启用';
        break;
      case ExtensionStatus.trial:
        color = Colors.orange;
        text = '试用中';
        break;
      case ExtensionStatus.installed:
        color = Colors.grey;
        text = '未启用';
        break;
      case ExtensionStatus.needUpdate:
        color = Colors.blue;
        text = '需更新';
        break;
      case ExtensionStatus.notInstalled:
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    switch (extension.status) {
      case ExtensionStatus.enabled:
      case ExtensionStatus.trial:
        return TextButton(
          onPressed: () {
            ref.read(extensionManagerProvider.notifier).disableExtension(extension.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_disableTip(extension.id)),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('禁用'),
        );
      case ExtensionStatus.installed:
        return FilledButton(
          onPressed: () {
            ref.read(extensionManagerProvider.notifier).enableExtension(extension.id);
            _showEnableDialog(context, ref);
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('启用'),
        );
      case ExtensionStatus.notInstalled:
      case ExtensionStatus.needUpdate:
      default:
        if (extension.pricingModel == PricingModel.free) {
          return FilledButton(
            onPressed: () {
              ref.read(extensionManagerProvider.notifier).enableExtension(extension.id);
              _showEnableDialog(context, ref);
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('安装'),
          );
        }
        return FilledButton(
          onPressed: () {
            ref.read(extensionManagerProvider.notifier).enableExtension(extension.id);
            _showEnableDialog(context, ref);
          },
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: Text(extension.trialDays != null ? '试用' : '购买'),
        );
    }
  }

  /// 启用后弹出功能说明对话框
  void _showEnableDialog(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // 先弹 SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_enableTip(extension.id)),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    // 再弹功能说明 Dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _getTypeColor(extension.type).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(extension.icon),
                size: 32,
                color: _getTypeColor(extension.type),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${extension.name} 已启用',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              extension.description,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // 使用提示
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates_rounded, size: 18, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getUsageTip(extension.id),
                      style: TextStyle(fontSize: 13, color: theme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: theme.primaryColor,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  String _getUsageTip(String id) {
    switch (id) {
      case 'metadata_repair':
        return '点击底部「歌单」→「美化」，或从设置页进入曲库美化中心开始修复';
      case 'lyrics_enhance':
        return '播放音乐时将自动尝试获取增强歌词，无需手动操作';
      case 'cover_repair':
        return '在曲库美化中心开始美化时，将自动下载并更新专辑封面';
      case 'ai_translate':
        return '播放外语歌曲时，歌词将自动翻译为中文并同步显示';
      default:
        return '扩展已激活，相关功能已解锁';
    }
  }

  Color _getTypeColor(ExtensionType type) {
    switch (type) {
      case ExtensionType.metadataRepair:
        return Colors.purple;
      case ExtensionType.lyricsEnhance:
        return Colors.blue;
      case ExtensionType.coverRepair:
        return Colors.orange;
      case ExtensionType.aiTranslate:
        return Colors.teal;
      case ExtensionType.audioEnhance:
        return Colors.red;
      case ExtensionType.cloudSync:
        return Colors.indigo;
      case ExtensionType.social:
        return Colors.pink;
      case ExtensionType.other:
      default:
        return Colors.grey;
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'auto_fix_high':
        return Icons.auto_fix_high_rounded;
      case 'lyrics':
        return Icons.lyrics_rounded;
      case 'image':
        return Icons.image_rounded;
      case 'translate':
        return Icons.translate_rounded;
      case 'cloud_sync':
        return Icons.cloud_sync_rounded;
      default:
        return Icons.extension_rounded;
    }
  }
}
