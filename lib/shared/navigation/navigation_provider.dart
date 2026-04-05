import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局导航控制器，让子页面可以切换 MainShell 的 tab
class NavigationController extends StateNotifier<int> {
  NavigationController() : super(0);

  void goToTab(int index) => state = index;

  void goToLocalMusic() => state = 0;      // 音乐
  void goToMetingPlaylist() => state = 1;   // 歌单
  void goToPlayer() => state = 2;            // 播放
  void goToNas() => state = 3;               // NAS
  void goToSettings() => state = 4;          // 设置
}

final navigationControllerProvider =
    StateNotifierProvider<NavigationController, int>((ref) {
  return NavigationController();
});
