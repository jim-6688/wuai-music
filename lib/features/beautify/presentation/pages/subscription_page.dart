import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/subscription_service.dart';

/// 付费引导页面
class SubscriptionPage extends StatefulWidget {
  final VoidCallback? onSubscribed;
  final bool showTrialOption;

  const SubscriptionPage({
    super.key,
    this.onSubscribed,
    this.showTrialOption = true,
  });

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  int _selectedPlan = 1; // 0 = standard, 1 = pro
  bool _isYearly = true;
  bool _isLoading = false;
  final _codeController = TextEditingController();
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  double get _price {
    if (_selectedPlan == 0) {
      return _isYearly 
          ? SubscriptionPricing.standardYearly 
          : SubscriptionPricing.standardMonthly;
    } else {
      return _isYearly 
          ? SubscriptionPricing.proYearly 
          : SubscriptionPricing.proMonthly;
    }
  }

  double get _originalPrice {
    if (_selectedPlan == 0) {
      return SubscriptionPricing.standardMonthly * 12;
    } else {
      return SubscriptionPricing.proMonthly * 12;
    }
  }

  String get _planName => _selectedPlan == 0 ? '标准版' : 'Pro 版';

  void _handleSubscribe() async {
    setState(() => _isLoading = true);

    // 模拟支付流程
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      widget.onSubscribed?.call();
      Navigator.of(context).pop(true);
    }
  }

  void _handleRedeemCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = '请输入兑换码');
      return;
    }

    setState(() {
      _isLoading = true;
      _codeError = null;
    });

    // TODO: 调用真实的兑换码验证
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      setState(() => _isLoading = false);
      // 模拟验证成功
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('兑换成功！'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('订阅美化功能'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部功能介绍
            _buildHeader(theme, isDark),
            const SizedBox(height: 24),

            // 订阅选项
            _buildPlanSelector(theme, isDark),
            const SizedBox(height: 20),

            // 周期切换
            _buildPeriodToggle(theme, isDark),
            const SizedBox(height: 24),

            // 价格显示
            _buildPriceDisplay(theme, isDark),
            const SizedBox(height: 24),

            // 功能对比
            _buildFeatureComparison(theme, isDark),
            const SizedBox(height: 24),

            // 订阅按钮
            _buildSubscribeButton(theme),
            const SizedBox(height: 16),

            // 兑换码
            _buildRedeemCode(theme, isDark),
            const SizedBox(height: 24),

            // 说明文字
            _buildDisclaimer(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withValues(alpha: 0.1),
            theme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome, color: theme.primaryColor, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '曲库美化 Pro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI 智能识别 · 一键美化曲库',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanSelector(ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _PlanCard(
            title: '标准版',
            price: SubscriptionPricing.standardMonthly,
            isSelected: _selectedPlan == 0,
            onTap: () => setState(() => _selectedPlan = 0),
            theme: theme,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _PlanCard(
            title: 'Pro 版',
            price: SubscriptionPricing.proMonthly,
            isSelected: _selectedPlan == 1,
            onTap: () => setState(() => _selectedPlan = 1),
            theme: theme,
            isDark: isDark,
            badge: '推荐',
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodToggle(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _PeriodButton(
              label: '月付',
              isSelected: !_isYearly,
              onTap: () => setState(() => _isYearly = false),
              theme: theme,
              isDark: isDark,
            ),
          ),
          Expanded(
            child: _PeriodButton(
              label: '年付',
              isSelected: _isYearly,
              onTap: () => setState(() => _isYearly = true),
              theme: theme,
              isDark: isDark,
              badge: '省 ¥${(_originalPrice - _price).toStringAsFixed(0)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceDisplay(ThemeData theme, bool isDark) {
    return Center(
      child: Column(
        children: [
          if (_isYearly)
            Text(
              '原价 ¥${_originalPrice.toStringAsFixed(0)}/年',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.black38,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              Text(
                _price.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _isYearly ? '/年' : '/月',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureComparison(ThemeData theme, bool isDark) {
    final standardFeatures = SubscriptionPricing.standardFeatures;
    final proFeatures = SubscriptionPricing.proFeatures;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '功能对比',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '标准版',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...standardFeatures.map((f) => _FeatureItem(
                      text: f,
                      isIncluded: true,
                      theme: theme,
                      isDark: isDark,
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pro 版',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '全功能',
                            style: TextStyle(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...proFeatures.map((f) => _FeatureItem(
                      text: f,
                      isIncluded: true,
                      theme: theme,
                      isDark: isDark,
                    )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscribeButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        onPressed: _isLoading ? null : _handleSubscribe,
        style: FilledButton.styleFrom(
          backgroundColor: theme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                '立即订阅 $_planName',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildRedeemCode(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '兑换码',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: '输入兑换码',
                    errorText: _codeError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isLoading ? null : _handleRedeemCode,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  foregroundColor: theme.primaryColor,
                ),
                child: const Text('兑换'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(ThemeData theme, bool isDark) {
    return Text(
      '• 订阅将通过应用内购买支付\n'
      '• 订阅会在当前周期结束前 24 小时内自动续订\n'
      '• 可随时在设置中取消订阅\n'
      '• 购买后可在多台设备使用',
      style: TextStyle(
        fontSize: 12,
        color: isDark ? Colors.white38 : Colors.black38,
        height: 1.6,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 子组件
// ═══════════════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  final String title;
  final double price;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDark;
  final String? badge;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.primaryColor.withValues(alpha: 0.1)
                  : (isDark ? const Color(0xFF161B22) : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? theme.primaryColor : (isDark ? Colors.white10 : Colors.black12),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? theme.primaryColor : (isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${price.toStringAsFixed(1)}/月',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDark;
  final String? badge;

  const _PeriodButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.isDark,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white24 : theme.primaryColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white : theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;
  final bool isIncluded;
  final ThemeData theme;
  final bool isDark;

  const _FeatureItem({
    required this.text,
    required this.isIncluded,
    required this.theme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isIncluded ? Icons.check : Icons.close,
            size: 14,
            color: isIncluded
                ? Colors.green
                : (isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.24)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isIncluded
                    ? (isDark ? Colors.white70 : Colors.black87)
                    : (isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 付费引导对话框（轻量级）
class SubscriptionDialog extends StatelessWidget {
  final String? featureName;
  final VoidCallback? onSubscribed;

  const SubscriptionDialog({
    super.key,
    this.featureName,
    this.onSubscribed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      title: Row(
        children: [
          Icon(Icons.lock, color: theme.primaryColor),
          const SizedBox(width: 8),
          const Text('订阅解锁'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            featureName != null
                ? '「$featureName」需要订阅后才能使用'
                : '此功能需要订阅后才能使用',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '标准版 ¥9.9/月起\nPro 版 ¥29.9/月起',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后再说'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubscriptionPage(onSubscribed: onSubscribed),
              ),
            );
          },
          child: const Text('查看订阅'),
        ),
      ],
    );
  }

  /// 显示付费引导对话框
  static Future<bool?> show(BuildContext context, {String? featureName}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => SubscriptionDialog(featureName: featureName),
    );
  }
}
