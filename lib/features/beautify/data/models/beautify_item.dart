/// 曲库美化项 - 单个曲目的美化结果
class BeautifyItem {
  /// 原曲目文件路径
  final String filePath;

  /// 原文件名（无封面/元数据时的参考）
  final String originalName;

  /// 匹配状态
  final BeautifyStatus status;

  /// 识别到的歌名
  final String? matchedTitle;

  /// 识别到的艺术家
  final String? matchedArtist;

  /// 识别到的专辑
  final String? matchedAlbum;

  /// MusicBrainz 记录 ID
  final String? mbid;

  /// 封面 URL 列表（从小到大排序）
  final List<String> coverUrls;

  /// 选中的封面 URL
  final String? selectedCoverUrl;

  /// 本地保存的封面路径
  final String? localCoverPath;

  /// 歌词内容（LRC 格式）
  final String? lyrics;

  /// AI 增强后的歌词
  final String? enhancedLyrics;

  /// 音频指纹
  final String? fingerprint;

  /// 匹配分数（0-1）
  final double confidence;

  /// 错误信息
  final String? errorMessage;

  /// 指纹提取进度
  final double fingerprintProgress;

  const BeautifyItem({
    required this.filePath,
    required this.originalName,
    this.status = BeautifyStatus.pending,
    this.matchedTitle,
    this.matchedArtist,
    this.matchedAlbum,
    this.mbid,
    this.coverUrls = const [],
    this.selectedCoverUrl,
    this.localCoverPath,
    this.lyrics,
    this.enhancedLyrics,
    this.fingerprint,
    this.confidence = 0.0,
    this.errorMessage,
    this.fingerprintProgress = 0.0,
  });

  /// 是否需要修复（任意字段有改善空间）
  bool get needsFix =>
      matchedTitle != null ||
      matchedAlbum != null ||
      coverUrls.isNotEmpty ||
      lyrics != null;

  /// 是否已完美匹配
  bool get isPerfect => confidence >= 0.95 && coverUrls.isNotEmpty && lyrics != null;

  BeautifyItem copyWith({
    String? filePath,
    String? originalName,
    BeautifyStatus? status,
    String? matchedTitle,
    String? matchedArtist,
    String? matchedAlbum,
    String? mbid,
    List<String>? coverUrls,
    String? selectedCoverUrl,
    String? localCoverPath,
    String? lyrics,
    String? enhancedLyrics,
    String? fingerprint,
    double? confidence,
    String? errorMessage,
    double? fingerprintProgress,
  }) {
    return BeautifyItem(
      filePath: filePath ?? this.filePath,
      originalName: originalName ?? this.originalName,
      status: status ?? this.status,
      matchedTitle: matchedTitle ?? this.matchedTitle,
      matchedArtist: matchedArtist ?? this.matchedArtist,
      matchedAlbum: matchedAlbum ?? this.matchedAlbum,
      mbid: mbid ?? this.mbid,
      coverUrls: coverUrls ?? this.coverUrls,
      selectedCoverUrl: selectedCoverUrl ?? this.selectedCoverUrl,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      lyrics: lyrics ?? this.lyrics,
      enhancedLyrics: enhancedLyrics ?? this.enhancedLyrics,
      fingerprint: fingerprint ?? this.fingerprint,
      confidence: confidence ?? this.confidence,
      errorMessage: errorMessage ?? this.errorMessage,
      fingerprintProgress: fingerprintProgress ?? this.fingerprintProgress,
    );
  }
}

/// 美化处理状态
enum BeautifyStatus {
  pending,       // 待处理
  extracting,    // 正在提取指纹
  recognizing,   // 正在识别
  enhancing,     // 正在增强
  completed,     // 完成
  failed,        // 失败
  skipped,       // 跳过（用户取消）
}

/// 批量美化任务状态
enum BeautifyTaskState {
  idle,
  scanning,      // 扫描曲目
  beautifying,   // 美化中
  paused,        // 暂停
  completed,     // 完成
  cancelled,     // 取消
}

/// 单个曲目的美化结果摘要
class BeautifyResult {
  final String filePath;
  final bool titleFixed;
  final bool artistFixed;
  final bool albumFixed;
  final bool coverDownloaded;
  final bool lyricsFetched;
  final bool lyricsEnhanced;
  final String? error;

  const BeautifyResult({
    required this.filePath,
    this.titleFixed = false,
    this.artistFixed = false,
    this.albumFixed = false,
    this.coverDownloaded = false,
    this.lyricsFetched = false,
    this.lyricsEnhanced = false,
    this.error,
  });
}

/// 封面增强配置
class CoverEnhanceConfig {
  /// 是否下载高清封面
  final bool downloadHiresCover;

  /// 是否启用 AI 超分（需要 API）
  final bool enableUpscale;

  /// 超分倍数（2x 或 4x）
  final int upscaleFactor;

  /// 封面质量（0-100）
  final int jpegQuality;

  const CoverEnhanceConfig({
    this.downloadHiresCover = true,
    this.enableUpscale = false,
    this.upscaleFactor = 2,
    this.jpegQuality = 92,
  });
}

/// 歌词增强配置
class LyricsEnhanceConfig {
  /// 是否自动翻译歌词
  final bool translateToChinese;

  /// 翻译目标语言
  final String targetLang;

  /// 是否美化排版
  final bool beautifyFormatting;

  const LyricsEnhanceConfig({
    this.translateToChinese = true,
    this.targetLang = 'zh',
    this.beautifyFormatting = true,
  });
}
