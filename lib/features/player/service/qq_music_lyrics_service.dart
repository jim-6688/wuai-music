import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// QQ音乐歌词服务
/// API文档: https://c.y.qq.com/
class QQMusicLyricsService {
  static const String _baseUrl = 'https://c.y.qq.com';
  static const String _searchUrl = 'https://c.y.qq.com/soso/fcgi-bin/client_search_cp';
  static const String _lyricsUrl = 'https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg';

  /// 根据歌曲名称模糊搜索，获取歌词
  /// 返回: LRC格式歌词字符串
  Future<String?> fetchLyricsBySongName(String songName, {String? artist}) async {
    try {
      if (kDebugMode) print('🎤 QQ音乐歌词搜索: $songName ${artist ?? ""}');

      // 1. 搜索歌曲
      final songId = await _searchSong(songName, artist: artist);
      if (songId == null) {
        if (kDebugMode) print('❌ 未找到歌曲: $songName');
        return null;
      }

      // 2. 获取歌词
      final lyrics = await _fetchLyrics(songId);
      if (lyrics != null && kDebugMode) {
        print('✅ QQ音乐歌词获取成功: ${lyrics.length} 字符');
      }
      return lyrics;
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐歌词获取失败: $e');
      return null;
    }
  }

  /// 搜索歌曲，返回歌曲ID
  Future<String?> _searchSong(String songName, {String? artist}) async {
    try {
      // 构建搜索关键词
      final keyword = artist != null ? '$songName $artist' : songName;
      
      final response = await http.get(
        Uri.parse(_searchUrl).replace(queryParameters: {
          'format': 'json',
          'p': '1',
          'n': '10',
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
      );

      if (response.statusCode != 200) {
        if (kDebugMode) print('❌ 搜索请求失败: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final songList = data['data']?['song']?['list'] as List?;
      
      if (songList == null || songList.isEmpty) {
        return null;
      }

      // 模糊匹配最佳结果
      final bestMatch = _findBestMatch(songName, artist, songList);
      if (bestMatch != null) {
        final songId = bestMatch['id']?.toString();
        final songTitle = bestMatch['name'] ?? '';
        final songArtist = (bestMatch['singer'] as List?)?.first?['name'] ?? '';
        if (kDebugMode) print('🎵 匹配歌曲: $songTitle - $songArtist (ID: $songId)');
        return songId;
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('❌ 搜索歌曲失败: $e');
      return null;
    }
  }

  /// 从搜索结果中找到最佳匹配
  Map<String, dynamic>? _findBestMatch(
    String targetSong, 
    String? targetArtist, 
    List<dynamic> songList,
  ) {
    final targetSongLower = targetSong.toLowerCase();
    final targetArtistLower = targetArtist?.toLowerCase() ?? '';

    // 计算匹配分数
    int bestScore = 0;
    Map<String, dynamic>? bestMatch;

    for (final song in songList) {
      final songName = (song['name'] as String?)?.toLowerCase() ?? '';
      final singers = song['singer'] as List?;
      final artistName = singers?.isNotEmpty == true 
          ? (singers!.first['name'] as String?)?.toLowerCase() ?? ''
          : '';

      int score = 0;

      // 歌名完全匹配 +50
      if (songName == targetSongLower) {
        score += 50;
      }
      // 歌名包含目标 +30
      else if (songName.contains(targetSongLower)) {
        score += 30;
      }
      // 目标包含歌名 +20
      else if (targetSongLower.contains(songName)) {
        score += 20;
      }

      // 歌手匹配
      if (targetArtistLower.isNotEmpty && artistName.isNotEmpty) {
        if (artistName.contains(targetArtistLower) || targetArtistLower.contains(artistName)) {
          score += 30;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMatch = song as Map<String, dynamic>;
      }
    }

    // 至少要有一定匹配度
    return bestScore >= 20 ? bestMatch : null;
  }

  /// 获取歌词
  Future<String?> _fetchLyrics(String songId) async {
    try {
      final response = await http.get(
        Uri.parse(_lyricsUrl).replace(queryParameters: {
          'songmid': songId,
          'format': 'json',
        }),
        headers: {
          'Referer': 'https://y.qq.com/',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final data = json.decode(response.body);
      final lyric = data['lyric'] as String?;
      
      if (lyric == null || lyric.isEmpty) {
        return null;
      }

      // 解码 Base64 歌词（QQ音乐歌词通常是 Base64 编码）
      try {
        final decoded = utf8.decode(base64Decode(lyric));
        return decoded;
      } catch (_) {
        // 如果不是 Base64，直接返回
        return lyric;
      }
    } catch (e) {
      if (kDebugMode) print('❌ 获取歌词失败: $e');
      return null;
    }
  }

  /// 批量获取歌词（用于歌单同步）
  Future<Map<String, String>> fetchLyricsForSongs(List<Map<String, String>> songs) async {
    final results = <String, String>{};
    
    for (final song in songs) {
      final songName = song['name'] ?? '';
      final artist = song['artist'];
      
      if (songName.isEmpty) continue;
      
      final lyrics = await fetchLyricsBySongName(songName, artist: artist);
      if (lyrics != null) {
        results[songName] = lyrics;
      }
      
      // 避免请求过快
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    return results;
  }
}