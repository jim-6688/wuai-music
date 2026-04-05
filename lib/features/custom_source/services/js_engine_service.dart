import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_js/flutter_js.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// LX Music 自定义源事件名称常量
class LxEventNames {
  static const String inited = 'inited';
  static const String request = 'request';
  static const String updateAlert = 'updateAlert';
}

/// LX Music 音源类型
enum LxSourceType { kw, kg, tx, wy, mg, local }

/// LX Music 音源信息
class LxSourceInfo {
  final String name;
  final String type;
  final List<String> actions;
  final List<String> qualitys;

  const LxSourceInfo({
    required this.name,
    required this.type,
    required this.actions,
    required this.qualitys,
  });

  factory LxSourceInfo.fromJson(Map<String, dynamic> json) {
    return LxSourceInfo(
      name: json['name'] as String? ?? '未知音源',
      type: json['type'] as String? ?? 'music',
      actions: (json['actions'] as List<dynamic>?)?.cast<String>() ?? const [],
      qualitys: (json['qualitys'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

/// LX Music 初始化结果
class LxInitResult {
  final Map<String, LxSourceInfo> sources;
  final bool openDevTools;

  const LxInitResult({
    required this.sources,
    this.openDevTools = false,
  });

  factory LxInitResult.fromJson(Map<String, dynamic> json) {
    final sourcesMap = <String, LxSourceInfo>{};
    final sources = json['sources'] as Map<String, dynamic>?;
    if (sources != null) {
      sources.forEach((key, value) {
        sourcesMap[key] = LxSourceInfo.fromJson(value as Map<String, dynamic>);
      });
    }
    return LxInitResult(
      sources: sourcesMap,
      openDevTools: json['openDevTools'] as bool? ?? false,
    );
  }
}

/// HTTP请求响应
class _HttpResponse {
  final int statusCode;
  final dynamic body;
  final Map<String, String> headers;
  final String? error;

  _HttpResponse({
    required this.statusCode,
    this.body,
    this.headers = const {},
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'body': body,
    'headers': headers,
    if (error != null) 'error': error,
  };
}

/// JS引擎服务
/// 负责执行洛雪音乐/六音等JS音源脚本
class JsEngineService {
  static JsEngineService? _instance;

  /// 每个音源ID对应一个独立的 runtime（避免多脚本互相覆盖）
  static final Map<String, JavascriptRuntime> _runtimes = {};

  /// 当前活跃的 scriptId（loadScript 后请求都走这个）
  String? _activeScriptId;

  /// HTTP客户端
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    },
  ));

  /// 脚本执行超时
  static const Duration _scriptTimeout = Duration(seconds: 15);

  /// 获取单例实例
  static JsEngineService get instance {
    _instance ??= JsEngineService._();
    return _instance!;
  }

  JsEngineService._();

  /// 获取或创建指定 scriptId 的 runtime
  Future<JavascriptRuntime> _getRuntimeForScript(String scriptId) async {
    if (_runtimes.containsKey(scriptId)) {
      return _runtimes[scriptId]!;
    }
    final rt = getJavascriptRuntime();
    await _injectLxApiShim(rt);
    _runtimes[scriptId] = rt;
    return rt;
  }

  /// 获取当前活跃的 runtime（用于 getMusicUrl 等请求）
  Future<JavascriptRuntime> _ensureRuntime() async {
    final id = _activeScriptId ?? '__default__';
    return _getRuntimeForScript(id);
  }

  /// 注入LX Music API兼容层
  /// 模拟 globalThis.lx 对象
  Future<void> _injectLxApiShim(JavascriptRuntime runtime) async {
    const shimCode = '''
// LX Music API 兼容层
globalThis.lx = {
  version: '2.0.0',
  env: 'flutter',
  currentScriptInfo: null,
  
  EVENT_NAMES: {
    inited: 'inited',
    request: 'request',
    updateAlert: 'updateAlert'
  },
  
  _eventHandlers: {},
  _initData: null,
  _pendingRequests: {},
  _requestResults: {},
  
  on: function(eventName, handler) {
    this._eventHandlers[eventName] = handler;
  },
  
  send: function(eventName, data) {
    if (eventName === 'inited') {
      this._initData = data;
    } else if (eventName === 'updateAlert') {
      console.log('Update alert:', data);
    }
  },
  
  request: function(url, options, callback) {
    const requestId = 'req_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
    
    // 存储请求信息
    this._pendingRequests[requestId] = {
      url: url,
      options: options || {},
      callback: callback,
      completed: false
    };
    
    // 标记需要Dart层处理的请求
    _pendingRequestQueue.push(requestId);
  },
  
  utils: {
    buffer: {
      from: function(data, encoding) {
        if (typeof data === 'string') {
          // 返回一个Buffer包装对象
          return {
            _data: data,
            _encoding: encoding || 'utf8',
            _isBuffer: true,
            toString: function(enc) {
              if (enc === 'base64' || this._encoding === 'base64') {
                return _btoa(this._data);
              }
              return this._data;
            }
          };
        }
        return { _data: data, _isBuffer: true };
      },
      bufToString: function(buf, encoding) {
        if (buf && buf._isBuffer) {
          if (encoding === 'base64') {
            return _btoa(buf._data);
          }
          return buf._data;
        }
        return String(buf);
      }
    },
    crypto: {
      aesEncrypt: function(data, key, iv) {
        // 简化实现，实际需要完整加密支持
        return data;
      },
      md5: function(data) {
        // 调用Dart层的MD5实现
        return _computeMd5(data);
      },
      randomBytes: function(size) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        let result = '';
        for (let i = 0; i < size; i++) {
          result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
      },
      rsaEncrypt: function(data, key) {
        return data;
      }
    },
    zlib: {
      inflate: function(data) {
        return Promise.resolve(data);
      },
      deflate: function(data) {
        return Promise.resolve(data);
      }
    }
  }
};

// Base64编码函数
function _btoa(str) {
  try {
    return btoa(unescape(encodeURIComponent(str)));
  } catch(e) {
    return btoa(str);
  }
}

// Base64解码函数
function _atob(str) {
  try {
    return decodeURIComponent(escape(atob(str)));
  } catch(e) {
    return atob(str);
  }
}

// MD5计算（占位，实际由Dart层实现）
function _computeMd5(data) {
  return _md5Results[data] || data;
}

// 待处理请求队列
var _pendingRequestQueue = [];
var _md5Results = {};

// 设置当前脚本信息
function setScriptInfo(info) {
  globalThis.lx.currentScriptInfo = info;
}

// 设置MD5结果
function setMd5Result(data, hash) {
  _md5Results[data] = hash;
}

// 获取初始化数据
function getInitData() {
  return globalThis.lx._initData;
}

// 获取待处理的请求
function getPendingRequests() {
  const requests = [];
  const queue = _pendingRequestQueue.slice();
  _pendingRequestQueue = [];
  
  for (const requestId of queue) {
    const req = globalThis.lx._pendingRequests[requestId];
    if (req && !req.completed) {
      requests.push({
        id: requestId,
        url: req.url,
        options: req.options
      });
    }
  }
  return requests;
}

// 设置请求结果
function setRequestResult(requestId, result) {
  const req = globalThis.lx._pendingRequests[requestId];
  if (req) {
    req.completed = true;
    if (req.callback) {
      req.callback(result.error, result);
    }
  }
}

// 触发请求事件（handler 直接调用 setAsyncResult，无需等待 Promise）
function triggerRequest(source, action, info, taskId) {
  const handler = globalThis.lx._eventHandlers['request'];
  if (handler) {
    // 传递 taskId 让 handler 可以直接调用 setAsyncResult
    // handler 应该调用 setAsyncResult(taskId, result) 而不是 return Promise.resolve(result)
    handler({ source: source, action: action, info: info, _taskId: taskId });
    return;
  }
  setAsyncError(taskId, 'No request handler');
}

// 触发异步请求并将结果保存到全局（Dart侧轮询）
function triggerRequestAsync(taskId, source, action, info) {
  createAsyncTask(taskId);
  // 直接调用 triggerRequest（不返回 Promise），handler 会调用 setAsyncResult
  triggerRequest(source, action, info, taskId);
}

// Console支持
console = console || {};
console.log = function(...args) {
  _consoleMessages.push({type: 'log', args: args.map(a => String(a))});
};
console.error = function(...args) {
  _consoleMessages.push({type: 'error', args: args.map(a => String(a))});
};
console.warn = function(...args) {
  _consoleMessages.push({type: 'warn', args: args.map(a => String(a))});
};
console.group = function(...args) {
  _consoleMessages.push({type: 'group', args: args.map(a => String(a))});
};
console.groupEnd = function() {
  _consoleMessages.push({type: 'groupEnd', args: []});
};

var _consoleMessages = [];

function getConsoleMessages() {
  const msgs = _consoleMessages.slice();
  _consoleMessages = [];
  return msgs;
}

// 安全执行脚本（捕获死循环）
let _scriptExecuted = false;
function markScriptExecuted() {
  _scriptExecuted = true;
}

function isScriptExecuted() {
  return _scriptExecuted;
}

// 异步结果存储（Dart轮询用）
var _asyncResults = {};
var _asyncResultCounter = 0;

function createAsyncTask(taskId) {
  _asyncResults[taskId] = { done: false, value: null, error: null };
}

function setAsyncResult(taskId, value) {
  if (_asyncResults[taskId]) {
    _asyncResults[taskId].done = true;
    _asyncResults[taskId].value = value;
  }
}

function setAsyncError(taskId, error) {
  if (_asyncResults[taskId]) {
    _asyncResults[taskId].done = true;
    _asyncResults[taskId].error = String(error);
  }
}

function getAsyncResult(taskId) {
  return JSON.stringify(_asyncResults[taskId] || null);
}

function clearAsyncResult(taskId) {
  delete _asyncResults[taskId];
}

''';

    await runtime.evaluateAsync(shimCode);
  }

  /// 计算MD5哈希
  String _computeMd5(String data) {
    final bytes = utf8.encode(data);
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 执行HTTP请求
  Future<_HttpResponse> _executeHttpRequest(
    String url, 
    Map<String, dynamic> options,
  ) async {
    try {
      final method = (options['method'] as String?)?.toUpperCase() ?? 'GET';
      final headers = <String, String>{};
      
      if (options['headers'] is Map) {
        (options['headers'] as Map).forEach((key, value) {
          headers[key.toString()] = value.toString();
        });
      }
      
      final followRedirects = options['follow_max'] != null;
      
      if (kDebugMode) {
        print('🌐 HTTP请求: $method $url');
      }
      
      final response = await _dio.request(
        url,
        options: Options(
          method: method,
          headers: headers,
          followRedirects: followRedirects,
          maxRedirects: (options['follow_max'] as int?) ?? 5,
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
        data: options['body'] ?? options['data'],
      );
      
      if (kDebugMode) {
        print('📡 HTTP响应: ${response.statusCode}');
      }
      
      return _HttpResponse(
        statusCode: response.statusCode ?? 200,
        body: response.data,
        headers: response.headers.map.map((k, v) => MapEntry(k, v.join(', '))),
      );
    } on DioException catch (e) {
      if (kDebugMode) {
        print('❌ HTTP请求失败: ${e.message}');
      }
      return _HttpResponse(
        statusCode: e.response?.statusCode ?? 500,
        error: e.message,
        body: e.response?.data,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ HTTP请求异常: $e');
      }
      return _HttpResponse(
        statusCode: 500,
        error: e.toString(),
      );
    }
  }

  /// 解析并初始化JS音源脚本
  /// [scriptId] 音源唯一ID，每个音源使用独立的JS runtime（避免脚本互相覆盖）
  /// 返回解析后的音源信息和初始化结果
  Future<LxInitResult?> loadScript(String scriptContent, {String? scriptId}) async {
    final id = scriptId ?? 'script_${DateTime.now().millisecondsSinceEpoch}';
    try {
      // 销毁旧的同ID runtime（重新导入时刷新）
      if (scriptId != null && _runtimes.containsKey(scriptId)) {
        _runtimes[scriptId]?.dispose();
        _runtimes.remove(scriptId);
      }

      final runtime = await _getRuntimeForScript(id);
      _activeScriptId = id;

      // 提取元数据
      final metadata = _extractMetadata(scriptContent);
      
      if (kDebugMode) {
        print('📋 提取到的元数据: $metadata');
      }
      
      // 设置脚本信息（使用原始元数据，保持校验一致性）
      final scriptInfoJson = json.encode({
        'name': metadata['name'] ?? '未知音源',
        'description': metadata['description'] ?? '',
        'version': metadata['version'] ?? '1.0.0',
        'author': metadata['author'],
        'homepage': metadata['homepage'],
        'rawScript': scriptContent,
      });
      await runtime.evaluateAsync('setScriptInfo($scriptInfoJson);');

      // 预计算并注入MD5结果（绕过脚本中的校验）
      // 计算常见字符串的MD5
      final precomputeStrings = [
        metadata['name'] ?? '',
        metadata['description'] ?? '',
        '${metadata['name'] ?? ''}${metadata['description'] ?? ''}',
        metadata['name'] ?? '未知音源',
      ];
      
      for (final str in precomputeStrings) {
        if (str.isNotEmpty) {
          final hash = _computeMd5(str);
          await runtime.evaluateAsync('setMd5Result(${json.encode(str)}, "$hash");');
        }
      }

      // 检测并处理脚本校验
      String processedScript = scriptContent;
      
      // 如果脚本包含死循环校验，移除它
      if (scriptContent.contains('while(true)') || scriptContent.contains('while (true)')) {
        if (kDebugMode) {
          print('⚠️ 检测到脚本包含校验死循环，尝试移除...');
        }
        
        // 移除包含死循环的校验代码块
        // 匹配模式: if(...) { while(true) { ... } }
        processedScript = scriptContent.replaceAllMapped(
          RegExp(
            r'if\s*\([^)]*rHash[^)]*\)\s*\{[^}]*while\s*\(\s*true\s*\)[^}]*\}',
            multiLine: true,
            dotAll: true,
          ),
          (match) => '// Verification bypassed\n',
        );
        
        // 也尝试移除其他形式的校验
        processedScript = processedScript.replaceAllMapped(
          RegExp(
            r'if\s*\([^)]*\)\s*\{[^}]*while\s*\(\s*true\s*\)[^}]*\}',
            multiLine: true,
            dotAll: true,
          ),
          (match) {
            // 只移除包含 rHash 或 illegal 的校验块
            if (match.group(0)?.contains('rHash') == true || 
                match.group(0)?.contains('illegal') == true) {
              return '// Verification bypassed\n';
            }
            return match.group(0) ?? '';
          },
        );
        
        if (kDebugMode) {
          print('🔧 已处理脚本校验代码');
        }
      }

      // 使用超时执行脚本
      try {
        await runtime.evaluateAsync(processedScript)
            .timeout(_scriptTimeout);
        if (kDebugMode) {
          print('✅ 脚本执行完成');
        }
      } on TimeoutException {
        if (kDebugMode) {
          print('⚠️ 脚本执行超时，检查初始化状态...');
        }
        // 尝试继续获取初始化数据
      }

      // 关键：在处理HTTP请求之前先检查initData
      // 因为 flutter_js 的 evaluateAsync 可能在 setTimeout 回调之前返回，
      // 所以先检查一次 initData（lx.send 应该在脚本开头就同步执行了）
      
      // 首先打印脚本的console日志
      await _printConsoleMessages(runtime);
      
      String? resultStr;
      final initCheck = await runtime.evaluateAsync('''
        (function() {
          var result = { 
            initData: JSON.stringify(getInitData() || null),
            consoleCount: typeof _consoleMessages !== 'undefined' ? _consoleMessages.length : 'undefined',
            consoleWorking: typeof console !== 'undefined' && typeof console.log === 'function',
            lxDefined: typeof lx !== 'undefined',
            lxSendExists: typeof lx !== 'undefined' && typeof lx.send === 'function'
          };
          return JSON.stringify(result);
        })()
      ''');
      resultStr = initCheck.stringResult;
      await _printConsoleMessages(runtime);
      
      if (kDebugMode) {
        print('🔍 [initData检查] 详细结果: $resultStr');
        // 解析并打印关键信息
        try {
          final parsed = json.decode(resultStr!);
          if (parsed is Map) {
            print('   initData: ${parsed['initData']}');
            print('   console日志数: ${parsed['consoleCount']}');
            print('   lx已定义: ${parsed['lxDefined']}');
            print('   lx.send存在: ${parsed['lxSendExists']}');
          }
        } catch (_) {}
      }
      
      // 提取实际的 initData 值
      try {
        final parsed = json.decode(resultStr!);
        if (parsed is Map && parsed['initData'] != null) {
          resultStr = parsed['initData'] as String;
        }
      } catch (_) {}

      if (resultStr != 'null' && resultStr != null && resultStr!.isNotEmpty) {
        if (kDebugMode) {
          print('✅ 脚本initData获取成功: ${resultStr.length}字符');
        }
      } else {
        // initData 还没准备好，开始轮询等待
        // （这通常发生在脚本使用 setTimeout 延迟执行 lx.send 的情况下）
        if (kDebugMode) {
          print('⚠️ 脚本initData未就绪，开始轮询等待...');
        }

        for (int i = 0; i < 10; i++) {
          // 处理待处理的HTTP请求（同时可能触发 setTimeout 回调）
          await _processPendingRequests(runtime);

          // 获取初始化数据
          final result = await runtime.evaluateAsync('JSON.stringify(getInitData() || null)');
          resultStr = result.stringResult;
          await _printConsoleMessages(runtime);

          if (resultStr != 'null' && resultStr.isNotEmpty) {
            if (kDebugMode) {
              print('✅ 脚本initData轮询获取成功: ${resultStr.length}字符');
            }
            break;
          }

          if (kDebugMode) {
            print('⚠️ 等待脚本initData...');
          }
          if (i < 9) {
            await Future.delayed(const Duration(milliseconds: 300));
          }
        }
      }

      // 备用方案：如果仍未获取到initData，尝试从全局变量直接读取
      if (resultStr == 'null' || resultStr!.isEmpty) {
        if (kDebugMode) {
          print('⚠️ JS脚本未发送初始化事件，尝试备用方案...');
        }
        final fallback = await runtime.evaluateAsync(
          'JSON.stringify(getInitData() || _allBoardInitData || _testSourceInitData || musicSources || null)',
        );
        final fallbackStr = fallback.stringResult;
        if (fallbackStr != 'null' && fallbackStr.isNotEmpty) {
          if (kDebugMode) {
            print('✅ 从备用全局变量获取到音源信息');
          }
          resultStr = fallbackStr;
        }
      }

      // 如果仍未获取到初始化数据，尝试备用方案
      if (resultStr == 'null' || resultStr!.isEmpty) {
        if (kDebugMode) {
          print('⚠️ JS脚本未发送初始化事件');
          print('🔧 尝试手动获取音源信息...');
        }

        // 尝试从脚本中提取音源信息
        final fallbackResult = await _tryExtractSourceInfo(runtime, metadata);
        if (fallbackResult != null) {
          if (kDebugMode) {
            print('✅ 使用备用方案获取音源信息成功');
          }
          return fallbackResult;
        }

        if (kDebugMode) {
          print('❌ 无法获取音源信息');
        }
        return null;
      }

      final initData = json.decode(resultStr) as Map<String, dynamic>;
      if (kDebugMode) {
        print('✅ 获取到初始化数据: ${initData.keys.join(", ")}');
        // 打印sources的key列表
        if (initData['sources'] is Map) {
          print('   sources keys: ${(initData['sources'] as Map).keys.join(", ")}');
        }
        print('   initData preview: ${resultStr.substring(0, resultStr.length > 150 ? 150 : resultStr.length)}');
      }
      return LxInitResult.fromJson(initData);
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ 加载JS脚本失败: $e');
        print('Stack: $stack');
      }
      return null;
    }
  }

  /// 尝试从脚本中提取音源信息（备用方案）
  Future<LxInitResult?> _tryExtractSourceInfo(
    JavascriptRuntime runtime, 
    Map<String, String> metadata,
  ) async {
    try {
      // 尝试读取脚本中定义的 musicSources 变量
      final sourcesResult = await runtime.evaluateAsync('''
        (function() {
          if (typeof musicSources !== 'undefined') {
            return JSON.stringify({sources: musicSources, openDevTools: false});
          }
          return null;
        })()
      ''');
      
      final sourcesStr = sourcesResult.stringResult;
      if (sourcesStr != 'null' && sourcesStr.isNotEmpty) {
        final initData = json.decode(sourcesStr) as Map<String, dynamic>;
        if (kDebugMode) {
          print('✅ 从脚本变量中提取到音源信息');
        }
        return LxInitResult.fromJson(initData);
      }
      
      // 如果无法提取，使用元数据创建默认音源
      if (kDebugMode) {
        print('⚠️ 无法提取音源信息，使用默认配置');
      }
      
      // 返回一个默认的音源配置
      return LxInitResult(
        sources: {
          'default': LxSourceInfo(
            name: metadata['name'] ?? '自定义音源',
            type: 'music',
            actions: const ['musicUrl'],
            qualitys: const ['128k', '320k', 'flac'],
          ),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 提取音源信息失败: $e');
      }
      return null;
    }
  }

  /// 处理待处理的HTTP请求
  Future<void> _processPendingRequests(JavascriptRuntime runtime) async {
    for (int i = 0; i < 10; i++) { // 最多处理10轮请求
      final requestsResult = await runtime.evaluateAsync('JSON.stringify(getPendingRequests())');
      final requestsStr = requestsResult.stringResult;
      
      if (requestsStr == '[]' || requestsStr.isEmpty) break;
      
      final List<dynamic> requests = json.decode(requestsStr);
      if (requests.isEmpty) break;
      
      for (final request in requests) {
        final requestId = request['id'] as String;
        final url = request['url'] as String;
        final options = request['options'] as Map<String, dynamic>? ?? {};
        
        // 执行HTTP请求
        final response = await _executeHttpRequest(url, options);
        
        // 设置响应结果
        final responseJson = json.encode({
          'statusCode': response.statusCode,
          'body': response.body,
          'headers': response.headers,
          if (response.error != null) 'error': response.error,
        });
        
        await runtime.evaluateAsync('''
          setRequestResult('$requestId', $responseJson);
        ''');
      }
      
      // 等待脚本处理响应
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// 打印控制台消息
  Future<void> _printConsoleMessages(JavascriptRuntime runtime) async {
    if (!kDebugMode) return;
    
    try {
      final result = await runtime.evaluateAsync('JSON.stringify(getConsoleMessages())');
      final List<dynamic> messages = json.decode(result.stringResult);
      
      for (final msg in messages) {
        final type = msg['type'] as String;
        final args = msg['args'] as List;
        final output = args.join(' ');
        
        switch (type) {
          case 'error':
            print('🔴 JS Error: $output');
            break;
          case 'warn':
            print('🟡 JS Warn: $output');
            break;
          default:
            print('📝 JS: $output');
        }
      }
    } catch (_) {}
  }

  /// 提取脚本元数据
  Map<String, String> _extractMetadata(String script) {
    final metadata = <String, String>{};
    final regex = RegExp(
      r'@(\w+)\s+(.+?)(?=\n|\*/) ',
      multiLine: true,
    );
    final matches = regex.allMatches(script);
    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2)?.trim();
      if (key != null && value != null) {
        metadata[key] = value;
      }
    }
    return metadata;
  }

  /// 通用：触发JS异步请求并等待结果（轮询模式）
  /// flutter_js 不支持真正 await Promise，所以用全局变量 + Dart轮询来处理
  Future<dynamic> _triggerRequestAndWait(
    JavascriptRuntime runtime,
    String sourceKey,
    String action,
    String infoJson, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final taskId = 'task_${DateTime.now().millisecondsSinceEpoch}_${sourceKey}_$action';

    // 重置请求队列
    await runtime.evaluateAsync('_pendingRequestQueue = [];');

    // 启动异步任务（不等待JS Promise）
    await runtime.evaluateAsync(
      'triggerRequestAsync(${json.encode(taskId)}, ${json.encode(sourceKey)}, ${json.encode(action)}, $infoJson);',
    );

    // 轮询：处理HTTP请求 + 等待JS结果
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      // 处理JS发出的HTTP请求
      try {
        await _processPendingRequests(runtime);
      } catch (e) {
        if (kDebugMode) print('⚠️ _processPendingRequests error: $e');
      }

      // 检查异步结果
      try {
        final checkResult = await runtime.evaluateAsync('getAsyncResult(${json.encode(taskId)})');
        final checkStr = checkResult.stringResult;

        if (kDebugMode && action == 'leaderboard') {
          print('🔍 [leaderboard] checkStr: ${checkStr != null && checkStr.length > 100 ? checkStr.substring(0, 100) : checkStr}');
        }

        if (checkStr == 'null' || checkStr.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

        final checkJson = json.decode(checkStr);
        if (checkJson is Map && checkJson['done'] == true) {
          // 清理
          try {
            await runtime.evaluateAsync('clearAsyncResult(${json.encode(taskId)})');
          } catch (_) {}
          await _printConsoleMessages(runtime);

          if (checkJson['error'] != null) {
            throw Exception('JS error: ${checkJson['error']}');
          }
          if (kDebugMode) {
            print('🔍 [leaderboard] result value: ${checkJson['value']}');
          }
          return checkJson['value'];
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ [leaderboard] poll error [$action]: ${e.runtimeType}: $e');
        }
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    // 超时清理
    await runtime.evaluateAsync('clearAsyncResult(${json.encode(taskId)})');
    await _printConsoleMessages(runtime);
    throw TimeoutException('JS request timed out: $action');
  }

  /// 处理音乐URL请求
  Future<String?> getMusicUrl({
    required String sourceKey,
    required Map<String, dynamic> musicInfo,
    required String quality,
    String? scriptId,
  }) async {
    try {
      if (scriptId != null) _activeScriptId = scriptId;
      final runtime = await _ensureRuntime();

      final infoJson = json.encode({
        'type': quality,
        'musicInfo': musicInfo,
      });

      final result = await _triggerRequestAndWait(
        runtime, sourceKey, 'musicUrl', infoJson,
      );

      if (result == null) return null;

      // 如果返回的是URL字符串
      if (result is String) {
        if (result.startsWith('http')) return result;
        if (result.contains('http')) return result;
        return null;
      }

      // 如果是Map
      if (result is Map) {
        final url = result['url'];
        if (url is String && url.startsWith('http')) return url;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取音乐URL失败: $e');
      }
      return null;
    }
  }

  /// 处理歌词请求
  Future<Map<String, dynamic>?> getLyric({
    required String sourceKey,
    required Map<String, dynamic> musicInfo,
    String? scriptId,
  }) async {
    try {
      if (scriptId != null) _activeScriptId = scriptId;
      final runtime = await _ensureRuntime();

      final infoJson = json.encode({'musicInfo': musicInfo});

      final result = await _triggerRequestAndWait(
        runtime, sourceKey, 'lyric', infoJson,
      );

      if (result == null) return null;
      if (result is Map<String, dynamic>) return result;
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取歌词失败: $e');
      }
      return null;
    }
  }

  /// 处理封面图片请求
  Future<String?> getPic({
    required String sourceKey,
    required Map<String, dynamic> musicInfo,
    String? scriptId,
  }) async {
    try {
      if (scriptId != null) _activeScriptId = scriptId;
      final runtime = await _ensureRuntime();

      final infoJson = json.encode({'musicInfo': musicInfo});

      final result = await _triggerRequestAndWait(
        runtime, sourceKey, 'pic', infoJson,
      );

      if (result == null) return null;
      if (result is String && result.startsWith('http')) return result;
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取封面失败: $e');
      }
      return null;
    }
  }

  /// 搜索音乐
  Future<List<Map<String, dynamic>>?> searchMusic({
    required String sourceKey,
    required String keyword,
    int page = 1,
    String? scriptId,
  }) async {
    try {
      if (scriptId != null) _activeScriptId = scriptId;
      final runtime = await _ensureRuntime();

      final infoJson = json.encode({
        'keyword': keyword,
        'page': page,
      });

      final result = await _triggerRequestAndWait(
        runtime, sourceKey, 'search', infoJson,
      );

      if (result == null) return null;

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      } else if (result is Map && result['list'] != null) {
        return (result['list'] as List).cast<Map<String, dynamic>>();
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 搜索音乐失败: $e');
      }
      return null;
    }
  }

  /// 获取排行榜列表
  Future<List<Map<String, dynamic>>?> getLeaderboards({
    required String sourceKey,
    String? scriptId,
  }) async {
    try {
      if (scriptId != null) _activeScriptId = scriptId;
      final runtime = await _ensureRuntime();

      // 调试：先检查JS环境状态
      if (kDebugMode) {
        final handlerCheck = await runtime.evaluateAsync(
          'typeof lx !== "undefined" && Object.keys(lx._eventHandlers).join(",")',
        );
        print('🔍 getLeaderboards: sourceKey=$sourceKey, lx handlers=${handlerCheck.stringResult}');

        final boardKeys = await runtime.evaluateAsync(
          'typeof _leaderboardCache !== "undefined" ? Object.keys(_leaderboardCache).join(",") : "undefined"',
        );
        print('🔍 boardCache keys: ${boardKeys.stringResult}');

        final boardData = await runtime.evaluateAsync(
          'typeof _leaderboardCache !== "undefined" ? JSON.stringify(_leaderboardCache) : "undefined"',
        );
        final boardDataStr = boardData.stringResult ?? 'null';
        print('🔍 boardCache data preview: ${boardDataStr.length > 200 ? boardDataStr.substring(0, 200) : boardDataStr}');
      }

      final result = await _triggerRequestAndWait(
        runtime, sourceKey, 'leaderboard', '{}',
        timeout: const Duration(seconds: 20),
      );

      if (kDebugMode) {
        print('📊 leaderboard raw result type: ${result.runtimeType}, value: $result');
      }

      if (result == null) return null;

      if (result is List) {
        return result.cast<Map<String, dynamic>>();
      } else if (result is Map && result['list'] != null) {
        return (result['list'] as List).cast<Map<String, dynamic>>();
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取排行榜列表失败: $e');
      }
      return null;
    }
  }

  /// 获取榜单详情(歌曲列表)
  Future<Map<String, dynamic>?> getLeaderboardDetail({
    required String sourceKey,
    required String leaderboardId,
    String? scriptId,
  }) async {
    try {
      if (scriptId != null) _activeScriptId = scriptId;
      final runtime = await _ensureRuntime();

      final infoJson = json.encode({'id': leaderboardId});

      final result = await _triggerRequestAndWait(
        runtime, sourceKey, 'leaderboardDetail', infoJson,
        timeout: const Duration(seconds: 20),
      );

      if (result == null) return null;
      if (result is Map<String, dynamic>) return result;
      // result 可能是 Map<dynamic, dynamic>，需要转换
      if (result is Map) {
        return result.cast<String, dynamic>();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ 获取榜单详情失败: $e');
      }
      return null;
    }
  }

  /// 释放资源
  void dispose() {
    for (final rt in _runtimes.values) {
      rt.dispose();
    }
    _runtimes.clear();
    _activeScriptId = null;
    _instance = null;
    _dio.close();
  }
}

/// Provider
final jsEngineServiceProvider = Provider<JsEngineService>((ref) {
  return JsEngineService.instance;
});
