import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/custom_source_service.dart';
import '../../services/js_engine_service.dart';
import '../../data/models/music_source.dart';

/// 自定义音源管理页面
class CustomSourceManagerPage extends ConsumerStatefulWidget {
  const CustomSourceManagerPage({super.key});

  @override
  ConsumerState<CustomSourceManagerPage> createState() => 
      _CustomSourceManagerPageState();
}

class _CustomSourceManagerPageState 
    extends ConsumerState<CustomSourceManagerPage> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;
  
  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final sources = ref.watch(customSourceServiceProvider);
    final service = ref.read(customSourceServiceProvider.notifier);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? [Colors.indigo.shade900, Colors.purple.shade900]
                : [Colors.blue.shade100, Colors.purple.shade100],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 顶部标题栏
              _buildHeader(isDarkMode),
              
              // 导入按钮
              _buildImportButtons(isDarkMode, service),
              
              // 音源列表
              Expanded(
                child: sources.isEmpty
                    ? _buildEmptyState(isDarkMode)
                    : _buildSourceList(sources, isDarkMode, service),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建顶部标题栏
  Widget _buildHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自定义音源管理',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '导入洛雪音乐、六音等JS音源脚本',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建导入按钮
  Widget _buildImportButtons(bool isDarkMode, CustomSourceService service) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // ── 内置测试源（最显眼，置顶）────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            onTap: _isLoading ? null : () => _importBuiltinTestSource(service),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    color: isDarkMode ? Colors.orange.shade300 : Colors.orange,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '内置测试源',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '无需网络，内置假数据，用于验证功能',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.add_circle_rounded,
                    color: isDarkMode ? Colors.orange.shade300 : Colors.orange,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 长青SVIP音源 ──────────────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            onTap: _isLoading ? null : () => _importChangqingSource(service),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.music_note_rounded,
                    color: isDarkMode ? Colors.purple.shade300 : Colors.purple,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '长青SVIP音源',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '从Downloads目录导入',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.add_circle_rounded,
                    color: isDarkMode ? Colors.purple.shade300 : Colors.purple,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 榜单测试音源 ──────────────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            onTap: _isLoading ? null : () => _importLeaderboardTestSource(service),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.leaderboard_rounded,
                    color: isDarkMode ? Colors.red.shade300 : Colors.red,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '榜单测试音源',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '测试榜单功能（3个榜单）',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.add_circle_rounded,
                    color: isDarkMode ? Colors.red.shade300 : Colors.red,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 全网榜单音源 ──────────────────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            onTap: _isLoading ? null : () => _importAllBoardSource(service),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    color: isDarkMode ? Colors.teal.shade300 : Colors.teal,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全网榜单音源',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '自动获取QQ/网易云/酷狗/酷我榜单',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Icon(
                    Icons.add_circle_rounded,
                    color: isDarkMode ? Colors.teal.shade300 : Colors.teal,
                  ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 本地导入 ───────────────────────────────────────────────
          GlassCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.folder_open_rounded,
                    color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '本地导入',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '从本地文件导入 .js 音源脚本',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // 在线导入
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        color: isDarkMode ? Colors.green.shade300 : Colors.green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '在线导入',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '从URL导入音源脚本',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: '粘贴音源脚本URL',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDarkMode 
                        ? Colors.white.withValues(alpha: 0.1) 
                        : Colors.black.withValues(alpha: 0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        Icons.download_rounded,
                        color: isDarkMode ? Colors.green.shade300 : Colors.green,
                      ),
                      onPressed: _isLoading 
                          ? null 
                          : () => _importFromUrl(service),
                    ),
                  ),
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          
          // 示例链接
          const SizedBox(height: 12),
          _buildExampleLinks(isDarkMode, service),
        ],
      ),
    );
  }
  
  /// 构建示例链接
  Widget _buildExampleLinks(bool isDarkMode, CustomSourceService service) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: isDarkMode ? Colors.orange.shade300 : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '推荐音源',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildExampleLink(
            '六音音源',
            'https://raw.githubusercontent.com/pdone/lx-music-source/main/sixyin/latest.js',
            isDarkMode,
            service,
          ),
          const SizedBox(height: 6),
          _buildExampleLink(
            'Huibq音源',
            'https://fastly.jsdelivr.net/gh/Huibq/keep-alive/render_api.js',
            isDarkMode,
            service,
          ),
        ],
      ),
    );
  }
  
  Widget _buildExampleLink(
    String name,
    String url,
    bool isDarkMode,
    CustomSourceService service,
  ) {
    return InkWell(
      onTap: () {
        _urlController.text = url;
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.link_rounded,
              size: 16,
              color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  color: isDarkMode ? Colors.blue.shade300 : Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 构建空状态
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
          const SizedBox(height: 16),
          Text(
            '暂无音源',
            style: TextStyle(
              fontSize: 18,
              color: isDarkMode ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方按钮导入音源脚本',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 构建音源列表
  Widget _buildSourceList(
    List<MusicSource> sources,
    bool isDarkMode,
    CustomSourceService service,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sources.length,
      itemBuilder: (context, index) {
        final source = sources[index];
        return _buildSourceCard(source, isDarkMode, service);
      },
    );
  }
  
  /// 构建音源卡片
  Widget _buildSourceCard(
    MusicSource source,
    bool isDarkMode,
    CustomSourceService service,
  ) {
    // 获取音源初始化信息
    final initResult = service.getSourceInitResult(source.id);
    final platforms = initResult?.sources.keys.toList() ?? <String>[];
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: Key(source.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.delete_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        onDismissed: (direction) {
          service.removeSource(source.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('已删除: ${source.name}')),
          );
        },
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 图标
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (source.isEnabled 
                          ? Colors.green 
                          : Colors.grey)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.music_note_rounded,
                      color: source.isEnabled 
                          ? (isDarkMode ? Colors.green.shade300 : Colors.green)
                          : (isDarkMode ? Colors.white38 : Colors.black38),
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                source.name,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${source.version}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode 
                                      ? Colors.blue.shade300 
                                      : Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        if (source.description != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            source.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // 开关
                  Switch(
                    value: source.isEnabled,
                    onChanged: (value) {
                      service.toggleSource(source.id);
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
              
              // 解析后的详细信息
              if (platforms.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildParsedInfo(source, platforms, initResult!, isDarkMode),
              ],
              
              const SizedBox(height: 8),
              
              // 底部信息
              Row(
                children: [
                  if (source.author != null) ...[
                    Icon(
                      Icons.person_rounded,
                      size: 14,
                      color: isDarkMode ? Colors.white54 : Colors.black45,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      source.author!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  
                  Icon(
                    source.isLocal 
                        ? Icons.folder_rounded 
                        : Icons.link_rounded,
                    size: 14,
                    color: isDarkMode ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    source.isLocal ? '本地' : '在线',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  
                  const Spacer(),
                  
                  // 支持的操作
                  if (source.actions.isNotEmpty)
                    _buildActionChips(source.actions, isDarkMode),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// 构建解析后的信息
  Widget _buildParsedInfo(
    MusicSource source,
    List<String> platforms,
    LxInitResult initResult,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: isDarkMode ? Colors.green.shade300 : Colors.green,
              ),
              const SizedBox(width: 6),
              Text(
                '已解析',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.green.shade300 : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // 支持的平台
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: platforms.map((platform) {
              final sourceInfo = initResult.sources[platform];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _getPlatformColor(platform).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getPlatformColor(platform).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPlatformIcon(platform),
                      size: 14,
                      color: _getPlatformColor(platform),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sourceInfo?.name ?? _getPlatformName(platform),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _getPlatformColor(platform),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          
          // 音质支持
          if (source.qualitys.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.high_quality_rounded,
                  size: 14,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Text(
                  '音质: ${source.qualitys.join(", ")}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// 获取平台颜色
  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'kw':
        return Colors.orange;
      case 'kg':
        return Colors.blue;
      case 'tx':
        return Colors.green;
      case 'wy':
        return Colors.red;
      case 'mg':
        return Colors.purple;
      case 'local':
        return Colors.grey;
      default:
        return Colors.teal;
    }
  }
  
  /// 获取平台图标
  IconData _getPlatformIcon(String platform) {
    switch (platform) {
      case 'kw':
        return Icons.music_note;
      case 'kg':
        return Icons.headphones;
      case 'tx':
        return Icons.queue_music;
      case 'wy':
        return Icons.album;
      case 'mg':
        return Icons.radio;
      case 'local':
        return Icons.folder_open;
      default:
        return Icons.music_note;
    }
  }
  
  /// 获取平台名称
  String _getPlatformName(String platform) {
    switch (platform) {
      case 'kw':
        return '酷我';
      case 'kg':
        return '酷狗';
      case 'tx':
        return 'QQ音乐';
      case 'wy':
        return '网易云';
      case 'mg':
        return '咪咕';
      case 'local':
        return '本地';
      default:
        return platform.toUpperCase();
    }
  }
  
  /// 构建操作标签
  Widget _buildActionChips(List<String> actions, bool isDarkMode) {
    final actionLabels = {
      'musicUrl': '播放',
      'lyric': '歌词',
      'pic': '封面',
    };
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: actions.take(3).map((action) {
        return Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            actionLabels[action] ?? action,
            style: TextStyle(
              fontSize: 10,
              color: isDarkMode ? Colors.purple.shade200 : Colors.purple.shade700,
            ),
          ),
        );
      }).toList(),
    );
  }
  
  /// 从文件导入
  Future<void> _importFromFile(CustomSourceService service) async {
    try {
      setState(() => _isLoading = true);

      // 安卓上 allowedExtensions: ['js'] 经常无法显示文件
      // 改为 FileType.any，选中后再检查扩展名
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path == null) {
          throw Exception('无法获取文件路径');
        }
        // 宽松检查：允许 .js 以及无扩展名的文本文件
        if (!path.toLowerCase().endsWith('.js') &&
            !path.toLowerCase().endsWith('.txt')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('请选择 .js 格式的音源脚本文件'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        final file = File(path);
        final source = await service.importFromFile(file);

        if (source != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('导入成功: ${source.name}'),
              backgroundColor: Colors.green,
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
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  /// 导入内置测试音源（从 assets 读取，无需选文件）
  Future<void> _importBuiltinTestSource(CustomSourceService service) async {
    try {
      setState(() => _isLoading = true);

      // 检查是否已导入过测试源（按名称判断）
      final sources = ref.read(customSourceServiceProvider);
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

      // 从 asset bundle 读取脚本
      final scriptContent = await rootBundle.loadString('assets/test_source.js');
      final source = await service.importFromString(scriptContent, isLocal: true);

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
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 导入榜单测试音源（从 assets 读取）
  Future<void> _importLeaderboardTestSource(CustomSourceService service) async {
    try {
      setState(() => _isLoading = true);

      // 检查是否已导入过
      final sources = ref.read(customSourceServiceProvider);
      if (sources.any((s) => s.name == '榜单测试音源')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('榜单测试音源已存在，无需重复导入'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 从 asset bundle 读取脚本
      final scriptContent = await rootBundle.loadString('assets/leaderboard_test.js');
      final source = await service.importFromString(scriptContent, isLocal: true);

      if (source != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已导入榜单测试音源: ${source.name}'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 导入全网榜单音源（从 assets 读取）
  Future<void> _importAllBoardSource(CustomSourceService service) async {
    try {
      setState(() => _isLoading = true);

      // 检查是否已导入过
      final sources = ref.read(customSourceServiceProvider);
      if (sources.any((s) => s.name == '全网榜单')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('全网榜单音源已存在，无需重复导入'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 从 asset bundle 读取脚本
      final scriptContent = await rootBundle.loadString('assets/all_board_source.js');
      final source = await service.importFromString(scriptContent, isLocal: true);

      if (source != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已导入全网榜单音源: ${source.name}'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 导入长青音源（从 assets 读取）
  Future<void> _importChangqingSource(CustomSourceService service) async {
    try {
      setState(() => _isLoading = true);

      // 检查是否已导入过长青音源
      final sources = ref.read(customSourceServiceProvider);
      if (sources.any((s) => s.name == '长青SVIP音源')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('长青音源已存在，无需重复导入'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 从 asset bundle 读取脚本
      final scriptContent = await rootBundle.loadString('assets/changqing.js');
      final source = await service.importFromString(scriptContent, isLocal: true);

      if (source != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 已导入长青音源: ${source.name}'),
            backgroundColor: Colors.green,
          ),
        );
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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 从URL导入
  Future<void> _importFromUrl(CustomSourceService service) async {
    final url = _urlController.text.trim();
    
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入音源URL')),
      );
      return;
    }
    
    try {
      setState(() => _isLoading = true);
      
      final source = await service.importFromUrl(url);
      
      if (source != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入成功: ${source.name}'),
            backgroundColor: Colors.green,
          ),
        );
        _urlController.clear();
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
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
