import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/beautify_provider.dart';
import '../../data/models/beautify_item.dart';

/// 美化配置面板（底部弹出）
class BeautifyConfigSheet extends ConsumerStatefulWidget {
  const BeautifyConfigSheet({super.key});

  @override
  ConsumerState<BeautifyConfigSheet> createState() => _BeautifyConfigSheetState();
}

class _BeautifyConfigSheetState extends ConsumerState<BeautifyConfigSheet> {
  late CoverEnhanceConfig _coverConfig;
  late LyricsEnhanceConfig _lyricsConfig;

  @override
  void initState() {
    super.initState();
    final state = ref.read(beautifyProvider);
    _coverConfig = state.coverConfig;
    _lyricsConfig = state.lyricsConfig;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 拖拽条
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 标题
          Text(
            '美化设置',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // 封面配置
          _SectionTitle('封面修复', Icons.image, theme.primaryColor),
          const SizedBox(height: 12),
          _SwitchTile(
            title: '下载高清封面',
            subtitle: '从 Cover Art Archive / iTunes 获取高质量专辑封面',
            value: _coverConfig.downloadHiresCover,
            onChanged: (v) => setState(() {
              _coverConfig = CoverEnhanceConfig(
                downloadHiresCover: v,
                enableUpscale: _coverConfig.enableUpscale,
                upscaleFactor: _coverConfig.upscaleFactor,
                jpegQuality: _coverConfig.jpegQuality,
              );
            }),
            isDark: isDark,
          ),

          // 歌词配置
          const SizedBox(height: 24),
          _SectionTitle('歌词增强', Icons.lyrics, Colors.purple),
          const SizedBox(height: 12),
          _SwitchTile(
            title: '自动翻译歌词',
            subtitle: '使用 AI 将外语歌词翻译为中文（需联网）',
            value: _lyricsConfig.translateToChinese,
            onChanged: (v) => setState(() {
              _lyricsConfig = LyricsEnhanceConfig(
                translateToChinese: v,
                targetLang: _lyricsConfig.targetLang,
                beautifyFormatting: _lyricsConfig.beautifyFormatting,
              );
            }),
            isDark: isDark,
          ),
          _SwitchTile(
            title: '美化歌词排版',
            subtitle: '规范化 LRC 时间轴、补全缺失时间、清理乱码',
            value: _lyricsConfig.beautifyFormatting,
            onChanged: (v) => setState(() {
              _lyricsConfig = LyricsEnhanceConfig(
                translateToChinese: _lyricsConfig.translateToChinese,
                targetLang: _lyricsConfig.targetLang,
                beautifyFormatting: v,
              );
            }),
            isDark: isDark,
          ),
          const SizedBox(height: 32),

          // 确认按钮
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                ref.read(beautifyProvider.notifier).updateCoverConfig(_coverConfig);
                ref.read(beautifyProvider.notifier).updateLyricsConfig(_lyricsConfig);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '保存设置',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isDark;

  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
