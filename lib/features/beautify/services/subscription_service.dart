import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 订阅档位
enum SubscriptionTier {
  free,       // 免费版
  standard,   // 标准版 ¥9.9/月
  pro,        // Pro 版 ¥29.9/月
}

/// 订阅状态
enum SubscriptionStatus {
  active,     // 订阅有效
  expired,    // 订阅过期
  trial,      // 试用期
  none,       // 未订阅
}

/// 订阅信息
class SubscriptionInfo {
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime? expiresAt;
  final DateTime? trialEndsAt;
  final int trialUsedCount;      // 试用期已使用次数
  final int trialTotalCount;     // 试用期总次数（默认3首）
  final bool isLifetime;         // 是否永久版

  const SubscriptionInfo({
    this.tier = SubscriptionTier.free,
    this.status = SubscriptionStatus.none,
    this.expiresAt,
    this.trialEndsAt,
    this.trialUsedCount = 0,
    this.trialTotalCount = 3,
    this.isLifetime = false,
  });

  /// 是否有付费订阅
  bool get isPaid => status == SubscriptionStatus.active && tier != SubscriptionTier.free;

  /// 是否在试用期
  bool get isInTrial => status == SubscriptionStatus.trial && trialUsedCount < trialTotalCount;

  /// 试用期剩余次数
  int get trialRemaining => trialTotalCount - trialUsedCount;

  /// 是否可以使用付费功能
  bool get canUsePremiumFeatures => isPaid || isInTrial;

  /// 是否可以使用 AI 翻译（仅 Pro 版）
  bool get canUseAiTranslation => 
      (tier == SubscriptionTier.pro && status == SubscriptionStatus.active) || isLifetime;

  /// 是否可以使用封面超分辨率（仅 Pro 版）
  bool get canUseCoverUpscaling => 
      (tier == SubscriptionTier.pro && status == SubscriptionStatus.active) || isLifetime;

  /// 订阅剩余天数
  int? get remainingDays {
    if (isLifetime) return null;
    final end = expiresAt;
    if (end == null) return null;
    final remaining = end.difference(DateTime.now()).inDays;
    return remaining > 0 ? remaining : 0;
  }

  SubscriptionInfo copyWith({
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? expiresAt,
    DateTime? trialEndsAt,
    int? trialUsedCount,
    int? trialTotalCount,
    bool? isLifetime,
  }) {
    return SubscriptionInfo(
      tier: tier ?? this.tier,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      trialEndsAt: trialEndsAt ?? this.trialEndsAt,
      trialUsedCount: trialUsedCount ?? this.trialUsedCount,
      trialTotalCount: trialTotalCount ?? this.trialTotalCount,
      isLifetime: isLifetime ?? this.isLifetime,
    );
  }

  Map<String, dynamic> toJson() => {
    'tier': tier.name,
    'status': status.name,
    'expiresAt': expiresAt?.toIso8601String(),
    'trialEndsAt': trialEndsAt?.toIso8601String(),
    'trialUsedCount': trialUsedCount,
    'trialTotalCount': trialTotalCount,
    'isLifetime': isLifetime,
  };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.none,
      ),
      expiresAt: json['expiresAt'] != null 
          ? DateTime.tryParse(json['expiresAt']) 
          : null,
      trialEndsAt: json['trialEndsAt'] != null 
          ? DateTime.tryParse(json['trialEndsAt']) 
          : null,
      trialUsedCount: json['trialUsedCount'] as int? ?? 0,
      trialTotalCount: json['trialTotalCount'] as int? ?? 3,
      isLifetime: json['isLifetime'] as bool? ?? false,
    );
  }
}

/// 订阅管理服务
class SubscriptionService extends ChangeNotifier {
  static const _keySubscriptionInfo = 'beautify_subscription_info';
  static const _keyDeviceId = 'beautify_device_id';

  SharedPreferences? _prefs;
  SubscriptionInfo _info = const SubscriptionInfo();
  
  /// 当前订阅信息
  SubscriptionInfo get info => _info;

  /// 是否已初始化
  bool get isInitialized => _prefs != null;

  /// 初始化服务
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadSubscriptionInfo();
  }

  /// 加载订阅信息
  Future<void> _loadSubscriptionInfo() async {
    final prefs = _prefs;
    if (prefs == null) return;

    final jsonStr = prefs.getString(_keySubscriptionInfo);
    if (jsonStr != null) {
      try {
        final json = _parseJson(jsonStr);
        _info = SubscriptionInfo.fromJson(json);
        
        // 检查订阅是否过期
        _info = _checkExpiration(_info);
      } catch (e) {
        debugPrint('Failed to parse subscription info: $e');
      }
    } else {
      // 首次使用，初始化试用期
      _info = SubscriptionInfo(
        status: SubscriptionStatus.trial,
        trialEndsAt: DateTime.now().add(const Duration(days: 7)),
        trialUsedCount: 0,
        trialTotalCount: 3,
      );
    }

    notifyListeners();
  }

  /// 检查过期状态
  SubscriptionInfo _checkExpiration(SubscriptionInfo info) {
    if (info.isLifetime) return info;
    
    if (info.status == SubscriptionStatus.active) {
      if (info.expiresAt != null && DateTime.now().isAfter(info.expiresAt!)) {
        return info.copyWith(status: SubscriptionStatus.expired);
      }
    }
    
    if (info.status == SubscriptionStatus.trial) {
      if (info.trialEndsAt != null && DateTime.now().isAfter(info.trialEndsAt!)) {
        return info.copyWith(status: SubscriptionStatus.none);
      }
    }
    
    return info;
  }

  /// 保存订阅信息
  Future<void> _saveSubscriptionInfo() async {
    final prefs = _prefs;
    if (prefs == null) return;
    
    await prefs.setString(_keySubscriptionInfo, _encodeJson(_info.toJson()));
  }

  /// 使用一次试用
  Future<bool> useTrial() async {
    if (!_info.isInTrial) return false;
    
    _info = _info.copyWith(trialUsedCount: _info.trialUsedCount + 1);
    await _saveSubscriptionInfo();
    notifyListeners();
    
    return true;
  }

  /// 激活订阅（支付成功后调用）
  Future<void> activateSubscription({
    required SubscriptionTier tier,
    required int months,
    bool lifetime = false,
  }) async {
    final now = DateTime.now();
    
    // 如果已有订阅且未过期，从当前过期时间延长
    DateTime? expiresAt;
    if (!lifetime && _info.expiresAt != null && _info.expiresAt!.isAfter(now)) {
      expiresAt = _info.expiresAt!.add(Duration(days: 30 * months));
    } else if (!lifetime) {
      expiresAt = now.add(Duration(days: 30 * months));
    }

    _info = SubscriptionInfo(
      tier: tier,
      status: SubscriptionStatus.active,
      expiresAt: expiresAt,
      isLifetime: lifetime,
    );

    await _saveSubscriptionInfo();
    notifyListeners();
  }

  /// 激活兑换码
  Future<bool> redeemCode(String code) async {
    // TODO: 调用服务端验证兑换码
    // 这里先做本地模拟
    final validCodes = {
      'BEAUTIFY-PRO-1M': (SubscriptionTier.pro, 1),
      'BEAUTIFY-PRO-12M': (SubscriptionTier.pro, 12),
      'BEAUTIFY-STD-1M': (SubscriptionTier.standard, 1),
      'BEAUTIFY-STD-12M': (SubscriptionTier.standard, 12),
      'BEAUTIFY-LIFETIME': (SubscriptionTier.pro, 0),
    };

    final result = validCodes[code.toUpperCase()];
    if (result == null) return false;

    final (tier, months) = result;
    await activateSubscription(
      tier: tier,
      months: months,
      lifetime: months == 0,
    );
    
    return true;
  }

  /// 取消订阅
  Future<void> cancelSubscription() async {
    _info = _info.copyWith(status: SubscriptionStatus.expired);
    await _saveSubscriptionInfo();
    notifyListeners();
  }

  /// 重置（用于调试）
  Future<void> reset() async {
    _info = SubscriptionInfo(
      status: SubscriptionStatus.trial,
      trialEndsAt: DateTime.now().add(const Duration(days: 7)),
      trialUsedCount: 0,
      trialTotalCount: 3,
    );
    await _saveSubscriptionInfo();
    notifyListeners();
  }

  /// 检查是否可以使用美化功能
  /// 返回 (canUse, reason)
  (bool, String) checkBeautifyAccess() {
    if (_info.isPaid) {
      return (true, '订阅有效');
    }
    
    if (_info.isInTrial) {
      return (true, '试用期剩余 ${_info.trialRemaining} 次');
    }
    
    return (false, '请订阅解锁此功能');
  }

  /// 检查是否可以使用 AI 翻译
  (bool, String) checkAiTranslationAccess() {
    if (_info.canUseAiTranslation) {
      return (true, 'Pro 版功能可用');
    }
    
    if (_info.isPaid && _info.tier == SubscriptionTier.standard) {
      return (false, 'AI 翻译需要 Pro 版订阅');
    }
    
    return (false, '请订阅 Pro 版解锁此功能');
  }

  // JSON 辅助方法
  Map<String, dynamic> _parseJson(String str) {
    return jsonDecode(str) as Map<String, dynamic>;
  }

  String _encodeJson(Map<String, dynamic> json) {
    return jsonEncode(json);
  }
}

/// 订阅价格配置
class SubscriptionPricing {
  static const standardMonthly = 9.9;
  static const standardYearly = 99.0;  // 省 ¥19.8
  static const proMonthly = 29.9;
  static const proYearly = 299.0;      // 省 ¥59.8
  static const lifetime = 299.0;

  static const standardFeatures = [
    '在线元数据识别',
    '高清封面下载',
    '歌词自动获取',
    '歌词排版美化',
    '批量处理',
  ];

  static const proFeatures = [
    '全部标准版功能',
    'AI 歌词翻译',
    '封面超分辨率增强',
    '优先客服支持',
    '提前体验新功能',
  ];
}
