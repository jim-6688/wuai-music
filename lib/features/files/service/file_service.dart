import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equatable/equatable.dart';
import '../data/models/track.dart';

/// 文件扫描状态枚举
enum ScanState { idle, scanning, completed, error }

/// 文件夹/文件项
class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedTime;

  const FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.size,
    this.modifiedTime,
  });
}

/// 扫描结果数据类
class ScanResult extends Equatable {
  final ScanState state;
  final double progress;
  final int scannedCount;
  final int musicCount;
  final List<Track> tracks;
  final String? errorMessage;
  final int? elapsedTime;

  const ScanResult({
    this.state = ScanState.idle,
    this.progress = 0.0,
    this.scannedCount = 0,
    this.musicCount = 0,
    this.tracks = const [],
    this.errorMessage,
    this.elapsedTime,
  });

  bool get isScanning => state == ScanState.scanning;
  bool get isCompleted => state == ScanState.completed;

  ScanResult copyWith({
    ScanState? state, double? progress, int? scannedCount,
    int? musicCount, List<Track>? tracks, String? errorMessage, int? elapsedTime,
  }) {
    return ScanResult(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      scannedCount: scannedCount ?? this.scannedCount,
      musicCount: musicCount ?? this.musicCount,
      tracks: tracks ?? this.tracks,
      errorMessage: errorMessage ?? this.errorMessage,
      elapsedTime: elapsedTime ?? this.elapsedTime,
    );
  }

  @override
  List<Object?> get props => [state, progress, scannedCount, musicCount, tracks, errorMessage, elapsedTime];
}

/// 本地文件服务
class FileService extends ChangeNotifier {
  ScanResult _scanResult = const ScanResult();
  List<FileItem> _currentFiles = [];
  List<FileItem> _musicFolders = [];
  String _currentPath = '';
  SharedPreferences? _prefs;

  // on_audio_query 实例（线程安全）
  final OnAudioQuery _audioQuery = OnAudioQuery();

  ScanResult get scanResult => _scanResult;
  List<Track> get tracks => _scanResult.tracks;
  List<FileItem> get currentFiles => _currentFiles;
  List<FileItem> get musicFolders => _musicFolders;
  String get currentPath => _currentPath;
  int get musicCount => _scanResult.musicCount;

  FileService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    // 应用启动时自动加载保存的音乐
    await _loadSavedTracks();
  }

  static const _audioExts = {
    '.mp3', '.m4a', '.aac', '.flac', '.wav', '.wma', '.ogg', '.opus',
    '.aiff', '.alac', '.ape', '.mpc', '.wv', '.tta',
  };

  // ─── 权限请求 ─────────────────────────────────────────────────────────

  /// 请求音频访问权限
  /// Android 13+ 需要 READ_MEDIA_AUDIO
  /// Android 12 及以下需要 READ_EXTERNAL_STORAGE
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) return true;

    try {
      // Android 13+
      var result = await Permission.audio.request();
      if (result.isGranted) return true;

      // Android 12-
      result = await Permission.storage.request();
      if (result.isGranted) return true;

      // 已拒绝时引导用户去设置
      if (result.isPermanentlyDenied) {
        if (kDebugMode) print('⚠️ 权限被永久拒绝，引导用户去设置');
        await openAppSettings();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 权限请求异常: $e');
    }
    return false;
  }

  /// 检查是否已获得权限
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    final audio = await Permission.audio.status;
    final storage = await Permission.storage.status;
    return audio.isGranted || storage.isGranted;
  }

  // ─── 主扫描入口 ──────────────────────────────────────────────────────

  Future<void> scanLocalMusic({List<String>? paths, bool recursive = true}) async {
    if (_scanResult.isScanning) return;

    _updateScanState(
      state: ScanState.scanning,
      progress: 0.0,
      tracks: [],
      scannedCount: 0,
      musicCount: 0,
    );

    // 请求权限（失败也继续）
    await requestPermissions();

    final startTime = DateTime.now();
    final foundTracks = <Track>[];
    int totalScanned = 0;

    try {
      // 优先使用用户指定的路径（如优盘路径）
      if (paths != null && paths.isNotEmpty) {
        if (kDebugMode) print('📂 使用用户指定路径: $paths');
        for (final scanPath in paths) {
          if (await Directory(scanPath).exists()) {
            final (tracks, count) = await _scanDirectory(scanPath, recursive);
            foundTracks.addAll(tracks);
            totalScanned += count;
            _reportProgress(foundTracks, totalScanned);
          } else {
            if (kDebugMode) print('⚠️ 路径不存在: $scanPath');
          }
        }
      } else if (Platform.isAndroid) {
        final isTV = await _isAndroidTV();

        if (isTV) {
          // TV 端：文件系统扫描
          if (kDebugMode) print('📺 TV 模式：文件系统扫描');
          final tvPaths = await _getTVScanPaths();
          if (kDebugMode) print('📺 TV 扫描路径: $tvPaths');
          for (final scanPath in tvPaths) {
            if (await Directory(scanPath).exists()) {
              final (tracks, count) = await _scanDirectory(scanPath, recursive);
              foundTracks.addAll(tracks);
              totalScanned += count;
              _reportProgress(foundTracks, totalScanned);
            }
          }
        } else {
          // 手机端：优先 on_audio_query 查询 MediaStore
          if (kDebugMode) print('📱 手机模式：MediaStore 查询');
          final mediaTracks = await _scanViaOnAudioQuery();
          foundTracks.addAll(mediaTracks);
          totalScanned = mediaTracks.length;
          _reportProgress(foundTracks, totalScanned);

          // MediaStore 为空时，文件系统兜底
          if (foundTracks.isEmpty) {
            if (kDebugMode) print('📂 MediaStore 无结果，尝试文件系统');
            final phonePaths = _getPhoneScanPaths();
            for (final scanPath in phonePaths) {
              if (await Directory(scanPath).exists()) {
                final (tracks, count) = await _scanDirectory(scanPath, recursive);
                foundTracks.addAll(tracks);
                totalScanned += count;
                _reportProgress(foundTracks, totalScanned);
              }
            }
          }
        }
      } else {
        // 非 Android：文件系统扫描
        final doc = await getApplicationDocumentsDirectory();
        final scanPaths = [p.join(doc.path, 'Music')];
        for (final scanPath in scanPaths) {
          if (await Directory(scanPath).exists()) {
            final (tracks, count) = await _scanDirectory(scanPath, recursive);
            foundTracks.addAll(tracks);
            totalScanned += count;
            _reportProgress(foundTracks, totalScanned);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ 扫描异常: $e');
      _updateScanState(state: ScanState.error, errorMessage: '扫描失败: $e');
      return;
    }

    final elapsed = DateTime.now().difference(startTime).inMilliseconds;

    _updateScanState(
      state: ScanState.completed,
      progress: 1.0,
      scannedCount: totalScanned,
      musicCount: foundTracks.length,
      tracks: foundTracks,
      elapsedTime: elapsed,
    );

    if (kDebugMode) {
      print('✅ 扫描完成: ${foundTracks.length} 首 / $totalScanned 文件 / ${elapsed}ms');
    }

    // 扫描完成后自动保存
    await saveTracks();
  }

  /// 每 20 个文件更新一次进度
  void _reportProgress(List<Track> foundTracks, int totalScanned) {
    _updateScanState(
      progress: totalScanned > 0
          ? (foundTracks.length / (totalScanned * 2)).clamp(0.05, 0.95)
          : 0.5,
      scannedCount: totalScanned,
      musicCount: foundTracks.length,
      tracks: List.from(foundTracks),
    );
  }

  // ─── on_audio_query 扫描（手机端）────────────────────────────────────

  /// 使用 on_audio_query 查询 MediaStore，获取所有音频文件
  Future<List<Track>> _scanViaOnAudioQuery() async {
    try {
      // 查询所有音频（按名称升序，防止一次性返回太多）
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      if (kDebugMode) print('📱 on_audio_query 返回: ${songs.length} 首');

      if (songs.isEmpty) return [];

      return songs.map((song) {
        // song.artist / song.album 返回 String?，空时为 ''
        final artistRaw = song.artist ?? '';
        final albumRaw  = song.album  ?? '';
        String artist = artistRaw.isNotEmpty && artistRaw != '<unknown>'
            ? artistRaw : '未知艺术家';
        String album  = albumRaw.isNotEmpty  && albumRaw  != '<unknown>'
            ? albumRaw  : '未知专辑';

        // 文件路径 - on_audio_query 返回完整文件路径或 content:// URI
        // 直接使用 song.data，just_audio 支持 content:// 和 file://
        final filePath = song.data;
        
        // 确保路径不为空（song.data 可能为 null）
        if (filePath == null || filePath.isEmpty) return null;

        // 专辑封面通过 album ID 获取
        // 在 UI 层通过 on_audio_query 的 queryArtwork 方法获取
        // 这里先不设置，在歌词页/播放器页通过歌曲 ID 查询

        return Track(
          id: song.id.toString(),
          filePath: filePath,
          title: song.title.isNotEmpty ? song.title : p.basenameWithoutExtension(filePath),
          artist: artist,
          album: album,
          duration: song.duration != null && song.duration! > 0
              ? Duration(milliseconds: song.duration!)
              : null,
        );
      }).whereType<Track>().toList();

    } catch (e) {
      if (kDebugMode) print('❌ on_audio_query 查询失败: $e');
      return [];
    }
  }

  // ─── 文件系统扫描（TV / 兜底）───────────────────────────────────────

  Future<(List<Track>, int)> _scanDirectory(String scanPath, bool recursive) async {
    final tracks = <Track>[];
    int totalFiles = 0;

    try {
      await for (final entity in Directory(scanPath).list(recursive: recursive, followLinks: false)) {
        if (entity is! File) continue;
        totalFiles++;

        final ext = p.extension(entity.path).toLowerCase();
        if (_audioExts.contains(ext)) {
          tracks.add(_createTrackFromPath(entity.path));
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 扫描目录失败: $scanPath - $e');
    }

    return (tracks, totalFiles);
  }

  // ─── TV 端扫描路径 ─────────────────────────────────────────────────

  Future<List<String>> _getTVScanPaths() async {
    final roots = <String>[];

    // 常见的外部存储挂载点（USB、SD卡等）
    final mountPoints = [
      '/storage',
      '/mnt/media_rw',
      '/mnt/usb',
      '/mnt/usb_storage',
      '/mnt/sdcard',
      '/mnt/external_sd',
      '/mnt/extSdCard',
      '/mnt/sda1',
      '/mnt/sdb1',
      '/mnt/sdc1',
      '/mnt/udisk',
      '/mnt/usbdisk',
      '/mnt/usbhost',
      '/mnt/usbhost1',
      '/mnt/usbhost2',
      '/mnt/usbhost3',
      '/storage/usbdisk',
      '/storage/udisk',
      '/storage/external',
      '/storage/sdcard1',
      '/storage/sdcard0',
    ];

    // 扫描所有挂载点
    for (final root in mountPoints) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list()) {
          if (entity is! Directory) continue;
          final name = p.basename(entity.path);
          // 排除系统目录
          if (name == 'emulated' || 
              name == 'self' || 
              name.startsWith('.') ||
              name == 'Android') continue;
          
          roots.add(entity.path);
          if (kDebugMode) print('📺 发现存储设备: ${entity.path}');
          
          // 同时添加常见子目录
          for (final sub in ['Music', 'music', 'Audio', 'audio', 'MP3', 'mp3']) {
            final subPath = '${entity.path}/$sub';
            if (await Directory(subPath).exists()) {
              roots.add(subPath);
              if (kDebugMode) print('📺 发现音乐目录: $subPath');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ 扫描挂载点失败: $root - $e');
      }
    }

    // 兜底：内部存储
    if (roots.isEmpty) {
      roots.addAll(_getPhoneScanPaths());
    }

    return roots.toSet().toList();
  }

  List<String> _getPhoneScanPaths() => [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/music',
    '/storage/emulated/0/Downloads',
    '/sdcard/Music',
    '/sdcard/music',
    '/sdcard/Downloads',
  ];

  // ─── TV 检测 ──────────────────────────────────────────────────────

  Future<bool> _isAndroidTV() async {
    try {
      for (final f in [
        '/system/etc/permissions/android.hardware.type.television.xml',
        '/system/etc/permissions/android.software.leanback.xml',
      ]) {
        if (await File(f).exists()) return true;
      }
      final bp = File('/system/build.prop');
      if (await bp.exists()) {
        final c = await bp.readAsString();
        if (c.contains('ro.build.characteristics=tv') ||
            c.contains('android.hardware.type.television')) return true;
      }
    } catch (_) {}
    return false;
  }

  // ─── 文件浏览 ──────────────────────────────────────────────────────

  Future<void> browsePath(String path) async {
    try {
      _currentPath = path;
      _currentFiles = [];
      _musicFolders = [];

      final dir = Directory(path);
      if (!await dir.exists()) return;

      await for (final entity in dir.list()) {
        final stat = await entity.stat();
        final ext = p.extension(entity.path).toLowerCase();

        if (entity is Directory) {
          _musicFolders.add(FileItem(
            name: p.basename(entity.path),
            path: entity.path,
            isDirectory: true,
            modifiedTime: stat.modified,
          ));
        } else if (_audioExts.contains(ext)) {
          _currentFiles.add(FileItem(
            name: p.basename(entity.path),
            path: entity.path,
            isDirectory: false,
            size: stat.size,
            modifiedTime: stat.modified,
          ));
        }
      }

      _musicFolders.sort((a, b) => a.name.compareTo(b.name));
      _currentFiles.sort((a, b) => a.name.compareTo(b.name));
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ 浏览失败: $e');
    }
  }

  Future<void> goBack() async {
    if (_currentPath.isEmpty) return;
    await browsePath(p.dirname(_currentPath));
  }

  Future<List<Track>> scanFolder(String path) async {
    final tracks = <Track>[];
    try {
      if (await Directory(path).exists()) {
        final (t, _) = await _scanDirectory(path, false);
        tracks.addAll(t);
      }
    } catch (e) {
      if (kDebugMode) print('❌ 扫描文件夹失败: $e');
    }
    return tracks;
  }

  // ─── Track 创建 ───────────────────────────────────────────────────

  Track _createTrackFromPath(String filePath) {
    final filename = p.basenameWithoutExtension(filePath);
    final parts = filename.split(' - ');
    final title = parts.length >= 2 ? parts.sublist(1).join(' - ').trim() : filename;
    final artist = parts.length >= 2 ? parts[0].trim() : '未知艺术家';

    return Track(
      id: filePath.hashCode.toString(),
      filePath: filePath,
      title: title,
      artist: artist,
      album: p.basename(p.dirname(filePath)),
      duration: null,
    );
  }

  // ─── 搜索 / 分组 ──────────────────────────────────────────────────

  List<Track> searchTracks(String query) {
    if (query.isEmpty) return _scanResult.tracks;
    final q = query.toLowerCase();
    return _scanResult.tracks.where((t) =>
      t.title.toLowerCase().contains(q) ||
      t.artist.toLowerCase().contains(q) ||
      t.album.toLowerCase().contains(q),
    ).toList();
  }

  Map<String, List<Track>> groupByArtist() {
    final g = <String, List<Track>>{};
    for (final t in _scanResult.tracks) {
      g.putIfAbsent(t.artist, () => []).add(t);
    }
    return g;
  }

  Map<String, List<Track>> groupByAlbum() {
    final g = <String, List<Track>>{};
    for (final t in _scanResult.tracks) {
      g.putIfAbsent(t.album, () => []).add(t);
    }
    return g;
  }

  // ─── 内部状态 ─────────────────────────────────────────────────────

  void _updateScanState({
    ScanState? state, double? progress, int? scannedCount,
    int? musicCount, List<Track>? tracks, String? errorMessage, int? elapsedTime,
  }) {
    _scanResult = _scanResult.copyWith(
      state: state, progress: progress, scannedCount: scannedCount,
      musicCount: musicCount, tracks: tracks, errorMessage: errorMessage, elapsedTime: elapsedTime,
    );
    notifyListeners();
  }

  void reset() {
    _scanResult = const ScanResult();
    _currentFiles = [];
    _musicFolders = [];
    _currentPath = '';
    notifyListeners();
  }

  // ─── 持久化存储 ───────────────────────────────────────────────────

  /// 保存扫描结果到本地
  Future<void> saveTracks() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    try {
      final tracksJson = _scanResult.tracks.map((t) => t.toJson()).toList();
      final jsonString = jsonEncode(tracksJson);
      await _prefs!.setString(_tracksStorageKey, jsonString);
      if (kDebugMode) print('💾 已保存 ${tracksJson.length} 首音乐');
    } catch (e) {
      if (kDebugMode) print('❌ 保存音乐失败: $e');
    }
  }

  /// 加载保存的音乐列表
  Future<void> _loadSavedTracks() async {
    if (_prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
    try {
      final jsonString = _prefs!.getString(_tracksStorageKey);
      if (jsonString == null || jsonString.isEmpty) {
        if (kDebugMode) print('📂 没有保存的音乐数据');
        return;
      }
      
      final List<dynamic> tracksJson = jsonDecode(jsonString);
      final tracks = tracksJson.map((j) => Track.fromJson(j)).toList();
      
      _updateScanState(
        state: ScanState.completed,
        progress: 1.0,
        musicCount: tracks.length,
        tracks: tracks,
      );
      
      if (kDebugMode) print('📂 已加载 ${tracks.length} 首保存的音乐');
    } catch (e) {
      if (kDebugMode) print('❌ 加载音乐失败: $e');
    }
  }

  static const String _tracksStorageKey = 'saved_music_tracks';

  // ─── 美化结果回写 ──────────────────────────────────────────────────────────

  /// 将曲库美化结果批量回写到本地音乐列表
  /// [results] key = filePath, value = { title, artist, album, albumArt }
  Future<int> applyBeautifyResults(Map<String, Map<String, String?>> results) async {
    if (results.isEmpty) return 0;

    int updatedCount = 0;
    final newTracks = _scanResult.tracks.map((track) {
      final patch = results[track.filePath];
      if (patch == null) return track;

      updatedCount++;
      return track.copyWith(
        title:    patch['title']    ?? track.title,
        artist:   patch['artist']   ?? track.artist,
        album:    patch['album']    ?? track.album,
        albumArt: patch['albumArt'] ?? track.albumArt,
      );
    }).toList();

    _updateScanState(tracks: newTracks, musicCount: newTracks.length);

    // 持久化
    await saveTracks();

    if (kDebugMode) print('✅ 已将 $updatedCount 首曲目的元数据回写到音乐库');
    return updatedCount;
  }
}
