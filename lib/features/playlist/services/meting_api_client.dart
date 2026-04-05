import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:wuaimusic/features/playlist/data/models/meting_models.dart';
import 'package:wuaimusic/features/playlist/data/models/playlist.dart';
import 'package:wuaimusic/features/playlist/services/netease_leaderboard_service.dart';

/// Meting API 客户端
/// 
/// 封装所有与 Meting API 的交互，包括歌单、歌曲、搜索等功能
/// 使用 NeteaseApiConfigStorage 统一管理 API 地址
class MetingApiClient {
  final Dio _dio;
  
  // 单例模式，避免重复创建
  static final MetingApiClient _instance = MetingApiClient._internal();
  factory MetingApiClient() => _instance;
  
  MetingApiClient._internal() 
    : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          responseType: ResponseType.plain,  // 强制返回字符串，然后手动解析
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ));

  /// 获取当前 API 地址（从统一配置读取）
  Future<String> get baseUrl async {
    // 直接返回 Meting API 地址，不再从 SharedPreferences 读取
    return 'https://api.injahow.cn/meting/';
  }

  /// 获取歌单详情
  /// 
  /// [id] 歌单 ID
  /// [platform] 平台，默认为 netease（网易云）
  Future<MetingResponse<MetingPlaylistDetail>> getPlaylist(
    String id, {
    String platform = 'netease',
  }) async {
    try {
      final url = await baseUrl;
      print('🔍 [MetingAPI] 请求 URL: $url');
      print('🔍 [MetingAPI] 参数: type=playlist, id=$id, server=$platform');
      
      final response = await _dio.get(
        url,
        queryParameters: {
          'type': 'playlist',
          'id': id,
          'server': platform,
        },
      );

      print('🔍 [MetingAPI] 响应状态码: ${response.statusCode}');
      print('🔍 [MetingAPI] 响应数据类型: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        final responseData = response.data;
        
        // 手动解析 JSON 字符串
        dynamic data;
        if (responseData is String) {
          try {
            data = json.decode(responseData);
            print('🔍 [MetingAPI] 解析后数据类型: ${data.runtimeType}');
          } catch (e) {
            print('❌ [MetingAPI] JSON解析失败: $e');
            return MetingResponse.error('数据解析失败');
          }
        } else {
          data = responseData;
        }
        
        print('🔍 [MetingAPI] 数据是否为List: ${data is List}');
        if (data is List) {
          print('🔍 [MetingAPI] List长度: ${data.length}');
        }
        
        // API 返回格式：直接是歌曲列表数组
        if (data != null && data is List) {
          // 歌单名称映射
          final String playlistName = {
            '3778678': '热歌榜',
            '3779629': '新歌榜',
            '19723756': '飙升榜',
            '2884035': '说唱榜',
            '3812895': '电音榜',
          }[id] ?? '歌单 $id';
          
          // 解析歌曲列表
          final List<MetingSong> songs = [];
          for (var songData in data) {
            try {
              if (songData is Map<String, dynamic>) {
                songs.add(MetingSong.fromJson(songData));
              } else if (songData is Map) {
                songs.add(MetingSong.fromJson(Map<String, dynamic>.from(songData)));
              }
            } catch (e) {
              print('⚠️ [MetingAPI] 解析歌曲失败: $e');
            }
          }
          
          print('✅ [MetingAPI] 成功解析 ${songs.length} 首歌曲');
          final playlist = MetingPlaylistDetail(
            id: id,
            name: playlistName,
            artist: '网易云音乐',
            url: '',
            platform: platform,
            songs: songs,
          );
          return MetingResponse.success(playlist);
        }
      }

      return MetingResponse.error('获取歌单失败');
    } on DioException catch (e) {
      print('❌ [MetingAPI] DioException: ${e.message}');
      return MetingResponse.error(
        '网络请求失败: ${e.message}',
        code: e.response?.statusCode,
      );
    } catch (e, stack) {
      print('❌ [MetingAPI] 异常: $e');
      print('Stack: $stack');
      return MetingResponse.error('解析数据失败: $e');
    }
  }

  /// 获取单曲信息
  /// 
  /// [id] 歌曲 ID
  /// [platform] 平台，默认为 netease（网易云）
  Future<MetingResponse<MetingSong>> getSong(
    String id, {
    String platform = 'netease',
  }) async {
    try {
      final response = await _dio.get(
        (await baseUrl),
        queryParameters: {
          'type': 'song',
          'id': id,
          'server': platform,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data != null) {
          final song = MetingSong.fromJson(data);
          return MetingResponse.success(song);
        }
      }

      return MetingResponse.error('获取歌曲失败');
    } on DioException catch (e) {
      return MetingResponse.error(
        '网络请求失败: ${e.message}',
        code: e.response?.statusCode,
      );
    } catch (e) {
      return MetingResponse.error('解析数据失败: $e');
    }
  }

  /// 搜索歌单
  /// 
  /// [keyword] 搜索关键词
  /// [platform] 平台，默认为 netease（网易云）
  /// [limit] 返回数量限制，默认为 30
  Future<MetingResponse<List<MetingPlaylistDetail>>> searchPlaylists(
    String keyword, {
    String platform = 'netease',
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get(
        (await baseUrl),
        queryParameters: {
          'type': 'playlist',
          'name': keyword,
          'server': platform,
          'count': limit,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data != null) {
          List<MetingPlaylistDetail> playlists = [];
          
          if (data is List) {
            playlists = data
                .map((e) => MetingPlaylistDetail.fromJson(e as Map<String, dynamic>))
                .toList();
          } else if (data is Map<String, dynamic>) {
            // 单个歌单的情况
            playlists = [MetingPlaylistDetail.fromJson(data)];
          }

          return MetingResponse.success(playlists);
        }
      }

      return MetingResponse.error('搜索歌单失败');
    } on DioException catch (e) {
      return MetingResponse.error(
        '网络请求失败: ${e.message}',
        code: e.response?.statusCode,
      );
    } catch (e) {
      return MetingResponse.error('解析数据失败: $e');
    }
  }

  /// 搜索歌曲
  /// 
  /// [keyword] 搜索关键词
  /// [platform] 平台，默认为 netease（网易云）
  /// [limit] 返回数量限制，默认为 30
  Future<MetingResponse<List<MetingSong>>> searchSongs(
    String keyword, {
    String platform = 'netease',
    int limit = 30,
  }) async {
    try {
      final response = await _dio.get(
        (await baseUrl),
        queryParameters: {
          'type': 'search',
          'id': keyword,
          'server': platform,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data != null) {
          List<MetingSong> songs = [];
          
          if (data is List) {
            songs = (data as List)
                .map((e) => MetingSong.fromJson(e as Map<String, dynamic>))
                .toList();
          } else if (data is Map<String, dynamic>) {
            songs = [MetingSong.fromJson(data)];
          }

          return MetingResponse.success(songs);
        }
      }

      return MetingResponse.error('搜索歌曲失败');
    } on DioException catch (e) {
      return MetingResponse.error(
        '网络请求失败: ${e.message}',
        code: e.response?.statusCode,
      );
    } catch (e) {
      return MetingResponse.error('解析数据失败: $e');
    }
  }

  /// 获取用户歌单列表
  /// 
  /// [uid] 用户 ID
  /// [platform] 平台，默认为 netease（网易云）
  /// [limit] 返回数量限制，默认为 50
  Future<MetingResponse<List<Playlist>>> getUserPlaylists(
    String uid, {
    String platform = 'netease',
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        (await baseUrl),
        queryParameters: {
          'type': 'user_playlist',
          'id': uid,
          'server': platform,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data != null) {
          List<Playlist> playlists = [];
          
          if (data is List) {
            playlists = (data as List)
                .map((e) => MetingPlaylistDetail.fromJson(e as Map<String, dynamic>).toPlaylist())
                .toList();
          } else if (data is Map<String, dynamic>) {
            playlists = [MetingPlaylistDetail.fromJson(data).toPlaylist()];
          }

          return MetingResponse.success(playlists);
        }
      }

      return MetingResponse.error('获取用户歌单失败');
    } on DioException catch (e) {
      return MetingResponse.error(
        '网络请求失败: ${e.message}',
        code: e.response?.statusCode,
      );
    } catch (e) {
      return MetingResponse.error('解析数据失败: $e');
    }
  }

  /// 获取歌曲播放地址
  /// 
  /// [id] 歌曲 ID
  /// [platform] 平台，默认为 netease（网易云）
  /// 
  /// 使用第三方API获取播放URL,支持多个音乐平台
  Future<MetingResponse<String>> getSongUrl(
    String id, {
    String platform = 'netease',
  }) async {
    try {
      // 映射平台名称到API参数
      final platformMap = {
        'netease': 'wy',
        'qq': 'tx',
        'kugou': 'kg',
        'kuwo': 'kw',
        'migu': 'mg',
      };
      
      final apiPlatform = platformMap[platform] ?? 'wy';
      
      // 构建第三方API URL (基于sixyin等音源使用的服务)
      // 例如: https://music.haitangw.cc/music/kw.php?type=mp3&id=xxx&level=320k
      List<String> possibleUrls = [];
      
      // 1. 尝试 haitangw.cc API (sixyin使用的)
      possibleUrls.add('https://music.haitangw.cc/music/$apiPlatform.php?type=mp3&id=$id&level=320k');
      
      // 2. 尝试其他常用API
      if (platform == 'netease') {
        possibleUrls.add('https://api.injahow.cn/meting/?server=netease&type=url&id=$id');
        possibleUrls.add('https://music.haitangw.cc/kgqq/qq.php?type=mp3&id=$id&level=320k');
      }
      
      // 尝试每个可能的URL
      for (final url in possibleUrls) {
        try {
          final response = await _dio.get(
            url,
            options: Options(
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );

          if (response.statusCode == 200) {
            final data = response.data;
            
            // 处理不同格式的响应
            String playUrl = '';
            
            if (data is String) {
              playUrl = data.trim();
              // 过滤掉HTML标签
              if (playUrl.startsWith('<') || playUrl.contains('<html')) {
                playUrl = '';
              }
            } else if (data is Map<String, dynamic>) {
              playUrl = data['url']?.toString() ?? 
                       data['link']?.toString() ?? 
                       data['data']?.toString() ?? '';
            }

            // 验证URL格式
            if (playUrl.isNotEmpty && 
                (playUrl.startsWith('http://') || playUrl.startsWith('https://'))) {
              if (kDebugMode) print('✅ [Meting] 获取播放URL成功: $url');
              return MetingResponse.success(playUrl);
            }
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ [Meting] URL获取失败 ($url): $e');
          continue; // 尝试下一个URL
        }
      }

      return MetingResponse.error('无法获取播放地址');
    } catch (e) {
      return MetingResponse.error('获取播放地址失败: $e');
    }
  }

  /// 获取歌词
  /// 
  /// [id] 歌曲 ID
  /// [platform] 平台，默认为 netease（网易云）
  Future<MetingResponse<String>> getLyric(
    String id, {
    String platform = 'netease',
  }) async {
    try {
      final response = await _dio.get(
        (await baseUrl),
        queryParameters: {
          'type': 'lrc',
          'id': id,
          'server': platform,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        
        if (data != null) {
          String lyric = '';
          
          if (data is String) {
            lyric = data;
          } else if (data is Map<String, dynamic>) {
            lyric = data['lyric']?.toString() ?? data['lrc']?.toString() ?? '';
          }

          if (lyric.isNotEmpty) {
            return MetingResponse.success(lyric);
          }
        }
      }

      return MetingResponse.error('获取歌词失败');
    } on DioException catch (e) {
      return MetingResponse.error(
        '网络请求失败: ${e.message}',
        code: e.response?.statusCode,
      );
    } catch (e) {
      return MetingResponse.error('解析数据失败: $e');
    }
  }

  /// 批量获取歌曲信息
  /// 
  /// [ids] 歌曲 ID 列表
  /// [platform] 平台，默认为 netease（网易云）
  Future<MetingResponse<List<MetingSong>>> getSongs(
    List<String> ids, {
    String platform = 'netease',
  }) async {
    try {
      // 批量请求
      final responses = await Future.wait(
        ids.map((id) => getSong(id, platform: platform)),
      );

      final songs = <MetingSong>[];
      final errors = <String>[];

      for (var response in responses) {
        if (response.success && response.data != null) {
          songs.add(response.data!);
        } else {
          errors.add(response.error ?? '未知错误');
        }
      }

      if (songs.isEmpty) {
        return MetingResponse.error('获取歌曲失败: ${errors.join(', ')}');
      }

      return MetingResponse.success(songs);
    } catch (e) {
      return MetingResponse.error('批量获取歌曲失败: $e');
    }
  }

  /// 验证 API 连接
  Future<bool> checkConnection() async {
    try {
      final response = await _dio.get(
        (await baseUrl),
        queryParameters: {
          'type': 'song',
          'id': 'test',
        },
        options: Options(
          receiveTimeout: const Duration(seconds: 3),
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 获取歌曲真实播放地址
  /// 
  /// [urlApi] Meting API 返回的 url 字段（如 https://api.injahow.cn/meting/?server=netease&type=url&id=xxx）
  Future<String?> resolveSongUrl(String urlApi) async {
    try {
      print('🔍 [MetingAPI] 获取播放地址: $urlApi');
      
      final response = await _dio.get(urlApi);
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // 解析响应
        String? realUrl;
        if (data is String) {
          // 直接返回的是音频 URL
          realUrl = data.trim();
        } else if (data is Map) {
          // 可能返回的是 JSON 对象
          realUrl = data['url']?.toString();
        }
        
        if (realUrl != null && realUrl.isNotEmpty) {
          print('✅ [MetingAPI] 获取到播放地址: $realUrl');
          return realUrl;
        }
      }
      
      print('⚠️ [MetingAPI] 未获取到播放地址');
      return null;
    } catch (e) {
      print('❌ [MetingAPI] 获取播放地址失败: $e');
      return null;
    }
  }

  /// 更新 API 基础 URL
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
  }

  /// 关闭客户端
  void close() {
    _dio.close();
  }
}
