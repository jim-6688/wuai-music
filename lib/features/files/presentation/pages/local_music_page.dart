import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../../shared/navigation/navigation_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../nas/presentation/pages/nas_devices_page.dart';
import '../../../nas/presentation/pages/nas_config_sync_page.dart';
import '../../../../core/providers/player_integration_provider.dart';
import '../../data/models/track.dart';
import '../../service/file_service.dart';
import '../providers/file_provider.dart';
import '../../../../core/providers/unified_tracks_provider.dart';

class LocalMusicPage extends ConsumerStatefulWidget {
  const LocalMusicPage({super.key});

  @override
  ConsumerState<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends ConsumerState<LocalMusicPage> {
  String _searchQuery = '';
  String _currentPath = '';
  bool _isInFolder = false;

  // 用户选择的文件夹列表
  final List<String> _selectedFolders = [];

  // ─── 选择文件夹 ────────────────────────────────────────────────────────────

  Future<void> _pickFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择音乐文件夹',
      );
      if (result != null && !_selectedFolders.contains(result)) {
        setState(() => _selectedFolders.add(result));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件夹失败: $e')),
        );
      }
    }
  }

  void _removeFolder(String path) {
    setState(() => _selectedFolders.remove(path));
  }

  // ─── 开始扫描（传入选中的文件夹） ─────────────────────────────────────────

  Future<void> _startScan() async {
    final fileService = ref.read(fileServiceProvider);
    final hasPermission = await fileService.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要存储权限才能扫描音乐')),
        );
      }
      return;
    }
    // 传入用户选择的文件夹，为空则让服务自行决定扫描路径
    fileService.scanLocalMusic(
      paths: _selectedFolders.isNotEmpty ? _selectedFolders : null,
    );
  }

  void _onFolderTap(String path) {
    setState(() {
      _currentPath = path;
      _isInFolder = true;
    });
    ref.read(fileServiceProvider).browsePath(path);
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

  @override
  Widget build(BuildContext context) {
    final fileService = ref.watch(fileServiceProvider);
    final scanResult = ref.watch(scanResultProvider);
    final tracks = ref.watch(unifiedTracksProvider);
    final localTrackCount = ref.watch(localTrackCountProvider);
    final nasTrackCount = ref.watch(nasTrackCountProvider);
    // 确保 NAS 播放器集成已注册（onNasPathDetected 回调）
    ref.watch(playerIntegrationProvider);

    return LiquidBackground(
      child: SafeArea(
        child: Column(
          children: [
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
                          _isInFolder ? '音乐文件夹' : '本地音乐',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
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
            // 操作按钮行 - 四个功能按钮等宽单行排列
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // 扫描音乐
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                    child: _ActionButton(
                      icon: scanResult.isScanning
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: scanResult.isScanning ? '扫描中' : '扫描',
                      onTap: scanResult.isScanning ? null : _startScan,
                      accentColor: Theme.of(context).primaryColor,
                    ),
                  ),
                  // 选择文件夹
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                    child: _ActionButton(
                      icon: const Icon(Icons.folder_open_rounded, size: 16),
                      label: '文件夹',
                      onTap: scanResult.isScanning ? null : _pickFolder,
                      accentColor: Colors.amber.shade600,
                    ),
                  ),
                  // NAS
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                    child: _ActionButton(
                      icon: Icon(Icons.storage_rounded, size: 16, color: Colors.blue.shade600),
                      label: 'NAS',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NasDevicesPage()),
                      ),
                      accentColor: Colors.blue.shade600,
                    ),
                  ),
                  // 同步 TV
                  SizedBox(
                    width: (MediaQuery.of(context).size.width - 32 - 24) / 4,
                    child: _ActionButton(
                      icon: Icon(Icons.tv_rounded, size: 16, color: Colors.purple.shade600),
                      label: '同步TV',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NasConfigSyncPage()),
                      ),
                      accentColor: Colors.purple.shade600,
                    ),
                  ),
                ],
              ),
            ),
            // 歌曲数量 & 状态提示（独立一行，紧凑）
            if (tracks.isNotEmpty || _currentPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.library_music_rounded, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      tracks.isNotEmpty
                          ? '${tracks.length} 首已保存'
                          : '浏览中',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                    if (nasTrackCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'NAS $nasTrackCount',
                          style: TextStyle(fontSize: 10, color: Colors.blue.shade600),
                        ),
                      ),
                    ],
                    if (localTrackCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '本地 $localTrackCount',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            // 已选文件夹 Chip 列表
            if (_selectedFolders.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '已选文件夹 (${_selectedFolders.length}) — 点击 × 移除',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: _selectedFolders.map((path) {
                        final name = path.split(Platform.pathSeparator).last;
                        return Chip(
                          avatar: const Icon(Icons.folder, size: 16),
                          label: Text(name, style: const TextStyle(fontSize: 12)),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => _removeFolder(path),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

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
            const SizedBox(height: 16),
            Expanded(
              child: _buildContent(context, fileService, scanResult, tracks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, FileService fileService, ScanResult scanResult, List<Track> tracks) {
    if (_searchQuery.isNotEmpty) {
      return _buildTrackList(fileService.searchTracks(_searchQuery));
    }
    if (_isInFolder) {
      return _buildFolderView(fileService);
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
              '暂无音乐',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '请选择文件夹或点击扫描按钮添加音乐',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return _buildTrackList(tracks);
  }

  Widget _buildFolderView(FileService fileService) {
    final folders = fileService.musicFolders;
    final files = fileService.currentFiles;

    if (folders.isEmpty && files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_off_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('该文件夹暂无音乐文件'),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final result = await fileService.scanFolder(_currentPath);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('扫描到 ${result.length} 首歌曲')),
                  );
                }
              },
              icon: const Icon(Icons.music_note),
              label: const Text('扫描该文件夹'),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        if (folders.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '📁 文件夹',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          ...folders.map((folder) => _FolderTile(
            name: folder.name,
            path: folder.path,
            onTap: () => _onFolderTap(folder.path),
          )),
          const SizedBox(height: 16),
        ],
        if (files.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '🎵 音频文件',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
          ),
          ...files.map((file) => _FileTile(file: file)),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: GlassButton(
            onPressed: () async {
              final result = await fileService.scanFolder(_currentPath);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('扫描到 ${result.length} 首歌曲')),
                );
              }
            },
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.music_note),
                const SizedBox(width: 8),
                Text('扫描该文件夹 (${files.length} 个文件)'),
              ],
            ),
          ),
        ),
      ],
    );
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
              // 不在这里弹 SnackBar，播放器自己处理结果
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
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () {},
                  color: Colors.grey,
                  iconSize: 20,
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

// ─── 操作按钮 ──────────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback? onTap;
  final Color accentColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabled = onTap == null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: disabled
              ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04))
              : accentColor.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? Colors.transparent
                : accentColor.withValues(alpha: isDark ? 0.35 : 0.25),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                color: disabled
                    ? Colors.grey.shade400
                    : accentColor,
                size: 18,
              ),
              child: icon,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: disabled
                    ? Colors.grey.shade400
                    : (isDark ? accentColor.withValues(alpha: 0.85) : accentColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _FolderTile extends StatelessWidget {
  final String name;
  final String path;
  final VoidCallback onTap;

  const _FolderTile({required this.name, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_rounded, color: Colors.amber),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    path,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _FileTile extends ConsumerWidget {
  final FileItem file;

  const _FileTile({required this.file});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GlassCard(
        onTap: () {
          final track = Track(
            id: file.path,
            filePath: file.path,
            title: file.name,
            artist: '未知艺术家',
            album: '未知专辑',
          );
          final audioService = ref.read(audioPlayerServiceProvider);
          audioService.playTrack(track);
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
                    file.name,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (file.size != null)
                    Text(
                      _formatSize(file.size!),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.play_circle_filled_rounded, color: Theme.of(context).primaryColor),
              onPressed: () {
                final track = Track(
                  id: file.path,
                  filePath: file.path,
                  title: file.name,
                  artist: '未知艺术家',
                  album: '未知专辑',
                );
                ref.read(audioPlayerServiceProvider).playTrack(track);
                ref.read(navigationControllerProvider.notifier).goToPlayer();
              },
              iconSize: 32,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
