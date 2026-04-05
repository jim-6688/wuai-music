import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../player/service/audio_equalizer_service.dart';

/// 均衡器服务 Provider（全局单例，保持状态跨页面）
final equalizerServiceProvider =
    ChangeNotifierProvider<AudioEqualizerService>((ref) {
  final service = AudioEqualizerService();
  service.initialize();
  return service;
});
