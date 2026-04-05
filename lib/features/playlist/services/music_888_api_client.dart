import 'dart:convert';
import 'dart:io';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';

/// 888333.xyz 音乐网站 API 客户端
///
/// 使用该网站的 API 来获取歌单数据
/// 网站: https://888333.xyz/music/
/// API: https://888333.xyz/music/api.php
class Music888ApiClient {
  static const String baseUrl = 'https://888333.xyz/music/api.php';

  /// 搜索歌曲
  ///
  /// [keyword] 搜索关键词
  /// [source] 平台，默认为 netease（网易云）
  /// [count] 返回数量限制，默认为 20
  /// [pages] 页码，默认为 1
  Future<MetingResponse<List<MetingSong>>> searchSongs(
    String keyword, {
    String source = 'netease',
    int count = 20,
    int pages = 1,
  }) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'types': 'search',
        'name': keyword,
        'source': source,
        'count': count.toString(),
        'pages': pages.toString(),
      });

      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);

        if (data is List) {
          final songs = data
              .map((e) => _convertToMetingSong(e as Map<String, dynamic>))
              .toList();
          return MetingResponse.success(songs);
        }
      }

      return MetingResponse.error('搜索歌曲失败');
    } catch (e) {
      return MetingResponse.error('网络请求失败: $e');
    }
  }

  /// 获取歌单详情
  ///
  /// [id] 歌单 ID
  /// [source] 平台，默认为 netease（网易云）
  Future<MetingResponse<MetingPlaylistDetail>> getPlaylist(
    String id, {
    String source = 'netease',
  }) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'types': 'playlist',
        'id': id,
        'source': source,
      });

      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);

        if (data is List) {
          // API 返回的是歌曲列表，需要构建歌单对象
          final songs = data
              .map((e) => _convertToMetingSong(e as Map<String, dynamic>))
              .toList();

          final playlist = MetingPlaylistDetail(
            id: id,
            name: '歌单',
            artist: '未知',
            pic: null,
            songs: songs,
            platform: source,
          );

          return MetingResponse.success(playlist);
        }
      }

      return MetingResponse.error('获取歌单失败');
    } catch (e) {
      return MetingResponse.error('网络请求失败: $e');
    }
  }

  /// 获取用户歌单列表
  ///
  /// [uid] 用户 ID
  /// [source] 平台，默认为 netease（网易云）
  Future<Map<String, dynamic>> getUserPlaylists(
    String uid, {
    String source = 'netease',
  }) async {
    try {
      final uri = Uri.parse(baseUrl).replace(queryParameters: {
        'types': 'user_playlist',
        'uid': uid,
        'source': source,
      });

      final request = await HttpClient().getUrl(uri);
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody);
        return data as Map<String, dynamic>;
      }

      return {
        'success': false,
        'error': '获取用户歌单失败，状态码: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': '网络请求失败: $e',
      };
    }
  }

  /// 将 888333 API 返回的歌曲格式转换为 MetingSong
  MetingSong _convertToMetingSong(Map<String, dynamic> data) {
    return MetingSong(
      id: data['id']?.toString() ?? '',
      name: data['name']?.toString() ?? '',
      artist: data['artist'] is List
          ? (data['artist'] as List).join('/')
          : data['artist']?.toString() ?? '',
      album: data['album']?.toString() ?? '',
      url: data['url_id']?.toString() ?? '',
      pic: _buildPicUrl(data['pic_id']?.toString()),
      lyricId: data['lyric_id']?.toString(),
      platform: data['source']?.toString() ?? 'netease',
    );
  }

  String? _buildPicUrl(String? picId) {
    if (picId == null || picId.isEmpty) return null;
    return 'https://api.injahow.cn/meting/?type=pic&id=$picId';
  }

  String? _buildLrcUrl(String? lrcId) {
    if (lrcId == null || lrcId.isEmpty) return null;
    return 'https://api.injahow.cn/meting/?type=lrc&id=$lrcId';
  }
}
