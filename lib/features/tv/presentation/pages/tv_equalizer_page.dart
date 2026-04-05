import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../player/presentation/providers/equalizer_provider.dart';
import '../../../player/service/audio_equalizer_service.dart';
import '../../widgets/tv_screen_adapter.dart';
import '../../../../shared/widgets/glass_widgets.dart';

/// TV 端均衡器设置页面
///
/// 支持遥控器操作:
/// - 方向键导航预设、频段、音效增强区域
/// - 左右键调整当前选中项的数值
/// - 上下键在三个区域之间切换焦点
/// - 确认键切换开关 / 选择预设
/// - 返回键返回
class TvEqualizerPage extends ConsumerStatefulWidget {
  const TvEqualizerPage({super.key});

  @override
  ConsumerState<TvEqualizerPage> createState() => _TvEqualizerPageState();
}

/// 焦点区域
enum _FocusSection {
  toggle,       // 开关
  presets,      // 预设列表
  bands,        // 10段频段
  effects,      // 音效增强
  advanced,     // 高级音效（杜比/空间音频）
  reset,        // 重置按钮
}

class _TvEqualizerPageState extends ConsumerState<TvEqualizerPage> {
  final FocusNode _rootFocusNode = FocusNode();

  // 焦点位置
  _FocusSection _section = _FocusSection.presets;
  int _presetIndex = 0;
  int _bandIndex = 0;
  int _effectIndex = 0; // 0=低音, 1=环绕, 2=混响

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _rootFocusNode.dispose();
    super.dispose();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return;
    final key = event.logicalKey;
    final eqService = ref.read(equalizerServiceProvider);
    final presets = eqService.getPresets();

    // 返回键
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.gameButtonB) {
      Navigator.of(context).pop();
      return;
    }

    // 上下区域切换
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _section = _FocusSection.values[
            (_section.index - 1).clamp(0, _FocusSection.values.length - 1)];
      });
      return;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _section = _FocusSection.values[
            (_section.index + 1).clamp(0, _FocusSection.values.length - 1)];
      });
      return;
    }

    // 确认键
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      _handleConfirm(eqService);
      return;
    }

    // 左右操作
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      _handleLeftRight(key == LogicalKeyboardKey.arrowRight, eqService, presets);
      return;
    }
  }

  void _handleConfirm(AudioEqualizerService eqService) {
    switch (_section) {
      case _FocusSection.toggle:
        ref.read(equalizerServiceProvider.notifier).enabled = !eqService.enabled;
        break;
      case _FocusSection.presets:
        final presets = eqService.getPresets();
        if (_presetIndex < presets.length) {
          ref.read(equalizerServiceProvider.notifier).applyPreset(presets[_presetIndex].id);
        }
        break;
      case _FocusSection.bands:
        // 在频段区域，确认键可以重置当前频段
        ref.read(equalizerServiceProvider.notifier).setBandGain(_bandIndex, 0);
        break;
      case _FocusSection.effects:
        // 确认键切换当前音效 0/12
        _toggleEffect(eqService);
        break;
      case _FocusSection.advanced:
        // 高级音效区域仅展示，确认键无操作
        break;
      case _FocusSection.reset:
        ref.read(equalizerServiceProvider.notifier).reset();
        break;
    }
  }

  void _handleLeftRight(bool isRight, AudioEqualizerService eqService, List<EqualizerPreset> presets) {
    switch (_section) {
      case _FocusSection.toggle:
        // 开关区域左右无操作
        break;
      case _FocusSection.presets:
        setState(() {
          _presetIndex = isRight
              ? (_presetIndex + 1).clamp(0, presets.length - 1)
              : (_presetIndex - 1).clamp(0, presets.length - 1);
        });
        break;
      case _FocusSection.bands:
        // 左右切换频段
        setState(() {
          _bandIndex = isRight
              ? (_bandIndex + 1).clamp(0, AudioEqualizerService.bandCount - 1)
              : (_bandIndex - 1).clamp(0, AudioEqualizerService.bandCount - 1);
        });
        break;
      case _FocusSection.effects:
        // 左右切换音效项
        setState(() {
          _effectIndex = isRight
              ? (_effectIndex + 1).clamp(0, 2)
              : (_effectIndex - 1).clamp(0, 2);
        });
        break;
      case _FocusSection.advanced:
        // 高级音效区域左右切换
        setState(() {
          _effectIndex = isRight
              ? (_effectIndex + 1).clamp(0, 3)
              : (_effectIndex - 1).clamp(0, 3);
        });
        break;
      case _FocusSection.reset:
        break;
    }
  }

  void _toggleEffect(AudioEqualizerService eqService) {
    final notifier = ref.read(equalizerServiceProvider.notifier);
    switch (_effectIndex) {
      case 0:
        notifier.bassBoost = eqService.bassBoost > 0 ? 0 : 6;
        break;
      case 1:
        notifier.surround = eqService.surround > 0 ? 0 : 6;
        break;
      case 2:
        notifier.reverb = eqService.reverb > 0 ? 0 : 6;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale = TvScreenAdapter.of(context).scale;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final eqService = ref.watch(equalizerServiceProvider);
    final presets = eqService.getPresets();

    return KeyboardListener(
      focusNode: _rootFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          Navigator.of(context).pop();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1A2E),
                      Color(0xFF16213E),
                      Color(0xFF0F0F23),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE8F4FD),
                      Color(0xFFF0F9FF),
                      Color(0xFFF8FAFC),
                    ],
                  ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // 顶部标题栏
                _buildHeader(scale, isDark, primaryColor, eqService),

                // 主要内容区
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: 48 * scale,
                      vertical: 16 * scale,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 预设区
                        _buildPresetsSection(scale, isDark, primaryColor, eqService, presets),
                        SizedBox(height: 32 * scale),

                        // 10段频段
                        _buildBandsSection(scale, isDark, primaryColor, eqService),
                        SizedBox(height: 32 * scale),

                        // 音效增强
                        _buildEffectsSection(scale, isDark, primaryColor, eqService),

                        SizedBox(height: 32 * scale),

                        // 高级音效（杜比/空间音频）
                        _buildAdvancedSection(scale, isDark, primaryColor, eqService),

                        SizedBox(height: 24 * scale),

                        // 重置按钮
                        _buildResetButton(scale, isDark, primaryColor),
                      ],
                    ),
                  ),
                ),

                // 底部操作提示
                _buildControlHints(scale, isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(double scale, bool isDark, Color primaryColor, AudioEqualizerService eqService) {
    return Padding(
      padding: EdgeInsets.all(32 * scale),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(16 * scale),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.equalizer_rounded,
              size: 48 * scale,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          SizedBox(width: 24 * scale),
          Text(
            '均衡器',
            style: TextStyle(
              fontSize: 48 * scale,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          // 开关
          _buildToggle(scale, isDark, primaryColor, eqService),
        ],
      ),
    );
  }

  Widget _buildToggle(double scale, bool isDark, Color primaryColor, AudioEqualizerService eqService) {
    final isFocused = _section == _FocusSection.toggle;
    return GestureDetector(
      onTap: () => ref.read(equalizerServiceProvider.notifier).enabled = !eqService.enabled,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: EdgeInsets.symmetric(
          horizontal: 32 * scale,
          vertical: 16 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32 * scale),
          color: eqService.enabled
              ? primaryColor.withValues(alpha: 0.2)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04)),
          border: Border.all(
            color: isFocused
                ? primaryColor
                : Colors.white.withValues(alpha: 0.1),
            width: isFocused ? 3 : 1,
          ),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.4),
                    blurRadius: 32,
                    spreadRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              eqService.enabled ? Icons.power_rounded : Icons.power_off_rounded,
              size: 28 * scale,
              color: isFocused
                  ? primaryColor
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
            SizedBox(width: 12 * scale),
            Text(
              eqService.enabled ? '已开启' : '已关闭',
              style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.w600,
                color: isFocused
                    ? primaryColor
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsSection(
    double scale,
    bool isDark,
    Color primaryColor,
    AudioEqualizerService eqService,
    List<EqualizerPreset> presets,
  ) {
    final isFocused = _section == _FocusSection.presets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('预设', scale, isDark),
        SizedBox(height: 16 * scale),
        // 预设卡片横向滚动
        SizedBox(
          height: 120 * scale,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: presets.length,
            itemBuilder: (context, index) {
              final preset = presets[index];
              final isSelected = eqService.currentPreset == preset.id;
              final isItemFocused = isFocused && index == _presetIndex;

              return Padding(
                padding: EdgeInsets.only(right: 16 * scale),
                child: GestureDetector(
                  onTap: () {
                    ref.read(equalizerServiceProvider.notifier).applyPreset(preset.id);
                    setState(() {
                      _section = _FocusSection.presets;
                      _presetIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 140 * scale,
                    padding: EdgeInsets.symmetric(
                      horizontal: 16 * scale,
                      vertical: 16 * scale,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20 * scale),
                      color: isItemFocused
                          ? primaryColor.withValues(alpha: 0.25)
                          : (isSelected
                              ? primaryColor.withValues(alpha: 0.12)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.04))),
                      border: Border.all(
                        color: isItemFocused
                            ? primaryColor
                            : (isSelected
                                ? primaryColor.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.1)),
                        width: isItemFocused ? 3 : (isSelected ? 2 : 1),
                      ),
                      boxShadow: isItemFocused
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 32,
                                spreadRadius: 8,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          preset.icon,
                          style: TextStyle(fontSize: 28 * scale),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          preset.name,
                          style: TextStyle(
                            fontSize: 20 * scale,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isItemFocused
                                ? primaryColor
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (isSelected && !isItemFocused)
                          Padding(
                            padding: EdgeInsets.only(top: 4 * scale),
                            child: Icon(
                              Icons.check_circle,
                              color: primaryColor,
                              size: 16 * scale,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBandsSection(
    double scale,
    bool isDark,
    Color primaryColor,
    AudioEqualizerService eqService,
  ) {
    final isFocused = _section == _FocusSection.bands;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('频率调节（左右选择频段，确认重置当前频段）', scale, isDark),
        SizedBox(height: 16 * scale),
        GlassCard(
          padding: EdgeInsets.symmetric(
            horizontal: 16 * scale,
            vertical: 20 * scale,
          ),
          child: SizedBox(
            height: 260 * scale,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(AudioEqualizerService.bandCount, (index) {
                final gain = eqService.getBandGain(index);
                final label = AudioEqualizerService.frequencyLabels[index];
                final isBandFocused = isFocused && index == _bandIndex;

                return _buildBandColumn(
                  scale: scale,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  gain: gain,
                  label: label,
                  isFocused: isBandFocused,
                  enabled: eqService.enabled,
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBandColumn({
    required double scale,
    required bool isDark,
    required Color primaryColor,
    required double gain,
    required String label,
    required bool isFocused,
    required bool enabled,
  }) {
    // 将增益值 [-12, 12] 映射到柱状图高度 [0, 1]
    final normalizedGain = (gain + 12) / 24;
    final barHeight = normalizedGain.clamp(0.05, 1.0);

    return Column(
      children: [
        // dB 值
        Text(
          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(0)}dB',
          style: TextStyle(
            fontSize: 16 * scale,
            fontWeight: isFocused ? FontWeight.w700 : FontWeight.w500,
            color: isFocused
                ? primaryColor
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
        SizedBox(height: 8 * scale),
        // 频段柱状图
        Expanded(
          child: Container(
            width: 32 * scale,
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32 * scale,
              height: 180 * scale * barHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8 * scale),
                color: isFocused
                    ? primaryColor
                    : (enabled
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.2))
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05))),
                border: isFocused
                    ? Border.all(color: primaryColor, width: 2)
                    : null,
                boxShadow: isFocused
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        // 频率标签
        Text(
          label,
          style: TextStyle(
            fontSize: 16 * scale,
            fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
            color: isFocused
                ? primaryColor
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ],
    );
  }

  Widget _buildEffectsSection(
    double scale,
    bool isDark,
    Color primaryColor,
    AudioEqualizerService eqService,
  ) {
    final isFocused = _section == _FocusSection.effects;

    final effects = [
      ('低音增强', '🔊', eqService.bassBoost),
      ('环绕声', '🔉', eqService.surround),
      ('混响', '🎵', eqService.reverb),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('音效增强（左右选择，确认开关）', scale, isDark),
        SizedBox(height: 16 * scale),
        Row(
          children: effects.asMap().entries.map((entry) {
            final index = entry.key;
            final (name, icon, value) = entry.value;
            final isEffectFocused = isFocused && index == _effectIndex;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                child: GestureDetector(
                  onTap: () {
                    _toggleEffect(eqService);
                    setState(() {
                      _section = _FocusSection.effects;
                      _effectIndex = index;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16 * scale,
                      vertical: 20 * scale,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20 * scale),
                      color: isEffectFocused
                          ? primaryColor.withValues(alpha: 0.2)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.03)),
                      border: Border.all(
                        color: isEffectFocused
                            ? primaryColor
                            : Colors.white.withValues(alpha: 0.1),
                        width: isEffectFocused ? 3 : 1,
                      ),
                      boxShadow: isEffectFocused
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.3),
                                blurRadius: 24,
                                spreadRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          icon,
                          style: TextStyle(fontSize: 32 * scale),
                        ),
                        SizedBox(height: 8 * scale),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 20 * scale,
                            fontWeight: isEffectFocused ? FontWeight.w600 : FontWeight.normal,
                            color: isEffectFocused
                                ? primaryColor
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        SizedBox(height: 8 * scale),
                        // 数值显示
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16 * scale,
                            vertical: 6 * scale,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12 * scale),
                            color: value > 0
                                ? primaryColor.withValues(alpha: 0.15)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03)),
                          ),
                          child: Text(
                            value > 0 ? '+${value.toInt()}' : '${value.toInt()}',
                            style: TextStyle(
                              fontSize: 22 * scale,
                              fontWeight: FontWeight.w700,
                              color: value > 0
                                  ? primaryColor
                                  : (isDark ? Colors.white54 : Colors.black45),
                            ),
                          ),
                        ),
                        // 进度条
                        SizedBox(height: 8 * scale),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4 * scale),
                          child: LinearProgressIndicator(
                            value: value / 12,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : Colors.black.withValues(alpha: 0.06),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              value > 0 ? primaryColor : primaryColor.withValues(alpha: 0.3),
                            ),
                            minHeight: 6 * scale,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildResetButton(double scale, bool isDark, Color primaryColor) {
    final isFocused = _section == _FocusSection.reset;
    return Center(
      child: GestureDetector(
        onTap: () => ref.read(equalizerServiceProvider.notifier).reset(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: EdgeInsets.symmetric(
            horizontal: 40 * scale,
            vertical: 16 * scale,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24 * scale),
            color: isFocused
                ? Colors.redAccent.withValues(alpha: 0.15)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.03)),
            border: Border.all(
              color: isFocused
                  ? Colors.redAccent
                  : Colors.white.withValues(alpha: 0.1),
              width: isFocused ? 3 : 1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.refresh_rounded,
                size: 24 * scale,
                color: isFocused
                    ? Colors.redAccent
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              SizedBox(width: 12 * scale),
              Text(
                '重置均衡器',
                style: TextStyle(
                  fontSize: 24 * scale,
                  fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                  color: isFocused
                      ? Colors.redAccent
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedSection(
    double scale,
    bool isDark,
    Color primaryColor,
    AudioEqualizerService eqService,
  ) {
    final isFocused = _section == _FocusSection.advanced;

    final advancedItems = [
      ('杜比全景声', '🎬', eqService.dolbyAtmosAvailable, 'Dolby Atmos'),
      ('杜比视界', '🖥️', eqService.dolbyVisionAvailable, 'Dolby Vision'),
      ('空间音频', '🌐', eqService.spatialAudioAvailable, 'Spatial Audio'),
      ('原生音效引擎', '🎛️', eqService.isNativeEffectAvailable, 'Native AudioEffect'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('高级音效 / 系统能力', scale, isDark),
        SizedBox(height: 16 * scale),
        Row(
          children: advancedItems.asMap().entries.map((entry) {
            final index = entry.key;
            final (name, icon, isAvailable, subtitle) = entry.value;
            final isItemFocused = isFocused && index == _effectIndex;

            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8 * scale),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16 * scale,
                    vertical: 20 * scale,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20 * scale),
                    color: isItemFocused
                        ? primaryColor.withValues(alpha: 0.2)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.03)),
                    border: Border.all(
                      color: isItemFocused
                          ? primaryColor
                          : Colors.white.withValues(alpha: 0.1),
                      width: isItemFocused ? 3 : 1,
                    ),
                    boxShadow: isItemFocused
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 24,
                              spreadRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        icon,
                        style: TextStyle(fontSize: 32 * scale),
                      ),
                      SizedBox(height: 8 * scale),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20 * scale,
                          fontWeight: isItemFocused ? FontWeight.w600 : FontWeight.normal,
                          color: isItemFocused
                              ? primaryColor
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      SizedBox(height: 8 * scale),
                      // 状态标识
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16 * scale,
                          vertical: 6 * scale,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12 * scale),
                          color: isAvailable
                              ? Colors.green.withValues(alpha: 0.15)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isAvailable ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                              size: 16 * scale,
                              color: isAvailable ? Colors.green : (isDark ? Colors.white54 : Colors.black45),
                            ),
                            SizedBox(width: 6 * scale),
                            Text(
                              isAvailable ? '可用' : '不可用',
                              style: TextStyle(
                                fontSize: 18 * scale,
                                fontWeight: FontWeight.w700,
                                color: isAvailable ? Colors.green : (isDark ? Colors.white54 : Colors.black45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14 * scale,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, double scale, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24 * scale,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black54,
      ),
    );
  }

  Widget _buildControlHints(double scale, bool isDark) {
    return Padding(
      padding: EdgeInsets.all(32 * scale),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 40 * scale,
          vertical: 20 * scale,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32 * scale),
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildHint(Icons.arrow_upward_rounded, '上/下', 22 * scale, isDark),
            SizedBox(width: 40 * scale),
            _buildHint(Icons.swap_horiz_rounded, '左/右', 22 * scale, isDark),
            SizedBox(width: 40 * scale),
            _buildHint(Icons.subdirectory_arrow_right_rounded, '确认', 22 * scale, isDark),
            SizedBox(width: 40 * scale),
            _buildHint(Icons.arrow_back_rounded, '返回', 22 * scale, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHint(IconData icon, String label, double fontSize, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
          ),
          child: Icon(
            icon,
            size: 24,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize.clamp(16.0, 22.0),
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ],
    );
  }
}
