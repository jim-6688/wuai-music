import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'dart:convert';
import '../data/models/track.dart';
import '../../lyrics/service/qq_music_lyric_service.dart';
import '../../playlist/services/netease_api_service.dart';
import '../../playlist/services/netease_leaderboard_service.dart';

/// 歌词候选条目（用于手动搜索展示）
class LyricsCandidate {
  final String platform;      // 平台: 'qq' | 'netease' | 'kugou' | 'kuwo'
  final String platformLabel; // 显示名称: 'QQ音乐' | '网易云' | '酷狗' | '酷我'
  final String songId;        // 平台内部歌曲ID
  final String title;         // 歌曲名
  final String artist;        // 歌手名
  final String? album;        // 专辑名
  final String? duration;     // 时长（格式 mm:ss）
  final int matchScore;       // 匹配分数（越高越相关）

  const LyricsCandidate({
    required this.platform,
    required this.platformLabel,
    required this.songId,
    required this.title,
    required this.artist,
    this.album,
    this.duration,
    this.matchScore = 0,
  });
}

/// 歌词项 - 支持逐字时间戳
class LyricsItem {
  final String text;
  final Duration startTime;
  final Duration endTime;
  final String? translation;
  final List<LyricWord>? words; // 逐字时间戳列表

  const LyricsItem({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.translation,
    this.words,
  });
}

/// 逐字时间戳（用于卡拉OK逐字高亮）
class LyricWord {
  final String word;
  final Duration startTime;
  final Duration endTime;

  const LyricWord({
    required this.word,
    required this.startTime,
    required this.endTime,
  });
}

/// 单词匹配（内部用）
class _WordMatch {
  final String text;
  final int startMs;
  final int endMs;
  _WordMatch(this.text, this.startMs, this.endMs);
}

/// 歌词服务 - 支持 lrc.cx(优先)、QQ音乐、网易云(weapi手机版)、酷狗、酷我
class LyricsService extends ChangeNotifier {
  List<LyricsItem> _lyrics = [];
  String? _currentLyric;
  int _currentIndex = 0;
  bool _isLoading = false;
  String? _errorMessage;
  
  // QQ音乐服务
  final QQMusicLyricService _qqMusicService = QQMusicLyricService();
  
  // 网易云 weapi 手机版服务（可选，通过 NeteaseCloudMusicApi）
  NeteaseApiService? _neteaseApiService;
  bool _neteaseApiAvailable = false;

  /// 设置网易云API服务（通过 weapi 手机版接口）
  void setNeteaseApiService(NeteaseApiService service) {
    _neteaseApiService = service;
    _neteaseApiAvailable = true;
    if (kDebugMode) print('🎵 网易云 weapi 歌词服务已接入');
  }

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<LyricsItem> get lyrics => List.unmodifiable(_lyrics);
  String? get currentLyric => _currentLyric;
  int get currentIndex => _currentIndex;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasLyrics => _lyrics.isNotEmpty;

  // ─── 更新当前歌词索引（根据播放位置）────────────────────────────────────────

  /// 根据当前播放位置更新当前歌词索引
  void updateCurrentLyric(Duration position) {
    if (_lyrics.isEmpty) return;

    final positionMs = position.inMilliseconds;
    int newIndex = 0;

    // 找到当前播放位置对应的歌词行
    for (int i = 0; i < _lyrics.length; i++) {
      if (positionMs >= _lyrics[i].startTime.inMilliseconds) {
        newIndex = i;
      } else {
        break;
      }
    }

    // 只有索引变化时才更新
    if (newIndex != _currentIndex) {
      _currentIndex = newIndex;
      _currentLyric = _lyrics[newIndex].text;
      notifyListeners();
    }
  }

  // ─── 自动获取歌词（多平台并发搜索，优先匹配歌名+时长）─────────────────────

  /// 根据歌曲名称自动模糊匹配下载歌词
  ///
  /// 策略：五平台并发搜索候选 → 按歌名+时长排序 → 依次尝试，失败自动下一个
  Future<bool> fetchLyricsAuto(String title, {String? artist, String? songId, int? durationMs}) async {
    if (title.isEmpty) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Step 1: 尝试 lrc.cx（最快，直接返回 LRC）
      if (kDebugMode) print('🎵 尝试 lrc.cx 获取歌词: $title - ${artist ?? "未知"}');
      final lrcCxSuccess = await _fetchLyricsFromLrcCx(title, artist: artist);
      if (lrcCxSuccess) return true;

      // Step 2: 多平台并发搜索候选歌词，按匹配度+时长排序
      if (kDebugMode) print('🔍 多平台并发搜索歌词候选: $title - ${artist ?? "未知"}');
      final candidates = await searchLyricsCandidates(title, artist: artist);

      if (candidates.isEmpty) {
        _errorMessage = '未找到歌词';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 按匹配度排序（歌名精确匹配 + 时长接近的优先）
      final sorted = _sortByRelevance(candidates, title, artist, durationMs);

      if (kDebugMode) {
        print('📋 候选歌词 ${sorted.length} 条，按相关度排序:');
        for (int i = 0; i < sorted.length && i < 5; i++) {
          final c = sorted[i];
          print('  #$i [${c.platformLabel}] ${c.title} - ${c.artist} (${c.duration ?? "未知时长"}) score=${c.matchScore}');
        }
      }

      // Step 3: 依次尝试候选，失败自动下一个（最多尝试前3个）
      final tryCount = sorted.length < 3 ? sorted.length : 3;
      for (int i = 0; i < tryCount; i++) {
        final candidate = sorted[i];
        if (kDebugMode) print('🔄 尝试候选 #$i: [${candidate.platformLabel}] ${candidate.title}');

        final success = await fetchLyricsFromCandidate(candidate);
        if (success) {
          if (kDebugMode) print('✅ 候选 #$i 歌词加载成功: ${_lyrics.length} 行');
          return true;
        }
        if (kDebugMode) print('⚠️ 候选 #$i 加载失败，尝试下一个');
      }

      _errorMessage = '未找到合适歌词';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '歌词获取失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 按相关度排序候选歌词（歌名匹配 + 时长接近的优先）
  List<LyricsCandidate> _sortByRelevance(List<LyricsCandidate> candidates, String title, String? artist, int? durationMs) {
    final titleLower = title.toLowerCase();
    final artistLower = artist?.toLowerCase() ?? '';

    final scored = candidates.map((c) {
      int score = c.matchScore;

      // 歌名精确匹配加分
      if (c.title.toLowerCase() == titleLower) {
        score += 40;
      } else if (c.title.toLowerCase().contains(titleLower)) {
        score += 20;
      }
      // 歌手匹配加分
      if (artistLower.isNotEmpty) {
        if (c.artist.toLowerCase().contains(artistLower)) {
          score += 15;
        }
      }
      // 时长匹配加分（差距越小越好）
      if (durationMs != null && c.duration != null) {
        final parts = c.duration!.split(':');
        if (parts.length == 2) {
          final candidateMs = int.tryParse(parts[0])! * 60000 + int.tryParse(parts[1])! * 1000;
          final diff = (candidateMs - durationMs).abs();
          if (diff < 3000) {
            score += 30; // 时长差 < 3秒，非常接近
          } else if (diff < 10000) {
            score += 20; // 时长差 < 10秒
          } else if (diff < 30000) {
            score += 10; // 时长差 < 30秒
          }
        }
      }

      return MapEntry(c, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  // ─── 从网易云获取歌词 ─────────────────────────────────────────────────────

  /// 搜索歌曲获取 ID（优先 weapi 手机版，降级到 /api/）
  Future<String?> searchSongId(String title, String artist) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (kDebugMode) print('🔍 网易云搜索歌曲: $title - $artist');

      // 优先使用 weapi 手机版接口
      if (_neteaseApiAvailable && _neteaseApiService != null) {
        final songId = await _searchSongIdViaWeapi(title, artist);
        if (songId != null) return songId;
        if (kDebugMode) print('⚠️ weapi 搜索无结果，降级到 /api/');
      }

      // 降级：旧的 /api/ 接口
      final query = Uri.encodeComponent('$title $artist');
      final url = 'https://music.163.com/api/search/get?s=$query&type=1&limit=1';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 6),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          final songs = json['result']?['songs'] as List?;
          if (songs != null && songs.isNotEmpty) {
            final songId = songs[0]['id'].toString();
            if (kDebugMode) print('✅ 网易云(/api)找到歌曲 ID: $songId');
            return songId;
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ 解析搜索结果失败: $e');
        }
      }

      _errorMessage = '未找到歌曲';
      if (kDebugMode) print('❌ $_errorMessage');
      return null;
    } catch (e) {
      _errorMessage = '搜索失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 通过 weapi 手机版接口搜索歌曲 ID
  Future<String?> _searchSongIdViaWeapi(String title, String artist) async {
    try {
      final keyword = artist.isNotEmpty ? '$title $artist' : title;
      final result = await _neteaseApiService!.search(
        keywords: keyword,
        type: 1,
        limit: 1,
      );

      if (result.songs.isNotEmpty) {
        final songId = result.songs.first.id;
        if (kDebugMode) print('✅ 网易云(weapi)找到歌曲 ID: $songId');
        return songId;
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('⚠️ weapi 搜索失败: $e');
      return null;
    }
  }

  /// 从网易云获取歌词（优先 weapi 手机版，降级到 /api/）
  Future<bool> fetchLyricsFromNetease(String songId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _lyrics = [];
      _currentLyric = null;
      _currentIndex = 0;
      notifyListeners();

      if (kDebugMode) print('📥 网易云获取歌词: songId=$songId');

      // 优先使用 weapi 手机版接口
      if (_neteaseApiAvailable && _neteaseApiService != null) {
        final success = await _fetchLyricsFromNeteaseWeapi(songId);
        if (success) return true;
        if (kDebugMode) print('⚠️ weapi 歌词获取失败，降级到 /api/');
      }

      // 降级：旧的 /api/ 接口
      final url = 'https://music.163.com/api/song/lyric?id=$songId&lv=-1&tv=-1';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 6),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          
          // 获取 LRC 格式歌词
          final lrc = json['lrc']?['lyric'] as String?;
          final tlyric = json['tlyric']?['lyric'] as String?; // 翻译歌词

          if (lrc != null && lrc.isNotEmpty) {
            _parseLyrics(lrc, tlyric);
            if (kDebugMode) print('✅ 网易云(/api)歌词获取成功: ${_lyrics.length} 行');
            _isLoading = false;
            notifyListeners();
            return true;
          } else {
            _errorMessage = '暂无歌词';
            if (kDebugMode) print('⚠️ $_errorMessage');
          }
        } catch (e) {
          _errorMessage = '解析歌词失败: $e';
          if (kDebugMode) print('❌ $_errorMessage');
        }
      } else {
        _errorMessage = '获取歌词失败 (${response.statusCode})';
        if (kDebugMode) print('❌ $_errorMessage');
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '网络错误: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// 通过 weapi 手机版接口获取歌词
  Future<bool> _fetchLyricsFromNeteaseWeapi(String songId) async {
    try {
      final lyric = await _neteaseApiService!.getLyric(songId);
      if (lyric != null && lyric.hasLyric && lyric.lyric != null && lyric.lyric!.isNotEmpty) {
        _parseLyrics(lyric.lyric!, lyric.tlyric);
        if (_lyrics.isNotEmpty) {
          if (kDebugMode) print('✅ 网易云(weapi)歌词获取成功: ${_lyrics.length} 行');
          _isLoading = false;
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('⚠️ weapi 歌词获取失败: $e');
      return false;
    }
  }

  /// 解析 LRC 格式歌词（支持逐字时间戳）
  void _parseLyrics(String lrcContent, String? translationContent) {
    try {
      final translationMap = _parseTranslation(translationContent);
      final lines = lrcContent.split('\n');
      final items = <LyricsItem>[];

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // 格式: [mm:ss.xx]歌词文本 或 [mm:ss.xx]<mm:ss.xx>字<mm:ss.xx>词
        final match = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)').firstMatch(line);
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = double.parse(match.group(2)!);
          String text = match.group(3)!;
          
          final startTimeMs = (minutes * 60 * 1000 + (seconds * 1000).toInt()).toInt();
          
          // 获取下一行的时间作为结束时间
          int endTimeMs = startTimeMs + 5000;
          if (i + 1 < lines.length) {
            final nextLine = lines[i + 1].trim();
            final nextMatch = RegExp(r'\[(\d+):(\d+\.\d+)\]').firstMatch(nextLine);
            if (nextMatch != null) {
              final nextMinutes = int.parse(nextMatch.group(1)!);
              final nextSeconds = double.parse(nextMatch.group(2)!);
              endTimeMs = (nextMinutes * 60 * 1000 + (nextSeconds * 1000).toInt()).toInt();
            }
          }

          // 解析逐字时间戳
          List<LyricWord>? words = _parseWordTimestamps(text, startTimeMs, endTimeMs);
          if (words != null && words.isNotEmpty) {
            // 用逐字时间更新结束时间
            endTimeMs = words.last.endTime.inMilliseconds;
            // 清理文本中的时间戳
            text = words.map((w) => w.word).join();
          }

          items.add(LyricsItem(
            text: text,
            startTime: Duration(milliseconds: startTimeMs),
            endTime: Duration(milliseconds: endTimeMs),
            translation: translationMap[startTimeMs],
            words: words,
          ));
        }
      }

      _lyrics = items;
      if (kDebugMode) print('📝 解析歌词: ${_lyrics.length} 行');
    } catch (e) {
      if (kDebugMode) print('❌ 解析 LRC 失败: $e');
      _lyrics = [];
    }
  }

  /// 解析逐字时间戳
  /// 支持格式: <00:12.34>字<00:12.56>词 或 {{00:12.34}}字{{00:12.56}}词
  List<LyricWord>? _parseWordTimestamps(String text, int lineStartMs, int lineEndMs) {
    // 匹配 <mm:ss.xx> 或 {{mm:ss.xx}} 格式的时间戳
    final wordMatches = <_WordMatch>[];
    
    // 匹配 <mm:ss.xx> 或 {{mm:ss.xx}}
    final timestampRegex = RegExp(r'<(\d+):(\d+\.\d+)>|{{(\d+):(\d+\.\d+)}}');
    int lastEnd = 0;
    int? lastTimestampMs;
    
    for (final match in timestampRegex.allMatches(text)) {
      // 提取时间戳
      int tsMin, tsSec, tsMs;
      if (match.group(1) != null) {
        // <mm:ss.xx> 格式
        tsMin = int.parse(match.group(1)!);
        final secParts = match.group(2)!.split('.');
        tsSec = int.parse(secParts[0]);
        tsMs = int.parse(secParts[1].padRight(3, '0').substring(0, 3));
      } else {
        // {{mm:ss.xx}} 格式
        tsMin = int.parse(match.group(3)!);
        final secParts = match.group(4)!.split('.');
        tsSec = int.parse(secParts[0]);
        tsMs = int.parse(secParts[1].padRight(3, '0').substring(0, 3));
      }
      final timestampMs = tsMin * 60 * 1000 + tsSec * 1000 + tsMs;
      
      // 提取时间戳前面的文字
      if (match.start > lastEnd) {
        final wordText = text.substring(lastEnd, match.start).trim();
        if (wordText.isNotEmpty && lastTimestampMs != null) {
          wordMatches.add(_WordMatch(wordText, lastTimestampMs, timestampMs));
        }
      }
      
      lastTimestampMs = timestampMs;
      lastEnd = match.end;
    }
    
    // 处理最后一个时间戳后面的文字
    if (lastEnd < text.length && lastTimestampMs != null) {
      final remainingText = text.substring(lastEnd).trim();
      if (remainingText.isNotEmpty) {
        wordMatches.add(_WordMatch(remainingText, lastTimestampMs, lineEndMs));
      }
    }
    
    if (wordMatches.isEmpty) return null;
    
    return wordMatches.map((wm) => LyricWord(
      word: wm.text,
      startTime: Duration(milliseconds: wm.startMs),
      endTime: Duration(milliseconds: wm.endMs),
    )).toList();
  }

  /// 解析翻译歌词
  Map<int, String> _parseTranslation(String? translationContent) {
    final map = <int, String>{};
    if (translationContent == null || translationContent.isEmpty) return map;

    try {
      final lines = translationContent.split('\n');
      for (final line in lines) {
        if (line.isEmpty) continue;
        // 格式: [mm:ss.xx]翻译文本
        final match = RegExp(r'\[(\d+):(\d+\.\d+)\](.*)').firstMatch(line);
        if (match != null) {
          final minutes = int.parse(match.group(1)!);
          final seconds = double.parse(match.group(2)!);
          final text = match.group(3)!;
          final timeStamp = (minutes * 60 * 1000 + (seconds * 1000).toInt()).toInt();
          map[timeStamp] = text;
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 解析翻译歌词失败: $e');
    }

    return map;
  }

  /// 清空歌词
  void clearLyrics() {
    _lyrics = [];
    _currentLyric = null;
    _currentIndex = 0;
    _errorMessage = null;
    notifyListeners();
  }

  /// 直接从 LRC 字符串内容加载歌词（供本地文件读取使用）
  void loadFromLrcContent(String lrcContent, {String? translationContent}) {
    _isLoading = false;
    _errorMessage = null;
    _lyrics = [];
    _currentLyric = null;
    _currentIndex = 0;
    _parseLyrics(lrcContent, translationContent);
    notifyListeners();
  }

  // ─── 多平台候选搜索 ────────────────────────────────────────────────────────

  /// 同时在 lrc.cx + QQ音乐 + 网易云 + 酷狗 + 酷我 搜索候选歌词列表
  ///
  /// 返回按平台分组排列的候选条目，每个条目含 [platform]、[songId]、[title]、[artist] 等信息
  Future<List<LyricsCandidate>> searchLyricsCandidates(
    String title, {
    String? artist,
  }) async {
    if (title.isEmpty) return [];

    final List<LyricsCandidate> results = [];

    // 五平台并发搜索
    final futures = await Future.wait([
      _searchLrcCxCandidate(title, artist: artist),
      _searchQQCandidates(title, artist: artist),
      _searchNeteaseCandidates(title, artist: artist),
      _searchKugouCandidates(title, artist: artist),
      _searchKuwoCandidates(title, artist: artist),
    ]);

    results.addAll(futures[0]);
    results.addAll(futures[1]);
    results.addAll(futures[2]);
    results.addAll(futures[3]);
    results.addAll(futures[4]);

    if (kDebugMode) {
      print('🔍 候选歌词总数: ${results.length} (lrc.cx:${futures[0].length}, QQ:${futures[1].length}, 网易云:${futures[2].length}, 酷狗:${futures[3].length}, 酷我:${futures[4].length})');
    }

    return results;
  }

  /// 搜索 QQ音乐 候选列表（返回多条）
  Future<List<LyricsCandidate>> _searchQQCandidates(
    String title, {
    String? artist,
  }) async {
    try {
      const searchApi = 'https://c.y.qq.com/soso/fcgi-bin/client_search_cp';
      final keyword = artist != null && artist.isNotEmpty ? '$title $artist' : title;

      final response = await http.get(
        Uri.parse(searchApi).replace(queryParameters: {
          'format': 'json',
          'p': '1',
          'n': '8',
          'w': keyword,
          'aggr': '1',
          'lossless': '0',
          'cr': '1',
          'new_json': '1',
        }),
        headers: {
          'Referer': 'https://y.qq.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      final songList = json['data']?['song']?['list'] as List?;
      if (songList == null || songList.isEmpty) return [];

      final titleLower = title.toLowerCase();
      final artistLower = artist?.toLowerCase() ?? '';

      return songList.map((song) {
        final songName = (song['songname'] ?? song['name'] ?? '').toString();
        final singerList = song['singer'] as List?;
        final singerName = singerList?.isNotEmpty == true
            ? (singerList!.map((s) => s['name']).join('/'))
            : (song['singername'] ?? '').toString();
        final songId = (song['songid'] ?? song['id'] ?? '').toString();
        final albumName = (song['albumname'] ?? song['album']?['name'] ?? '').toString();
        final interval = song['interval'] as int?;
        final dur = interval != null
            ? '${interval ~/ 60}:${(interval % 60).toString().padLeft(2, '0')}'
            : null;

        // 计算匹配分数
        int score = 0;
        if (songName.toLowerCase() == titleLower) score += 60;
        else if (songName.toLowerCase().contains(titleLower)) score += 30;
        if (artistLower.isNotEmpty) {
          if (singerName.toLowerCase().contains(artistLower) ||
              artistLower.contains(singerName.toLowerCase())) {
            score += 30;
          }
        }

        return LyricsCandidate(
          platform: 'qq',
          platformLabel: 'QQ音乐',
          songId: songId,
          title: songName,
          artist: singerName,
          album: albumName.isNotEmpty ? albumName : null,
          duration: dur,
          matchScore: score,
        );
      }).where((c) => c.songId.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐候选搜索失败: $e');
      return [];
    }
  }

  /// 搜索网易云候选列表（返回多条）（优先 weapi 手机版）
  Future<List<LyricsCandidate>> _searchNeteaseCandidates(
    String title, {
    String? artist,
  }) async {
    // 优先使用 weapi 手机版接口
    if (_neteaseApiAvailable && _neteaseApiService != null) {
      final candidates = await _searchNeteaseCandidatesViaWeapi(title, artist: artist);
      if (candidates.isNotEmpty) return candidates;
      if (kDebugMode) print('⚠️ weapi 候选搜索无结果，降级到 /api/');
    }

    // 降级：旧的 /api/ 接口
    try {
      final keyword = artist != null && artist.isNotEmpty ? '$title $artist' : title;
      final query = Uri.encodeComponent(keyword);
      final url = 'https://music.163.com/api/search/get?s=$query&type=1&limit=8';

      final response = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 6),
        onTimeout: () => http.Response('timeout', 408),
      );

      if (response.statusCode != 200) return [];

      final json = jsonDecode(response.body);
      final songs = json['result']?['songs'] as List?;
      if (songs == null || songs.isEmpty) return [];

      final titleLower = title.toLowerCase();
      final artistLower = artist?.toLowerCase() ?? '';

      return songs.map((song) {
        final songName = (song['name'] ?? '').toString();
        final artists = song['artists'] as List?;
        final singerName = artists?.isNotEmpty == true
            ? (artists!.map((a) => a['name']).join('/'))
            : '';
        final songId = song['id'].toString();
        final albumName = (song['album']?['name'] ?? '').toString();
        final duration = song['duration'] as int?; // 毫秒
        final dur = duration != null
            ? '${duration ~/ 60000}:${((duration % 60000) ~/ 1000).toString().padLeft(2, '0')}'
            : null;

        // 计算匹配分数
        int score = 0;
        if (songName.toLowerCase() == titleLower) score += 60;
        else if (songName.toLowerCase().contains(titleLower)) score += 30;
        if (artistLower.isNotEmpty) {
          if (singerName.toLowerCase().contains(artistLower) ||
              artistLower.contains(singerName.toLowerCase())) {
            score += 30;
          }
        }

        return LyricsCandidate(
          platform: 'netease',
          platformLabel: '网易云',
          songId: songId,
          title: songName,
          artist: singerName,
          album: albumName.isNotEmpty ? albumName : null,
          duration: dur,
          matchScore: score,
        );
      }).where((c) => c.songId.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) print('❌ 网易云候选搜索失败: $e');
      return [];
    }
  }

  /// 通过 weapi 手机版接口搜索网易云候选列表
  Future<List<LyricsCandidate>> _searchNeteaseCandidatesViaWeapi(
    String title, {
    String? artist,
  }) async {
    try {
      final keyword = artist != null && artist.isNotEmpty ? '$title $artist' : title;
      final result = await _neteaseApiService!.search(
        keywords: keyword,
        type: 1,
        limit: 8,
      );

      if (result.songs.isEmpty) return [];

      final titleLower = title.toLowerCase();
      final artistLower = artist?.toLowerCase() ?? '';

      return result.songs.map((song) {
        final songName = song.name;
        final singerName = song.artistsName;
        final songId = song.id;
        final albumName = song.albumName;
        final dur = song.duration > 0
            ? '${song.duration ~/ 60000}:${((song.duration % 60000) ~/ 1000).toString().padLeft(2, '0')}'
            : null;

        int score = 0;
        if (songName.toLowerCase() == titleLower) score += 60;
        else if (songName.toLowerCase().contains(titleLower)) score += 30;
        if (artistLower.isNotEmpty &&
            singerName.toLowerCase().contains(artistLower)) score += 30;

        return LyricsCandidate(
          platform: 'netease',
          platformLabel: '网易云',
          songId: songId,
          title: songName,
          artist: singerName,
          album: albumName != null && albumName.isNotEmpty ? albumName : null,
          duration: dur,
          matchScore: score,
        );
      }).where((c) => c.songId.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) print('❌ 网易云(weapi)候选搜索失败: $e');
      return [];
    }
  }

  /// 根据候选条目获取并应用歌词
  ///
  /// [candidate] 用户选择的歌词候选条目
  Future<bool> fetchLyricsFromCandidate(LyricsCandidate candidate) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (candidate.platform == 'lrccx') {
        // lrc.cx：用 title+artist 直接请求
        final success = await _fetchLyricsFromLrcCx(
          candidate.title,
          artist: candidate.artist.isNotEmpty ? candidate.artist : null,
        );
        return success;
      } else if (candidate.platform == 'qq') {
        // QQ音乐：直接用 songId 获取歌词
        final lyric = await _qqMusicService.fetchLyricBySongId(candidate.songId);
        if (lyric != null && lyric.isNotEmpty) {
          _parseLyrics(lyric, null);
          if (kDebugMode) print('✅ QQ音乐候选歌词加载成功: ${_lyrics.length} 行');
          _isLoading = false;
          notifyListeners();
          return true;
        }
        _errorMessage = 'QQ音乐歌词获取失败';
      } else if (candidate.platform == 'netease') {
        // 网易云：直接用 songId 获取歌词
        final success = await fetchLyricsFromNetease(candidate.songId);
        return success;
      } else if (candidate.platform == 'kugou') {
        // 酷狗：songId 存的是 hash
        final success = await _fetchLyricsFromKugou(candidate.songId);
        return success;
      } else if (candidate.platform == 'kuwo') {
        // 酷我：songId 存的是 musicrid
        final success = await _fetchLyricsFromKuwo(candidate.songId);
        return success;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '歌词加载失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── 酷狗 ──────────────────────────────────────────────────────────────────

  /// 酷狗搜索，返回 hash
  Future<String?> _searchKugouHash(String title, {String? artist}) async {
    try {
      final keyword = Uri.encodeComponent(
          artist != null && artist.isNotEmpty ? '$title $artist' : title);
      final url =
          'https://songsearch.kugou.com/song_search_v2?keyword=$keyword&page=1&pagesize=1&platform=WebFilter';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data']?['lists'] as List?;
        if (list != null && list.isNotEmpty) {
          return list[0]['FileHash']?.toString();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ 酷狗搜索失败: $e');
    }
    return null;
  }

  /// 搜索酷狗候选列表
  Future<List<LyricsCandidate>> _searchKugouCandidates(
    String title, {
    String? artist,
  }) async {
    try {
      final keyword = Uri.encodeComponent(
          artist != null && artist.isNotEmpty ? '$title $artist' : title);
      final url =
          'https://songsearch.kugou.com/song_search_v2?keyword=$keyword&page=1&pagesize=8&platform=WebFilter';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body);
      final list = json['data']?['lists'] as List?;
      if (list == null || list.isEmpty) return [];

      final titleLower = title.toLowerCase();
      final artistLower = artist?.toLowerCase() ?? '';

      return list.map((song) {
        final songName = (song['SongName'] ?? '').toString();
        final singerName = (song['SingerName'] ?? '').toString();
        final hash = (song['FileHash'] ?? '').toString();
        final albumName = (song['AlbumName'] ?? '').toString();
        final duration = song['Duration'] as int?;
        final dur = duration != null
            ? '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}'
            : null;

        int score = 0;
        if (songName.toLowerCase() == titleLower) score += 60;
        else if (songName.toLowerCase().contains(titleLower)) score += 30;
        if (artistLower.isNotEmpty &&
            singerName.toLowerCase().contains(artistLower)) score += 30;

        return LyricsCandidate(
          platform: 'kugou',
          platformLabel: '酷狗',
          songId: hash,
          title: songName,
          artist: singerName,
          album: albumName.isNotEmpty ? albumName : null,
          duration: dur,
          matchScore: score,
        );
      }).where((c) => c.songId.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) print('❌ 酷狗候选搜索失败: $e');
      return [];
    }
  }

  /// 通过 hash 从酷狗获取歌词（accesskey 二步法）
  Future<bool> _fetchLyricsFromKugou(String hash) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _lyrics = [];
      _currentLyric = null;
      _currentIndex = 0;
      notifyListeners();

      if (kDebugMode) print('📥 酷狗获取歌词: hash=$hash');

      final searchUrl =
          'https://lyrics.kugou.com/search?ver=1&man=yes&client=pc&keyword=&duration=&hash=$hash';
      final searchResp = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0',
      }).timeout(const Duration(seconds: 6));

      if (searchResp.statusCode != 200) {
        _errorMessage = '酷狗歌词搜索失败 (${searchResp.statusCode})';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final searchJson = jsonDecode(searchResp.body);
      final kugouCandidates = searchJson['candidates'] as List?;
      if (kugouCandidates == null || kugouCandidates.isEmpty) {
        _errorMessage = '酷狗未找到歌词';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final accesskey = kugouCandidates[0]['accesskey']?.toString() ?? '';
      final id = kugouCandidates[0]['id']?.toString() ?? '';

      final downloadUrl =
          'https://lyrics.kugou.com/download?ver=1&client=pc&accesskey=$accesskey&id=$id&fmt=lrc&charset=utf8';
      final downloadResp = await http.get(Uri.parse(downloadUrl), headers: {
        'User-Agent': 'Mozilla/5.0',
      }).timeout(const Duration(seconds: 6));

      if (downloadResp.statusCode == 200) {
        final downloadJson = jsonDecode(downloadResp.body);
        final encodedContent = downloadJson['content']?.toString() ?? '';
        if (encodedContent.isNotEmpty) {
          String lrcContent;
          try {
            lrcContent = utf8.decode(base64Decode(encodedContent));
          } catch (_) {
            lrcContent = encodedContent;
          }
          _parseLyrics(lrcContent, null);
          if (_lyrics.isNotEmpty) {
            if (kDebugMode) print('✅ 酷狗歌词获取成功: ${_lyrics.length} 行');
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      _errorMessage = '酷狗歌词内容为空';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '酷狗歌词获取失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── 酷我 ──────────────────────────────────────────────────────────────────

  /// 酷我搜索，返回 rid
  Future<String?> _searchKuwoId(String title, {String? artist}) async {
    try {
      final keyword = Uri.encodeComponent(
          artist != null && artist.isNotEmpty ? '$title $artist' : title);
      final url =
          'https://kuwo.cn/api/www/search/searchMusicBykeyWord?key=$keyword&pn=0&rn=1&httpsStatus=1';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.kuwo.cn/',
        'cookie': 'kw_token=any',
        'csrf': 'any',
      }).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['data']?['list'] as List?;
        if (list != null && list.isNotEmpty) {
          return list[0]['rid']?.toString();
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ 酷我搜索失败: $e');
    }
    return null;
  }

  /// 搜索酷我候选列表
  Future<List<LyricsCandidate>> _searchKuwoCandidates(
    String title, {
    String? artist,
  }) async {
    try {
      final keyword = Uri.encodeComponent(
          artist != null && artist.isNotEmpty ? '$title $artist' : title);
      final url =
          'https://kuwo.cn/api/www/search/searchMusicBykeyWord?key=$keyword&pn=0&rn=8&httpsStatus=1';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.kuwo.cn/',
        'cookie': 'kw_token=any',
        'csrf': 'any',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body);
      final list = json['data']?['list'] as List?;
      if (list == null || list.isEmpty) return [];

      final titleLower = title.toLowerCase();
      final artistLower = artist?.toLowerCase() ?? '';

      return list.map((song) {
        final songName = (song['name'] ?? '').toString();
        final singerName = (song['artist'] ?? '').toString();
        final musicrid = (song['rid'] ?? '').toString();
        final albumName = (song['album'] ?? '').toString();
        final duration = song['duration'] as int?;
        final dur = duration != null
            ? '${duration ~/ 60}:${(duration % 60).toString().padLeft(2, '0')}'
            : null;

        int score = 0;
        if (songName.toLowerCase() == titleLower) score += 60;
        else if (songName.toLowerCase().contains(titleLower)) score += 30;
        if (artistLower.isNotEmpty &&
            singerName.toLowerCase().contains(artistLower)) score += 30;

        return LyricsCandidate(
          platform: 'kuwo',
          platformLabel: '酷我',
          songId: musicrid,
          title: songName,
          artist: singerName,
          album: albumName.isNotEmpty ? albumName : null,
          duration: dur,
          matchScore: score,
        );
      }).where((c) => c.songId.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) print('❌ 酷我候选搜索失败: $e');
      return [];
    }
  }

  /// 通过 musicrid 从酷我获取歌词
  Future<bool> _fetchLyricsFromKuwo(String musicrid) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _lyrics = [];
      _currentLyric = null;
      _currentIndex = 0;
      notifyListeners();

      if (kDebugMode) print('📥 酷我获取歌词: musicrid=$musicrid');

      final url =
          'https://kuwo.cn/newh5/singles/songinfoandlrc?musicId=$musicrid&httpsStatus=1';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.kuwo.cn/',
        'cookie': 'kw_token=any',
        'csrf': 'any',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final lrcList = json['data']?['lrclist'] as List?;

        if (lrcList != null && lrcList.isNotEmpty) {
          // 酷我格式: [{time: "0.000", lineLyric: "xxx"}, ...] → 标准 LRC
          final buffer = StringBuffer();
          for (final line in lrcList) {
            final timeStr = line['time']?.toString() ?? '';
            final lyricText = line['lineLyric']?.toString() ?? '';
            final timeSec = double.tryParse(timeStr) ?? 0.0;
            final min = timeSec ~/ 60;
            final sec = timeSec % 60;
            final secStr = sec.toStringAsFixed(2).padLeft(5, '0');
            buffer.writeln('[$min:$secStr]$lyricText');
          }
          _parseLyrics(buffer.toString(), null);
          if (_lyrics.isNotEmpty) {
            if (kDebugMode) print('✅ 酷我歌词获取成功: ${_lyrics.length} 行');
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      _errorMessage = '酷我歌词内容为空';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = '酷我歌词获取失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── lrc.cx ───────────────────────────────────────────────────────────────

  /// 直接从 lrc.cx API 获取并应用歌词
  ///
  /// GET https://api.lrc.cx/lyrics?title=xxx&artist=xxx → 纯文本 LRC
  Future<bool> _fetchLyricsFromLrcCx(String title, {String? artist}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      _lyrics = [];
      _currentLyric = null;
      _currentIndex = 0;
      notifyListeners();

      final params = <String, String>{'title': title};
      if (artist != null && artist.isNotEmpty) params['artist'] = artist;
      final uri = Uri.https('api.lrc.cx', '/lyrics', params);

      if (kDebugMode) print('📥 lrc.cx 获取歌词: $uri');

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final lrcContent = response.body.trim();
        if (lrcContent.isNotEmpty && lrcContent.contains('[')) {
          _parseLyrics(lrcContent, null);
          if (_lyrics.isNotEmpty) {
            if (kDebugMode) print('✅ lrc.cx 歌词获取成功: ${_lyrics.length} 行');
            _isLoading = false;
            notifyListeners();
            return true;
          }
        }
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      if (kDebugMode) print('❌ lrc.cx 歌词获取失败: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// lrc.cx 候选搜索（仅返回1条，作为最高优先候选）
  Future<List<LyricsCandidate>> _searchLrcCxCandidate(
    String title, {
    String? artist,
  }) async {
    try {
      final params = <String, String>{'title': title};
      if (artist != null && artist.isNotEmpty) params['artist'] = artist;
      final uri = Uri.https('api.lrc.cx', '/lyrics', params);

      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final lrcContent = response.body.trim();
        if (lrcContent.isNotEmpty && lrcContent.contains('[')) {
          return [
            LyricsCandidate(
              platform: 'lrccx',
              platformLabel: 'lrc.cx',
              songId: '${title}_${artist ?? ""}',
              title: title,
              artist: artist ?? '',
              matchScore: 100, // 最高优先级
            ),
          ];
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ lrc.cx 候选搜索失败: $e');
    }
    return [];
  }
}