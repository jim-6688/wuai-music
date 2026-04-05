import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/custom_color_schemes.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../shared/widgets/glass_widgets.dart';

/// 主题配色选择页面
class ThemePickerPage extends ConsumerStatefulWidget {
  const ThemePickerPage({super.key});

  @override
  ConsumerState<ThemePickerPage> createState() => _ThemePickerPageState();
}

class _ThemePickerPageState extends ConsumerState<ThemePickerPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeConfig = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('主题配色'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '浅色模式'),
            Tab(text: '深色模式'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildColorSchemeList(
            AppColorSchemes.lightSchemes,
            themeConfig,
            false,
          ),
          _buildColorSchemeList(
            AppColorSchemes.darkSchemes,
            themeConfig,
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildColorSchemeList(
    List<ThemeColorScheme> schemes,
    ThemeConfig themeConfig,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: schemes.length + 1, // +1 for custom color option
      itemBuilder: (context, index) {
        if (index == schemes.length) {
          return _buildCustomColorCard(themeConfig, isDark);
        }

        final scheme = schemes[index];
        final isSelected = themeConfig.colorSchemeId == scheme.id &&
            !themeConfig.useCustomColor;

        return _ColorSchemeCard(
          scheme: scheme,
          isSelected: isSelected,
          onTap: () {
            ref.read(themeProvider.notifier).setColorScheme(scheme.id);
          },
        );
      },
    );
  }

  Widget _buildCustomColorCard(ThemeConfig themeConfig, bool isDark) {
    final isCustomSelected = themeConfig.useCustomColor;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: () => _showCustomColorPicker(themeConfig),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeConfig.customPrimaryColor ?? const Color(0xFF007AFF),
                      themeConfig.customSecondaryColor ?? const Color(0xFF5856D6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.palette,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🎨 自定义颜色',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isCustomSelected ? '当前使用' : '点击设置',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (isCustomSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).primaryColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCustomColorPicker(ThemeConfig themeConfig) {
    showDialog(
      context: context,
      builder: (context) => _CustomColorPickerDialog(
        initialPrimaryColor: themeConfig.customPrimaryColor ?? const Color(0xFF007AFF),
        initialSecondaryColor:
            themeConfig.customSecondaryColor ?? const Color(0xFF5856D6),
        onColorSelected: (primary, secondary) {
          ref.read(themeProvider.notifier).setCustomColors(
                primaryColor: primary,
                secondaryColor: secondary,
              );
        },
      ),
    );
  }
}

/// 配色方案卡片
class _ColorSchemeCard extends StatelessWidget {
  final ThemeColorScheme scheme;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSchemeCard({
    required this.scheme,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: [
          // 颜色预览
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: scheme.gradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primaryColor,
                      scheme.secondaryColor,
                    ],
                  ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: scheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                scheme.emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // 名称
          Expanded(
            child: Text(
              scheme.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // 选中标记
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: Theme.of(context).primaryColor,
              size: 28,
            ),
        ],
      ),
    );
  }
}

/// 自定义颜色选择对话框
class _CustomColorPickerDialog extends StatefulWidget {
  final Color initialPrimaryColor;
  final Color initialSecondaryColor;
  final Function(Color, Color) onColorSelected;

  const _CustomColorPickerDialog({
    required this.initialPrimaryColor,
    required this.initialSecondaryColor,
    required this.onColorSelected,
  });

  @override
  State<_CustomColorPickerDialog> createState() =>
      _CustomColorPickerDialogState();
}

class _CustomColorPickerDialogState extends State<_CustomColorPickerDialog> {
  late Color _primaryColor;
  late Color _secondaryColor;

  // 预设颜色
  final List<Color> _presetColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _primaryColor = widget.initialPrimaryColor;
    _secondaryColor = widget.initialSecondaryColor;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('自定义颜色'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 预览
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  '预览效果',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 主色调
            const Text(
              '主色调',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildColorGrid(_primaryColor, (color) {
              setState(() => _primaryColor = color);
            }),

            const SizedBox(height: 16),

            // 副色调
            const Text(
              '副色调',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildColorGrid(_secondaryColor, (color) {
              setState(() => _secondaryColor = color);
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorSelected(_primaryColor, _secondaryColor);
            Navigator.pop(context);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildColorGrid(Color selectedColor, Function(Color) onColorSelected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetColors.map((color) {
        final isSelected = color.value == selectedColor.value;
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
