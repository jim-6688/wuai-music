import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_synckit/flutter_synckit.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// NAS 同步配置
class NasSyncConfig {
  final String name;
  final String serverUrl;
  final String username;
  final String password;
  final String remoteDirectory;
  final ConflictStrategy conflictStrategy;
  final bool syncOnWifiOnly;
  final bool autoSync;
  final int syncIntervalMinutes;

  const NasSyncConfig({
    required this.name,
    required this.serverUrl,
    required this.username,
    required this.password,
    this.remoteDirectory = '/',
    this.conflictStrategy = ConflictStrategy.smartMerge,
    this.syncOnWifiOnly = true,
    this.autoSync = false,
    this.syncIntervalMinutes = 30,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'serverUrl': serverUrl,
    'username': username,
    'password': password,
    'remoteDirectory': remoteDirectory,
    'conflictStrategy': conflictStrategy.index,
    'syncOnWifiOnly': syncOnWifiOnly,
    'autoSync': autoSync,
    'syncIntervalMinutes': syncIntervalMinutes,
  };

  factory NasSyncConfig.fromJson(Map<String, dynamic> json) => NasSyncConfig(
    name: json['name']?.toString() ?? '',
    serverUrl: json['serverUrl']?.toString() ?? '',
    username: json['username']?.toString() ?? '',
    password: json['password']?.toString() ?? '',
    remoteDirectory: json['remoteDirectory']?.toString() ?? '/',
    conflictStrategy: ConflictStrategy.values[json['conflictStrategy'] ?? 2],
    syncOnWifiOnly: json['syncOnWifiOnly'] ?? true,
    autoSync: json['autoSync'] ?? false,
    syncIntervalMinutes: json['syncIntervalMinutes'] ?? 30,
  );
}

/// 同步任务状态
enum SyncStatus {
  idle,
  syncing,
  paused,
  error,
  completed,
}

/// 同步进度
class SyncProgress {
  final int totalFiles;
  final int completedFiles;
  final int failedFiles;
  final String? currentFile;
  final double percentage;
  final SyncStatus status;
  final String? errorMessage;

  const SyncProgress({
    this.totalFiles = 0,
    this.completedFiles = 0,
    this.failedFiles = 0,
    this.currentFile,
    this.percentage = 0,
    this.status = SyncStatus.idle,
    this.errorMessage,
  });

  SyncProgress copyWith({
    int? totalFiles,
    int? completedFiles,
    int? failedFiles,
    String? currentFile,
    double? percentage,
    SyncStatus? status,
    String? errorMessage,
  }) {
    return SyncProgress(
      totalFiles: totalFiles ?? this.totalFiles,
      completedFiles: completedFiles ?? this.completedFiles,
      failedFiles: failedFiles ?? this.failedFiles,
      currentFile: currentFile ?? this.currentFile,
      percentage: percentage ?? this.percentage,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// NAS 同步服务
class NasSyncService extends ChangeNotifier {
  FlutterSyncKit? _syncKit;
  NasSyncConfig? _config;
  SyncProgress _progress = const SyncProgress();
  List<NasSyncConfig> _savedConfigs = [];
  StreamSubscription? _eventSubscription;
  Timer? _autoSyncTimer;

  // ─── Getters ──────────────────────────────────────────────────────────────

  SyncProgress get progress => _progress;
  NasSyncConfig? get config => _config;
  List<NasSyncConfig> get savedConfigs => List.unmodifiable(_savedConfigs);
  bool get isInitialized => _syncKit != null;
  bool get isSyncing => _progress.status == SyncStatus.syncing;

  // ─── 初始化 ────────────────────────────────────────────────────────────────

  /// 初始化同步服务
  Future<bool> initialize(NasSyncConfig config) async {
    try {
      _config = config;
      _progress = SyncProgress(status: SyncStatus.syncing);
      notifyListeners();

      // 获取本地存储目录
      final appDir = await getApplicationDocumentsDirectory();
      final localDir = '${appDir.path}/nas_sync/${config.name}';

      // 确保目录存在
      final dir = Directory(localDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 初始化 SyncKit
      _syncKit = FlutterSyncKit();
      await _syncKit!.initialize(SyncConfig(
        serverUrl: config.serverUrl,
        username: config.username,
        password: config.password,
        localDirectory: localDir,
        remoteDirectory: config.remoteDirectory,
        conflictStrategy: config.conflictStrategy,
        syncOnWifiOnly: config.syncOnWifiOnly,
        chunkSize: 1024 * 1024 * 2, // 2MB 分块
        maxConcurrentTasks: 3,
        maxRetries: 3,
        enableChecksum: true,
        autoSync: false, // 手动控制同步
      ));

      // 监听同步事件
      _eventSubscription = _syncKit!.eventStream.listen(_handleSyncEvent);

      _progress = SyncProgress(status: SyncStatus.idle);
      notifyListeners();

      if (kDebugMode) print('✅ NAS 同步服务初始化成功: ${config.name}');
      return true;
    } catch (e) {
      _progress = SyncProgress(
        status: SyncStatus.error,
        errorMessage: '初始化失败: $e',
      );
      notifyListeners();
      if (kDebugMode) print('❌ NAS 同步服务初始化失败: $e');
      return false;
    }
  }

  // ─── 同步操作 ──────────────────────────────────────────────────────────────

  /// 开始完整同步
  Future<dynamic> sync() async {
    if (_syncKit == null) {
      _progress = SyncProgress(
        status: SyncStatus.error,
        errorMessage: '请先初始化同步服务',
      );
      notifyListeners();
      return null;
    }

    try {
      _progress = SyncProgress(status: SyncStatus.syncing);
      notifyListeners();

      final result = await _syncKit!.sync();

      _progress = SyncProgress(
        status: SyncStatus.completed,
        totalFiles: result.totalFiles,
        completedFiles: result.successCount,
        failedFiles: result.failedCount,
        percentage: 100,
      );
      notifyListeners();

      if (kDebugMode) {
        print('✅ 同步完成: ${result.successCount}/${result.totalFiles}');
      }

      return result;
    } catch (e) {
      _progress = SyncProgress(
        status: SyncStatus.error,
        errorMessage: '同步失败: $e',
      );
      notifyListeners();
      return null;
    }
  }

  /// 上传单个文件
  Future<bool> uploadFile(String localPath, {String? remotePath}) async {
    if (_syncKit == null) return false;

    try {
      await _syncKit!.upload(localPath, remotePath: remotePath);
      if (kDebugMode) print('✅ 上传成功: $localPath');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 上传失败: $e');
      return false;
    }
  }

  /// 下载单个文件
  Future<bool> downloadFile(String remotePath, {String? localPath}) async {
    if (_syncKit == null) return false;

    try {
      await _syncKit!.download(remotePath, localPath: localPath);
      if (kDebugMode) print('✅ 下载成功: $remotePath');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 下载失败: $e');
      return false;
    }
  }

  /// 暂停同步
  void pauseSync() {
    // TODO: flutter_synckit 暂停功能可能不可用
    // _syncKit?.pause();
    _progress = _progress.copyWith(status: SyncStatus.paused);
    notifyListeners();
  }

  /// 恢复同步
  void resumeSync() {
    // TODO: flutter_synckit 恢复功能可能不可用
    // _syncKit?.resume();
    _progress = _progress.copyWith(status: SyncStatus.syncing);
    notifyListeners();
  }

  // ─── 自动同步 ──────────────────────────────────────────────────────────────

  /// 启动自动同步
  void startAutoSync({int intervalMinutes = 30}) {
    stopAutoSync();
    
    _autoSyncTimer = Timer.periodic(
      Duration(minutes: intervalMinutes),
      (_) => sync(),
    );

    if (kDebugMode) print('🔄 自动同步已启动 (每 $intervalMinutes 分钟)');
  }

  /// 停止自动同步
  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
    if (kDebugMode) print('⏹️ 自动同步已停止');
  }

  // ─── 配置管理 ──────────────────────────────────────────────────────────────

  /// 保存配置
  void saveConfig(NasSyncConfig config) {
    final index = _savedConfigs.indexWhere((c) => c.name == config.name);
    if (index >= 0) {
      _savedConfigs[index] = config;
    } else {
      _savedConfigs.add(config);
    }
    notifyListeners();
  }

  /// 删除配置
  void deleteConfig(String name) {
    _savedConfigs.removeWhere((c) => c.name == name);
    notifyListeners();
  }

  // ─── 事件处理 ──────────────────────────────────────────────────────────────

  void _handleSyncEvent(SyncEvent event) {
    final type = event.type;
    
    // 使用字符串匹配来处理不同的事件类型
    if (type.toString().contains('syncStarted')) {
      _progress = SyncProgress(status: SyncStatus.syncing);
    } else if (type.toString().contains('taskProgress')) {
      _progress = _progress.copyWith(
        currentFile: event.file?.name,
        percentage: event.progress ?? 0,
      );
    } else if (type.toString().contains('syncCompleted')) {
      _progress = _progress.copyWith(
        status: SyncStatus.completed,
        percentage: 100,
      );
    } else if (type.toString().contains('error') && !type.toString().contains('conflict')) {
      _progress = SyncProgress(
        status: SyncStatus.error,
        errorMessage: 'Sync error occurred',
      );
    } else if (type.toString().contains('conflictDetected')) {
      if (kDebugMode) print('⚠️ 检测到冲突: ${event.file?.name}');
    }
    
    notifyListeners();
  }

  // ─── 清理 ──────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    stopAutoSync();
    _eventSubscription?.cancel();
    _syncKit?.dispose();
    super.dispose();
  }
}