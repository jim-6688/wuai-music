import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../custom_source/services/custom_source_service.dart';
import '../../../custom_source/data/models/music_source.dart';

/// 自定义源导入页面
/// 允许用户导入JS音源脚本用于无损音乐播放
class CustomSourceImportPage extends ConsumerStatefulWidget {
  const CustomSourceImportPage({super.key});

  @override
  ConsumerState<CustomSourceImportPage> createState() =>
      _CustomSourceImportPageState();
}

class _CustomSourceImportPageState
    extends ConsumerState<CustomSourceImportPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _importFromUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showStatus('请输入音源地址', false);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final service = ref.read(customSourceServiceProvider.notifier);
      final source = await service.importFromUrl(url);

      if (source != null) {
        _showStatus('导入成功: ${source.name}', true);
        _urlController.clear();
      } else {
        _showStatus('导入失败: 音源格式错误', false);
      }
    } catch (e) {
      _showStatus('导入失败: $e', false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showStatus(String message, bool success) {
    setState(() {
      _statusMessage = message;
      _isSuccess = success;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sources = ref.watch(customSourceServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('自定义音源导入'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明卡片
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.music_note_rounded,
                          color: Colors.purple.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '关于自定义音源',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '自定义音源用于获取高品质音乐播放源（无损/320K）。\n\n'
                      '• 排行榜数据：使用网易云API获取\n'
                      '• 无损音源：通过JS脚本获取\n\n'
                      '支持的音源格式：洛雪音乐JS脚本、六音源码等',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // URL导入
              const Text(
                '从URL导入',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: '输入JS音源URL地址',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        onPressed: _isLoading ? null : _importFromUrl,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_isLoading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              const Icon(Icons.download_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(_isLoading ? '导入中...' : '导入'),
                          ],
                        ),
                      ),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _isSuccess
                              ? Colors.green.withAlpha(20)
                              : Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: _isSuccess ? Colors.green : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: TextStyle(
                                  color: _isSuccess ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 常用音源
              const Text(
                '推荐音源地址',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildSourcePreset(
                '吾爱Music官方音源',
                '内置全网榜单音源',
                Icons.home_rounded,
                Colors.blue,
              ),
              const SizedBox(height: 8),
              _buildSourcePreset(
                '六音音源',
                '六音源码(内置)',
                Icons.six_ft_apart_rounded,
                Colors.orange,
              ),
              const SizedBox(height: 8),
              _buildSourcePreset(
                'GitHub音源',
                '洛雪音乐/六音等',
                Icons.code_rounded,
                Colors.green,
              ),
              const SizedBox(height: 32),

              // 已导入的音源
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '已导入的音源',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${sources.length} 个',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (sources.isEmpty)
                GlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.library_music_outlined,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '暂无导入的音源',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...sources.map((source) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildSourceCard(source),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourcePreset(
    String name,
    String description,
    IconData icon,
    Color color,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () {
        // 这里可以添加预设音源的导入逻辑
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name 为内置音源，无需导入')),
        );
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green.shade400,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(MusicSource source) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: source.isEnabled
                  ? Colors.green.withAlpha(30)
                  : Colors.grey.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              source.isEnabled ? Icons.check_circle : Icons.pause_circle,
              color: source.isEnabled ? Colors.green : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purple.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'v${source.version}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.purple.shade400,
                        ),
                      ),
                    ),
                    if (source.scriptUrl != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          Uri.parse(source.scriptUrl!).host,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.white54
                                : Colors.black45,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              source.isEnabled
                  ? Icons.toggle_on_rounded
                  : Icons.toggle_off_rounded,
              color: source.isEnabled ? Colors.green : Colors.grey,
              size: 28,
            ),
            onPressed: () {
              ref
                  .read(customSourceServiceProvider.notifier)
                  .toggleSource(source.id);
            },
          ),
        ],
      ),
    );
  }
}
