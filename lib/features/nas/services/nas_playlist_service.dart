import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../files/data/models/track.dart';
import '../service/nas_service.dart';

/// NAS 虚拟歌单服务
/// 将 NAS 音乐虚拟成本地歌单，实现无缝播放
class NasPlaylistService extends ChangeNotifier {
  final NasService _nasService;
  
  /// 缓存目录（用于存放下载的 NAS 音乐）
  String? _cacheDir;
  
  /// 虚拟歌单（NAS 音乐列表）
  List<Track> _nasTracks = [];
  
  /// NAS 歌单名称映射
  Map<String, List<Track>> _tracksByFolder = {};
  
  /// 是否正在扫描
  bool _isScanning = false;
  
  /// 扫描进度
  int _scannedCount = 0;
  int _totalCount = 0;
  
  /// 已缓存的文件（NAS路径 -> 本地缓存路径）
  Map<String, String> _cachedFiles = {};
  
  /// NAS 设备 ID -> 扫描的共享/目录
  Map<String, String> _scannedSources = {};

  NasPlaylistService(this._nasService) {
    _init();
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<Track> get nasTracks => List.unmodifiable(_nasTracks);
  Map<String, List<Track>> get tracksByFolder => Map.unmodifiable(_tracksByFolder);
  bool get isScanning => _isScanning;
  int get scannedCount => _scannedCount;
  int get totalCount => _totalCount;
  String? get cacheDir => _cacheDir;

  // ─── 初始化 ────────────────────────────────────────────────────────────────

  Future<void> _init() async {
    // 获取缓存目录
    _cacheDir = '${Directory.systemTemp.path}/nas_music_cache';
    await Directory(_cacheDir!).create(recursive: true);
    
    // 加载已缓存的文件映射
    await _loadCachedFiles();
    
    // 加载已扫描的 NAS 歌单
    await _loadNasTracks();
  }

  /// 加载缓存文件映射
  Future<void> _loadCachedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('nas_cached_files');
      if (cachedJson != null) {
        final Map<String, dynamic> map = json.decode(cachedJson);
        _cachedFiles = map.map((k, v) => MapEntry(k, v as String));
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 加载缓存映射失败: $e');
    }
  }

  /// 保存缓存文件映射
  Future<void> _saveCachedFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nas_cached_files', json.encode(_cachedFiles));
    } catch (e) {
      if (kDebugMode) print('⚠️ 保存缓存映射失败: $e');
    }
  }

  /// 加载 NAS 歌单
  Future<void> _loadNasTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tracksJson = prefs.getString('nas_tracks');
      if (tracksJson != null) {
        final List<dynamic> list = json.decode(tracksJson);
        _nasTracks = list.map((j) => Track.fromJson(j as Map<String, dynamic>)).toList();
        _groupByFolder();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 加载 NAS 歌单失败: $e');
    }
  }

  /// 保存 NAS 歌单
  Future<void> _saveNasTracks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nas_tracks', json.encode(_nasTracks.map((t) => t.toJson()).toList()));
    } catch (e) {
      if (kDebugMode) print('⚠️ 保存 NAS 歌单失败: $e');
    }
  }

  // ─── 扫描 NAS 音乐 ──────────────────────────────────────────────────────────

  /// 扫描 NAS 目录，生成虚拟歌单
  Future<List<Track>> scanNasMusic({
    required NasDevice device,
    required String share,
    String? relPath,
    bool recursive = true,
  }) async {
    if (_isScanning) return _nasTracks;
    
    _isScanning = true;
    _scannedCount = 0;
    _totalCount = 0;
    notifyListeners();

    try {
      // 连接 NAS
      if (_nasService.connectedDevice?.id != device.id) {
        final ok = await _nasService.connect(device);
        if (!ok) {
          _isScanning = false;
          notifyListeners();
          return _nasTracks;
        }
      }

      // 扫描目录
      final tracks = <Track>[];
      await _scanDirectory(
        device: device,
        share: share,
        relPath: relPath ?? '',
        tracks: tracks,
        recursive: recursive,
      );

      // 添加到歌单（去重）
      for (final track in tracks) {
        if (!_nasTracks.any((t) => t.filePath == track.filePath)) {
          _nasTracks.add(track);
        }
      }

      // 记录扫描源
      _scannedSources[device.id] = share;
      
      // 按文件夹分组
      _groupByFolder();
      
      // 保存
      await _saveNasTracks();
      
      if (kDebugMode) print('✅ 扫描完成: ${tracks.length} 首音乐');
      
      return _nasTracks;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// 递归扫描目录
  Future<void> _scanDirectory({
    required NasDevice device,
    required String share,
    required String relPath,
    required List<Track> tracks,
    required bool recursive,
  }) async {
    final items = await _nasService.browseFolder(
      device,
      share: share,
      relPath: relPath,
    );

    for (final item in items) {
      if (item.isDirectory && recursive) {
        // 递归扫描子目录
        await _scanDirectory(
          device: device,
          share: share,
          relPath: item.path,
          tracks: tracks,
          recursive: recursive,
        );
      } else if (item.isAudioFile) {
        // 添加音频文件
        _totalCount++;
        final track = await _createTrackFromSmbItem(device, share, item);
        if (track != null) {
          tracks.add(track);
          _scannedCount++;
          if (_scannedCount % 10 == 0) notifyListeners();
        }
      }
    }
  }

  /// 从 SMB 文件创建虚拟 Track
  Future<Track?> _createTrackFromSmbItem(
    NasDevice device,
    String share,
    SmbItem item,
  ) async {
    try {
      // 生成唯一 ID
      final id = 'nas_${device.ip}_${share}_${item.path}'.hashCode.toString();
      
      // 虚拟路径（用于标识）
      final virtualPath = 'smb://${device.ip}/$share/${item.path}';
      
      // 从文件名提取标题
      String title = item.name;
      if (title.contains('.')) {
        title = title.substring(0, title.lastIndexOf('.'));
      }

      return Track(
        id: id,
        filePath: virtualPath,
        title: title,
        artist: 'Unknown Artist',
        album: share,
        duration: null, // 播放时获取
        albumArt: null,
      );
    } catch (e) {
      if (kDebugMode) print('⚠️ 创建 Track 失败: $e');
      return null;
    }
  }

  /// 按文件夹分组
  void _groupByFolder() {
    _tracksByFolder.clear();
    
    for (final track in _nasTracks) {
      // 从虚拟路径提取文件夹
      // smb://192.168.9.99/share/dir/file.mp3 -> smb://192.168.9.99/share/dir
      final parts = track.filePath.split('/');
      if (parts.length > 4) {
        final folder = parts.sublist(0, parts.length - 1).join('/');
        _tracksByFolder.putIfAbsent(folder, () => []).add(track);
      } else {
        // 根目录
        final root = parts.sublist(0, 4).join('/');
        _tracksByFolder.putIfAbsent(root, () => []).add(track);
      }
    }
  }

  // ─── 播放支持 ────────────────────────────────────────────────────────────────

  /// 获取可播放的本地路径
  /// 如果文件已缓存，返回缓存路径
  /// 否则下载到缓存并返回
  Future<String> getPlayablePath(Track track) async {
    final virtualPath = track.filePath;
    
    // 检查是否已缓存
    if (_cachedFiles.containsKey(virtualPath)) {
      final cachedPath = _cachedFiles[virtualPath]!;
      if (await File(cachedPath).exists()) {
        if (kDebugMode) print('✅ 使用缓存: $cachedPath');
        return cachedPath;
      }
    }

    // 下载到缓存
    if (kDebugMode) print('⬇️ 下载 NAS 文件: $virtualPath');
    
    final localPath = await _downloadToCache(track);
    if (localPath != null) {
      _cachedFiles[virtualPath] = localPath;
      await _saveCachedFiles();
      return localPath;
    }

    throw Exception('无法获取可播放路径: $virtualPath');
  }

  /// 下载 NAS 文件到本地缓存
  Future<String?> _downloadToCache(Track track) async {
    try {
      // 解析虚拟路径
      // smb://192.168.9.99/share/dir/file.mp3
      final uri = Uri.parse(track.filePath);
      final host = uri.host;
      final pathSegments = uri.pathSegments;
      
      if (pathSegments.isEmpty) return null;
      
      final share = pathSegments[0];
      final relPath = pathSegments.sublist(1).join('/');
      
      // 查找对应的 NAS 设备
      final device = _nasService.devices.firstWhere(
        (d) => d.ip == host,
        orElse: () => throw Exception('未找到 NAS 设备: $host'),
      );

      // 确保已连接
      if (_nasService.connectedDevice?.id != device.id) {
        await _nasService.connect(device);
      }

      // 使用 smb_connect 下载文件
      final smbPath = '/$share/$relPath';
      if (kDebugMode) print('📥 下载: $smbPath');
      
      final smbFile = await _nasService.smbConnection!.file(smbPath);
      
      // 使用 openRead 读取文件内容（流式读取）
      final stream = await _nasService.smbConnection!.openRead(smbFile);
      final allBytes = <int>[];
      await for (final chunk in stream) {
        allBytes.addAll(chunk);
      }
      
      // 保存到缓存
      final fileName = p.basename(track.filePath);
      final cachePath = '$_cacheDir/${track.id}_$fileName';
      final cacheFile = File(cachePath);
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(allBytes);
      
      if (kDebugMode) print('✅ 已缓存: $cachePath');
      return cachePath;
    } catch (e) {
      if (kDebugMode) print('❌ 下载失败: $e');
      return null;
    }
  }

  /// 清除缓存
  Future<void> clearCache() async {
    try {
      if (_cacheDir != null) {
        final dir = Directory(_cacheDir!);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
          await dir.create(recursive: true);
        }
      }
      _cachedFiles.clear();
      await _saveCachedFiles();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('❌ 清除缓存失败: $e');
    }
  }

  /// 移除 NAS 歌单
  void removeTrack(String trackId) {
    _nasTracks.removeWhere((t) => t.id == trackId);
    _groupByFolder();
    notifyListeners();
    _saveNasTracks();
  }

  /// 清空 NAS 歌单
  void clearTracks() {
    _nasTracks.clear();
    _tracksByFolder.clear();
    _scannedSources.clear();
    notifyListeners();
    _saveNasTracks();
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    if (_cacheDir == null) return 0;
    
    try {
      final dir = Directory(_cacheDir!);
      if (!await dir.exists()) return 0;
      
      int size = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
      return size;
    } catch (e) {
      return 0;
    }
  }
}
