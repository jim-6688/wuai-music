import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/config_sync_service.dart';
import '../../models/nas_device_config.dart';
import '../../providers/nas_playlist_provider.dart';
import '../providers/nas_provider.dart';
import '../../service/nas_service.dart';

/// NAS 配置同步页面 - 手机端
/// 生成二维码供 TV 扫描
class NasConfigSyncPage extends ConsumerStatefulWidget {
  const NasConfigSyncPage({super.key});

  @override
  ConsumerState<NasConfigSyncPage> createState() => _NasConfigSyncPageState();
}

class _NasConfigSyncPageState extends ConsumerState<NasConfigSyncPage> {
  String? _qrData;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _generateQRCode();
  }

  Future<void> _generateQRCode() async {
    setState(() => _isGenerating = true);

    try {
      final nasService = ref.read(nasServiceProvider);
      final syncService = ref.read(configSyncServiceProvider);

      // 从已保存的设备生成配置
      final devices = nasService.savedDevices.map((d) {
        return NasDeviceConfig(
          id: d.id,
          name: d.name,
          ip: d.ip,
          port: d.port,
          username: d.username,
          password: d.password,
          autoConnect: d.autoConnect,
          musicShares: d.musicShares,
          createdAt: DateTime.now(),
        );
      }).toList();

      if (devices.isEmpty) {
        setState(() {
          _qrData = null;
          _isGenerating = false;
        });
        return;
      }

      final qrData = syncService.generateQRData(devices);
      setState(() {
        _qrData = qrData;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成二维码失败: $e')),
        );
      }
    }
  }

  Future<void> _shareConfig() async {
    if (_qrData == null) return;

    try {
      // 保存到临时文件并分享
      final result = await Share.share(
        _qrData!,
        subject: 'NAS 设备配置',
      );

      if (result.status == ShareResultStatus.success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('配置已分享')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nasService = ref.watch(nasServiceProvider);
    final devices = nasService.savedDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('同步到 TV'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 说明
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.tv,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '扫描二维码同步 NAS 配置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '在 TV 端打开「设置 → 同步手机配置」扫描此二维码',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // 设备列表
                if (devices.isNotEmpty) ...[
                  Text(
                    '已配置的 NAS 设备 (${devices.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...devices.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(
                                Icons.storage,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      d.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      '${d.ip}:${d.port}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.check_circle,
                                color: Colors.green.shade400,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      )),
                  const SizedBox(height: 24),
                ],

                // 二维码
                if (_isGenerating)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_qrData != null)
                  GlassContainer(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        QrImageView(
                          data: _qrData!,
                          version: QrVersions.auto,
                          size: 240,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Theme.of(context).primaryColor,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '配置大小: ${(_qrData!.length / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  GlassContainer(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(
                          Icons.cloud_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '暂无 NAS 设备配置',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '请先添加 NAS 设备',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // 操作按钮
                if (_qrData != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: GlassButton(
                          onPressed: _shareConfig,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share),
                              SizedBox(width: 8),
                              Text('分享配置'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlassButton(
                          onPressed: _generateQRCode,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.refresh),
                              SizedBox(width: 8),
                              Text('刷新二维码'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 32),

                // 使用说明
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.help_outline,
                            size: 20,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '使用说明',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStep('1', '在 TV 端打开音乐播放器'),
                      _buildStep('2', '进入「设置」页面'),
                      _buildStep('3', '选择「同步手机配置」'),
                      _buildStep('4', '扫描上方二维码'),
                      _buildStep('5', '确认导入配置'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
