import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../providers/custom_source_provider.dart' show customSourceProvider;
import '../../../custom_source/data/models/music_source.dart';
import '../../../custom_source/services/custom_source_service.dart' show CustomSourceService;
import '../../../custom_source/presentation/pages/custom_source_search_page.dart';
import '../../../custom_source/presentation/pages/leaderboard_page.dart';

/// 自定义音源页面 - 替换原来的歌单页面
class CustomSourcePage extends ConsumerStatefulWidget {
  const CustomSourcePage({super.key});

  @override
  ConsumerState<CustomSourcePage> createState() => _CustomSourcePageState();
}

class _CustomSourcePageState extends ConsumerState<CustomSourcePage> {
  
  @override
  void initState() {
    super.initState();
    // 音源已在服务初始化时自动加载
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sources = ref.watch(customSourceProvider);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.indigo.shade900, Colors.purple.shade900]
                : [Colors.indigo.shade100, Colors.purple.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              _buildHeader(isDarkMode),
              
              // 音源列表
              Expanded(
                child: sources.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : _buildSourceList(sources, isDarkMode),
              ),
              
              // 底部操作栏：只在没有音源时显示
              if (sources.isEmpty) _buildBottomBar(isDarkMode),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.source_rounded,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            '自定义音源',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          // 添加音源按钮（始终显示）
          GlassButton(
            onPressed: () => _showImportOptions(),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.add_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          // 排行榜按钮
          GlassButton(
            onPressed: () => _openLeaderboard(),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.leaderboard_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          // 搜索按钮
          GlassButton(
            onPressed: () => _openSearchPage(),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.search_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          // 帮助按钮
          GlassButton(
            onPressed: () => _showHelpDialog(),
            padding: const EdgeInsets.all(10),
            child: Icon(
              Icons.help_outline_rounded,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  /// 显示导入选项对话框
  void _showImportOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('导入音源', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.science_rounded, color: Colors.orange),
                title: const Text('内置测试源'),
                subtitle: const Text('无需网络，一键导入验证功能'),
                onTap: () { Navigator.pop(ctx); _importBuiltinTestSource(); },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file_rounded),
                title: const Text('从 JS 文件导入'),
                onTap: () { Navigator.pop(ctx); _importSource(); },
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('从 URL 导入'),
                onTap: () { Navigator.pop(ctx); _importFromUrl(); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 导入内置测试源（和管理页共用同一服务）
  Future<void> _importBuiltinTestSource() async {
    try {
      final sources = ref.read(customSourceProvider);
      if (sources.any((s) => s.name == '吾爱测试源')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('测试源已存在，无需重复导入'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      final scriptContent = await rootBundle.loadString('assets/test_source.js');
      final source = await ref.read(customSourceProvider.notifier).importFromString(
        scriptContent,
        isLocal: true,
      );
      if (source != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已导入内置测试源: ${source.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  
  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_rounded,
            size: 80,
            color: isDarkMode ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 24),
          Text(
            '暂无音源',
            style: TextStyle(
              fontSize: 20,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '点击下方按钮导入JS音源脚本',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _importSource(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('导入音源'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSourceList(List<MusicSource> sources, bool isDarkMode) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return _buildSourceCard(source, isDarkMode);
      },
    );
  }
  
  Widget _buildSourceCard(MusicSource source, bool isDarkMode) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showSourceDetail(source),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getSourceColor(source.name).withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSourceIcon(source.name),
                      color: _getSourceColor(source.name),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (source.author != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            source.author!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 状态指示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '已启用',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green.shade400,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              
              // 支持的平台
              if (source.actions != null && source.actions!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: source.actions!.map((action) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (isDarkMode ? Colors.white10 : Colors.black.withAlpha(5)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getActionLabel(action),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              
              // 音质支持
              if (source.qualitys != null && source.qualitys!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.high_quality_rounded,
                      size: 14,
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '支持音质: ${source.qualitys!.join(", ")}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDarkMode ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ],
              
              // 操作按钮
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteSource(source),
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: Colors.red.shade400,
                    ),
                    label: Text(
                      '删除',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildBottomBar(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withAlpha(30) : Colors.white.withAlpha(50),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _importSource(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('导入音源'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _importFromFile(),
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('从文件导入'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getSourceColor(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('酷我') || lowerName.contains('kuwo')) {
      return Colors.orange;
    } else if (lowerName.contains('酷狗') || lowerName.contains('kugou')) {
      return Colors.blue;
    } else if (lowerName.contains('网易') || lowerName.contains('netease')) {
      return Colors.red;
    } else if (lowerName.contains('QQ') || lowerName.contains('qq')) {
      return Colors.green;
    } else if (lowerName.contains('咪咕') || lowerName.contains('migu')) {
      return Colors.pink;
    } else if (lowerName.contains('洛雪') || lowerName.contains('lx')) {
      return Colors.cyan;
    }
    return Colors.purple;
  }
  
  IconData _getSourceIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('酷我') || lowerName.contains('kuwo')) {
      return Icons.radio_rounded;
    } else if (lowerName.contains('酷狗') || lowerName.contains('kugou')) {
      return Icons.music_note_rounded;
    } else if (lowerName.contains('网易') || lowerName.contains('netease')) {
      return Icons.library_music_rounded;
    } else if (lowerName.contains('QQ') || lowerName.contains('qq')) {
      return Icons.queue_music_rounded;
    } else if (lowerName.contains('咪咕') || lowerName.contains('migu')) {
      return Icons.album_rounded;
    }
    return Icons.source_rounded;
  }
  
  String _getActionLabel(String action) {
    switch (action) {
      case 'musicUrl':
        return '🎵 播放链接';
      case 'lyric':
        return '📝 歌词';
      case 'pic':
        return '🖼️ 封面';
      default:
        return action;
    }
  }
  
  Future<void> _importSource() async {
    try {
      // 安卓 allowedExtensions: ['js'] 经常无法显示文件，改为 FileType.any
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        int successCount = 0;
        List<String> errors = [];
        
        for (final file in result.files) {
          if (file.path != null) {
            final path = file.path!;
            // 宽松检查：只接受 .js / .txt（无扩展名文件也放行）
            if (!path.toLowerCase().endsWith('.js') &&
                !path.toLowerCase().endsWith('.txt')) {
              errors.add('${file.name}: 请选择 .js 格式文件');
              continue;
            }
            try {
              final source = await ref.read(customSourceProvider.notifier).importFromFile(
                File(path),
              );
              if (source != null) {
                successCount++;
              } else {
                errors.add('${file.name}: 导入返回null');
              }
            } catch (e) {
              errors.add('${file.name}: $e');
            }
          }
        }
        
        if (mounted) {
          String message = '成功导入 $successCount 个音源';
          if (errors.isNotEmpty) {
            message += '\n失败: ${errors.join("\n")}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: Duration(seconds: errors.isEmpty ? 2 : 5),
              backgroundColor: errors.isEmpty ? null : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _importFromFile() async {
    await _importSource();
  }

  Future<void> _importFromUrl() async {
    final urlCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('从 URL 导入音源'),
        content: TextField(
          controller: urlCtrl,
          decoration: const InputDecoration(
            labelText: '音源 JS 文件 URL',
            hintText: 'https://example.com/source.js',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),
        ],
      ),
    );

    if (confirmed == true && urlCtrl.text.isNotEmpty && mounted) {
      try {
        final source = await ref.read(customSourceProvider.notifier).importFromUrl(urlCtrl.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已导入音源: ${source?.name ?? "未知"}')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('导入失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  
  void _deleteSource(MusicSource source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除音源'),
        content: Text('确定要删除 "${source.name}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(customSourceProvider.notifier).removeSource(source.id);
              Navigator.pop(ctx);
            },
            child: Text(
              '删除',
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showSourceDetail(MusicSource source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                source.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (source.description != null) ...[
                const SizedBox(height: 8),
                Text(
                  source.description!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildDetailRow('作者', source.author ?? '未知'),
              _buildDetailRow('版本', source.version ?? '1'),
              if (source.actions != null)
                _buildDetailRow('功能', source.actions!.join(', ')),
              if (source.qualitys != null)
                _buildDetailRow('音质', source.qualitys!.join(', ')),
              if (source.homepage != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    // TODO: 打开主页链接
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('查看主页'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于自定义音源'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('自定义音源支持导入洛雪音乐、六音等JS音源脚本。'),
            SizedBox(height: 16),
            Text('支持的格式:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 洛雪音乐 JS 音源脚本'),
            Text('• 六音音源脚本'),
            SizedBox(height: 16),
            Text('功能:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('• 获取播放链接'),
            Text('• 获取歌词'),
            Text('• 获取封面图片'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
  
  /// 打开搜索页面
  void _openSearchPage() {
    final sources = ref.read(customSourceProvider);
    final enabledSources = sources.where((s) => s.isEnabled).toList();
    
    if (enabledSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先导入并启用音源'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomSourceSearchPage(),
      ),
    );
  }
  
  /// 打开排行榜页面
  void _openLeaderboard() {
    final sources = ref.read(customSourceProvider);
    final enabledSources = sources.where((s) => s.isEnabled).toList();
    
    if (enabledSources.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先导入并启用音源'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const LeaderboardPage(),
      ),
    );
  }
}
