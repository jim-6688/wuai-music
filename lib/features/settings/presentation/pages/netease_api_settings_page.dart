import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../playlist/services/netease_leaderboard_service.dart';
import '../../../playlist/providers/netease_provider.dart';
import '../../../player/presentation/providers/lyrics_provider.dart';

/// 网易云API设置页面
class NeteaseApiSettingsPage extends ConsumerStatefulWidget {
  const NeteaseApiSettingsPage({super.key});

  @override
  ConsumerState<NeteaseApiSettingsPage> createState() =>
      _NeteaseApiSettingsPageState();
}

class _NeteaseApiSettingsPageState
    extends ConsumerState<NeteaseApiSettingsPage> {
  late TextEditingController _urlController;
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;
  String? _currentSavedUrl;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: NeteaseLeaderboardService.instance.baseUrl,
    );
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final config = await NeteaseLeaderboardService.instance.getConfig();
    setState(() {
      _currentSavedUrl = config.apiBaseUrl;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testSuccess = false;
        _testResult = '请输入有效的API地址';
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // 临时使用输入的 URL 测试连接
      final service = NeteaseLeaderboardService.instance;
      final originalUrl = service.baseUrl;
      await service.updateBaseUrl(url);
      final success = await service.testConnection();

      if (!success) {
        // 恢复原始 URL
        await service.updateBaseUrl(originalUrl);
      }

      setState(() {
        _testSuccess = success;
        _testResult = success
            ? '连接成功！可以正常获取网易云数据'
            : '连接失败，请检查地址是否正确，或服务是否已启动';
      });
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = '连接失败: $e';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _saveUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的API地址')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. 更新 NeteaseLeaderboardService（持久化到 SharedPreferences）
      await NeteaseLeaderboardService.instance.updateBaseUrl(url);
      // 2. 同步更新 NeteaseApiService
      final apiService = ref.read(neteaseApiServiceProvider);
      await apiService.updateBaseUrl(url);
      // 3. 同步更新歌词服务
      final lyricsService = ref.read(lyricsServiceProvider);
      lyricsService.setNeteaseApiService(apiService);

      setState(() {
        _currentSavedUrl = url;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API地址已保存并生效')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetToDefault() async {
    const defaultUrl = 'http://localhost:3000';
    await NeteaseLeaderboardService.instance.updateBaseUrl(defaultUrl);
    // 同步更新 NeteaseApiService
    final apiService = ref.read(neteaseApiServiceProvider);
    await apiService.updateBaseUrl(defaultUrl);
    _urlController.text = defaultUrl;
    setState(() {
      _currentSavedUrl = defaultUrl;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已重置为默认地址')),
      );
    }
  }

  Future<void> _openDeployGuide() async {
    final uri = Uri.parse('https://github.com/Binaryify/NeteaseCloudMusicApi');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('网易云API设置'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: LiquidBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 说明卡片
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.blue.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '使用说明',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '网易云API用于获取官方榜单数据、用户歌单、在线搜索和歌词。\n\n'
                      '本应用使用 NeteaseCloudMusicApi 开源项目作为后端服务，您需要自行部署或使用公共实例。\n\n'
                      '支持的功能：\n'
                      '• 官方榜单（热歌榜、新歌榜等）\n'
                      '• 用户登录（手机号 / 二维码）\n'
                      '• 歌单同步与详情\n'
                      '• 在线搜索\n'
                      '• 歌词获取\n'
                      '• 多种音质（128k ~ Hi-Res）',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 部署指南
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_upload_rounded,
                          color: Colors.green.shade400,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '快速部署',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '推荐部署方式（任选一种）：\n\n'
                      '1. Vercel 部署（免费，推荐新手）\n'
                      '   fork 仓库后一键部署到 Vercel\n\n'
                      '2. Docker 部署\n'
                      '   docker run -d -p 3000:3000 binaryify/neteasecloudmusicapi\n\n'
                      '3. 本地部署\n'
                      '   git clone 仓库 → npm install → node app.js\n\n'
                      '部署后将访问地址填入下方即可。',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _openDeployGuide,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('查看项目仓库'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.green.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 当前状态
              if (_currentSavedUrl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Icon(Icons.dns_outlined, size: 16, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        '当前地址: $_currentSavedUrl',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),

              // API地址输入
              const Text(
                'API地址',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _urlController,
                      decoration: InputDecoration(
                        hintText: 'http://localhost:3000',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 测试结果
                    if (_testResult != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testSuccess
                              ? Colors.green.withAlpha(20)
                              : Colors.red.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _testSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.error_rounded,
                              color: _testSuccess
                                  ? Colors.green
                                  : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _testResult!,
                                style: TextStyle(
                                  color: _testSuccess
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      onPressed: _isTesting ? null : _testConnection,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isTesting)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            const Icon(Icons.wifi_tethering_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(_isTesting ? '测试中...' : '测试连接'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GlassButton(
                      onPressed: _isLoading ? null : _saveUrl,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isLoading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          else
                            const Icon(Icons.save_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(_isLoading ? '保存中...' : '保存'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  onPressed: _resetToDefault,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restore_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('重置为默认'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
