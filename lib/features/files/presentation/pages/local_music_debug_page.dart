import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/navigation/navigation_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../data/models/track.dart';
import '../../service/file_service_debug.dart';
import '../providers/file_provider.dart';

/// 调试版本地音乐页面
class LocalMusicDebugPage extends ConsumerStatefulWidget {
  const LocalMusicDebugPage({super.key});

  @override
  ConsumerState<LocalMusicDebugPage> createState() => _LocalMusicDebugPageState();
}

class _LocalMusicDebugPageState extends ConsumerState<LocalMusicDebugPage> {
  String _searchQuery = '';
  String _currentPath = '';
  bool _isInFolder = false;
  final List<String> _selectedFolders = [];
  bool _showDebugLog = false;

  @override
  Widget build(BuildContext context) {
    final fileService = ref.watch(fileServiceProvider);
    final scanResult = ref.watch(scanResultProvider);
    final tracks = ref.watch(tracksProvider);

    return LiquidBackground(
      child: SafeArea(
        child: Column(
          children: [
            // ─── 顶部标题栏 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isInFolder)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _goBack,
                        ),
                      Expanded(
                        child: Text(
                          _isInFolder ? '音乐文件夹' : '本地音乐 (调试模式)',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // 调试日志开关
                      IconButton(
                        icon: Icon(
                          _showDebugLog ? Icons.bug_report : Icons.bug_report_outlined,
                          color: _showDebugLog ? Colors.red : Colors.grey,
                        ),
                        onPressed: () => setState(() => _showDebugLog = !_showDebugLog),
                        tooltip: '查看调试日志',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: Colors.grey.shade600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: '搜索歌曲、歌手...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (value) => setState(() => _searchQuery = value),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () => setState(() => _searchQuery = ''),
                            iconSize: 20,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── 操作按钮 ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  GlassButton(
                    onPressed: scanResult.isScanning ? null : _startScan,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (scanResult.isScanning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.refresh_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(scanResult.isScanning ? '扫描中...' : '扫描音乐'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 检查权限按钮
                  GlassButton(
                    onPressed: _checkPermission,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.security, size: 18),
                        const SizedBox(width: 8),
                        Text('检查权限'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${tracks.length} 首歌曲',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        if (scanResult.errorMessage != null)
                          Text(
                            '错误: ${scanResult.errorMessage}',
                            style: TextStyle(fontSize: 11, color: Colors.red),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ─── 扫描进度 ─────────────────────────────────────────────
            if (scanResult.isScanning)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: scanResult.progress,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade300,
                        valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已扫描 ${scanResult.scannedCount} 个文件',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        Text(
                          '${(scanResult.progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            // ─── 调试日志面板 ─────────────────────────────────────────────
            if (_showDebugLog)
              Container(
                height: 200,
                margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.bug_report, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            '调试日志',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              (fileService as dynamic).reset();
                            }),
                            child: Text('清空', style: TextStyle(color: Colors.red, fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: (fileService as dynamic).debugLogs?.length ?? 0,
                        itemBuilder: (context, index) {
                          final log = (fileService as dynamic).debugLogs[index] as String;
                          return Text(
                            log,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              color: log.contains('❌') || log.contains('⚠️')
                                  ? Colors.red.shade300
                                  : log.contains('✅')
                                      ? Colors.green.shade300
                                      : Colors.green.shade200,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // ─── 音乐列表 ─────────────────────────────────────────────
            Expanded(
              child: _buildContent(context, fileService, scanResult, tracks),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startScan() async {
    final fileService = ref.read(fileServiceProvider);
    final hasPermission = await fileService.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要存储权限才能扫描音乐'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    fileService.scanLocalMusic(
      paths: _selectedFolders.isNotEmpty ? _selectedFolders : null,
    );
  }

  Future<void> _checkPermission() async {
    final fileService = ref.read(fileServiceProvider);
    final hasPerm = await fileService.hasPermission();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasPerm ? '✅ 已有存储权限' : '❌ 没有存储权限'),
          backgroundColor: hasPerm ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _goBack() {
    if (_currentPath.isNotEmpty) {
      final parts = _currentPath.split(Platform.pathSeparator);
      parts.removeLast();
      final parentPath = parts.join(Platform.pathSeparator);
      setState(() {
        _currentPath = parentPath;
        _isInFolder = parentPath.isNotEmpty;
      });
      ref.read(fileServiceProvider).browsePath(parentPath);
    }
  }

  Widget _buildContent(BuildContext context, FileService fileService, ScanResult scanResult, List<Track> tracks) {
    if (_searchQuery.isNotEmpty) {
      return _buildTrackList(fileService.searchTracks(_searchQuery));
    }
    return _buildRootView(fileService, scanResult, tracks);
  }

  Widget _buildRootView(FileService fileService, ScanResult scanResult, List<Track> tracks) {
    if (scanResult.isScanning && tracks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在扫描音乐文件...'),
          ],
        ),
      );
    }
    if (tracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              scanResult.isScanning ? '扫描中...' : '暂无音乐，请点击扫描',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            // 调试信息
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('调试信息:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('状态: ${scanResult.state}', style: TextStyle(fontSize: 11)),
                  Text('错误: ${scanResult.errorMessage ?? "无"}', style: TextStyle(fontSize: 11)),
                  Text('扫描文件数: ${scanResult.scannedCount}', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _buildTrackList(tracks);
  }

  Widget _buildTrackList(List<Track> trackList) {
    if (trackList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('没有找到匹配的歌曲', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: trackList.length,
      itemBuilder: (context, index) {
        final track = trackList[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            onTap: () {
              final audioService = ref.read(audioPlayerServiceProvider);
              audioService.playTrack(track, playlist: trackList);
              ref.read(navigationControllerProvider.notifier).goToPlayer();
            },
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.music_note, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${track.artist} • ${track.album}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (track.duration != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _formatDuration(track.duration!),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
