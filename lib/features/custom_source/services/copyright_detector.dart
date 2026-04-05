import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../data/models/music_url_result.dart';

/// 版权限制检测服务
class CopyrightDetector {
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  /// 检测音源URL是否有效
  static Future<bool> isUrlValid(String url) async {
    if (!url.startsWith('http')) return false;

    try {
      final response = await _dio.head(url);

      final statusCode = response.statusCode ?? 0;
      final contentType = response.headers.value('content-type') ?? '';

      // 检查HTTP状态码
      if (statusCode >= 400) {
        if (kDebugMode) {
          print('⚠️ URL无效: HTTP $statusCode');
        }
        return false;
      }

      // 检查内容类型是否为音频
      final isAudio = contentType.contains('audio') || 
                     contentType.contains('octet-stream');
      if (!isAudio) {
        if (kDebugMode) {
          print('⚠️ URL无效: Content-Type=$contentType');
        }
        return false;
      }

      // 检查文件大小（至少100KB）
      final contentLength = int.tryParse(
        response.headers.value('content-length') ?? '0'
      ) ?? 0;

      final isValidSize = contentLength >= 100 * 1024;
      if (!isValidSize) {
        if (kDebugMode) {
          print('⚠️ URL无效: 文件过小 $contentLength bytes');
        }
      }

      return isValidSize;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ URL验证失败: $e');
      }
      return false;
    }
  }

  /// 检测是否为真实无损音质
  /// FLAC文件通常大于20MB
  static Future<bool> isRealLossless(String url) async {
    try {
      final response = await _dio.head(url);
      final contentType = response.headers.value('content-type') ?? '';
      final contentLength = int.tryParse(
        response.headers.value('content-length') ?? '0'
      ) ?? 0;

      bool isFlacType = contentType.contains('flac');
      bool isSizeLarge = contentLength > 20 * 1024 * 1024;

      if (kDebugMode) {
        print('🎵 无损验证: type=$contentType, size=${(contentLength / 1024 / 1024).toStringAsFixed(2)}MB');
      }

      return isFlacType && isSizeLarge;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ 无损验证失败: $e');
      }
      return false;
    }
  }

  /// 分析错误类型
  /// 根据错误消息判断具体失败原因
  static MusicUrlResult analyzeError(dynamic error) {
    final errorStr = error.toString().toLowerCase();

    // VIP歌曲检测
    if (errorStr.contains('vip') || 
        errorStr.contains('member') || 
        errorStr.contains('会员')) {
      return MusicUrlResult.failure(
        error: '该歌曲为VIP专属',
        errorCode: -200,
        isVipRequired: true,
      );
    }

    // 版权限制检测
    if (errorStr.contains('copyright') || 
        errorStr.contains('版权') ||
        errorStr.contains('no copyright')) {
      return MusicUrlResult.failure(
        error: '版权限制',
        errorCode: -110,
        isCopyrightRestricted: true,
      );
    }

    // 地区限制检测
    if (errorStr.contains('geo') || 
        errorStr.contains('region') || 
        errorStr.contains('地区') ||
        errorStr.contains('unavailable in your region')) {
      return MusicUrlResult.failure(
        error: '地区限制',
        errorCode: 600,
        isGeoBlocked: true,
      );
    }

    // 歌曲不存在检测
    if (errorStr.contains('not found') || 
        errorStr.contains('不存在') ||
        errorStr.contains('460') ||
        errorStr.contains('404')) {
      return MusicUrlResult.failure(
        error: '歌曲不存在',
        errorCode: -460,
        isNotFound: true,
      );
    }

    // 网络错误
    if (errorStr.contains('network') || 
        errorStr.contains('timeout') ||
        errorStr.contains('network error')) {
      return MusicUrlResult.failure(
        error: '网络错误，请检查网络连接',
        errorCode: -1,
      );
    }

    // 服务器错误
    if (errorStr.contains('500') || 
        errorStr.contains('server error')) {
      return MusicUrlResult.failure(
        error: '服务器错误',
        errorCode: -500,
      );
    }

    // 通用错误
    return MusicUrlResult.failure(
      error: error.toString(),
    );
  }

  /// 从响应数据中分析错误
  static MusicUrlResult analyzeResponse(Map<String, dynamic> response) {
    final code = response['code'];
    final msg = response['msg'] ?? response['message'] ?? '';
    final data = response['data'];

    // 根据错误码判断
    if (code != null) {
      switch (code) {
        case -110:
          return MusicUrlResult.failure(
            error: '版权限制',
            errorCode: code as int,
            isCopyrightRestricted: true,
          );
        case -200:
          return MusicUrlResult.failure(
            error: '需要VIP',
            errorCode: code as int,
            isVipRequired: true,
          );
        case -460:
          return MusicUrlResult.failure(
            error: '歌曲不存在',
            errorCode: code as int,
            isNotFound: true,
          );
        case 404:
          return MusicUrlResult.failure(
            error: '歌曲不存在',
            errorCode: code as int,
            isNotFound: true,
          );
        case 600:
          return MusicUrlResult.failure(
            error: '地区限制',
            errorCode: code as int,
            isGeoBlocked: true,
          );
      }
    }

    // 根据消息判断
    final msgStr = msg.toString().toLowerCase();
    return analyzeError(msgStr);
  }

  /// 验证音质是否匹配
  /// 有些平台会返回比请求更低音质的URL
  static bool isQualityMatch(String url, String requestedQuality) {
    if (url.isEmpty) return false;

    // FLAC音质检测
    if (requestedQuality.contains('flac')) {
      return url.toLowerCase().contains('.flac');
    }

    // 其他音质通常返回MP3
    if (requestedQuality.contains('k')) {
      return url.toLowerCase().contains('.mp3');
    }

    return true;
  }

  /// 获取URL实际音质（通过文件扩展名推断）
  static String? inferQuality(String url) {
    final urlLower = url.toLowerCase();
    
    if (urlLower.contains('.flac')) {
      return 'flac';
    } else if (urlLower.contains('.mp3')) {
      // 尝试从URL中推断音质
      if (urlLower.contains('320') || urlLower.contains('high')) {
        return '320k';
      } else if (urlLower.contains('192')) {
        return '192k';
      } else if (urlLower.contains('128')) {
        return '128k';
      } else {
        return 'unknown';
      }
    } else if (urlLower.contains('.m4a')) {
      return 'aac';
    }
    
    return null;
  }
}
