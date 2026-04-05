import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/beautify_item.dart';
import '../services/beautify_service.dart';
import '../services/audio_fingerprint_service.dart';
import '../services/music_metadata_service.dart';
import '../services/lyrics_enhance_service.dart';
import '../services/subscription_service.dart';
import '../../../features/files/presentation/providers/file_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// 订阅服务 Provider
// ═══════════════════════════════════════════════════════════════════

final subscriptionServiceProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionInfo>((ref) {
  return SubscriptionNotifier();
});

class SubscriptionNotifier extends StateNotifier<SubscriptionInfo> {
  SubscriptionService? _service;

  SubscriptionNotifier() : super(const SubscriptionInfo());

  Future<void> initialize() async {
    _service = SubscriptionService();
    await _service!.initialize();
    state = _service!.info;
  }

  Future<bool> useTrial() async {
    final result = await _service?.useTrial() ?? false;
    state = _service?.info ?? const SubscriptionInfo();
    return result;
  }

  Future<void> activateSubscription({
    required SubscriptionTier tier,
    required int months,
    bool lifetime = false,
  }) async {
    await _service?.activateSubscription(tier: tier, months: months, lifetime: lifetime);
    state = _service?.info ?? const SubscriptionInfo();
  }

  Future<bool> redeemCode(String code) async {
    final result = await _service?.redeemCode(code) ?? false;
    state = _service?.info ?? const SubscriptionInfo();
    return result;
  }

  SubscriptionService? get service => _service;
}

// ═══════════════════════════════════════════════════════════════════
// 核心服务 Providers
// ═══════════════════════════════════════════════════════════════════

final beautifyServiceProvider = Provider<BeautifyService>((ref) {
  final subscriptionService = ref.watch(subscriptionServiceProvider.notifier).service;
  final service = BeautifyService(
    fingerprintService: AudioFingerprintService(),
    metadataService: MusicMetadataService(),
    lyricsService: LyricsEnhanceService(),
    subscriptionService: subscriptionService,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

// ═══════════════════════════════════════════════════════════════════
// 曲库美化状态 Notifier
// ═══════════════════════════════════════════════════════════════════

/// 曲库美化状态
class BeautifyState {
  final BeautifyTaskState taskState;
  final List<BeautifyItem> items;
  final int currentIndex;
  final int totalCount;
  final int completedCount;
  final int failedCount;
  final String? currentOperation; // 当前正在做什么
  final String? errorMessage;
  final bool isPaused;
  final CoverEnhanceConfig coverConfig;
  final LyricsEnhanceConfig lyricsConfig;

  const BeautifyState({
    this.taskState = BeautifyTaskState.idle,
    this.items = const [],
    this.currentIndex = -1,
    this.totalCount = 0,
    this.completedCount = 0,
    this.failedCount = 0,
    this.currentOperation,
    this.errorMessage,
    this.isPaused = false,
    this.coverConfig = const CoverEnhanceConfig(),
    this.lyricsConfig = const LyricsEnhanceConfig(),
  });

  double get progress => totalCount > 0 ? completedCount / totalCount : 0.0;

  BeautifyState copyWith({
    BeautifyTaskState? taskState,
    List<BeautifyItem>? items,
    int? currentIndex,
    int? totalCount,
    int? completedCount,
    int? failedCount,
    String? currentOperation,
    String? errorMessage,
    bool? isPaused,
    CoverEnhanceConfig? coverConfig,
    LyricsEnhanceConfig? lyricsConfig,
  }) {
    return BeautifyState(
      taskState: taskState ?? this.taskState,
      items: items ?? this.items,
      currentIndex: currentIndex ?? this.currentIndex,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
      failedCount: failedCount ?? this.failedCount,
      currentOperation: currentOperation ?? this.currentOperation,
      errorMessage: errorMessage ?? this.errorMessage,
      isPaused: isPaused ?? this.isPaused,
      coverConfig: coverConfig ?? this.coverConfig,
      lyricsConfig: lyricsConfig ?? this.lyricsConfig,
    );
  }
}

/// 曲库美化 Notifier（管理批量美化任务）
class BeautifyNotifier extends StateNotifier<BeautifyState> {
  final BeautifyService _service;
  final Ref _ref;
  final Map<String, BeautifyItem> _itemsMap = {};
  bool _cancelled = false;

  BeautifyNotifier(this._service, this._ref) : super(const BeautifyState());

  // ═══════════════════════════════════════════════════════════════════
  // 公开方法
  // ═══════════════════════════════════════════════════════════════════

  /// 添加待美化曲目（可批量添加）
  void addItems(List<BeautifyItem> items) {
    for (final item in items) {
      _itemsMap[item.filePath] = item;
    }
    state = state.copyWith(
      items: _itemsMap.values.toList(),
      totalCount: _itemsMap.length,
    );
  }

  /// 从文件路径列表创建待处理项并添加
  void addFromPaths(List<String> filePaths) {
    final items = filePaths.map((path) {
      final name = path.split('/').last.split('\\').last;
      final nameWithoutExt = name.contains('.')
          ? name.substring(0, name.lastIndexOf('.'))
          : name;
      return BeautifyItem(
        filePath: path,
        originalName: nameWithoutExt,
        status: BeautifyStatus.pending,
      );
    }).toList();
    addItems(items);
  }

  /// 开始批量美化
  Future<void> startBeautify() async {
    if (state.taskState == BeautifyTaskState.beautifying) return;

    _cancelled = false;
    final items = state.items.toList();

    state = state.copyWith(
      taskState: BeautifyTaskState.beautifying,
      currentIndex: 0,
      completedCount: 0,
      failedCount: 0,
      currentOperation: '开始分析曲目...',
    );

    for (var i = 0; i < items.length; i++) {
      if (_cancelled) {
        state = state.copyWith(taskState: BeautifyTaskState.cancelled);
        return;
      }

      while (state.isPaused && !_cancelled) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (_cancelled) break;

      state = state.copyWith(
        currentIndex: i,
        currentOperation: '正在分析: ${items[i].originalName}',
      );

      final result = await _service.beautify(
        filePath: items[i].filePath,
        originalName: items[i].originalName,
        coverConfig: state.coverConfig,
        lyricsConfig: state.lyricsConfig,
        onProgress: (partial) {
          _updateItem(partial);
        },
      );

      _updateItem(result);

      state = state.copyWith(
        completedCount: state.completedCount + (result.status == BeautifyStatus.completed ? 1 : 0),
        failedCount: state.failedCount + (result.status == BeautifyStatus.failed ? 1 : 0),
      );
    }

    if (!_cancelled) {
      state = state.copyWith(
        taskState: BeautifyTaskState.completed,
        currentOperation: '美化完成！',
      );

      // ── 美化结束后：将结果回写到音乐库 ──────────────────────────────
      await _applyResultsToLibrary();
    }
  }

  /// 暂停
  void pause() {
    state = state.copyWith(isPaused: true);
  }

  /// 继续
  void resume() {
    state = state.copyWith(isPaused: false);
  }

  /// 取消
  void cancel() {
    _cancelled = true;
    state = state.copyWith(
      taskState: BeautifyTaskState.cancelled,
      isPaused: false,
    );
  }

  /// 重置
  void reset() {
    _cancelled = false;
    _itemsMap.clear();
    state = const BeautifyState();
  }

  /// 手动更新某项（用户选择封面/修改匹配结果后）
  void updateItem(BeautifyItem item) {
    _updateItem(item);
  }

  /// 更新封面配置
  void updateCoverConfig(CoverEnhanceConfig config) {
    state = state.copyWith(coverConfig: config);
  }

  /// 更新歌词配置
  void updateLyricsConfig(LyricsEnhanceConfig config) {
    state = state.copyWith(lyricsConfig: config);
  }

  /// 获取当前正在处理的项
  BeautifyItem? get currentItem {
    if (state.currentIndex < 0 || state.currentIndex >= state.items.length) {
      return null;
    }
    return state.items[state.currentIndex];
  }

  void _updateItem(BeautifyItem item) {
    _itemsMap[item.filePath] = item;
    state = state.copyWith(items: _itemsMap.values.toList());
  }

  // ─── 将美化结果回写到音乐库 ───────────────────────────────────────────────

  Future<void> _applyResultsToLibrary() async {
    try {
      final patch = <String, Map<String, String?>>{};

      for (final item in _itemsMap.values) {
        if (item.status != BeautifyStatus.completed) continue;
        if (item.matchedTitle == null &&
            item.matchedArtist == null &&
            item.matchedAlbum == null &&
            item.localCoverPath == null &&
            item.lyrics == null) continue;

        // 1. 写入 LRC 歌词文件（与音频同目录，同名）
        if (item.lyrics != null && item.lyrics!.isNotEmpty) {
          try {
            final lrcPath = _toLrcPath(item.filePath);
            await File(lrcPath).writeAsString(item.lyrics!, flush: true);
            if (kDebugMode) print('🎵 歌词已写入: $lrcPath');
          } catch (e) {
            if (kDebugMode) print('⚠️ 歌词写入失败: $e');
          }
        }

        // 2. 收集元数据补丁
        patch[item.filePath] = {
          'title':    item.matchedTitle,
          'artist':   item.matchedArtist,
          'album':    item.matchedAlbum,
          'albumArt': item.localCoverPath,
        };
      }

      if (patch.isNotEmpty) {
        final fileService = _ref.read(fileServiceProvider);
        final count = await fileService.applyBeautifyResults(patch);
        if (kDebugMode) print('✅ 元数据回写完成，共更新 $count 首曲目');
      }
    } catch (e) {
      if (kDebugMode) print('❌ 元数据回写异常: $e');
    }
  }

  /// 将音频路径转换为同目录同名的 .lrc 路径
  String _toLrcPath(String audioPath) {
    final lastDot = audioPath.lastIndexOf('.');
    final basePath = lastDot >= 0 ? audioPath.substring(0, lastDot) : audioPath;
    return '$basePath.lrc';
  }
}

// ═══════════════════════════════════════════════════════════════════
// Providers
// ═══════════════════════════════════════════════════════════════════

final beautifyProvider = StateNotifierProvider<BeautifyNotifier, BeautifyState>((ref) {
  final service = ref.watch(beautifyServiceProvider);
  return BeautifyNotifier(service, ref);
});

/// 进度 Provider（用于进度条展示）
final beautifyProgressProvider = Provider<double>((ref) {
  return ref.watch(beautifyProvider).progress;
});

/// 任务状态 Provider
final beautifyTaskStateProvider = Provider<BeautifyTaskState>((ref) {
  return ref.watch(beautifyProvider).taskState;
});

/// 是否正在美化中
final isBeautifyingProvider = Provider<bool>((ref) {
  final s = ref.watch(beautifyProvider).taskState;
  return s == BeautifyTaskState.beautifying;
});

/// 当前正在处理的项
final currentBeautifyItemProvider = Provider<BeautifyItem?>((ref) {
  final state = ref.watch(beautifyProvider);
  if (state.currentIndex < 0 || state.currentIndex >= state.items.length) {
    return null;
  }
  return state.items[state.currentIndex];
});

/// 美化结果统计
final beautifyStatsProvider = Provider<BeautifyStats>((ref) {
  final state = ref.watch(beautifyProvider);
  return BeautifyStats(
    total: state.totalCount,
    completed: state.completedCount,
    failed: state.failedCount,
    pending: state.totalCount - state.completedCount - state.failedCount,
  );
});

class BeautifyStats {
  final int total;
  final int completed;
  final int failed;
  final int pending;

  const BeautifyStats({
    required this.total,
    required this.completed,
    required this.failed,
    required this.pending,
  });
}
