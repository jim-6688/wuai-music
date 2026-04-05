import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/extension.dart';

/// 扩展功能管理 Provider
final extensionManagerProvider =
    StateNotifierProvider<ExtensionManagerNotifier, ExtensionManagerState>(
  (ref) => ExtensionManagerNotifier(),
);

/// 扩展功能管理状态
class ExtensionManagerState {
  final List<Extension> extensions;
  final bool isLoading;
  final String? error;

  const ExtensionManagerState({
    this.extensions = const [],
    this.isLoading = false,
    this.error,
  });

  ExtensionManagerState copyWith({
    List<Extension>? extensions,
    bool? isLoading,
    String? error,
  }) {
    return ExtensionManagerState(
      extensions: extensions ?? this.extensions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取指定扩展
  Extension? getExtension(String id) {
    try {
      return extensions.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 获取已启用的扩展
  List<Extension> get enabledExtensions {
    return extensions
        .where((e) => e.status == ExtensionStatus.enabled || e.isInTrial)
        .toList();
  }

  /// 检查扩展是否已启用
  bool isExtensionEnabled(String id) {
    final ext = getExtension(id);
    if (ext == null) return false;
    return ext.status == ExtensionStatus.enabled || ext.isInTrial;
  }
}

/// 扩展功能管理 Notifier
class ExtensionManagerNotifier extends StateNotifier<ExtensionManagerState> {
  static const String _prefsKey = 'extensions_data';

  ExtensionManagerNotifier() : super(const ExtensionManagerState()) {
    _initialize();
  }

  /// 初始化内置扩展
  void _initialize() {
    final builtInExtensions = _getBuiltInExtensions();
    state = state.copyWith(extensions: builtInExtensions);
    _loadFromPrefs();
  }

  /// 获取内置扩展列表
  List<Extension> _getBuiltInExtensions() {
    return [
      // 元数据修复扩展
      const Extension(
        id: 'metadata_repair',
        name: '智能元数据修复',
        description: '音频指纹识别、自动匹配歌曲信息、修复缺失的元数据',
        icon: 'auto_fix_high',
        type: ExtensionType.metadataRepair,
        pricingModel: PricingModel.subscription,
        price: 9.9,
        priceUnit: '月',
        isBuiltIn: true,
        trialDays: 3,
        dependencies: [],
      ),
      // 歌词增强扩展
      const Extension(
        id: 'lyrics_enhance',
        name: '歌词增强',
        description: '自动获取歌词、美化排版、多语言翻译',
        icon: 'lyrics',
        type: ExtensionType.lyricsEnhance,
        pricingModel: PricingModel.subscription,
        price: 6.9,
        priceUnit: '月',
        isBuiltIn: true,
        trialDays: 3,
        dependencies: [],
      ),
      // 封面修复扩展
      const Extension(
        id: 'cover_repair',
        name: '高清封面修复',
        description: '从多个来源获取高清专辑封面、自动匹配替换',
        icon: 'image',
        type: ExtensionType.coverRepair,
        pricingModel: PricingModel.subscription,
        price: 4.9,
        priceUnit: '月',
        isBuiltIn: true,
        trialDays: 3,
        dependencies: [],
      ),
      // AI翻译扩展
      const Extension(
        id: 'ai_translate',
        name: 'AI 歌词翻译',
        description: '使用 AI 智能翻译歌词，支持 20+ 种语言',
        icon: 'translate',
        type: ExtensionType.aiTranslate,
        pricingModel: PricingModel.payPerUse,
        price: 0.1,
        priceUnit: '首',
        isBuiltIn: true,
        trialDays: 5,
        dependencies: ['lyrics_enhance'],
      ),
      // 云端同步扩展（预留）
      const Extension(
        id: 'cloud_sync',
        name: '云端同步',
        description: '歌单、播放记录、设置云端同步',
        icon: 'cloud_sync',
        type: ExtensionType.cloudSync,
        pricingModel: PricingModel.subscription,
        price: 12.9,
        priceUnit: '月',
        isBuiltIn: true,
        trialDays: 7,
        dependencies: [],
      ),
    ];
  }

  /// 从本地存储加载
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_prefsKey);
      if (data != null) {
        // 合并本地状态与内置扩展
        // 实际实现需要解析 JSON 并合并状态
      }
    } catch (e) {
      // 忽略加载错误
    }
  }

  /// 保存到本地存储
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = state.extensions.map((e) => e.toJson()).toList();
      // 实际实现需要序列化
    } catch (e) {
      // 忽略保存错误
    }
  }

  /// 启用扩展（开始试用或正式启用）
  Future<bool> enableExtension(String id) async {
    final ext = state.getExtension(id);
    if (ext == null) return false;

    // 检查依赖
    for (final depId in ext.dependencies) {
      if (!state.isExtensionEnabled(depId)) {
        state = state.copyWith(
          error: '需要先启用依赖：${state.getExtension(depId)?.name ?? depId}',
        );
        return false;
      }
    }

    Extension updatedExt;
    if (ext.pricingModel == PricingModel.free) {
      // 免费扩展直接启用
      updatedExt = ext.copyWith(
        status: ExtensionStatus.enabled,
        enabledAt: DateTime.now(),
      );
    } else {
      // 付费扩展开始试用
      updatedExt = ext.copyWith(
        status: ExtensionStatus.trial,
        trialEndAt: DateTime.now().add(Duration(days: ext.trialDays ?? 3)),
      );
    }

    _updateExtension(updatedExt);
    await _saveToPrefs();
    return true;
  }

  /// 禁用扩展
  Future<void> disableExtension(String id) async {
    final ext = state.getExtension(id);
    if (ext == null) return;

    final updatedExt = ext.copyWith(
      status: ExtensionStatus.installed,
      enabledAt: null,
      trialEndAt: null,
    );

    _updateExtension(updatedExt);
    await _saveToPrefs();
  }

  /// 购买扩展（预留接口）
  Future<bool> purchaseExtension(String id) async {
    // TODO: 对接支付系统
    // 这里暂时模拟购买成功
    final ext = state.getExtension(id);
    if (ext == null) return false;

    final updatedExt = ext.copyWith(
      status: ExtensionStatus.enabled,
      enabledAt: DateTime.now(),
      trialEndAt: null,
    );

    _updateExtension(updatedExt);
    await _saveToPrefs();
    return true;
  }

  /// 更新扩展配置
  Future<void> updateExtensionConfig(
    String id,
    Map<String, dynamic> config,
  ) async {
    final ext = state.getExtension(id);
    if (ext == null) return;

    final updatedExt = ext.copyWith(
      config: {...?ext.config, ...config},
    );

    _updateExtension(updatedExt);
    await _saveToPrefs();
  }

  /// 更新扩展
  void _updateExtension(Extension updated) {
    final newExtensions = state.extensions.map((e) {
      return e.id == updated.id ? updated : e;
    }).toList();

    state = state.copyWith(extensions: newExtensions);
  }

  /// 检查扩展是否可用
  bool isExtensionAvailable(String id) {
    return state.isExtensionEnabled(id);
  }
}
