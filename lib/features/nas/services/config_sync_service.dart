import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/nas_device_config.dart';

/// NAS 配置同步服务
/// 
/// 功能：
/// 1. 手机端生成配置二维码
/// 2. TV 端扫描二维码同步配置
/// 3. 导出/导入配置文件
class ConfigSyncService {
  static const String _configFileName = 'nas_config.json';
  
  /// 导出 NAS 配置为 JSON 字符串
  String exportConfig(List<NasDeviceConfig> devices) {
    final config = {
      'version': 1,
      'devices': devices.map((d) => d.toJson()).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    return jsonEncode(config);
  }
  
  /// 从 JSON 字符串导入配置
  List<NasDeviceConfig> importConfig(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final version = json['version'] as int?;
      if (version != 1) {
        throw FormatException('不支持的配置版本: $version');
      }
      
      final devicesJson = json['devices'] as List<dynamic>;
      return devicesJson
          .map((d) => NasDeviceConfig.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('导入配置失败: $e');
      rethrow;
    }
  }
  
  /// 生成配置二维码数据
  /// 返回用于生成二维码的字符串
  String generateQRData(List<NasDeviceConfig> devices) {
    final config = exportConfig(devices);
    // 如果配置太长，可能需要压缩或分片
    // 这里先简单处理
    return config;
  }
  
  /// 保存配置到本地文件
  Future<String> saveConfigToFile(List<NasDeviceConfig> devices) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$_configFileName');
    final content = exportConfig(devices);
    await file.writeAsString(content, encoding: utf8);
    return file.path;
  }
  
  /// 从本地文件加载配置
  Future<List<NasDeviceConfig>?> loadConfigFromFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$_configFileName');
      if (!await file.exists()) return null;
      
      final content = await file.readAsString(encoding: utf8);
      return importConfig(content);
    } catch (e) {
      debugPrint('加载配置文件失败: $e');
      return null;
    }
  }
  
  /// 检查配置是否有效
  bool isValidConfig(String jsonString) {
    try {
      final config = importConfig(jsonString);
      return config.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  
  /// 合并配置（去重）
  List<NasDeviceConfig> mergeConfigs(
    List<NasDeviceConfig> existing,
    List<NasDeviceConfig> imported,
  ) {
    final existingIds = existing.map((d) => d.id).toSet();
    final merged = List<NasDeviceConfig>.from(existing);
    
    for (final device in imported) {
      if (!existingIds.contains(device.id)) {
        merged.add(device);
      }
    }
    
    return merged;
  }
}

/// Provider
final configSyncServiceProvider = Provider<ConfigSyncService>((ref) {
  return ConfigSyncService();
});
