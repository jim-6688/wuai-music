import 'package:flutter/foundation.dart';

/// NAS 设备配置模型
/// 用于配置同步和持久化
class NasDeviceConfig {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String? username;
  final String? password;
  final bool autoConnect;
  final List<String> musicShares;
  final DateTime createdAt;
  final DateTime? lastConnectedAt;

  const NasDeviceConfig({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 445,
    this.username,
    this.password,
    this.autoConnect = false,
    this.musicShares = const [],
    required this.createdAt,
    this.lastConnectedAt,
  });

  /// 从 JSON 创建
  factory NasDeviceConfig.fromJson(Map<String, dynamic> json) {
    return NasDeviceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int? ?? 445,
      username: json['username'] as String?,
      password: json['password'] as String?,
      autoConnect: json['autoConnect'] as bool? ?? false,
      musicShares: (json['musicShares'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastConnectedAt: json['lastConnectedAt'] != null
          ? DateTime.parse(json['lastConnectedAt'] as String)
          : null,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ip': ip,
      'port': port,
      'username': username,
      'password': password,
      'autoConnect': autoConnect,
      'musicShares': musicShares,
      'createdAt': createdAt.toIso8601String(),
      'lastConnectedAt': lastConnectedAt?.toIso8601String(),
    };
  }

  /// 复制并修改
  NasDeviceConfig copyWith({
    String? id,
    String? name,
    String? ip,
    int? port,
    String? username,
    String? password,
    bool? autoConnect,
    List<String>? musicShares,
    DateTime? createdAt,
    DateTime? lastConnectedAt,
    bool clearPassword = false,
  }) {
    return NasDeviceConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      ip: ip ?? this.ip,
      port: port ?? this.port,
      username: username ?? this.username,
      password: clearPassword ? null : (password ?? this.password),
      autoConnect: autoConnect ?? this.autoConnect,
      musicShares: musicShares ?? this.musicShares,
      createdAt: createdAt ?? this.createdAt,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NasDeviceConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
