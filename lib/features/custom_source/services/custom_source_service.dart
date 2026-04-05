import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../data/models/music_source.dart';
import '../data/models/music_url_result.dart';
import '../data/models/cache_entry.dart';
import 'js_engine_service.dart';
import 'url_cache_service.dart';
import 'copyright_detector.dart';

export '../data/models/music_source.dart' show LeaderboardInfo, LeaderboardDetail, FavoriteLeaderboard, MusicInfo;
export '../data/models/music_url_result.dart';

/// 自定义音源服务
/// 负责解析和执行JS音源脚本（洛雪音乐/六音格式）
class CustomSourceService extends StateNotifier<List<MusicSource>> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// URL缓存服务
  UrlCacheService? _urlCacheService;

  CustomSourceService(this._ref) : super([]) {
    _loadSources();
    _loadFavoriteLeaderboards();
    _initializeCacheService();
  }

  /// 初始化缓存服务
  Future<void> _initializeCacheService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _urlCacheService = UrlCacheService(prefs);
      if (kDebugMode) {
        print('✅ URL缓存服务已初始化');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 初始化缓存服务失败: $e');
      }
    }
  }

  /// SharedPreferences key
  static const String _storageKey = 'custom_music_sources';
  static const String _favoriteLeaderboardsKey = 'favorite_leaderboards';

  /// 已初始化的音源缓存
  final Map<String, LxInitResult> _initializedSources = {};

  /// 收藏的榜单缓存
  List<FavoriteLeaderboard> _favoriteLeaderboards = [];

  /// 内置音源列表
  static const List<Map<String, String>> _builtInSources = [
    {'name': 'test_source.js', 'displayName': '测试音源(内置数据)'},
    {'name': 'all_board_source.js', 'displayName': '全网榜单音源(内置数据)'},
  ];

  /// 加载已保存的音源，如果没有则导入内置音源
  Future<void> _loadSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sourcesJson = prefs.getString(_storageKey);

      if (sourcesJson != null && sourcesJson.isNotEmpty) {
        // 有保存的音源，直接加载
        final List<dynamic> sourcesList = json.decode(sourcesJson);
        state = sourcesList
            .map((json) => MusicSource.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          print('✅ 已加载 ${state.length} 个自定义音源');
        }
      } else {
        // 没有保存的音源，导入内置音源
        if (kDebugMode) {
          print('📦 未找到保存的音源，开始导入内置音源...');
        }
        
        for (final builtIn in _builtInSources) {
          try {
            final scriptContent = await rootBundle.loadString('assets/${builtIn['name']}');
            final now = DateTime.now();
            final source = MusicSource(
              id: 'built_in_${builtIn['name']}',
              name: builtIn['displayName']!,
              scriptContent: scriptContent,
              version: '1.0.0',
              createdAt: now,
              updatedAt: now,
              isEnabled: true,
              actions: const ['musicUrl', 'lyric', 'pic', 'search', 'leaderboard', 'leaderboardDetail'],
              qualitys: const ['128k', '320k', 'flac'],
            );
            state = [...state, source];
            
            if (kDebugMode) {
              print('✅ 已导入内置音源: ${builtIn['displayName']}');
            }
          } catch (e) {
            if (kDebugMode) {
              print('❌ 导入内置音源 ${builtIn['name']} 失败: $e');
            }
          }
        }
        
        // 保存导入的内置音源
        if (state.isNotEmpty) {
          await _saveSources();
        }
      }

      // 串行初始化每个音源（避免并行导致 JS runtime 的 lx._initData 被覆盖）
      // 原因：flutter_js evaluateAsync 在 Dart microtask 中交错执行，
      //       多个脚本并行初始化时，后执行的脚本会覆盖 lx._initData
      for (final source in state) {
        await _initializeSource(source);
      }

      if (kDebugMode) {
        print('✅ 所有音源初始化完成，共 ${state.length} 个');
        // 打印每个音源的初始化结果
        for (final source in state) {
          final result = _initializedSources[source.id];
          if (result != null) {
            print('   📡 ${source.name}: platforms=${result.sources.keys.join(", ")}');
          } else {
            print('   ⚠️ ${source.name}: 初始化失败或无榜单');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载自定义音源失败: $e');
      }
    }
  }

  /// 加载收藏的榜单
  Future<void> _loadFavoriteLeaderboards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getString(_favoriteLeaderboardsKey);

      if (favoritesJson != null) {
        final List<dynamic> favoritesList = json.decode(favoritesJson);
        _favoriteLeaderboards = favoritesList
            .map((json) => FavoriteLeaderboard.fromJson(json as Map<String, dynamic>))
            .toList();

        if (kDebugMode) {
          print('✅ 已加载 ${_favoriteLeaderboards.length} 个收藏榜单');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 加载收藏榜单失败: $e');
      }
    }
  }

  /// 保存收藏的榜单
  Future<void> _saveFavoriteLeaderboards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = json.encode(
        _favoriteLeaderboards.map((f) => f.toJson()).toList(),
      );
      await prefs.setString(_favoriteLeaderboardsKey, favoritesJson);

      if (kDebugMode) {
        print('💾 已保存 ${_favoriteLeaderboards.length} 个收藏榜单');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存收藏榜单失败: $e');
      }
    }
  }

  /// 获取收藏的榜单列表
  List<FavoriteLeaderboard> get favoriteLeaderboards => _favoriteLeaderboards;

  /// 检查榜单是否已收藏
  bool isLeaderboardFavorite(LeaderboardInfo leaderboard) {
    final uniqueId = '${leaderboard.sourceId}_${leaderboard.id}';
    return _favoriteLeaderboards.any((f) => f.uniqueId == uniqueId);
  }

  /// 收藏榜单
  Future<void> addFavoriteLeaderboard(LeaderboardInfo leaderboard) async {
    final uniqueId = '${leaderboard.sourceId}_${leaderboard.id}';
    if (_favoriteLeaderboards.any((f) => f.uniqueId == uniqueId)) {
      return; // 已收藏
    }

    _favoriteLeaderboards.add(FavoriteLeaderboard(
      leaderboard: leaderboard,
      favoritedAt: DateTime.now(),
    ));

    await _saveFavoriteLeaderboards();

    if (kDebugMode) {
      print('❤️ 已收藏榜单: ${leaderboard.name}');
    }
  }

  /// 取消收藏榜单
  Future<void> removeFavoriteLeaderboard(LeaderboardInfo leaderboard) async {
    final uniqueId = '${leaderboard.sourceId}_${leaderboard.id}';
    _favoriteLeaderboards.removeWhere((f) => f.uniqueId == uniqueId);

    await _saveFavoriteLeaderboards();

    if (kDebugMode) {
      print('💔 已取消收藏榜单: ${leaderboard.name}');
    }
  }

  /// 切换榜单收藏状态
  Future<bool> toggleFavoriteLeaderboard(LeaderboardInfo leaderboard) async {
    if (isLeaderboardFavorite(leaderboard)) {
      await removeFavoriteLeaderboard(leaderboard);
      return false;
    } else {
      await addFavoriteLeaderboard(leaderboard);
      return true;
    }
  }

  /// 初始化音源脚本
  Future<LxInitResult?> _initializeSource(MusicSource source) async {
    if (_initializedSources.containsKey(source.id)) {
      if (kDebugMode) {
        print('⏭️ 音源 ${source.name} 已初始化，跳过');
      }
      return _initializedSources[source.id];
    }

    if (kDebugMode) {
      print('🔄 开始初始化音源: ${source.name} (id=${source.id})');
    }

    try {
      final jsEngine = JsEngineService.instance;
      final result = await jsEngine.loadScript(source.scriptContent, scriptId: source.id);

      if (result != null) {
        _initializedSources[source.id] = result;

        // 更新音源的actions和qualitys
        final firstSource = result.sources.values.firstOrNull;
        if (firstSource != null) {
          final updatedSource = source.copyWith(
            actions: firstSource.actions,
            qualitys: firstSource.qualitys,
          );
          state = state.map((s) => s.id == source.id ? updatedSource : s).toList();
          await _saveSources();
        }

        if (kDebugMode) {
          print('✅ 音源初始化成功: ${source.name}');
          print('   支持平台: ${result.sources.keys.join(", ")}');
          print('   支持动作: ${firstSource?.actions.join(", ")}');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ 音源 ${source.name} loadScript 返回 null');
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 初始化音源失败: ${source.name}, 错误: $e');
      }
      return null;
    }
  }

  /// 保存音源列表
  Future<void> _saveSources() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sourcesJson = json.encode(state.map((s) => s.toJson()).toList());
      await prefs.setString(_storageKey, sourcesJson);

      if (kDebugMode) {
        print('💾 已保存 ${state.length} 个自定义音源');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ 保存自定义音源失败: $e');
      }
    }
  }

  /// 从字符串内容导入音源（如从 assets 读取）
  Future<MusicSource?> importFromString(
    String content, {
    bool isLocal = true,
    String? scriptUrl,
  }) async {
    try {
      return await _importScriptContent(
        content,
        scriptUrl: scriptUrl,
        isLocal: isLocal,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 从字符串导入音源失败: $e');
      }
      rethrow;
    }
  }

  /// 从本地文件导入音源
  Future<MusicSource?> importFromFile(File file) async {
    try {
      final content = await file.readAsString();
      return await _importScriptContent(content, isLocal: true);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 从文件导入音源失败: $e');
      }
      rethrow;
    }
  }

  /// 从URL导入音源
  Future<MusicSource?> importFromUrl(String url) async {
    try {
      final response = await _dio.get(url);
      final content = response.data.toString();
      return await _importScriptContent(content, scriptUrl: url, isLocal: false);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 从URL导入音源失败: $e');
      }
      rethrow;
    }
  }

  /// 导入脚本内容
  Future<MusicSource?> _importScriptContent(
    String scriptContent, {
    String? scriptUrl,
    required bool isLocal,
  }) async {
    try {
      // 提取元数据
      final metadata = _extractMetadata(scriptContent);

      if (metadata['name'] == null) {
        throw Exception('脚本缺少必要的 @name 元数据');
      }

      // 生成唯一ID
      final id = 'source_${DateTime.now().millisecondsSinceEpoch}';

      // 尝试初始化，失败时使用默认配置（不阻断导入）
      LxInitResult initResult;
      try {
        final result = await JsEngineService.instance.loadScript(scriptContent, scriptId: id);
        initResult = result ?? LxInitResult(
          sources: {
            'default': LxSourceInfo(
              name: metadata['name'] ?? '自定义音源',
              type: 'music',
              actions: const ['musicUrl', 'lyric'],
              qualitys: const ['128k', '320k', 'flac'],
            ),
          },
        );
      } catch (e) {
        if (kDebugMode) print('⚠️ 音源初始化异常，使用默认配置: $e');
        initResult = LxInitResult(
          sources: {
            'default': LxSourceInfo(
              name: metadata['name'] ?? '自定义音源',
              type: 'music',
              actions: const ['musicUrl', 'lyric'],
              qualitys: const ['128k', '320k', 'flac'],
            ),
          },
        );
      }

      // 获取首个音源的动作和音质配置
      final firstSource = initResult.sources.values.firstOrNull;

      // 创建音源对象
      final source = MusicSource(
        id: id,
        name: metadata['name']!,
        description: metadata['description'],
        version: metadata['version'] ?? '1.0.0',
        author: metadata['author'],
        homepage: metadata['homepage'],
        scriptContent: scriptContent,
        scriptUrl: scriptUrl,
        isLocal: isLocal,
        isEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        actions: firstSource?.actions ?? const ['musicUrl'],
        qualitys: firstSource?.qualitys ?? const ['128k', '320k', 'flac'],
      );

      // 缓存初始化结果
      _initializedSources[id] = initResult;

      // 添加到列表并持久化
      await addSource(source);

      if (kDebugMode) print('✅ 音源导入成功: ${source.name}');
      return source;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 导入脚本失败: $e');
      }
      rethrow;
    }
  }

  /// 提取脚本元数据
  /// 只保留每个 key 的第一次出现，避免内嵌库的注释覆盖音源自身的元数据
  Map<String, String> _extractMetadata(String script) {
    final metadata = <String, String>{};

    // 只解析文件最开头的注释区域（前 3000 字符），避免内嵌库注释干扰
    final headerRegion = script.length > 3000 ? script.substring(0, 3000) : script;

    // 统一提取策略：直接扫描 @key value 格式的行
    // 兼容以下所有格式：
    //   /** \n * @name xxx \n */         (JSDoc)
    //   // @name xxx                      (单行注释)
    //   // ==UserScript== \n // @name xxx (油猴格式)
    //   @name xxx                         (裸 @ 格式)
    final lineRegex = RegExp(
      r'(?:^|\n)\s*(?://\s*\*?|/\*\*?\s*|\*\s*)?@(\w+)\s+([^\n\r\*]+)',
      multiLine: true,
    );

    final matches = lineRegex.allMatches(headerRegion);
    for (final match in matches) {
      final key = match.group(1)?.trim();
      final value = match.group(2)?.trim();
      // 只保留每个 key 的第一次出现，忽略空值
      if (key != null && value != null && value.isNotEmpty && !metadata.containsKey(key)) {
        metadata[key] = value;
      }
    }

    return metadata;
  }

  /// 添加音源
  Future<void> addSource(MusicSource source) async {
    state = [...state, source];
    await _saveSources();
  }

  /// 移除音源
  Future<void> removeSource(String sourceId) async {
    _initializedSources.remove(sourceId);
    state = state.where((s) => s.id != sourceId).toList();
    await _saveSources();
  }

  /// 更新音源
  Future<void> updateSource(MusicSource source) async {
    state = state.map((s) => s.id == source.id ? source : s).toList();
    _initializedSources.remove(source.id);
    await _initializeSource(source);
    await _saveSources();
  }

  /// 启用/禁用音源
  Future<void> toggleSource(String sourceId) async {
    state = state.map((s) {
      if (s.id == sourceId) {
        return s.copyWith(isEnabled: !s.isEnabled);
      }
      return s;
    }).toList();
    await _saveSources();
  }

  /// 获取启用的音源列表
  List<MusicSource> get enabledSources {
    return state.where((s) => s.isEnabled).toList();
  }

  /// 获取音源的初始化结果
  LxInitResult? getSourceInitResult(String sourceId) {
    return _initializedSources[sourceId];
  }

  /// 搜索音乐
  /// 遍历所有启用的音源进行搜索
  Future<List<MusicSearchResult>> searchMusic(
    String keyword, {
    int page = 1,
    String? sourceKey,
  }) async {
    final results = <MusicSearchResult>[];

    if (kDebugMode) {
      print('🔍 开始搜索: "$keyword", 页码: $page');
    }

    for (final source in enabledSources) {
      try {
        final initResult = _initializedSources[source.id];
        if (initResult == null) {
          if (kDebugMode) {
            print('⚠️ 音源 ${source.name} 未初始化,跳过');
          }
          continue;
        }

        // 如果指定了sourceKey，只搜索该平台
        final platforms = sourceKey != null
            ? [sourceKey]
            : initResult.sources.keys.toList();

        for (final platform in platforms) {
          final result = await _executeSearch(
            source,
            platform,
            keyword,
            page,
          );
          if (result != null) {
            results.add(result);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 音源 ${source.name} 搜索失败: $e');
        }
      }
    }

    if (kDebugMode) {
      print('✅ 搜索完成，找到 ${results.length} 个结果');
    }

    return results;
  }

  /// 执行搜索
  Future<MusicSearchResult?> _executeSearch(
    MusicSource source,
    String sourceKey,
    String keyword,
    int page,
  ) async {
    if (kDebugMode) {
      print('🔍 搜索: ${source.name} ($sourceKey), 关键词: $keyword');
    }

    try {
      final jsEngine = JsEngineService.instance;

      // 调用JS脚本的搜索功能
      final searchResult = await jsEngine.searchMusic(
        sourceKey: sourceKey,
        keyword: keyword,
        page: page,
        scriptId: source.id,
      );

      if (searchResult == null || searchResult.isEmpty) {
        if (kDebugMode) {
          print('ℹ️ ${source.name} ($sourceKey): 无结果');
        }
        return null;
      }

      // 转换为MusicSearchResult
      final musicList = searchResult.map((item) {
        return MusicInfo.fromJson(item, source.id);
      }).toList();

      if (kDebugMode) {
        print('✅ ${source.name} ($sourceKey): 找到 ${musicList.length} 首');
      }

      return MusicSearchResult(
        list: musicList,
        total: musicList.length,
        page: page,
        limit: 30,
        sourceId: source.id,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 搜索失败: $e');
      }
      return null;
    }
  }

  /// 获取音乐URL
  Future<MusicUrlInfo?> getMusicUrl(
    String sourceId,
    String musicId,
    String quality, {
    String sourceKey = 'kw',
    Map<String, dynamic>? musicInfo,
  }) async {
    final source = state.where((s) => s.id == sourceId).firstOrNull;
    if (source == null || !source.isEnabled) {
      return null;
    }

    try {
      final jsEngine = JsEngineService.instance;

      final musicData = musicInfo ?? {'id': musicId, 'songId': musicId};

      final result = await jsEngine.getMusicUrl(
        sourceKey: sourceKey,
        musicInfo: musicData,
        quality: quality,
        scriptId: sourceId,
      );

      if (result != null) {
        return MusicUrlInfo(url: result);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取音乐URL失败: $e');
      }
      return null;
    }
  }

  /// 获取歌词
  Future<LyricInfo?> getLyric(
    String sourceId,
    String musicId, {
    String sourceKey = 'kw',
    Map<String, dynamic>? musicInfo,
  }) async {
    final source = state.where((s) => s.id == sourceId).firstOrNull;
    if (source == null || !source.isEnabled) {
      return null;
    }

    try {
      final jsEngine = JsEngineService.instance;

      final musicData = musicInfo ?? {'id': musicId, 'songId': musicId};

      final result = await jsEngine.getLyric(
        sourceKey: sourceKey,
        musicInfo: musicData,
        scriptId: sourceId,
      );

      if (result != null) {
        return LyricInfo.fromJson(result);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取歌词失败: $e');
      }
      return null;
    }
  }

  /// 获取封面
  Future<String?> getAlbumCover(
    String sourceId,
    String musicId, {
    String sourceKey = 'kw',
    Map<String, dynamic>? musicInfo,
  }) async {
    final source = state.where((s) => s.id == sourceId).firstOrNull;
    if (source == null || !source.isEnabled) {
      return null;
    }

    try {
      final jsEngine = JsEngineService.instance;

      final musicData = musicInfo ?? {'id': musicId, 'songId': musicId};

      return await jsEngine.getPic(
        sourceKey: sourceKey,
        musicInfo: musicData,
        scriptId: sourceId,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取封面失败: $e');
      }
      return null;
    }
  }

  /// 执行HTTP请求（供JS引擎调用）
  Future<String> executeHttpRequest({
    required String url,
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      final response = await _dio.request(
        url,
        options: Options(
          method: method,
          headers: headers,
        ),
        data: body,
      );
      return response.data.toString();
    } catch (e) {
      if (kDebugMode) {
        print('❌ HTTP请求失败: $e');
      }
      rethrow;
    }
  }

  /// 获取排行榜列表
  /// 从所有启用的音源获取榜单
  Future<List<LeaderboardInfo>> getLeaderboards() async {
    final allLeaderboards = <LeaderboardInfo>[];

    if (kDebugMode) {
      print('📊 开始获取排行榜列表');
      print('  启用的音源: ${enabledSources.map((s) => s.name).join(", ")}');
      print('  已初始化的音源: ${_initializedSources.keys.join(", ")}');
    }

    for (final source in enabledSources) {
      try {
        final initResult = _initializedSources[source.id];
        if (initResult == null) {
          if (kDebugMode) {
            print('  ⚠️ 音源 ${source.name} 未初始化');
          }
          continue;
        }

        if (kDebugMode) {
          print('  📡 音源 ${source.name} 包含平台: ${initResult.sources.keys.join(", ")}');
        }

        // 遍历音源支持的所有平台
        for (final platform in initResult.sources.keys) {
          final leaderboards = await _getLeaderboardsForPlatform(
            source,
            platform,
          );
          if (kDebugMode) {
            print('    平台 $platform 获取到 ${leaderboards.length} 个榜单');
          }
          allLeaderboards.addAll(leaderboards);
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 音源 ${source.name} 获取榜单失败: $e');
        }
      }
    }

    if (kDebugMode) {
      print('✅ 共获取 ${allLeaderboards.length} 个榜单');
    }

    return allLeaderboards;
  }

  /// 获取指定平台的榜单
  Future<List<LeaderboardInfo>> _getLeaderboardsForPlatform(
    MusicSource source,
    String sourceKey,
  ) async {
    try {
      final jsEngine = JsEngineService.instance;
      final result = await jsEngine.getLeaderboards(
        sourceKey: sourceKey,
        scriptId: source.id,
      );

      if (result == null || result.isEmpty) {
        return [];
      }

      final leaderboards = result.map((item) {
        item['sourceId'] = source.id;
        return LeaderboardInfo.fromJson(item, sourceId: source.id);
      }).toList();

      if (kDebugMode) {
        print('  ✅ ${source.name}($sourceKey): ${leaderboards.length}个榜单');
      }

      return leaderboards;
    } catch (e) {
      if (kDebugMode) {
        print('  ❌ ${source.name}($sourceKey): $e');
      }
      return [];
    }
  }

  /// 获取榜单详情
  Future<LeaderboardDetail?> getLeaderboardDetail(
    LeaderboardInfo leaderboard,
  ) async {
    try {
      final source = state.firstWhere((s) => s.id == leaderboard.sourceId);
      if (!source.isEnabled) return null;

      final jsEngine = JsEngineService.instance;
      final result = await jsEngine.getLeaderboardDetail(
        sourceKey: leaderboard.source,
        leaderboardId: leaderboard.id,
        scriptId: source.id,
      );

      if (result == null) return null;

      return LeaderboardDetail.fromJson(result, leaderboard, leaderboard.sourceId);
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取榜单详情失败: $e');
      }
      return null;
    }
  }

  // ==================== 新增方法：多平台Fallback和音质降级 ====================

  /// 获取音乐URL（带多平台fallback）
  /// 
  /// 参数:
  /// - sourceId: 音源ID
  /// - musicId: 歌曲ID
  /// - quality: 音质要求
  /// - platformOrder: 平台尝试顺序，默认 [wy, kg, kw, tx, mg]
  /// - enableCache: 是否启用缓存，默认true
  /// 
  /// 返回: MusicUrlResult 音源获取结果
  Future<MusicUrlResult?> getMusicUrlWithFallback({
    required String sourceId,
    required String musicId,
    required String quality,
    List<String>? platformOrder,
    bool enableCache = true,
  }) async {
    try {
      final source = state.where((s) => s.id == sourceId).firstOrNull;
      if (source == null || !source.isEnabled) {
        return MusicUrlResult.failure(
          error: '音源未找到或已禁用',
        );
      }

      // 确定平台尝试顺序
      final platforms = platformOrder ?? ['wy', 'kg', 'kw', 'tx', 'mg'];

      if (kDebugMode) {
        print('🔄 开始多平台尝试: $musicId, 顺序: $platforms, 音质: $quality');
      }

      // 1. 检查缓存
      if (enableCache && _urlCacheService != null) {
        for (final platform in platforms) {
          final cached = _urlCacheService!.get(musicId, quality, platform);
          if (cached != null) {
            if (kDebugMode) {
              print('✅ 缓存命中: $platform');
            }
            return MusicUrlResult.success(
              url: cached.url,
              platform: platform,
              actualQuality: quality,
              fromCache: true,
            );
          }
        }
      }

      // 2. 依次尝试各平台
      final jsEngine = JsEngineService.instance;
      for (final platform in platforms) {
        try {
          if (kDebugMode) {
            print('📍 尝试平台: $platform');
          }

          final result = await jsEngine.getMusicUrl(
            sourceKey: platform,
            musicInfo: {'id': musicId, 'songId': musicId},
            quality: quality,
            scriptId: sourceId,
          );

          if (result != null && result.startsWith('http')) {
            // 验证URL有效性
            final isValid = await CopyrightDetector.isUrlValid(result);
            if (!isValid) {
              if (kDebugMode) {
                print('⚠️ URL验证失败: $platform');
              }
              continue;
            }

            // 成功！缓存并返回
            if (enableCache && _urlCacheService != null) {
              await _urlCacheService!.set(musicId, quality, platform, result);
            }

            if (kDebugMode) {
              print('✅ 获取成功: $platform - ${result.substring(0, 50)}...');
            }

            return MusicUrlResult.success(
              url: result,
              platform: platform,
              actualQuality: quality,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('⚠️ 平台$platform失败: $e');
          }
          // 继续尝试下一个平台
          continue;
        }
      }

      // 3. 所有平台都失败
      return MusicUrlResult.failure(
        error: '所有平台均无法获取音源',
        errorCode: -999,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ fallback过程异常: $e');
      }
      return MusicUrlResult.failure(
        error: e.toString(),
      );
    }
  }

  /// 尝试音质降级获取
  /// 
  /// 当高音质获取失败时，自动降级到低音质
  /// 
  /// 参数:
  /// - sourceId: 音源ID
  /// - musicId: 歌曲ID
  /// - preferredQuality: 首选音质
  /// - platformOrder: 平台尝试顺序
  /// - enableCache: 是否启用缓存
  /// 
  /// 返回: MusicUrlResult 音源获取结果
  Future<MusicUrlResult?> getMusicUrlWithQualityFallback({
    required String sourceId,
    required String musicId,
    required String preferredQuality,
    List<String>? platformOrder,
    bool enableCache = true,
  }) async {
    // 定义音质降级序列
    final qualitySequence = {
      'flac24bit': ['flac24bit', 'flac', '320k', '192k', '128k'],
      'flac': ['flac', '320k', '192k', '128k'],
      '320k': ['320k', '192k', '128k'],
      '192k': ['192k', '128k'],
      '128k': ['128k'],
    };

    final qualities = qualitySequence[preferredQuality] ?? ['128k'];

    if (kDebugMode) {
      print('📉 尝试音质降级: $preferredQuality → 降级序列: $qualities');
    }

    for (final quality in qualities) {
      try {
        final result = await getMusicUrlWithFallback(
          sourceId: sourceId,
          musicId: musicId,
          quality: quality,
          platformOrder: platformOrder,
          enableCache: enableCache,
        );

        if (result?.isSuccess ?? false) {
          final isDowngraded = quality != preferredQuality;
          
          if (isDowngraded && kDebugMode) {
            print('✅ 使用降级音质: $quality (原需求: $preferredQuality)');
          }

          return result!.copyWith(
            isQualityDowngraded: isDowngraded,
          );
        } else if (result?.shouldRetry == false) {
          // 如果不应该重试（如版权限制），直接返回
          return result;
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ 尝试音质$quality失败: $e');
        }
        continue;
      }
    }

    return MusicUrlResult.failure(
      error: '所有音质均不可用',
    );
  }

  /// 获取缓存统计信息
  Future<Map<String, dynamic>?> getCacheStats() async {
    if (_urlCacheService == null) return null;
    return await _urlCacheService!.getStats();
  }

  /// 清空URL缓存
  Future<void> clearCache() async {
    if (_urlCacheService == null) return;
    await _urlCacheService!.clear();
  }

  /// 清理过期缓存
  Future<int> cleanExpiredCache() async {
    if (_urlCacheService == null) return 0;
    return await _urlCacheService!.cleanExpired();
  }
}

/// Provider
final customSourceServiceProvider =
    StateNotifierProvider<CustomSourceService, List<MusicSource>>((ref) {
  return CustomSourceService(ref);
});
