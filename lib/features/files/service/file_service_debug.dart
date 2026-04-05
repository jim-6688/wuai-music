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

/// 本地文件服务 - 调试增强版
class FileService extends ChangeNotifier {
  ScanResult _scanResult = const ScanResult();
  List<FileItem> _currentFiles = [];
  List<FileItem> _musicFolders = [];
  String _currentPath = '';
  SharedPreferences? _prefs;

  // on_audio_query 实例（线程安全）
  final OnAudioQuery _audioQuery = OnAudioQuery();

  // 调试日志
  final List<String> _debugLogs = [];
  List<String> get debugLogs => _debugLogs;

  ScanResult get scanResult => _scanResult;
  List<Track> get tracks => _scanResult.tracks;
  List<FileItem> get currentFiles => _currentFiles;
  List<FileItem> get musicFolders => _musicFolders;
  String get currentPath => _currentPath;
  int get musicCount => _scanResult.musicCount;

  FileService() {
    _init();
  }

  void _log(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    _debugLogs.add(logMessage);
    if (kDebugMode) print('🎵 $logMessage');
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _log('FileService 初始化');
    // 应用启动时自动加载保存的音乐
    await _loadSavedTracks();
  }

  static const _audioExts = {
    '.mp3', '.m4a', '.aac', '.flac', '.wav', '.wma', '.ogg', '.opus',
    '.aiff', '.alac', '.ape', '.mpc', '.wv', '.tta',
  };

  // ─── 权限请求 ─────────────────────────────────────────────────────────

  /// 请求音频访问权限 - 增强调试版
  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) {
      _log('非Android平台，跳过权限请求');
      return true;
    }

    try {
      _log('开始请求权限...');
      
      // Android 13+ (API 33+)
      final audioStatus = await Permission.audio.status;
      _log('READ_MEDIA_AUDIO 权限状态: $audioStatus');
      
      if (audioStatus.isGranted) {
        _log('✅ 已有 READ_MEDIA_AUDIO 权限');
        return true;
      }

      // 请求 Android 13+ 音频权限
      var result = await Permission.audio.request();
      _log('请求 READ_MEDIA_AUDIO 结果: $result');
      
      if (result.isGranted) {
        _log('✅ 获取 READ_MEDIA_AUDIO 权限成功');
        return true;
      }

      // Android 12- (API 32-)
      final storageStatus = await Permission.storage.status;
      _log('READ_EXTERNAL_STORAGE 权限状态: $storageStatus');
      
      if (storageStatus.isGranted) {
        _log('✅ 已有 READ_EXTERNAL_STORAGE 权限');
        return true;
      }

      result = await Permission.storage.request();
      _log('请求 READ_EXTERNAL_STORAGE 结果: $result');
      
      if (result.isGranted) {
        _log('✅ 获取 READ_EXTERNAL_STORAGE 权限成功');
        return true;
      }

      // 已拒绝时引导用户去设置
      if (result.isPermanentlyDenied) {
        _log('⚠️ 权限被永久拒绝，引导用户去设置');
        await openAppSettings();
      }

      _log('❌ 权限请求失败');
      return false;
    } catch (e) {
      _log('❌ 权限请求异常: $e');
      return false;
    }
  }

  /// 检查是否已获得权限
  Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return true;
    final audio = await Permission.audio.status;
    final storage = await Permission.storage.status;
    final hasPermission = audio.isGranted || storage.isGranted;
    _log('权限检查: audio=$audio, storage=$storage, 结果=$hasPermission');
    return hasPermission;
  }

  // ─── 主扫描入口 ──────────────────────────────────────────────────────

  Future<void> scanLocalMusic({List<String>? paths, bool recursive = true}) async {
    if (_scanResult.isScanning) {
      _log('⚠️ 扫描正在进行中，跳过');
      return;
    }

    _log('━━━ 开始扫描本地音乐 ━━━');
    _updateScanState(
      state: ScanState.scanning,
      progress: 0.0,
      tracks: [],
      scannedCount: 0,
      musicCount: 0,
    );

    // 请求权限
    final hasPerm = await requestPermissions();
    if (!hasPerm) {
      _log('❌ 没有存储权限，无法扫描');
      _updateScanState(
        state: ScanState.error,
        errorMessage: '需要存储权限才能扫描音乐',
      );
      return;
    }

    final startTime = DateTime.now();
    final foundTracks = <Track>[];
    int totalScanned = 0;

    try {
      if (Platform.isAndroid) {
        final isTV = await _isAndroidTV();
        _log('设备类型: ${isTV ? "TV" : "手机"}');

        if (isTV) {
          // TV 端：文件系统扫描
          _log('📺 TV模式: 文件系统扫描');
          final tvPaths = await _getTVScanPaths();
          _log('TV扫描路径: $tvPaths');
          
          for (final scanPath in tvPaths) {
            if (await Directory(scanPath).exists()) {
              _log('扫描目录: $scanPath');
              final (tracks, count) = await _scanDirectory(scanPath, recursive);
              foundTracks.addAll(tracks);
              totalScanned += count;
              _log('找到 ${tracks.length} 首音乐，扫描 $count 个文件');
              _reportProgress(foundTracks, totalScanned);
            } else {
              _log('目录不存在: $scanPath');
            }
          }
        } else {
          // 手机端：优先 on_audio_query 查询 MediaStore
          _log('📱 手机模式: MediaStore查询');
          final mediaTracks = await _scanViaOnAudioQuery();
          foundTracks.addAll(mediaTracks);
          totalScanned = mediaTracks.length;
          _log('MediaStore返回: ${mediaTracks.length} 首');
          _reportProgress(foundTracks, totalScanned);

          // MediaStore 为空时，文件系统兜底
          if (foundTracks.isEmpty) {
            _log('⚠️ MediaStore为空，尝试文件系统兜底扫描');
            final phonePaths = _getPhoneScanPaths();
            _log('手机扫描路径: $phonePaths');
            
            for (final scanPath in phonePaths) {
              if (await Directory(scanPath).exists()) {
                _log('扫描目录: $scanPath');
                final (tracks, count) = await _scanDirectory(scanPath, recursive);
                foundTracks.addAll(tracks);
                totalScanned += count;
                _log('找到 ${tracks.length} 首音乐，扫描 $count 个文件');
                _reportProgress(foundTracks, totalScanned);
              } else {
                _log('目录不存在: $scanPath');
              }
            }
          }
        }
      } else {
        // 非 Android：文件系统扫描
        _log('非Android平台: 文件系统扫描');
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
    } catch (e, stackTrace) {
      _log('❌ 扫描异常: $e');
      _log('堆栈: $stackTrace');
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

    _log('━━━ 扫描完成 ━━━');
    _log('总音乐数: ${foundTracks.length}');
    _log('总扫描文件: $totalScanned');
    _log('耗时: ${elapsed}ms');

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

  /// 使用 on_audio_query 查询 MediaStore - 增强调试版
  Future<List<Track>> _scanViaOnAudioQuery() async {
    try {
      _log('开始 on_audio_query 查询...');
      
      // 先检查权限
      final hasPerm = await hasPermission();
      if (!hasPerm) {
        _log('❌ 没有权限，无法查询 MediaStore');
        return [];
      }

      // 查询所有音频
      _log('调用 querySongs...');
      final songs = await _audioQuery.querySongs(
        sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

      _log('on_audio_query 返回 ${songs.length} 首歌曲');

      if (songs.isEmpty) {
        _log('⚠️ MediaStore 查询结果为空');
        return [];
      }

      // 打印前5首歌曲的详细信息（调试）
      if (kDebugMode && songs.isNotEmpty) {
        for (var i = 0; i < (songs.length < 5 ? songs.length : 5); i++) {
          final song = songs[i];
          _log('歌曲[$i]: ${song.title} - ${song.artist} | ${song.data}');
        }
      }

      final tracks = songs.map((song) {
        final artistRaw = song.artist ?? '';
        final albumRaw  = song.album  ?? '';
        String artist = artistRaw.isNotEmpty && artistRaw != '<unknown>'
            ? artistRaw : '未知艺术家';
        String album  = albumRaw.isNotEmpty  && albumRaw  != '<unknown>'
            ? albumRaw  : '未知专辑';

        final filePath = song.data;
        
        if (filePath == null || filePath.isEmpty) {
          _log('⚠️ 歌曲路径为空: ${song.title}');
          return null;
        }

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

      _log('成功转换 ${tracks.length} 首歌曲为Track对象');
      return tracks;

    } catch (e, stackTrace) {
      _log('❌ on_audio_query 查询失败: $e');
      _log('堆栈: $stackTrace');
      return [];
    }
  }

  // ─── 文件系统扫描（TV / 兜底）───────────────────────────────────────

  Future<(List<Track>, int)> _scanDirectory(String scanPath, bool recursive) async {
    final tracks = <Track>[];
    int totalFiles = 0;

    try {
      _log('扫描目录: $scanPath (递归: $recursive)');
      await for (final entity in Directory(scanPath).list(recursive: recursive, followLinks: false)) {
        if (entity is! File) continue;
        totalFiles++;

        final ext = p.extension(entity.path).toLowerCase();
        if (_audioExts.contains(ext)) {
          tracks.add(_createTrackFromPath(entity.path));
        }
      }
      _log('目录扫描完成: $totalFiles 个文件, ${tracks.length} 首音乐');
    } catch (e) {
      _log('⚠️ 扫描目录失败: $scanPath - $e');
    }

    return (tracks, totalFiles);
  }

  // ─── TV 端扫描路径 ─────────────────────────────────────────────────

  Future<List<String>> _getTVScanPaths() async {
    final roots = <String>[];

    // 优先外部挂载点（USB）
    for (final root in ['/storage', '/mnt/media_rw', '/mnt/usb', '/mnt/usb_storage']) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      try {
        await for (final entity in dir.list()) {
          if (entity is! Directory) continue;
          final name = p.basename(entity.path);
          if (name == 'emulated' || name == 'self') continue;
          roots.add(entity.path);
          for (final sub in ['Music', 'music', 'Audio', 'audio']) {
            final subPath = '${entity.path}/$sub';
            if (await Directory(subPath).exists()) roots.add(subPath);
          }
        }
      } catch (_) {}
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
      _log('❌ 浏览失败: $e');
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
      _log('❌ 扫描文件夹失败: $e');
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
    _debugLogs.clear();
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
      _log('💾 已保存 ${tracksJson.length} 首音乐');
    } catch (e) {
      _log('❌ 保存音乐失败: $e');
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
        _log('📂 没有保存的音乐数据');
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
      
      _log('📂 已加载 ${tracks.length} 首保存的音乐');
    } catch (e) {
      _log('❌ 加载音乐失败: $e');
    }
  }

  static const String _tracksStorageKey = 'saved_music_tracks';
}
