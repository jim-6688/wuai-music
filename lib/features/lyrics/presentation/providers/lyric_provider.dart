import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/lyric_service.dart';

/// 歌词服务 Provider
final lyricServiceProvider = ChangeNotifierProvider<LyricService>((ref) {
  final service = LyricService();
  return service;
});

/// 当前歌词 Provider
final currentLyricProvider = ChangeNotifierProvider<LyricService>((ref) {
  return ref.watch(lyricServiceProvider);
}).select((service) => service.currentLyric);

/// 是否有歌词 Provider
final hasLyricProvider = ChangeNotifierProvider<LyricService>((ref) {
  return ref.watch(lyricServiceProvider);
}).select((service) => service.hasLyric);

/// 当前行索引 Provider
final currentLineIndexProvider = ChangeNotifierProvider<LyricService>((ref) {
  return ref.watch(lyricServiceProvider);
}).select((service) => service.currentLineIndex);

/// 当前歌词行 Provider
final currentLineProvider = ChangeNotifierProvider<LyricService>((ref) {
  return ref.watch(lyricServiceProvider);
}).select((service) => service.currentLine);

/// 歌词进度 Provider
final lyricProgressProvider = ChangeNotifierProvider<LyricService>((ref) {
  return ref.watch(lyricServiceProvider);
}).select((service) => service.progress);

/// 是否正在加载 Provider
final isLyricLoadingProvider = ChangeNotifierProvider<LyricService>((ref) {
  return ref.watch(lyricServiceProvider);
}).select((service) => service.isLoading);
