import 'package:flutter/material.dart';

/// 音乐平台枚举
enum MusicPlatform {
  netease('网易云', 'netease', Colors.red),
  qq('QQ音乐', 'qq', Colors.green),
  kugou('酷狗', 'kugou', Colors.blue),
  kuwo('酷我', 'kuwo', Colors.orange),
  migu('咪咕', 'migu', Colors.pink),
  local('本地', 'local', Colors.grey);

  final String label;
  final String id;
  final Color color;
  const MusicPlatform(this.label, this.id, this.color);
}

/// 同步记录
class SyncRecord {
  final String id;
  final String playlistId;
  final String playlistName;
  final MusicPlatform platform;
  final DateTime syncTime;
  final int trackCount;
  final bool success;
  final String? errorMessage;

  const SyncRecord({
    required this.id,
    required this.playlistId,
    required this.playlistName,
    required this.platform,
    required this.syncTime,
    required this.trackCount,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'playlistId': playlistId,
    'playlistName': playlistName,
    'platform': platform.id,
    'syncTime': syncTime.toIso8601String(),
    'trackCount': trackCount,
    'success': success,
    'errorMessage': errorMessage,
  };

  factory SyncRecord.fromJson(Map<String, dynamic> json) => SyncRecord(
    id: json['id']?.toString() ?? '',
    playlistId: json['playlistId']?.toString() ?? '',
    playlistName: json['playlistName']?.toString() ?? '',
    platform: MusicPlatform.values.firstWhere(
      (p) => p.id == json['platform'],
      orElse: () => MusicPlatform.netease,
    ),
    syncTime: DateTime.tryParse(json['syncTime']?.toString() ?? '') ?? DateTime.now(),
    trackCount: json['trackCount'] ?? 0,
    success: json['success'] ?? false,
    errorMessage: json['errorMessage']?.toString(),
  );
}