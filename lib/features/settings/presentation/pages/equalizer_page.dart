import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../../player/presentation/providers/equalizer_provider.dart';
import '../../../player/service/audio_equalizer_service.dart';

/// 手机端均衡器设置页面
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqService = ref.watch(equalizerServiceProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return LiquidBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('均衡器'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            // 开关
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Switch(
                value: eqService.enabled,
                activeThumbColor: colorScheme.primary,
                onChanged: (value) {
                  ref.read(equalizerServiceProvider.notifier).enabled = value;
                },
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 预设选择
              const Text(
                '预设',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildPresetList(context, ref, eqService),
              const SizedBox(height: 24),

              // 10段均衡器
              const Text(
                '频率调节',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildBandSliders(ref, eqService, colorScheme),
              const SizedBox(height: 24),

              // 音效增强
              const Text(
                '音效增强',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildEffectControls(ref, eqService, colorScheme),
              const SizedBox(height: 24),

              // 重置按钮
              Center(
                child: GlassButton(
                  onPressed: () {
                    ref.read(equalizerServiceProvider.notifier).reset();
                  },
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('重置均衡器'),
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

  /// 预设列表 - 使用 GlassCard 风格
  Widget _buildPresetList(
    BuildContext context,
    WidgetRef ref,
    AudioEqualizerService eqService,
  ) {
    final presets = eqService.getPresets();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: presets.map((preset) {
        final isSelected = eqService.currentPreset == preset.id;
        return GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          onTap: () {
            ref.read(equalizerServiceProvider.notifier).applyPreset(preset.id);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : Colors.grey.withValues(alpha: 0.3),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  preset.icon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 4),
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 10段均衡器滑块
  Widget _buildBandSliders(
    WidgetRef ref,
    AudioEqualizerService eqService,
    ColorScheme colorScheme,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: SizedBox(
        height: 220,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(AudioEqualizerService.bandCount, (index) {
            return _buildBandSlider(ref, eqService, index, colorScheme);
          }),
        ),
      ),
    );
  }

  Widget _buildBandSlider(
    WidgetRef ref,
    AudioEqualizerService eqService,
    int band,
    ColorScheme colorScheme,
  ) {
    final gain = eqService.getBandGain(band);
    final label = AudioEqualizerService.frequencyLabels[band];

    return Column(
      children: [
        // dB 标签
        Text(
          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        // 滑块（垂直）
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.surfaceContainerHighest,
                thumbColor: colorScheme.primary,
                overlayColor: colorScheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: gain,
                min: -12,
                max: 12,
                onChanged: eqService.enabled
                    ? (value) {
                        ref
                            .read(equalizerServiceProvider.notifier)
                            .setBandGain(band, value);
                      }
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // 频率标签
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 音效增强控件
  Widget _buildEffectControls(
    WidgetRef ref,
    AudioEqualizerService eqService,
    ColorScheme colorScheme,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildEffectSlider(
            ref,
            label: '低音增强',
            icon: '🔊',
            value: eqService.bassBoost,
            colorScheme: colorScheme,
            onChanged: (v) {
              ref.read(equalizerServiceProvider.notifier).bassBoost = v;
            },
          ),
          const SizedBox(height: 8),
          _buildEffectSlider(
            ref,
            label: '环绕声',
            icon: '🔉',
            value: eqService.surround,
            colorScheme: colorScheme,
            onChanged: (v) {
              ref.read(equalizerServiceProvider.notifier).surround = v;
            },
          ),
          const SizedBox(height: 8),
          _buildEffectSlider(
            ref,
            label: '混响',
            icon: '🎵',
            value: eqService.reverb,
            colorScheme: colorScheme,
            onChanged: (v) {
              ref.read(equalizerServiceProvider.notifier).reverb = v;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEffectSlider(
    WidgetRef ref, {
    required String label,
    required String icon,
    required double value,
    required ColorScheme colorScheme,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 12),
                  activeTrackColor: colorScheme.primary,
                  inactiveTrackColor: colorScheme.surfaceContainerHighest,
                  thumbColor: colorScheme.primary,
                ),
                child: Slider(
                  value: value,
                  min: 0,
                  max: 12,
                  onChanged:
                      ref.read(equalizerServiceProvider).enabled ? onChanged : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
