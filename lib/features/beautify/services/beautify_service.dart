import 'dart:io';
import 'package:http/http.dart' as http;
import '../data/models/beautify_item.dart';
import 'audio_fingerprint_service.dart';
import 'music_metadata_service.dart';
import 'lyrics_enhance_service.dart';
import 'subscription_service.dart';

/// 曲库美化核心服务
/// 编排：指纹提取 → 元数据查询 → 封面下载 → 歌词获取/增强
class BeautifyService {
  final AudioFingerprintService _fingerprintService;
  final MusicMetadataService _metadataService;
  final LyricsEnhanceService _lyricsService;
  final SubscriptionService? _subscriptionService;
  final http.Client _client;

  BeautifyService({
    AudioFingerprintService? fingerprintService,
    MusicMetadataService? metadataService,
    LyricsEnhanceService? lyricsService,
    SubscriptionService? subscriptionService,
  })  : _fingerprintService = fingerprintService ?? AudioFingerprintService(),
        _metadataService = metadataService ?? MusicMetadataService(),
        _lyricsService = lyricsService ?? LyricsEnhanceService(),
        _subscriptionService = subscriptionService,
        _client = http.Client();

  /// 检查是否有访问权限
  /// 返回 (canAccess, reason)
  (bool, String) checkAccess({bool requireAiTranslation = false}) {
    final sub = _subscriptionService;
    if (sub == null) return (true, '订阅服务未初始化，允许使用');
    
    if (requireAiTranslation) {
      return sub.checkAiTranslationAccess();
    }
    return sub.checkBeautifyAccess();
  }

  /// 使用一次试用
  Future<bool> useTrial() async {
    return await _subscriptionService?.useTrial() ?? true;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 单曲目美化流程
  // ═══════════════════════════════════════════════════════════════════

  /// 对单个曲目执行完整美化流程
  Future<BeautifyItem> beautify({
    required String filePath,
    required String originalName,
    CoverEnhanceConfig coverConfig = const CoverEnhanceConfig(),
    LyricsEnhanceConfig lyricsConfig = const LyricsEnhanceConfig(),
    void Function(BeautifyItem partial)? onProgress,
  }) async {
    try {
      // 阶段 1：提取音频指纹
      var item = BeautifyItem(
        filePath: filePath,
        originalName: originalName,
        status: BeautifyStatus.extracting,
      );
      onProgress?.call(item);

      Map<String, dynamic> fingerprintData;
      try {
        fingerprintData = await _fingerprintService.extractFingerprint(filePath);
      } catch (e) {
        // 平台不支持时，用文件名匹配
        fingerprintData = {'fingerprint': '', 'duration': 0.0};
      }

      item = item.copyWith(
        fingerprint: fingerprintData['fingerprint'] as String?,
        fingerprintProgress: 1.0,
      );

      // 阶段 2：识别歌曲（指纹匹配 或 文件名匹配）
      item = item.copyWith(status: BeautifyStatus.recognizing);
      onProgress?.call(item);

      final duration = (fingerprintData['duration'] as num?)?.toDouble() ?? 0.0;
      final matched = await _recognizeSong(
        fingerprint: fingerprintData['fingerprint'] as String? ?? '',
        duration: duration,
        fallbackName: originalName,
      );

      if (matched != null) {
        item = item.copyWith(
          matchedTitle: matched.title,
          matchedArtist: matched.artist,
          matchedAlbum: matched.album,
          mbid: matched.mbid,
          confidence: matched.confidence,
        );
        onProgress?.call(item);
      }

      // 阶段 3：获取封面
      if (matched?.releaseMbid != null || matched?.album.isNotEmpty == true) {
        item = await _fetchAndSaveCover(item, matched!, coverConfig);
        onProgress?.call(item);
      }

      // 阶段 4：获取并增强歌词
      if (matched != null) {
        item = await _fetchAndEnhanceLyrics(item, matched, lyricsConfig);
        onProgress?.call(item);
      }

      item = item.copyWith(status: BeautifyStatus.completed);
      onProgress?.call(item);
      return item;

    } catch (e) {
      return BeautifyItem(
        filePath: filePath,
        originalName: originalName,
        status: BeautifyStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// 识别歌曲：指纹优先，其次文件名
  Future<MusicBrainzResult?> _recognizeSong({
    required String fingerprint,
    required double duration,
    required String fallbackName,
  }) async {
    // 指纹匹配（MusicBrainz + duration approximate search）
    if (fingerprint.isNotEmpty && duration > 10) {
      final results = await _metadataService.lookupByFingerprint(fingerprint, duration);
      if (results.isNotEmpty) {
        return results.first;
      }
    }

    // 文件名解析匹配
    final parsed = _parseFileName(fallbackName);
    if (parsed != null) {
      final results = await _metadataService.searchByName(parsed.title, parsed.artist);
      if (results.isNotEmpty) {
        return results.first;
      }
    }

    return null;
  }

  /// 解析文件名为 歌名 + 艺术家
  _ParsedName? _parseFileName(String fileName) {
    // 常见分隔符
    for (final sep in [' - ', ' – ', ' — ', ' _ ', '｜']) {
      if (fileName.contains(sep)) {
        final parts = fileName.split(sep);
        if (parts.length >= 2) {
          return _ParsedName(
            artist: parts[0].trim(),
            title: parts[1].replaceFirst(RegExp(r'\.[^.]+$'), '').trim(),
          );
        }
      }
    }
    return null;
  }

  /// 下载并保存封面
  Future<BeautifyItem> _fetchAndSaveCover(
    BeautifyItem item,
    MusicBrainzResult matched,
    CoverEnhanceConfig config,
  ) async {
    try {
      final urls = await _metadataService.fetchAllCovers(
        matched.releaseMbid,
        matched.album,
        matched.artist,
      );

      if (urls.isEmpty) return item;

      // 下载第一张（最高质量）
      final targetUrl = urls.first;
      final resp = await _client.get(Uri.parse(targetUrl));
      if (resp.statusCode != 200) return item;

      // 保存到文件同目录下
      final musicDir = Directory(filePathWithoutFile(item.filePath));
      final coverPath = '${musicDir.path}/cover_${matched.mbid}.jpg';

      final coverFile = File(coverPath);
      await coverFile.writeAsBytes(resp.bodyBytes);

      return item.copyWith(
        coverUrls: urls,
        selectedCoverUrl: targetUrl,
        localCoverPath: coverPath,
      );
    } catch (e) {
      return item; // 封面下载失败不影响其他流程
    }
  }

  /// 获取并增强歌词
  Future<BeautifyItem> _fetchAndEnhanceLyrics(
    BeautifyItem item,
    MusicBrainzResult matched,
    LyricsEnhanceConfig config,
  ) async {
    try {
      // 优先从本地找 LRC
      String? lrc = await _lyricsService.loadLrcFromPath(item.filePath);
      
      // 从网易云获取歌词
      lrc ??= await _lyricsService.fetchNeteaseLyrics(
        matched.title,
        matched.artist,
      );

      if (lrc == null || lrc.isEmpty) return item;

      // AI 美化
      String enhanced = lrc;
      if (config.translateToChinese || config.beautifyFormatting) {
        enhanced = await _lyricsService.enhanceLyrics(
          lrc,
          config.targetLang,
        );
      }

      return item.copyWith(
        lyrics: lrc,
        enhancedLyrics: enhanced,
      );
    } catch (e) {
      return item;
    }
  }

  String filePathWithoutFile(String path) {
    final lastSep = path.lastIndexOf(RegExp(r'[/\\]'));
    return lastSep >= 0 ? path.substring(0, lastSep) : path;
  }

  void dispose() {
    _metadataService.dispose();
    _lyricsService.dispose();
    _client.close();
  }
}

class _ParsedName {
  final String artist;
  final String title;
  const _ParsedName({required this.artist, required this.title});
}
