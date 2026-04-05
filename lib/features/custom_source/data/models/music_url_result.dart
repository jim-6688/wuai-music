/// 音源获取结果模型
class MusicUrlResult {
  /// 音源URL（可播放的直链）
  final String? url;
  
  /// 错误信息
  final String? error;
  
  /// 错误代码（参考各平台API）
  final int? errorCode;
  
  /// 是否需要VIP权限
  final bool isVipRequired;
  
  /// 是否为版权限制
  final bool isCopyrightRestricted;
  
  /// 是否为IP地区限制
  final bool isGeoBlocked;
  
  /// 是否歌曲不存在
  final bool isNotFound;
  
  /// 实际获取到的音质
  final String? actualQuality;
  
  /// 获取这个URL的平台（kw/kg/tx/wy/mg）
  final String? platform;
  
  /// 获取时间戳
  final DateTime timestamp;
  
  /// 缓存命中？
  final bool fromCache;

  /// 是否为音质降级
  final bool isQualityDowngraded;

  const MusicUrlResult({
    this.url,
    this.error,
    this.errorCode,
    this.isVipRequired = false,
    this.isCopyrightRestricted = false,
    this.isGeoBlocked = false,
    this.isNotFound = false,
    this.actualQuality,
    this.platform,
    required this.timestamp,
    this.fromCache = false,
    this.isQualityDowngraded = false,
  });

  /// 是否为成功
  bool get isSuccess => url != null && url!.isNotEmpty;

  /// 是否为失败
  bool get isFailure => !isSuccess;

  /// 获取用户友好的错误信息
  String get userFriendlyError {
    if (isVipRequired) return '该歌曲为VIP专属，需要会员权限';
    if (isCopyrightRestricted) return '该歌曲因版权限制无法播放';
    if (isGeoBlocked) return '该歌曲在您所在地区不可用';
    if (isNotFound) return '未找到该歌曲';
    if (isQualityDowngraded) return '音质降级';
    return error ?? '无法获取音源';
  }

  /// 是否应该重试
  bool get shouldRetry {
    // 版权限制和地区限制不应该重试
    if (isCopyrightRestricted || isGeoBlocked) return false;
    // VIP限制可以尝试低音质
    if (isVipRequired) return true;
    // 歌曲不存在不应该重试
    if (isNotFound) return false;
    // 其他错误可以重试
    return true;
  }

  /// 工厂方法：从错误代码创建
  factory MusicUrlResult.fromErrorCode(int code) {
    final errors = {
      -110: '版权限制',
      -200: '需要VIP',
      -460: '歌曲不存在',
      -500: '服务器错误',
      -999: '需要登录',
      600: '地区限制',
      -1: '网络错误',
    };
    
    return MusicUrlResult(
      url: null,
      error: errors[code] ?? '未知错误($code)',
      errorCode: code,
      isVipRequired: code == -200,
      isCopyrightRestricted: code == -110,
      isGeoBlocked: code == 600,
      isNotFound: code == -460,
      timestamp: DateTime.now(),
    );
  }

  /// 工厂方法：成功
  factory MusicUrlResult.success({
    required String url,
    required String platform,
    String? actualQuality,
    bool fromCache = false,
    bool isQualityDowngraded = false,
  }) {
    return MusicUrlResult(
      url: url,
      platform: platform,
      actualQuality: actualQuality,
      fromCache: fromCache,
      isQualityDowngraded: isQualityDowngraded,
      timestamp: DateTime.now(),
    );
  }

  /// 工厂方法：失败
  factory MusicUrlResult.failure({
    required String error,
    int? errorCode,
    bool isVipRequired = false,
    bool isCopyrightRestricted = false,
    bool isGeoBlocked = false,
    bool isNotFound = false,
  }) {
    return MusicUrlResult(
      url: null,
      error: error,
      errorCode: errorCode,
      isVipRequired: isVipRequired,
      isCopyrightRestricted: isCopyrightRestricted,
      isGeoBlocked: isGeoBlocked,
      isNotFound: isNotFound,
      timestamp: DateTime.now(),
    );
  }

  /// 复制并修改部分字段
  MusicUrlResult copyWith({
    String? url,
    String? error,
    int? errorCode,
    bool? isVipRequired,
    bool? isCopyrightRestricted,
    bool? isGeoBlocked,
    bool? isNotFound,
    String? actualQuality,
    String? platform,
    DateTime? timestamp,
    bool? fromCache,
    bool? isQualityDowngraded,
  }) {
    return MusicUrlResult(
      url: url ?? this.url,
      error: error ?? this.error,
      errorCode: errorCode ?? this.errorCode,
      isVipRequired: isVipRequired ?? this.isVipRequired,
      isCopyrightRestricted: isCopyrightRestricted ?? this.isCopyrightRestricted,
      isGeoBlocked: isGeoBlocked ?? this.isGeoBlocked,
      isNotFound: isNotFound ?? this.isNotFound,
      actualQuality: actualQuality ?? this.actualQuality,
      platform: platform ?? this.platform,
      timestamp: timestamp ?? this.timestamp,
      fromCache: fromCache ?? this.fromCache,
      isQualityDowngraded: isQualityDowngraded ?? this.isQualityDowngraded,
    );
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'MusicUrlResult(success, url: ${url?.substring(0, 50)}..., platform: $platform, quality: $actualQuality, fromCache: $fromCache)';
    } else {
      return 'MusicUrlResult(failure, error: $error, errorCode: $errorCode)';
    }
  }
}
