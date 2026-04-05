/// 扩展功能状态枚举
enum ExtensionStatus {
  /// 未安装
  notInstalled,
  /// 已安装但未启用
  installed,
  /// 已启用
  enabled,
  /// 需要更新
  needUpdate,
  /// 试用期
  trial,
}

/// 扩展功能类型枚举
enum ExtensionType {
  /// 元数据修复
  metadataRepair,
  /// 歌词增强
  lyricsEnhance,
  /// 封面修复
  coverRepair,
  /// AI翻译
  aiTranslate,
  /// 音质增强
  audioEnhance,
  /// 云端同步
  cloudSync,
  /// 社交功能
  social,
  /// 其他
  other,
}

/// 扩展功能定价模式
enum PricingModel {
  /// 免费
  free,
  /// 一次性购买
  oneTime,
  /// 订阅制
  subscription,
  /// 按量付费
  payPerUse,
}

/// 扩展功能数据模型
class Extension {
  final String id;
  final String name;
  final String description;
  final String icon;
  final ExtensionType type;
  final ExtensionStatus status;
  final PricingModel pricingModel;
  final double? price;
  final String? priceUnit;
  final bool isBuiltIn;
  final String? version;
  final String? latestVersion;
  final DateTime? installedAt;
  final DateTime? enabledAt;
  final DateTime? trialEndAt;
  final Map<String, dynamic>? config;
  final List<String> dependencies;
  final int? trialDays;

  const Extension({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.type,
    this.status = ExtensionStatus.notInstalled,
    this.pricingModel = PricingModel.free,
    this.price,
    this.priceUnit,
    this.isBuiltIn = false,
    this.version,
    this.latestVersion,
    this.installedAt,
    this.enabledAt,
    this.trialEndAt,
    this.config,
    this.dependencies = const [],
    this.trialDays,
  });

  Extension copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    ExtensionType? type,
    ExtensionStatus? status,
    PricingModel? pricingModel,
    double? price,
    String? priceUnit,
    bool? isBuiltIn,
    String? version,
    String? latestVersion,
    DateTime? installedAt,
    DateTime? enabledAt,
    DateTime? trialEndAt,
    Map<String, dynamic>? config,
    List<String>? dependencies,
    int? trialDays,
  }) {
    return Extension(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      status: status ?? this.status,
      pricingModel: pricingModel ?? this.pricingModel,
      price: price ?? this.price,
      priceUnit: priceUnit ?? this.priceUnit,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      version: version ?? this.version,
      latestVersion: latestVersion ?? this.latestVersion,
      installedAt: installedAt ?? this.installedAt,
      enabledAt: enabledAt ?? this.enabledAt,
      trialEndAt: trialEndAt ?? this.trialEndAt,
      config: config ?? this.config,
      dependencies: dependencies ?? this.dependencies,
      trialDays: trialDays ?? this.trialDays,
    );
  }

  /// 是否处于试用期
  bool get isInTrial {
    if (trialEndAt == null) return false;
    return DateTime.now().isBefore(trialEndAt!);
  }

  /// 试用期剩余天数
  int? get trialDaysRemaining {
    if (trialEndAt == null) return null;
    final remaining = trialEndAt!.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  /// 是否需要付费
  bool get requiresPayment {
    return pricingModel != PricingModel.free && status != ExtensionStatus.enabled;
  }

  /// 显示价格文本
  String get priceDisplay {
    switch (pricingModel) {
      case PricingModel.free:
        return '免费';
      case PricingModel.oneTime:
        return price != null ? '¥${price!.toStringAsFixed(0)}' : '付费';
      case PricingModel.subscription:
        if (price != null && priceUnit != null) {
          return '¥${price!.toStringAsFixed(0)}/$priceUnit';
        }
        return '订阅';
      case PricingModel.payPerUse:
        return '按量付费';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon': icon,
      'type': type.name,
      'status': status.name,
      'pricingModel': pricingModel.name,
      'price': price,
      'priceUnit': priceUnit,
      'isBuiltIn': isBuiltIn,
      'version': version,
      'latestVersion': latestVersion,
      'installedAt': installedAt?.toIso8601String(),
      'enabledAt': enabledAt?.toIso8601String(),
      'trialEndAt': trialEndAt?.toIso8601String(),
      'config': config,
      'dependencies': dependencies,
      'trialDays': trialDays,
    };
  }

  factory Extension.fromJson(Map<String, dynamic> json) {
    return Extension(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      type: ExtensionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ExtensionType.other,
      ),
      status: ExtensionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExtensionStatus.notInstalled,
      ),
      pricingModel: PricingModel.values.firstWhere(
        (e) => e.name == json['pricingModel'],
        orElse: () => PricingModel.free,
      ),
      price: json['price'] as double?,
      priceUnit: json['priceUnit'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      version: json['version'] as String?,
      latestVersion: json['latestVersion'] as String?,
      installedAt: json['installedAt'] != null
          ? DateTime.parse(json['installedAt'] as String)
          : null,
      enabledAt: json['enabledAt'] != null
          ? DateTime.parse(json['enabledAt'] as String)
          : null,
      trialEndAt: json['trialEndAt'] != null
          ? DateTime.parse(json['trialEndAt'] as String)
          : null,
      config: json['config'] as Map<String, dynamic>?,
      dependencies: (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      trialDays: json['trialDays'] as int?,
    );
  }
}
