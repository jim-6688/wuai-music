import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/lyrics_service.dart';
import '../../../playlist/providers/netease_provider.dart';

final lyricsServiceProvider = ChangeNotifierProvider((ref) {
  final service = LyricsService();
  // 接入网易云 weapi 手机版 API 服务
  final neteaseApiService = ref.watch(neteaseApiServiceProvider);
  service.setNeteaseApiService(neteaseApiService);
  return service;
});
