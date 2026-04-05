import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../service/nas_service.dart';

// NAS 服务 Provider
final nasServiceProvider = ChangeNotifierProvider<NasService>((ref) {
  return NasService();
});

// NAS 设备列表 Provider
final nasDevicesProvider = ChangeNotifierProvider<NasService>((ref) {
  return ref.watch(nasServiceProvider);
}).select((service) => service.devices);

// NAS 是否正在扫描 Provider
final isNasScanningProvider = ChangeNotifierProvider<NasService>((ref) {
  return ref.watch(nasServiceProvider);
}).select((service) => service.isScanning);

// NAS 当前连接的设备 Provider
final connectedNasDeviceProvider = ChangeNotifierProvider<NasService>((ref) {
  return ref.watch(nasServiceProvider);
}).select((service) => service.connectedDevice);
