import 'dart:convert';

/// URL缓存条目
class CacheEntry {
  /// 音源URL
  final String url;
  
  /// 创建时间
  final DateTime createdAt;
  
  /// 来源平台
  final String platform;
  
  /// 音质类型
  final String quality;
  
  /// 文件大小（字节）
  final int? fileSize;

  const CacheEntry({
    required this.url,
    required this.createdAt,
    required this.platform,
    required this.quality,
    this.fileSize,
  });

  /// 检查缓存是否过期
  bool isExpired(int ttlMinutes) {
    return DateTime.now().difference(createdAt).inMinutes > ttlMinutes;
  }

  /// 获取缓存时长（分钟）
  int get ageMinutes => DateTime.now().difference(createdAt).inMinutes;

  Map<String, dynamic> toJson() => {
    'url': url,
    'createdAt': createdAt.toIso8601String(),
    'platform': platform,
    'quality': quality,
    'fileSize': fileSize,
  };

  factory CacheEntry.fromJson(Map<String, dynamic> json) => CacheEntry(
    url: json['url'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    platform: json['platform'] as String,
    quality: json['quality'] as String,
    fileSize: json['fileSize'] as int?,
  );

  CacheEntry copyWith({
    String? url,
    DateTime? createdAt,
    String? platform,
    String? quality,
    int? fileSize,
  }) {
    return CacheEntry(
      url: url ?? this.url,
      createdAt: createdAt ?? this.createdAt,
      platform: platform ?? this.platform,
      quality: quality ?? this.quality,
      fileSize: fileSize ?? this.fileSize,
    );
  }

  @override
  String toString() {
    return 'CacheEntry(url: $url, platform: $platform, quality: $quality, age: $ageMinutes minutes)';
  }
}
