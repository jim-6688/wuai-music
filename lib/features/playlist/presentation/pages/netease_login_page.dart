import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/netease_models.dart';
import '../../providers/netease_provider.dart';

/// 网易云音乐登录页面
class NeteaseLoginPage extends ConsumerStatefulWidget {
  const NeteaseLoginPage({super.key});

  @override
  ConsumerState<NeteaseLoginPage> createState() => _NeteaseLoginPageState();
}

class _NeteaseLoginPageState extends ConsumerState<NeteaseLoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isQrMode = true; // 默认二维码登录（更安全）
  QrCodeInfo? _qrInfo;
  Timer? _qrCheckTimer;
  Timer? _countdownTimer;
  bool _isLoading = false;
  int _remainingSeconds = 300; // 二维码有效期 5 分钟
  String? _scanStatusText;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _qrCheckTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// 手机号登录
  Future<void> _loginWithPhone() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      _showError('请输入手机号和密码');
      return;
    }

    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      _showError('请输入正确的手机号');
      return;
    }

    setState(() => _isLoading = true);

    final syncService = ref.read(neteaseSyncServiceProvider);
    final success = await syncService.loginWithPhone(
      phone: phone,
      password: password,
    );

    setState(() => _isLoading = false);

    if (success) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      _showError(syncService.errorMessage ?? '登录失败');
    }
  }

  /// 初始化二维码登录
  Future<void> _initQrLogin() async {
    _cancelTimers();

    setState(() {
      _qrInfo = null;
      _scanStatusText = null;
      _remainingSeconds = 300;
    });

    final syncService = ref.read(neteaseSyncServiceProvider);
    final info = await syncService.createQrCode();

    if (info != null) {
      setState(() {
        _qrInfo = info;
        _scanStatusText = '请打开网易云音乐App扫码';
      });

      // 开始轮询检查扫码状态
      _startQrCheck();

      // 开始过期倒计时
      _startCountdown();
    } else {
      _showError('生成二维码失败，请检查API设置');
    }
  }

  /// 检查二维码状态
  void _startQrCheck() {
    _qrCheckTimer?.cancel();
    _qrCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_qrInfo == null) {
        timer.cancel();
        return;
      }

      final syncService = ref.read(neteaseSyncServiceProvider);
      final success = await syncService.checkQrCodeStatus(_qrInfo!.key);

      if (success) {
        timer.cancel();
        _cancelTimers();
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else if (syncService.errorMessage?.contains('过期') == true) {
        timer.cancel();
        setState(() {
          _scanStatusText = '二维码已过期，请刷新';
        });
      }
    });
  }

  /// 过期倒计时
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _qrCheckTimer?.cancel();
        if (mounted && _qrInfo != null) {
          setState(() {
            _scanStatusText = '二维码已过期，请点击下方刷新';
          });
        }
      }
    });
  }

  void _cancelTimers() {
    _qrCheckTimer?.cancel();
    _countdownTimer?.cancel();
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('网易云音乐登录'),
        actions: [
          if (_isQrMode)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isQrMode = false;
                  _cancelTimers();
                });
              },
              icon: const Icon(Icons.phone_android, size: 18),
              label: const Text('密码登录'),
            )
          else
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isQrMode = true;
                  _initQrLogin();
                });
              },
              icon: const Icon(Icons.qr_code, size: 18),
              label: const Text('扫码登录'),
            ),
        ],
      ),
      body: _isQrMode ? _buildQrLogin(isDarkMode) : _buildPhoneLogin(),
    );
  }

  /// 手机号登录
  Widget _buildPhoneLogin() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          // Logo
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.music_note,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // 手机号输入
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: '手机号',
              prefixIcon: const Icon(Icons.phone_android),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 密码输入
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 登录按钮
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _loginWithPhone,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '登录',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // 说明
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      '温馨提示',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• 请确保已在设置中配置 API 地址\n'
                  '• 推荐使用扫码登录，更加安全\n'
                  '• 登录状态会被安全保存在本地',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 二维码登录
  Widget _buildQrLogin(bool isDarkMode) {
    final isExpired = _remainingSeconds <= 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 网易云 Logo
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.music_note,
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '扫码登录',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 二维码容器
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      children: [
                        // 二维码或加载中
                        if (_qrInfo != null && !isExpired)
                          Center(
                            child: QrImageView(
                              data: _qrInfo!.qrUrl,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              errorStateBuilder: (context, error) {
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: Icon(Icons.error_outline, size: 48),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width: 200,
                            height: 200,
                            alignment: Alignment.center,
                            color: Colors.grey.shade50,
                            child: const CircularProgressIndicator(),
                          ),

                        // 过期遮罩
                        if (isExpired)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.qr_code_2,
                                        size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    Text(
                                      '二维码已过期',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 倒计时
                  Text(
                    isExpired
                        ? '二维码已失效'
                        : '${_formatCountdown(_remainingSeconds)} 后过期',
                    style: TextStyle(
                      fontSize: 13,
                      color: isExpired
                          ? Colors.red.shade400
                          : (_remainingSeconds < 60
                              ? Colors.orange.shade400
                              : Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 扫码状态提示
            if (_scanStatusText != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _scanStatusText!.contains('过期')
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _scanStatusText!.contains('过期')
                          ? Icons.error_outline
                          : Icons.phone_android,
                      size: 16,
                      color: _scanStatusText!.contains('过期')
                          ? Colors.red.shade400
                          : Colors.blue.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _scanStatusText!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _scanStatusText!.contains('过期')
                            ? Colors.red.shade400
                            : Colors.blue.shade400,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // 步骤说明
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStep('1', '打开网易云音乐App'),
                  const SizedBox(height: 8),
                  _buildStep('2', '点击右上角扫描图标'),
                  const SizedBox(height: 8),
                  _buildStep('3', '扫描上方二维码完成登录'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 刷新按钮
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _initQrLogin,
                icon: const Icon(Icons.refresh),
                label: const Text('刷新二维码'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade500,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
