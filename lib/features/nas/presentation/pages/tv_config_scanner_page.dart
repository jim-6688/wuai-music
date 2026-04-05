import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../services/config_sync_service.dart';
import '../../models/nas_device_config.dart';
import '../../providers/nas_playlist_provider.dart';
import '../providers/nas_provider.dart';
import '../../service/nas_service.dart';

/// TV 端二维码扫描页面
/// 用于扫描手机端生成的配置二维码
class TvConfigScannerPage extends ConsumerStatefulWidget {
  const TvConfigScannerPage({super.key});

  @override
  ConsumerState<TvConfigScannerPage> createState() => _TvConfigScannerPageState();
}

class _TvConfigScannerPageState extends ConsumerState<TvConfigScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.front, // TV 通常前置摄像头
  );

  bool _isProcessing = false;
  bool _scanSuccess = false;
  String? _errorMessage;
  int _importedCount = 0;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _scanSuccess) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final barcode = barcodes.first;
    final rawValue = barcode.rawValue;
    if (rawValue == null) return;

    _processQRData(rawValue);
  }

  Future<void> _processQRData(String data) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final syncService = ref.read(configSyncServiceProvider);
      
      // 验证配置
      if (!syncService.isValidConfig(data)) {
        throw FormatException('无效的配置格式');
      }

      // 导入配置
      final importedDevices = syncService.importConfig(data);
      
      if (importedDevices.isEmpty) {
        throw Exception('配置中没有设备');
      }

      // 合并到现有配置
      final nasService = ref.read(nasServiceProvider);
      final existingConfigs = nasService.savedDevices.map((d) {
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

      final mergedConfigs = syncService.mergeConfigs(
        existingConfigs,
        importedDevices,
      );

      // 保存合并后的配置
      for (final config in importedDevices) {
        if (!nasService.savedDevices.any((d) => d.id == config.id)) {
          await nasService.addDeviceFromConfig(config);
        }
      }

      setState(() {
        _scanSuccess = true;
        _importedCount = importedDevices.length;
        _isProcessing = false;
      });

      // 震动反馈
      HapticFeedback.mediumImpact();

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString();
      });

      // 继续扫描
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _errorMessage = null);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTV = screenSize.width > 1000; // 简单判断是否 TV

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 扫描器
          if (!_scanSuccess)
            MobileScanner(
              controller: _scannerController,
              onDetect: _onDetect,
            ),

          // 遮罩层
          if (!_scanSuccess)
            CustomPaint(
              painter: _ScannerOverlayPainter(),
              size: Size.infinite,
            ),

          // 顶部提示
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isProcessing ? '正在解析配置...' : '扫描手机端二维码',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '将二维码置于取景框内',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 错误提示
          if (_errorMessage != null)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 成功页面
          if (_scanSuccess)
            Container(
              color: Colors.black.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green.shade500,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      '同步成功！',
                      style: TextStyle(
                        fontSize: isTV ? 32 : 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '已导入 $_importedCount 个 NAS 设备配置',
                      style: TextStyle(
                        fontSize: isTV ? 20 : 16,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 48,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        '完成',
                        style: TextStyle(fontSize: isTV ? 18 : 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 底部手动输入选项
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: 24,
                right: 24,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => _showManualInputDialog(),
                    icon: const Icon(
                      Icons.edit,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      '手动输入',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                    ),
                    label: const Text(
                      '取消',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动输入配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('粘贴从手机端分享的配置文本：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '粘贴配置 JSON...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _processQRData(controller.text);
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }
}

/// 扫描框遮罩绘制器
class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    // 扫描框大小
    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;

    // 绘制半透明遮罩（中间镂空）
    final scanRect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);
    final outerPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final innerPath = Path()..addRect(scanRect);
    final combinedPath = Path.combine(PathOperation.difference, outerPath, innerPath);
    canvas.drawPath(combinedPath, paint);

    // 绘制扫描框边框
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cornerLength = 30.0;

    // 四个角
    final corners = [
      // 左上角
      [Offset(left, top + cornerLength), Offset(left, top), Offset(left + cornerLength, top)],
      // 右上角
      [Offset(left + scanAreaSize - cornerLength, top), Offset(left + scanAreaSize, top), Offset(left + scanAreaSize, top + cornerLength)],
      // 右下角
      [Offset(left + scanAreaSize, top + scanAreaSize - cornerLength), Offset(left + scanAreaSize, top + scanAreaSize), Offset(left + scanAreaSize - cornerLength, top + scanAreaSize)],
      // 左下角
      [Offset(left + cornerLength, top + scanAreaSize), Offset(left, top + scanAreaSize), Offset(left, top + scanAreaSize - cornerLength)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], borderPaint);
      canvas.drawLine(corner[1], corner[2], borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
