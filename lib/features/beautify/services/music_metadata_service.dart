import 'dart:convert';
import 'package:http/http.dart' as http;

/// 音乐元数据查询服务
/// 整合 MusicBrainz + Cover Art Archive + iTunes Search API
class MusicMetadataService {
  static const _mbBase = 'https://musicbrainz.org/ws/2';
  static const _caaBase = 'https://coverartarchive.org';
  static const _itunesBase = 'https://itunes.apple.com/search';

  final http.Client _client;

  MusicMetadataService({http.Client? client}) : _client = client ?? http.Client();

  // ═══════════════════════════════════════════════════════════════════
  // MusicBrainz API
  // ═══════════════════════════════════════════════════════════════════

  /// 根据音频指纹查询 MusicBrainz
  /// [fingerprint] 简化的 Chromaprint 指纹
  /// [duration] 音频时长（秒）
  Future<List<MusicBrainzResult>> lookupByFingerprint(
    String fingerprint,
    double duration,
  ) async {
    // MusicBrainz 不直接支持指纹查询，但支持录音搜索
    // 这里用录音搜索 API，通过duration近似匹配
    // AcoustID 的实际实现：上传 fpcalc 结果到 AcoustID 服务器
    // 简化方案：通过 iTunes/iGuess 搜索
    try {
      // 近似方案：用 duration 搜索同长度范围的曲目
      final durationInt = duration.round();
      final minDuration = durationInt - 5;
      final maxDuration = durationInt + 5;

      final uri = Uri.parse('$_mbBase/recording').replace(
        queryParameters: {
          'query': 'duration:[$minDuration TO $maxDuration]',
          'limit': '10',
          'fmt': 'json',
        },
      );

      final resp = await _client.get(uri, headers: {
        'User-Agent': 'GlassMusicPlayer/1.0 (contact@glassmusic.app)',
        'Accept': 'application/json',
      });

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final recordings = data['recordings'] as List? ?? [];

      return recordings.map((r) {
        final releases = r['releases'] as List? ?? [];
        final firstRelease = releases.isNotEmpty ? releases.first : null;
        return MusicBrainzResult(
          title: r['title'] ?? '',
          artist: (r['artist-credit'] as List?)
                  ?.map((a) => a['name'] ?? '')
                  .join(', ') ?? '',
          album: firstRelease?['title'] ?? '',
          mbid: r['id'] ?? '',
          releaseMbid: firstRelease?['id'],
          duration: (r['length'] ?? 0) ~/ 1000,
          score: (r['score'] ?? 0) as int,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 根据歌名+艺术家搜索 MusicBrainz
  Future<List<MusicBrainzResult>> searchByName(String title, String artist) async {
    try {
      final query = Uri.encodeComponent('$title artist:$artist');
      final uri = Uri.parse('$_mbBase/recording').replace(
        queryParameters: {'query': query, 'limit': '8', 'fmt': 'json'},
      );

      final resp = await _client.get(uri, headers: {
        'User-Agent': 'GlassMusicPlayer/1.0 (contact@glassmusic.app)',
        'Accept': 'application/json',
      });

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final recordings = data['recordings'] as List? ?? [];

      return recordings.map((r) {
        final releases = r['releases'] as List? ?? [];
        final firstRelease = releases.isNotEmpty ? releases.first : null;
        return MusicBrainzResult(
          title: r['title'] ?? '',
          artist: (r['artist-credit'] as List?)
                  ?.map((a) => a['name'] ?? '')
                  .join(', ') ?? '',
          album: firstRelease?['title'] ?? '',
          mbid: r['id'] ?? '',
          releaseMbid: firstRelease?['id'],
          duration: (r['length'] ?? 0) ~/ 1000,
          score: (r['score'] ?? 0) as int,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Cover Art Archive API
  // ═══════════════════════════════════════════════════════════════════

  /// 获取专辑封面 URL 列表（从大到小）
  Future<List<String>> fetchCoverUrls(String releaseMbid) async {
    try {
      final uri = Uri.parse('$_caaBase/release/$releaseMbid');
      final resp = await _client.get(uri, headers: {
        'Accept': 'application/json',
      });

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final images = data['images'] as List? ?? [];

      // 按尺寸排序：优先 2500 > 1400 > 1200 > 500 > 250
      final sorted = images.where((img) => img['image'] != null).toList()
        ..sort((a, b) {
          final aw = a['thumbnails']?['2500'] ?? a['thumbnails']?['large'] ?? '';
          final bw = b['thumbnails']?['2500'] ?? b['thumbnails']?['large'] ?? '';
          return bw.compareTo(aw); // 大的排前面
        });

      return sorted.map((img) {
        final thumbs = img['thumbnails'] as Map<String, dynamic>? ?? {};
        return (thumbs['2500'] ?? thumbs['1400'] ?? thumbs['1200'] ?? thumbs['large'] ?? img['image']) as String;
      }).where((url) => url.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }

  /// 根据专辑名搜索 iTunes 高清封面
  Future<List<String>> fetchItunesCovers(String album, String artist) async {
    try {
      final term = Uri.encodeComponent('$album $artist');
      final uri = Uri.parse('$_itunesBase').replace(
        queryParameters: {
          'term': term,
          'entity': 'album',
          'limit': '5',
        },
      );

      final resp = await _client.get(uri);
      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];

      return results
          .map((item) => item['artworkUrl100'] as String?)
          .where((url) => url != null)
          .map((url) {
            // 把 100x100 的 URL 升级到 600x600
            return url!.replaceFirst('/100x100bb.jpg', '/600x600bb.jpg');
          })
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 综合获取封面：从 Cover Art Archive 优先，再降级 iTunes
  Future<List<String>> fetchAllCovers(String? releaseMbid, String album, String artist) async {
    final urls = <String>[];

    // 1. Cover Art Archive（MusicBrainz 官方，高质量）
    if (releaseMbid != null && releaseMbid.isNotEmpty) {
      final caaUrls = await fetchCoverUrls(releaseMbid);
      urls.addAll(caaUrls);
    }

    // 2. iTunes 兜底
    if (urls.isEmpty) {
      final itunesUrls = await fetchItunesCovers(album, artist);
      urls.addAll(itunesUrls);
    }

    return urls.toSet().toList(); // 去重
  }

  void dispose() {
    _client.close();
  }
}

/// MusicBrainz 录音搜索结果
class MusicBrainzResult {
  final String title;
  final String artist;
  final String album;
  final String mbid;           // 录音 ID
  final String? releaseMbid;   // 发行 ID
  final int duration;          // 秒
  final int score;            // 匹配分 0-100

  const MusicBrainzResult({
    required this.title,
    required this.artist,
    required this.album,
    required this.mbid,
    this.releaseMbid,
    required this.duration,
    required this.score,
  });

  double get confidence => score / 100.0;
}
