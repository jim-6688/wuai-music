import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../data/models/lyric_model.dart';
import 'lyric_cache_service.dart';

/// 歌词多语言服务
/// 
/// 负责歌词的多语言支持，包括：
/// - 多语言歌词获取
/// - 语言切换
/// - 翻译歌词生成
/// - 语言偏好设置
class LyricMultiLanguageService {
  /// 单例实例
  static LyricMultiLanguageService? _instance;
  
  /// 缓存服务
  final LyricCacheService _cacheService;
  
  /// 支持的语言列表
  static const List<SupportedLanguage> supportedLanguages = [
    SupportedLanguage(code: 'zh', name: '中文', nativeName: '中文'),
    SupportedLanguage(code: 'en', name: '英文', nativeName: 'English'),
    SupportedLanguage(code: 'ja', name: '日文', nativeName: '日本語'),
    SupportedLanguage(code: 'ko', name: '韩文', nativeName: '한국어'),
    SupportedLanguage(code: 'fr', name: '法文', nativeName: 'Français'),
    SupportedLanguage(code: 'de', name: '德文', nativeName: 'Deutsch'),
    SupportedLanguage(code: 'es', name: '西班牙文', nativeName: 'Español'),
    SupportedLanguage(code: 'pt', name: '葡萄牙文', nativeName: 'Português'),
  ];
  
  /// 当前选中的语言
  String _currentLanguage = 'zh';
  
  /// 语言映射表（原始语言 -> 翻译语言）
  final Map<String, Map<String, LyricTranslation>> _translationCache = {};

  /// 获取单例实例
  static LyricMultiLanguageService get instance {
    _instance ??= LyricMultiLanguageService._(LyricCacheService.instance);
    return _instance!;
  }

  LyricMultiLanguageService._(this._cacheService);

  /// 初始化服务
  Future<void> initialize() async {
    await _cacheService.initialize();
    
    if (kDebugMode) {
      print('✅ 歌词多语言服务初始化完成');
      print('🌐 支持语言数: ${supportedLanguages.length}');
      print('📌 当前语言: $_currentLanguage');
    }
  }

  /// 获取当前语言
  String get currentLanguage => _currentLanguage;

  /// 获取当前语言信息
  SupportedLanguage get currentLanguageInfo {
    return supportedLanguages.firstWhere(
      (l) => l.code == _currentLanguage,
      orElse: () => supportedLanguages.first,
    );
  }

  /// 设置当前语言
  set currentLanguage(String code) {
    if (supportedLanguages.any((l) => l.code == code)) {
      _currentLanguage = code;
      if (kDebugMode) {
        print('🌐 语言已切换: $code');
      }
    }
  }

  /// 获取支持的语言列表
  List<SupportedLanguage> getLanguages() => supportedLanguages;

  /// 获取指定语言的歌词
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [language] 目标语言（默认当前语言）
  Future<MultiLanguageLyric?> getLyricWithLanguage({
    required String title,
    required String artist,
    String? language,
  }) async {
    final targetLang = language ?? _currentLanguage;
    
    try {
      // 1. 尝试从缓存获取指定语言
      String? lrcContent = await _cacheService.getCachedLyric(
        title: title,
        artist: artist,
        language: targetLang,
      );
      
      // 2. 如果缓存没有，获取原始语言歌词
      String? originalLrc = await _cacheService.getCachedLyric(
        title: title,
        artist: artist,
        language: null, // 原始语言
      );
      
      // 3. 解析歌词
      LyricData? originalLyric;
      LyricData? translatedLyric;
      
      if (originalLrc != null) {
        originalLyric = LyricParser.parse(originalLrc);
      }
      
      if (lrcContent != null) {
        translatedLyric = LyricParser.parse(lrcContent);
      }
      
      // 4. 获取可用语言列表
      final availableLanguages = await _cacheService.getCachedLanguages(
        title: title,
        artist: artist,
      );
      
      return MultiLanguageLyric(
        title: title,
        artist: artist,
        originalLyric: originalLyric,
        translatedLyric: translatedLyric,
        currentLanguage: targetLang,
        availableLanguages: availableLanguages,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取多语言歌词失败: $e');
      }
      return null;
    }
  }

  /// 翻译歌词
  /// 
  /// [lyricData] 原始歌词
  /// [sourceLanguage] 源语言
  /// [targetLanguage] 目标语言
  Future<LyricData?> translateLyric({
    required LyricData lyricData,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    if (sourceLanguage == targetLanguage) return lyricData;
    
    final key = '${lyricData.title}_${lyricData.artist}';
    
    try {
      // 检查翻译缓存
      if (_translationCache.containsKey(key) &&
          _translationCache[key]!.containsKey(targetLanguage)) {
        return _translationCache[key]![targetLanguage]!.translatedLyric;
      }
      
      // TODO: 调用翻译 API
      // 这里预留接口，实际需要接入翻译服务
      // 例如：Google Translate API, DeepL API, etc.
      
      // 模拟翻译（实际实现中需要替换）
      final translatedLyric = await _simulateTranslation(lyricData, targetLanguage);
      
      if (translatedLyric != null) {
        // 缓存翻译结果
        _translationCache[key] ??= {};
        _translationCache[key]![targetLanguage] = LyricTranslation(
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
          translatedLyric: translatedLyric,
          translatedAt: DateTime.now(),
        );
        
        // 保存到歌词缓存
        await _cacheService.cacheLyric(
          title: lyricData.title ?? '',
          artist: lyricData.artist ?? '',
          language: targetLanguage,
          lrcContent: LyricParser.generateLrc(translatedLyric),
          metadata: {
            'sourceLanguage': sourceLanguage,
            'isTranslation': true,
          },
        );
      }
      
      return translatedLyric;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 歌词翻译失败: $e');
      }
      return null;
    }
  }

  /// 模拟翻译（实际实现中需要替换为真实翻译 API）
  Future<LyricData?> _simulateTranslation(
    LyricData original,
    String targetLanguage,
  ) async {
    // 这里只是模拟，实际需要接入翻译服务
    // 实际实现中应该调用真实的翻译 API
    if (kDebugMode) {
      print('⚠️ 模拟翻译模式，实际需要接入翻译 API');
    }
    
    // 返回原始歌词，实际会通过翻译 API 生成翻译
    return original;
  }

  /// 保存多语言歌词
  /// 
  /// [title] 歌曲标题
  /// [artist] 艺术家
  /// [lyricData] 歌词数据
  /// [language] 语言标识
  Future<void> saveLyricWithLanguage({
    required String title,
    required String artist,
    required LyricData lyricData,
    required String language,
    bool isTranslation = false,
  }) async {
    await _cacheService.cacheLyric(
      title: title,
      artist: artist,
      language: language,
      lrcContent: LyricParser.generateLrc(lyricData),
      metadata: {
        'isTranslation': isTranslation,
      },
    );
  }

  /// 获取已缓存的语言列表
  Future<List<String?>> getAvailableLanguages({
    required String title,
    required String artist,
  }) async {
    return await _cacheService.getCachedLanguages(
      title: title,
      artist: artist,
    );
  }

  /// 删除指定语言的歌词
  Future<void> removeLyricLanguage({
    required String title,
    required String artist,
    required String language,
  }) async {
    await _cacheService.removeCachedLyric(
      title: title,
      artist: artist,
      language: language,
    );
  }

  /// 检查是否支持指定语言
  bool isLanguageSupported(String code) {
    return supportedLanguages.any((l) => l.code == code);
  }

  /// 获取语言名称
  String getLanguageName(String code) {
    final language = supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => SupportedLanguage(code: code, name: code, nativeName: code),
    );
    return language.name;
  }

  /// 获取语言原生名称
  String getLanguageNativeName(String code) {
    final language = supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => SupportedLanguage(code: code, name: code, nativeName: code),
    );
    return language.nativeName;
  }

  /// 获取语言国旗 emoji
  String getLanguageFlag(String code) {
    final flags = {
      'zh': '🇨🇳',
      'en': '🇺🇸',
      'ja': '🇯🇵',
      'ko': '🇰🇷',
      'fr': '🇫🇷',
      'de': '🇩🇪',
      'es': '🇪🇸',
      'pt': '🇵🇹',
    };
    return flags[code] ?? '🌐';
  }

  /// 清除翻译缓存
  void clearTranslationCache() {
    _translationCache.clear();
    if (kDebugMode) {
      print('🗑️ 已清除翻译缓存');
    }
  }
}

/// 支持的语言数据类
class SupportedLanguage {
  /// 语言代码
  final String code;
  
  /// 语言名称（中文）
  final String name;
  
  /// 语言原生名称
  final String nativeName;

  const SupportedLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });
}

/// 多语言歌词数据类
class MultiLanguageLyric {
  /// 歌曲标题
  final String title;
  
  /// 艺术家
  final String artist;
  
  /// 原始歌词
  final LyricData? originalLyric;
  
  /// 翻译歌词
  final LyricData? translatedLyric;
  
  /// 当前语言
  final String currentLanguage;
  
  /// 可用的语言列表
  final List<String?> availableLanguages;

  MultiLanguageLyric({
    required this.title,
    required this.artist,
    this.originalLyric,
    this.translatedLyric,
    required this.currentLanguage,
    required this.availableLanguages,
  });

  /// 获取当前显示的歌词
  LyricData? get currentLyric {
    // 如果当前语言不是原始语言，返回翻译歌词
    if (currentLanguage != 'zh' && translatedLyric != null) {
      return translatedLyric;
    }
    return originalLyric ?? translatedLyric;
  }

  /// 是否有原始歌词
  bool get hasOriginalLyric => originalLyric != null && !originalLyric!.isEmpty;

  /// 是否有翻译歌词
  bool get hasTranslatedLyric => translatedLyric != null && !translatedLyric!.isEmpty;

  /// 是否为空
  bool get isEmpty => !hasOriginalLyric && !hasTranslatedLyric;
}

/// 歌词翻译数据类
class LyricTranslation {
  /// 源语言
  final String sourceLanguage;
  
  /// 目标语言
  final String targetLanguage;
  
  /// 翻译后的歌词
  final LyricData translatedLyric;
  
  /// 翻译时间
  final DateTime translatedAt;

  LyricTranslation({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.translatedLyric,
    required this.translatedAt,
  });
}
