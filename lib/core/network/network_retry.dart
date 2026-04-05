import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// 网络重试配置
class NetworkRetryConfig {
  final int maxRetries;           // 最大重试次数
  final Duration initialDelay;    // 初始延迟
  final Duration maxDelay;        // 最大延迟
  final double backoffMultiplier; // 退避倍数
  final List<int> retryStatusCodes; // 需要重试的 HTTP 状态码

  const NetworkRetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.retryStatusCodes = const [408, 429, 500, 502, 503, 504],
  });
}

/// 网络请求包装器 - 支持自动重试
class NetworkRetryHandler {
  final NetworkRetryConfig config;
  final void Function(String message, int attempt, int maxAttempts)? onRetry;
  final void Function(String error)? onError;

  NetworkRetryHandler({
    this.config = const NetworkRetryConfig(),
    this.onRetry,
    this.onError,
  });

  /// 执行带重试的请求
  Future<T> execute<T>(
    Future<T> Function() request, {
    String? operationName,
  }) async {
    int attempt = 0;
    Duration delay = config.initialDelay;

    while (true) {
      try {
        attempt++;
        final result = await request();
        
        // 请求成功，返回结果
        if (attempt > 1 && kDebugMode) {
          print('✅ $operationName 成功 (第 $attempt 次尝试)');
        }
        return result;
        
      } catch (e) {
        // 检查是否应该重试
        if (!_shouldRetry(e, attempt)) {
          onError?.call('请求失败: $e');
          rethrow;
        }

        // 记录重试
        final message = '$operationName 失败，准备重试 ($attempt/${config.maxRetries}): $e';
        onRetry?.call(message, attempt, config.maxRetries);
        
        if (kDebugMode) {
          print('⚠️ $message');
          print('   等待 ${delay.inSeconds} 秒后重试...');
        }

        // 等待后重试
        await Future.delayed(delay);
        
        // 计算下次延迟（指数退避）
        final nextMs = (delay.inMilliseconds * config.backoffMultiplier).toInt();
        final minMs = config.initialDelay.inMilliseconds;
        final maxMs = config.maxDelay.inMilliseconds;
        delay = Duration(milliseconds: nextMs.clamp(minMs, maxMs));
      }
    }
  }

  /// 判断是否应该重试
  bool _shouldRetry(dynamic error, int attempt) {
    // 超过最大重试次数
    if (attempt >= config.maxRetries) {
      return false;
    }

    // 网络错误 - 应该重试
    if (error is SocketException) return true;
    if (error is TimeoutException) return true;
    if (error is HttpException) return true;

    // 检查错误消息
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('network_error')) return true;
    if (errorString.contains('connection refused')) return true;
    if (errorString.contains('connection reset')) return true;
    if (errorString.contains('connection timed out')) return true;
    if (errorString.contains('network is unreachable')) return true;
    if (errorString.contains('host lookup failed')) return true;

    // HTTP 状态码错误
    if (error is FormatException) {
      // 可能是解析错误，不重试
      return false;
    }

    return false;
  }
}

/// SMB 连接重试处理器
class SmbRetryHandler {
  final NetworkRetryHandler retryHandler;
  
  SmbRetryHandler({
    NetworkRetryConfig? config,
    void Function(String, int, int)? onRetry,
    void Function(String)? onError,
  }) : retryHandler = NetworkRetryHandler(
    config: config ?? const NetworkRetryConfig(maxRetries: 5),
    onRetry: onRetry,
    onError: onError,
  );

  /// 连接 SMB（带重试）
  Future<bool> connectWithRetry(
    Future<bool> Function() connect, {
    String? deviceName,
  }) async {
    return retryHandler.execute(
      connect,
      operationName: '连接 SMB ${deviceName ?? ""}',
    );
  }

  /// 浏览文件夹（带重试）
  Future<List<dynamic>> browseWithRetry(
    Future<List<dynamic>> Function() browse, {
    String? path,
  }) async {
    return retryHandler.execute(
      browse,
      operationName: '浏览文件夹 ${path ?? ""}',
    );
  }
}

/// 全局网络状态监控
class NetworkMonitor extends ChangeNotifier {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  bool _isOnline = true;
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  final List<String> _errorHistory = [];

  bool get isOnline => _isOnline;
  int get consecutiveFailures => _consecutiveFailures;
  DateTime? get lastFailureTime => _lastFailureTime;
  List<String> get errorHistory => List.unmodifiable(_errorHistory);

  /// 记录网络错误
  void recordError(String error) {
    _consecutiveFailures++;
    _lastFailureTime = DateTime.now();
    _isOnline = false;
    
    _errorHistory.add('[${DateTime.now().toIso8601String()}] $error');
    
    // 只保留最近 50 条错误
    if (_errorHistory.length > 50) {
      _errorHistory.removeAt(0);
    }
    
    notifyListeners();
    
    if (kDebugMode) {
      print('🔴 网络错误: $error');
      print('   连续失败次数: $_consecutiveFailures');
    }
  }

  /// 记录成功
  void recordSuccess() {
    if (_consecutiveFailures > 0) {
      if (kDebugMode) {
        print('✅ 网络恢复 (之前失败 $_consecutiveFailures 次)');
      }
    }
    
    _consecutiveFailures = 0;
    _isOnline = true;
    notifyListeners();
  }

  /// 清除历史
  void clearHistory() {
    _errorHistory.clear();
    notifyListeners();
  }
}

/// 便捷方法扩展
extension NetworkRetryExtension on Future<dynamic> {
  /// 添加自动重试
  Future<dynamic> withRetry({
    int maxRetries = 3,
    String? operationName,
    void Function(String, int, int)? onRetry,
  }) async {
    final handler = NetworkRetryHandler(
      config: NetworkRetryConfig(maxRetries: maxRetries),
      onRetry: onRetry,
    );
    
    return handler.execute(
      () => this,
      operationName: operationName,
    );
  }
}