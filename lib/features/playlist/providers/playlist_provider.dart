import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/playlist_sync_service.dart';
import '../services/multi_platform_playlist_service.dart';

final playlistSyncServiceProvider = ChangeNotifierProvider((ref) {
  return PlaylistSyncService();
});

final multiPlatformPlaylistServiceProvider = ChangeNotifierProvider((ref) {
  return MultiPlatformPlaylistService();
});
