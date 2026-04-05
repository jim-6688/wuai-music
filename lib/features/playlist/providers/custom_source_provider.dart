import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../custom_source/data/models/music_source.dart';
import '../../custom_source/services/custom_source_service.dart';

/// 自定义音源列表 Provider
/// ⚠️ 不在这里重新创建 Provider，直接复用 custom_source_service.dart 中的唯一实例
/// 保证 CustomSourcePage 和 CustomSourceManagerPage 使用的是同一个 StateNotifier
final customSourceProvider = customSourceServiceProvider;
