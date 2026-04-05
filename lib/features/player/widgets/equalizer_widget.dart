import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math' as math;
import '../service/audio_equalizer_service.dart';

/// 高级均衡器控件
/// 
/// 提供 10 段均衡器可视化控制和预设管理
class EqualizerWidget extends StatefulWidget {
  /// 均衡器服务
  final AudioEqualizerService equalizerService;
  
  /// 紧凑模式
  final bool compact;
  
  /// 高度
  final double height;

  const EqualizerWidget({
    super.key,
    required this.equalizerService,
    this.compact = false,
    this.height = 300,
  });

  @override
  State<EqualizerWidget> createState() => _EqualizerWidgetState();
}

class _EqualizerWidgetState extends State<EqualizerWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    if (widget.compact) {
      return _buildCompactView(colorScheme);
    }
    
    return _buildFullView(colorScheme);
  }

  /// 构建紧凑视图
  Widget _buildCompactView(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // 开关
          Switch(
            value: widget.equalizerService.enabled,
            onChanged: (value) {
              widget.equalizerService.enabled = value;
              setState(() {});
            },
          ),
          const SizedBox(width: 12),
          
          // 预设选择器
          Expanded(
            child: DropdownButton<String>(
              value: widget.equalizerService.currentPreset,
              isExpanded: true,
              items: widget.equalizerService.getPresets().map((preset) {
                return DropdownMenuItem(
                  value: preset.id,
                  child: Row(
                    children: [
                      Text(preset.icon),
                      const SizedBox(width: 8),
                      Text(preset.name),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  widget.equalizerService.applyPreset(value);
                  setState(() {});
                }
              },
            ),
          ),
          
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showEqualizerDialog(context),
          ),
        ],
      ),
    );
  }

  /// 构建完整视图
  Widget _buildFullView(ColorScheme colorScheme) {
    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          Row(
            children: [
              Icon(
                Icons.equalizer,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '均衡器',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              
              // 开关
              Switch(
                value: widget.equalizerService.enabled,
                onChanged: (value) {
                  widget.equalizerService.enabled = value;
                  setState(() {});
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 预设选择器
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.equalizerService.getPresets().length,
              itemBuilder: (context, index) {
                final preset = widget.equalizerService.getPresets()[index];
                final isSelected = widget.equalizerService.currentPreset == preset.id;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(preset.icon),
                        const SizedBox(width: 4),
                        Text(preset.name),
                      ],
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        widget.equalizerService.applyPreset(preset.id);
                        setState(() {});
                      }
                    },
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 均衡器滑块
          Expanded(
            child: _buildEqualizerSliders(colorScheme),
          ),
          
          const SizedBox(height: 16),
          
          // 音效增强
          _buildEffectControls(colorScheme),
        ],
      ),
    );
  }

  /// 构建均衡器滑块
  Widget _buildEqualizerSliders(ColorScheme colorScheme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(AudioEqualizerService.bandCount, (index) {
            return _buildBandSlider(index, colorScheme);
          }),
        );
      },
    );
  }

  /// 构建单频段滑块
  Widget _buildBandSlider(int band, ColorScheme colorScheme) {
    final gain = widget.equalizerService.getBandGain(band);
    final label = AudioEqualizerService.frequencyLabels[band];
    
    return Column(
      children: [
        // dB 标签
        Text(
          '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(0)}dB',
          style: TextStyle(
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        
        const SizedBox(height: 4),
        
        // 滑块
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                activeTrackColor: colorScheme.primary,
                inactiveTrackColor: colorScheme.surfaceContainerHighest,
                thumbColor: colorScheme.primary,
                overlayColor: colorScheme.primary.withValues(alpha: 0.2),
              ),
              child: Slider(
                value: gain,
                min: -12,
                max: 12,
                onChanged: widget.equalizerService.enabled
                    ? (value) {
                        widget.equalizerService.setBandGain(band, value);
                        setState(() {});
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
            fontSize: 10,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 构建音效增强控件
  Widget _buildEffectControls(ColorScheme colorScheme) {
    return Row(
      children: [
        // 虚拟低音
        Expanded(
          child: _buildEffectSlider(
            '低音增强',
            '🔊',
            widget.equalizerService.bassBoost,
            (value) {
              widget.equalizerService.bassBoost = value;
              setState(() {});
            },
            colorScheme,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 环绕声
        Expanded(
          child: _buildEffectSlider(
            '环绕声',
            '🔉',
            widget.equalizerService.surround,
            (value) {
              widget.equalizerService.surround = value;
              setState(() {});
            },
            colorScheme,
          ),
        ),
        
        const SizedBox(width: 8),
        
        // 混响
        Expanded(
          child: _buildEffectSlider(
            '混响',
            '🎵',
            widget.equalizerService.reverb,
            (value) {
              widget.equalizerService.reverb = value;
              setState(() {});
            },
            colorScheme,
          ),
        ),
      ],
    );
  }

  /// 构建音效滑块
  Widget _buildEffectSlider(
    String label,
    String icon,
    double value,
    ValueChanged<double> onChanged,
    ColorScheme colorScheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 12,
            onChanged: widget.equalizerService.enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  /// 显示均衡器对话框
  void _showEqualizerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // 拖动条
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // 内容
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    child: EqualizerWidget(
                      equalizerService: widget.equalizerService,
                      compact: false,
                      height: 400,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 均衡器可视化组件
/// 
/// 显示实时频谱可视化
class EqualizerVisualizer extends StatelessWidget {
  /// 频谱数据
  final List<double> spectrumData;
  
  /// 颜色
  final Color? color;
  
  /// 高度
  final double height;
  
  /// 宽度
  final double? width;

  const EqualizerVisualizer({
    super.key,
    required this.spectrumData,
    this.color,
    this.height = 100,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = color ?? colorScheme.primary;
    
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SpectrumPainter(
          spectrumData: spectrumData,
          color: barColor,
        ),
      ),
    );
  }
}

/// 频谱绘制器
class _SpectrumPainter extends CustomPainter {
  final List<double> spectrumData;
  final Color color;

  _SpectrumPainter({
    required this.spectrumData,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return;
    
    final barWidth = size.width / spectrumData.length;
    final maxHeight = size.height;
    
    for (int i = 0; i < spectrumData.length; i++) {
      final value = spectrumData[i].clamp(0.0, 1.0);
      final barHeight = maxHeight * value;
      
      final rect = Rect.fromLTWH(
        i * barWidth + 1,
        maxHeight - barHeight,
        barWidth - 2,
        barHeight,
      );
      
      final gradient = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.5),
          color,
        ],
      );
      
      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpectrumPainter oldDelegate) {
    return oldDelegate.spectrumData != spectrumData;
  }
}

/// 预设管理组件
class EqualizerPresetList extends StatelessWidget {
  final AudioEqualizerService equalizerService;
  final ValueChanged<String>? onPresetSelected;

  const EqualizerPresetList({
    super.key,
    required this.equalizerService,
    this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final presets = equalizerService.getPresets();
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: presets.length,
      itemBuilder: (context, index) {
        final preset = presets[index];
        final isSelected = equalizerService.currentPreset == preset.id;
        
        return ListTile(
          leading: Text(
            preset.icon,
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(preset.name),
          trailing: isSelected
              ? Icon(Icons.check, color: theme.colorScheme.primary)
              : null,
          selected: isSelected,
          onTap: () {
            equalizerService.applyPreset(preset.id);
            onPresetSelected?.call(preset.id);
          },
        );
      },
    );
  }
}
