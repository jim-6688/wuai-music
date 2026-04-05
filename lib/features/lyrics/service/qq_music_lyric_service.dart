import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// QQ音乐歌词服务
/// 
/// 提供QQ音乐API歌词搜索和下载功能
/// API文档参考: https://gitcode.net/mirrors/jsososo/QQMusicApi
class QQMusicLyricService extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// QQ音乐搜索API (使用公开镜像)
  static const String _searchApi = 'https://c.y.qq.com/soso/fcgi-bin/client_search_cp';
  /// QQ音乐歌词API
  static const String _lyricApi = 'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg';

  /// 根据歌曲名称和歌手模糊搜索歌词
  /// 
  /// [title] 歌曲名称
  /// [artist] 歌手名称（可选）
  /// 返回: LRC格式歌词文本，失败返回null
  Future<String?> searchAndFetchLyric(String title, {String? artist}) async {
    if (title.isEmpty) return null;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      if (kDebugMode) {
        print('🎵 QQ音乐搜索: $title${artist != null ? ' - $artist' : ''}');
      }

      // Step 1: 搜索歌曲获取 songid
      final songId = await _searchSongId(title, artist: artist);
      if (songId == null) {
        _errorMessage = 'QQ音乐未找到歌曲: $title';
        if (kDebugMode) print('⚠️ $_errorMessage');
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Step 2: 获取歌词
      final lyric = await fetchLyricBySongId(songId);
      
      _isLoading = false;
      notifyListeners();
      return lyric;
    } catch (e) {
      _errorMessage = 'QQ音乐歌词获取失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// 搜索歌曲ID
  /// 
  /// 返回歌曲的songid，失败返回null
  Future<String?> _searchSongId(String title, {String? artist}) async {
    try {
      // 构建搜索关键词
      final keyword = artist != null && artist.isNotEmpty 
          ? '$title $artist' 
          : title;
      
      // QQ音乐搜索API参数
      final params = {
        'format': 'json',
        'p': '1',           // 页码
        'n': '10',          // 每页数量
        'w': keyword,       // 搜索关键词
        'aggr': '1',        // 聚合
        'lossless': '0',    // 无损
        'cr': '1',          // 版权
        'new_json': '1',    // 新JSON格式
      };

      final uri = Uri.parse(_searchApi).replace(queryParameters: params);
      
      final response = await http.get(
        uri,
        headers: {
          'Referer': 'https://y.qq.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        if (kDebugMode) print('⚠️ QQ音乐搜索失败: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      final data = json['data'];
      if (data == null) return null;

      final songList = data['song']?['list'] as List?;
      if (songList == null || songList.isEmpty) {
        if (kDebugMode) print('⚠️ QQ音乐搜索结果为空');
        return null;
      }

      // 模糊匹配：优先选择标题和歌手最匹配的结果
      String? bestMatchId;
      int bestScore = 0;

      for (final song in songList) {
        final songName = (song['songname'] ?? song['name'] ?? '').toString();
        final singerName = (song['singername'] ?? 
                           (song['singer'] is List 
                               ? (song['singer'] as List).map((s) => s['name']).join('/')
                               : song['singer'] ?? '')).toString();
        final songid = song['songid']?.toString() ?? song['id']?.toString();
        
        if (songid == null) continue;

        // 计算匹配分数
        int score = 0;
        
        // 标题匹配
        if (_fuzzyMatch(title.toLowerCase(), songName.toLowerCase())) {
          score += 50;
          // 完全匹配加分
          if (title.toLowerCase() == songName.toLowerCase()) {
            score += 30;
          }
        }
        
        // 歌手匹配
        if (artist != null && artist.isNotEmpty) {
          if (_fuzzyMatch(artist.toLowerCase(), singerName.toLowerCase())) {
            score += 30;
            if (artist.toLowerCase() == singerName.toLowerCase()) {
              score += 20;
            }
          }
        }

        if (score > bestScore) {
          bestScore = score;
          bestMatchId = songid;
        }

        if (kDebugMode) {
          print('  候选: $songName - $singerName (score: $score)');
        }
      }

      if (bestMatchId != null && kDebugMode) {
        print('✅ QQ音乐找到歌曲ID: $bestMatchId (score: $bestScore)');
      }

      return bestMatchId;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐搜索异常: $e');
      return null;
    }
  }

  /// 根据歌曲ID获取歌词（公开方法，供外部直接按 ID 获取）
  Future<String?> fetchLyricBySongId(String songId) async {
    try {
      final params = {
        'songid': songId,
        'format': 'json',
        'nobase64': '1',  // 不使用base64编码
      };

      final uri = Uri.parse(_lyricApi).replace(queryParameters: params);
      
      final response = await http.get(
        uri,
        headers: {
          'Referer': 'https://y.qq.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        if (kDebugMode) print('⚠️ QQ音乐歌词获取失败: ${response.statusCode}');
        return null;
      }

      final json = jsonDecode(response.body);
      
      // QQ音乐歌词可能在不同字段
      String? lyric = json['lyric']?.toString();
      
      // 尝试其他可能的字段
      lyric ??= json['lrc']?.toString();
      lyric ??= json['lyrics']?.toString();
      
      if (lyric == null || lyric.isEmpty) {
        if (kDebugMode) print('⚠️ QQ音乐歌词为空');
        return null;
      }

      // 清理歌词格式
      lyric = _cleanLyric(lyric);
      
      if (kDebugMode) {
        final lineCount = lyric.split('\n').where((l) => l.contains('[') && l.contains(']')).length;
        print('✅ QQ音乐歌词获取成功: $lineCount 行');
      }

      return lyric;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐歌词获取异常: $e');
      return null;
    }
  }

  /// 模糊匹配
  bool _fuzzyMatch(String query, String target) {
    if (query.isEmpty) return false;
    
    // 移除括号内容和空格进行匹配
    final cleanQuery = query.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[（(].*?[）)]'), '');
    final cleanTarget = target.replaceAll(RegExp(r'\s+'), '').replaceAll(RegExp(r'[（(].*?[）)]'), '');
    
    return cleanTarget.contains(cleanQuery) || cleanQuery.contains(cleanTarget);
  }

  /// 清理歌词格式
  String _cleanLyric(String lyric) {
    // 移除可能的JSON包装
    if (lyric.startsWith('"') && lyric.endsWith('"')) {
      lyric = lyric.substring(1, lyric.length - 1);
    }
    
    // 处理转义字符
    lyric = lyric
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '')
        .replaceAll('\r', '');
    
    return lyric;
  }

  /// 清除错误信息
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}