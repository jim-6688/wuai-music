import 'package:flutter/material.dart';

/// 开发者配置说明页面
/// 告知用户当前 API 状态和数据来源
class DeveloperConfigPage extends StatelessWidget {
  const DeveloperConfigPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据来源说明'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNeteaseSection(),
            const SizedBox(height: 24),
            _buildQQSection(),
            const SizedBox(height: 24),
            _buildDisclaimerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildNeteaseSection() {
    return _buildCard(
      icon: Icons.music_note,
      title: '网易云音乐',
      color: Colors.red,
      children: [
        const Text(
          '数据来源：网易云音乐开放平台 API',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          '• 公共榜单：无需登录即可浏览\n'
          '• 个人歌单：需扫码登录你的网易云账号\n'
          '• 数据安全：账号信息仅存储在你的设备本地',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildQQSection() {
    return _buildCard(
      icon: Icons.audiotrack,
      title: 'QQ音乐',
      color: Colors.green,
      children: [
        const Text(
          '数据来源：QQ音乐开放平台 API',
          style: TextStyle(fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          '• 当前状态：审核中\n'
          '• 临时方案：使用 Web API 获取公共榜单\n'
          '• 审核通过后：将切换为官方 API',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'QQ 音乐 API 审核通过后将自动升级为官方接口',
                  style: TextStyle(fontSize: 12, color: Colors.orange),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimerSection() {
    return _buildCard(
      icon: Icons.security,
      title: '数据安全声明',
      color: Colors.blue,
      children: [
        const Text(
          '1. 你的网易云音乐/QQ音乐账号信息仅存储在你的设备本地\n'
          '2. 我们不会收集、上传或分享你的个人数据\n'
          '3. 所有 API 调用均通过官方授权接口进行\n'
          '4. 你可以随时退出登录，清除本地存储的账号信息',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}
