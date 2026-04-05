import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/notification_service.dart';

/// 通知栏服务 Provider
final notificationServiceProvider = ChangeNotifierProvider<NotificationService>((ref) {
  final service = NotificationService();
  return service;
});

/// 是否已初始化 Provider
final isNotificationInitializedProvider = ChangeNotifierProvider<NotificationService>((ref) {
  return ref.watch(notificationServiceProvider);
}).select((service) => service.isInitialized);
