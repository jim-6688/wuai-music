import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// 专辑封面获取服务
/// 支持多平台：LrcApi(优先)、QQ音乐、网易云、酷狗、酷我
/// 封面统一以 Uint8List 字节缓存，方便 Image.memory 直接渲染
class AlbumArtService {
  /// 字节缓存（key = title_artist_album）
  final Map<String, Uint8List> _bytesCache = {};

  /// 保留 URL 缓存用于兼容本地路径/已有逻辑
  final Map<String, String> _coverCache = {};

  // ─── 公共接口 ──────────────────────────────────────────────────────────────

  /// 获取专辑封面字节（优先 LrcApi，失败后依次尝试各平台）
  ///
  /// 返回：图片 [Uint8List]，或 null
  Future<Uint8List?> getAlbumCoverBytes(String title, {String? artist, String? album}) async {
    if (title.isEmpty) return null;

    final cacheKey = '${title}_${artist ?? ""}_${album ?? ""}';
    if (_bytesCache.containsKey(cacheKey)) return _bytesCache[cacheKey];

    if (kDebugMode) print('🖼️ 尝试获取专辑封面: $title - ${artist ?? "未知"}');

    try {
      // 0. LrcApi /cover → 直接返回二进制（最优先）
      final lrcBytes = await _getLrcApiCoverBytes(title, artist: artist);
      if (lrcBytes != null) {
        _bytesCache[cacheKey] = lrcBytes;
        return lrcBytes;
      }

      // 1. QQ音乐 → 取 URL 后下载
      final qqUrl = await _getQQMusicCoverUrl(title, artist: artist, album: album);
      if (qqUrl != null) {
        final bytes = await _downloadBytes(qqUrl);
        if (bytes != null) { _bytesCache[cacheKey] = bytes; return bytes; }
      }

      // 2. 网易云 → 取 URL 后下载
      final neteaseUrl = await _getNeteaseCoverUrl(title, artist: artist);
      if (neteaseUrl != null) {
        final bytes = await _downloadBytes(neteaseUrl);
        if (bytes != null) { _bytesCache[cacheKey] = bytes; return bytes; }
      }

      // 3. 酷狗 → 取 URL 后下载
      final kugouUrl = await _getKugouCoverUrl(title, artist: artist);
      if (kugouUrl != null) {
        final bytes = await _downloadBytes(kugouUrl);
        if (bytes != null) { _bytesCache[cacheKey] = bytes; return bytes; }
      }

      // 4. 酷我 → 取 URL 后下载
      final kuwoUrl = await _getKuwoCoverUrl(title, artist: artist);
      if (kuwoUrl != null) {
        final bytes = await _downloadBytes(kuwoUrl);
        if (bytes != null) { _bytesCache[cacheKey] = bytes; return bytes; }
      }

      if (kDebugMode) print('⚠️ 未找到专辑封面');
      return null;
    } catch (e) {
      if (kDebugMode) print('❌ 获取专辑封面失败: $e');
      return null;
    }
  }

  /// 兼容旧接口：仍可获取封面 URL（供已有逻辑使用）
  Future<String?> getAlbumCover(String title, {String? artist, String? album}) async {
    if (title.isEmpty) return null;
    final cacheKey = '${title}_${artist ?? ""}_${album ?? ""}';
    if (_coverCache.containsKey(cacheKey)) return _coverCache[cacheKey];

    // LrcApi 无 URL 可用，直接走其他平台
    final qqUrl = await _getQQMusicCoverUrl(title, artist: artist, album: album);
    if (qqUrl != null) { _coverCache[cacheKey] = qqUrl; return qqUrl; }
    final neteaseUrl = await _getNeteaseCoverUrl(title, artist: artist);
    if (neteaseUrl != null) { _coverCache[cacheKey] = neteaseUrl; return neteaseUrl; }
    final kugouUrl = await _getKugouCoverUrl(title, artist: artist);
    if (kugouUrl != null) { _coverCache[cacheKey] = kugouUrl; return kugouUrl; }
    final kuwoUrl = await _getKuwoCoverUrl(title, artist: artist);
    if (kuwoUrl != null) { _coverCache[cacheKey] = kuwoUrl; return kuwoUrl; }
    return null;
  }

  // ─── LrcApi ───────────────────────────────────────────────────────────────

  /// GET https://api.lrc.cx/cover?title=xxx&artist=xxx → 302 → 图片二进制
  Future<Uint8List?> _getLrcApiCoverBytes(String title, {String? artist}) async {
    try {
      final params = <String, String>{'title': title};
      if (artist != null && artist.isNotEmpty) params['artist'] = artist;
      final uri = Uri.https('api.lrc.cx', '/cover', params);

      if (kDebugMode) print('📥 LrcApi cover: $uri');

      // http.get 会自动跟随重定向，最终获取到图片字节
      final response = await http.get(uri, headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final ct = response.headers['content-type'] ?? '';
        if (ct.startsWith('image/')) {
          if (kDebugMode) print('✅ LrcApi cover 获取成功 (${response.bodyBytes.length} bytes)');
          return response.bodyBytes;
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ LrcApi cover 获取失败: $e');
    }
    return null;
  }

  // ─── 各平台 URL 获取 ───────────────────────────────────────────────────────

  Future<String?> _getQQMusicCoverUrl(String title, {String? artist, String? album}) async {
    try {
      final keyword = artist != null ? '$title $artist' : title;
      final searchUrl =
          'https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&p=1&n=10&w=$keyword';
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final songs = json['data']?['song']?['list'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final albumMid = songs[0]['albummid'];
          final albumId = songs[0]['albumid'];
          if (albumMid != null) return 'https://y.qq.com/music/photo_new/T002R300x300M000$albumMid.jpg';
          if (albumId != null) return 'https://y.qq.com/music/photo_new/T002R300x300M000$albumId.jpg';
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ QQ音乐封面获取失败: $e');
    }
    return null;
  }

  Future<String?> _getNeteaseCoverUrl(String title, {String? artist}) async {
    try {
      final keyword = Uri.encodeComponent('$title ${artist ?? ""}');
      final searchUrl = 'https://music.163.com/api/search/get?s=$keyword&type=1&limit=1';
      final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final songs = json['result']?['songs'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final picUrl = songs[0]['al']?['picUrl'];
          if (picUrl != null) return '$picUrl?param=300y300';
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ 网易云封面获取失败: $e');
    }
    return null;
  }

  Future<String?> _getKugouCoverUrl(String title, {String? artist}) async {
    try {
      final keyword = Uri.encodeComponent(
          artist != null && artist.isNotEmpty ? '$title $artist' : title);
      final searchUrl =
          'https://songsearch.kugou.com/song_search_v2?keyword=$keyword&page=1&pagesize=1&platform=WebFilter';
      final response = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final songs = json['data']?['lists'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final song = songs[0];
          final imgUrl = song['ImgUrl']?.toString() ?? '';
          if (imgUrl.isNotEmpty) {
            return imgUrl.replaceFirst(RegExp(r'/\{size\}$'), '/400');
          }
          final albumId = song['AlbumID']?.toString() ?? '';
          if (albumId.isNotEmpty && albumId != '0') {
            return 'https://imge.kugou.com/stdmusic/20150717/${albumId.padLeft(20, '0')}.jpg';
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ 酷狗封面获取失败: $e');
    }
    return null;
  }

  Future<String?> _getKuwoCoverUrl(String title, {String? artist}) async {
    try {
      final keyword = Uri.encodeComponent(
          artist != null && artist.isNotEmpty ? '$title $artist' : title);
      final searchUrl =
          'https://kuwo.cn/api/www/search/searchMusicBykeyWord?key=$keyword&pn=0&rn=1&httpsStatus=1';
      final response = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.kuwo.cn/',
        'cookie': 'kw_token=any',
        'csrf': 'any',
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final songs = json['data']?['list'] as List?;
        if (songs != null && songs.isNotEmpty) {
          final song = songs[0];
          final pic = song['pic']?.toString() ?? '';
          if (pic.isNotEmpty) return pic.replaceAll('50x50', '300x300');
          final albumpic = song['albumpic']?.toString() ?? '';
          if (albumpic.isNotEmpty) return albumpic;
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ 酷我封面获取失败: $e');
    }
    return null;
  }

  // ─── 辅助方法 ──────────────────────────────────────────────────────────────

  /// 下载 URL 对应的图片字节
  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 封面图片下载失败 ($url): $e');
    }
    return null;
  }

  /// 清除缓存
  void clearCache() {
    _coverCache.clear();
    _bytesCache.clear();
  }

  /// 获取缓存大小
  int get cacheSize => _bytesCache.length;
}
