import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── 枚举 & 常量 ──────────────────────────────────────────────────────────────

enum NasConnectionState { disconnected, connecting, connected, error }

class NasBrand {
  final String name;
  final String? defaultPort;
  final String? defaultShare;
  final String logo;

  const NasBrand({
    required this.name,
    this.defaultPort,
    this.defaultShare,
    required this.logo,
  });
}

const Map<String, NasBrand> nasBrands = {
  'synology':    NasBrand(name: 'Synology 群晖',     defaultPort: '445', defaultShare: 'music',     logo: '🏢'),
  'qnap':        NasBrand(name: 'QNAP 威联通',        defaultPort: '445', defaultShare: 'Multimedia', logo: '📦'),
  'asustor':     NasBrand(name: 'ASUSTOR 华芸',       defaultPort: '445', defaultShare: 'Music',      logo: '🖥️'),
  'terramaster': NasBrand(name: 'Terramaster 铁威马', defaultPort: '445', defaultShare: 'Music',      logo: '💾'),
  'buffalo':     NasBrand(name: 'Buffalo 巴法络',     defaultPort: '445', defaultShare: 'share',      logo: '🐃'),
  'wd':          NasBrand(name: 'WD My Cloud',        defaultPort: '445', defaultShare: 'Public',     logo: '☁️'),
  'fnos':        NasBrand(name: 'fnOS 飞牛NAS',       defaultPort: '445', defaultShare: 'media',      logo: '🐟'),
  'custom':      NasBrand(name: '自定义',              defaultPort: '445',  defaultShare: null,         logo: '⚙️'),
};

// ─── SMB 文件项 ───────────────────────────────────────────────────────────────

class SmbItem {
  final String name;
  final String path;
  final String share;
  final bool isDirectory;
  final int? size;
  final DateTime? modifiedTime;

  const SmbItem({
    required this.name,
    required this.path,
    this.share = '',
    required this.isDirectory,
    this.size,
    this.modifiedTime,
  });

  bool get isAudioFile {
    if (isDirectory) return false;
    final ext = name.toLowerCase();
    return _audioExts.contains(ext);
  }
}

const _audioExts = {
  '.mp3', '.m4a', '.aac', '.flac', '.wav', '.wma', '.ogg', '.opus',
  '.aiff', '.alac', '.ape', '.mpc', '.wv', '.tta',
};

// ─── NAS 设备 ─────────────────────────────────────────────────────────────────

class NasDevice {
  final String id;
  final String name;
  final String ip;
  final int port;
  final String? username;
  final String? password;
  final String? brand;
  final NasConnectionState state;
  final List<String> shares;
  final DateTime? lastConnected;
  final String? currentPath;
  final bool autoConnect;
  final List<String> musicShares;

  const NasDevice({
    required this.id,
    required this.name,
    required this.ip,
    this.port = 445,
    this.username,
    this.password,
    this.brand,
    this.state = NasConnectionState.disconnected,
    this.shares = const [],
    this.lastConnected,
    this.currentPath,
    this.autoConnect = false,
    this.musicShares = const [],
  });

  NasDevice copyWith({
    String? id, String? name, String? ip, int? port,
    String? username, String? password, String? brand,
    NasConnectionState? state, List<String>? shares,
    DateTime? lastConnected, String? currentPath,
    bool? autoConnect, List<String>? musicShares,
  }) => NasDevice(
    id: id ?? this.id, name: name ?? this.name, ip: ip ?? this.ip,
    port: port ?? this.port, username: username ?? this.username,
    password: password ?? this.password, brand: brand ?? this.brand,
    state: state ?? this.state, shares: shares ?? this.shares,
    lastConnected: lastConnected ?? this.lastConnected,
    currentPath: currentPath ?? this.currentPath,
    autoConnect: autoConnect ?? this.autoConnect,
    musicShares: musicShares ?? this.musicShares,
  );

  bool get isConnected  => state == NasConnectionState.connected;
  bool get isConnecting => state == NasConnectionState.connecting;
  bool get hasCredentials => username != null && username!.isNotEmpty;
  String get displayName => brand != null ? (nasBrands[brand]?.name ?? name) : name;
}

// ─── 面包屑 ───────────────────────────────────────────────────────────────────

class NasBreadcrumb {
  final String label;
  final String relPath;
  final String share;
  const NasBreadcrumb({required this.label, required this.relPath, required this.share});
}

// ─── NAS 服务 ─────────────────────────────────────────────────────────────────

class NasService extends ChangeNotifier {
  final List<NasDevice> _devices = [];
  NasDevice? _connectedDevice;
  bool _isScanning = false;
  String? _errorMessage;

  // SMB 连接实例
  SmbConnect? _smbConnection;
  String? _currentShare;

  // 路径状态
  String _currentRelPath = '';
  List<SmbItem> _currentItems = [];
  bool _isBrowsing = false;

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<NasDevice> get devices       => List.unmodifiable(_devices);
  NasDevice?      get connectedDevice => _connectedDevice;
  bool            get isScanning    => _isScanning;
  String?         get errorMessage  => _errorMessage;
  List<SmbItem>   get currentItems => List.unmodifiable(_currentItems);
  String          get currentPath   => _currentRelPath;
  String          get currentShare  => _currentShare ?? '';
  SmbConnect?     get smbConnection => _smbConnection; // 暴露SMB连接实例

  String get displayPath {
    if (_connectedDevice == null) return '';
    final ip = _connectedDevice!.ip;
    if ((_currentShare ?? '').isEmpty) return '//$ip';
    if (_currentRelPath.isEmpty) return '//$ip/${_currentShare}';
    return '//$ip/${_currentShare}/$_currentRelPath';
  }

  List<NasBreadcrumb> get breadcrumbs {
    if (_connectedDevice == null) return [];
    final ip = _connectedDevice!.ip;
    final crumbs = <NasBreadcrumb>[NasBreadcrumb(label: ip, relPath: '', share: '')];
    final share = _currentShare ?? '';
    if (share.isNotEmpty) {
      crumbs.add(NasBreadcrumb(label: share, relPath: '', share: share));
      if (_currentRelPath.isNotEmpty) {
        String acc = '';
        for (final part in _currentRelPath.split('/')) {
          acc = acc.isEmpty ? part : '$acc/$part';
          crumbs.add(NasBreadcrumb(label: part, relPath: acc, share: share));
        }
      }
    }
    return crumbs;
  }

  /// 获取已保存的设备列表（用于配置同步）
  List<NasDevice> get savedDevices => List.unmodifiable(_devices);

  // ─── 构造 ─────────────────────────────────────────────────────────────────

  NasService() {
    _loadDevices();
  }

  // ─── 持久化 ─────────────────────────────────────────────────────────────

  Future<void> _loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = prefs.getString('nas_devices');
      if (devicesJson != null) {
        final List<dynamic> devicesList = json.decode(devicesJson);
        _devices.clear();
        _devices.addAll(devicesList.map((json) => _deviceFromJson(json)).toList());
        notifyListeners();
        if (kDebugMode) print('✅ 已加载 ${_devices.length} 个 NAS 设备');
      }
    } catch (e) {
      if (kDebugMode) print('❌ 加载 NAS 设备失败: $e');
    }
  }

  Future<void> _saveDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final devicesJson = json.encode(_devices.map((d) => _deviceToJson(d)).toList());
      await prefs.setString('nas_devices', devicesJson);
      if (kDebugMode) print('💾 已保存 ${_devices.length} 个 NAS 设备');
    } catch (e) {
      if (kDebugMode) print('❌ 保存 NAS 设备失败: $e');
    }
  }

  Map<String, dynamic> _deviceToJson(NasDevice device) {
    return {
      'id': device.id,
      'name': device.name,
      'ip': device.ip,
      'port': device.port,
      'username': device.username,
      'password': device.password,
      'brand': device.brand,
      'shares': device.shares,
      'lastConnected': device.lastConnected?.toIso8601String(),
      'autoConnect': device.autoConnect,
      'musicShares': device.musicShares,
    };
  }

  NasDevice _deviceFromJson(Map<String, dynamic> json) {
    return NasDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      ip: json['ip'] as String,
      port: json['port'] as int? ?? 445,
      username: json['username'] as String?,
      password: json['password'] as String?,
      brand: json['brand'] as String?,
      shares: (json['shares'] as List<dynamic>?)?.cast<String>() ?? [],
      lastConnected: json['lastConnected'] != null 
          ? DateTime.parse(json['lastConnected'] as String) 
          : null,
      autoConnect: json['autoConnect'] as bool? ?? false,
      musicShares: (json['musicShares'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  // ─── 局域网扫描 ───────────────────────────────────────────────────────────

  /// 刷新设备列表（重新加载已保存的设备）
  Future<void> refreshDevices() async {
    await _loadDevices();
  }

  Future<void> scanDevices() async {
    if (_isScanning) return;
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final subnet = await _getSubnet();
      if (subnet == null) {
        _errorMessage = '无法获取本机 IP，请检查 Wi-Fi 连接';
        _isScanning = false;
        notifyListeners();
        return;
      }

      if (kDebugMode) print('🔍 扫描子网: $subnet.0/24');

      const nasPorts = [445, 5000, 8080, 8000, 8181, 80];
      final futures = <Future<void>>[];

      for (int i = 1; i <= 254; i++) {
        final ip = '$subnet.$i';
        futures.add(_probeHost(ip, nasPorts));
      }

      for (int i = 0; i < futures.length; i += 30) {
        final batch = futures.sublist(i, (i + 30).clamp(0, futures.length));
        await Future.wait(batch);
      }

      if (kDebugMode) print('✅ 扫描完成，发现 ${_devices.length} 台设备');
    } catch (e) {
      _errorMessage = '扫描失败: $e';
      if (kDebugMode) print('❌ $_errorMessage');
    }

    _isScanning = false;
    notifyListeners();
  }

  Future<void> _probeHost(String ip, List<int> ports) async {
    for (final port in ports) {
      try {
        final socket = await Socket.connect(ip, port,
            timeout: const Duration(milliseconds: 300));
        socket.destroy();

        if (_devices.any((d) => d.ip == ip)) return;

        final brand = _guessBrand(port);
        final device = NasDevice(
          id: 'scan_${ip}_$port',
          name: brand != null ? '${nasBrands[brand]!.name} ($ip)' : 'NAS ($ip)',
          ip: ip,
          port: port,
          brand: brand,
          username: brand == 'wd' ? 'admin' : null,
          password: null,
        );
        _devices.add(device);
        notifyListeners();
        if (kDebugMode) print('  📡 发现: $ip:$port (${brand ?? 'unknown'})');
        return;
      } catch (_) {}
    }
  }

  String? _guessBrand(int port) {
    switch (port) {
      case 5000: return 'synology';
      case 8080: return 'qnap';
      case 8000: return 'asustor';
      case 8181: return 'terramaster';
      case 3000: return 'fnos'; // 飞牛NAS Web端口
      case 445:  return null;   // SMB默认端口，无法判断
      case 80:   return 'wd';
      default:   return null;
    }
  }

  Future<String?> _getSubnet() async {
    try {
      final info = NetworkInfo();
      final ip = await info.getWifiIP();
      if (ip == null || ip.isEmpty) return null;
      final parts = ip.split('.');
      if (parts.length != 4) return null;
      return '${parts[0]}.${parts[1]}.${parts[2]}';
    } catch (e) {
      if (kDebugMode) print('⚠️ 获取 IP 失败: $e');
      return null;
    }
  }

  // ─── 设备管理 ─────────────────────────────────────────────────────────────

  void addDevice(NasDevice device) {
    if (!_devices.any((d) => d.id == device.id)) {
      _devices.add(device);
      notifyListeners();
      _saveDevices(); // 保存到本地
    }
  }

  /// 从配置添加设备（用于配置同步）
  Future<void> addDeviceFromConfig(dynamic config) async {
    // config 可能是 NasDeviceConfig 或 Map
    Map<String, dynamic> json;
    if (config is Map<String, dynamic>) {
      json = config;
    } else {
      // 假设是 NasDeviceConfig，转换为 JSON
      throw UnimplementedError('请传入 Map<String, dynamic>');
    }

    final device = _deviceFromJson(json);
    if (!_devices.any((d) => d.id == device.id)) {
      _devices.add(device);
      notifyListeners();
      await _saveDevices();
      if (kDebugMode) print('✅ 已从配置添加设备: ${device.name}');
    } else {
      // 更新现有设备
      final idx = _devices.indexWhere((d) => d.id == device.id);
      _devices[idx] = device;
      notifyListeners();
      await _saveDevices();
      if (kDebugMode) print('🔄 已更新设备: ${device.name}');
    }
  }

  void removeDevice(String deviceId) {
    _devices.removeWhere((d) => d.id == deviceId);
    if (_connectedDevice?.id == deviceId) {
      _disposeConnection();
    }
    notifyListeners();
    _saveDevices(); // 保存到本地
  }

  // ─── 连接 / 认证 ─────────────────────────────────────────────────────────

  Future<bool> connect(NasDevice device) async {
    _errorMessage = null;
    final idx = _devices.indexWhere((d) => d.id == device.id);
    if (idx >= 0) {
      _devices[idx] = device.copyWith(state: NasConnectionState.connecting);
      notifyListeners();
    }

    try {
      await _disposeConnectionQuiet();

      if (kDebugMode) print('🔌 连接 SMB: ${device.ip}:${device.port} '
          'user=${device.username ?? 'fnuser'}');

      // 飞牛NAS默认用户名可能是fnuser或admin
      final username = device.username ?? 'fnuser';
      final password = device.password ?? '';

      _smbConnection = await SmbConnect.connectAuth(
        host: device.ip,
        username: username,
        password: password,
        domain: '',
        debugPrint: kDebugMode,
      );

      // 获取共享列表
      List<SmbFile> smbShares;
      try {
        smbShares = await _smbConnection!.listShares();
        if (kDebugMode) print('📂 获取到 ${smbShares.length} 个共享: ${smbShares.map((s) => s.name).join(", ")}');
      } catch (e) {
        if (kDebugMode) print('⚠️ 获取共享列表失败: $e');
        smbShares = [];
      }

      // 飞牛NAS可能的共享名
      final fnosShares = ['media', 'Music', 'music', 'Public', 'public', 'share', 'data', 'Data'];
      
      final shareNames = smbShares.map((s) => s.name.trim()).toList()
        ..removeWhere((s) => s.isEmpty || s.endsWith('\$'));
      
      // 如果获取不到共享，添加飞牛NAS常用共享名
      if (shareNames.isEmpty) {
        shareNames.addAll(fnosShares);
        if (kDebugMode) print('📂 使用默认共享列表: $shareNames');
      }

      final connected = device.copyWith(
        state: NasConnectionState.connected,
        lastConnected: DateTime.now(),
        shares: shareNames,
      );

      if (idx >= 0) _devices[idx] = connected;
      _connectedDevice = connected;
      _currentShare = null;
      _currentRelPath = '';
      _currentItems = [];

      if (kDebugMode) print('✅ SMB 连接成功: ${device.name}，共享: $shareNames');
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '连接失败: $e';
      if (idx >= 0) {
        _devices[idx] = device.copyWith(state: NasConnectionState.error);
      }
      if (kDebugMode) print('❌ $_errorMessage');
      await _disposeConnectionQuiet();
      notifyListeners();
      return false;
    }
  }

  void disconnect() {
    if (_connectedDevice == null) return;
    final idx = _devices.indexWhere((d) => d.id == _connectedDevice!.id);
    if (idx >= 0) {
      _devices[idx] = _devices[idx].copyWith(state: NasConnectionState.disconnected);
    }
    _connectedDevice = null;
    _disposeConnection();
    _currentShare = null;
    _currentRelPath = '';
    _currentItems = [];
    notifyListeners();
  }

  // ─── 文件浏览 ─────────────────────────────────────────────────────────────

  Future<List<SmbItem>> browseFolder(
    NasDevice device, {
    String share = '',
    String relPath = '',
  }) async {
    if (_isBrowsing) return _currentItems;
    _isBrowsing = true;

    try {
      if (_connectedDevice?.id != device.id || !(_connectedDevice?.isConnected ?? false)) {
        final ok = await connect(device);
        if (!ok) {
          _isBrowsing = false;
          return [];
        }
      }

      _currentShare = share;
      _currentRelPath = relPath;
      notifyListeners();

      final items = await _fetchItems(share: share, relPath: relPath);
      _currentItems = items;
      notifyListeners();
      return items;
    } finally {
      _isBrowsing = false;
    }
  }

  /// 真实获取目录内容（使用官方 API: connect.file() + listFiles()）
  /// 官方示例：
  ///   SmbFile folder = await connect.file("/home");
  ///   List<SmbFile> files = await connect.listFiles(folder);
  Future<List<SmbItem>> _fetchItems({
    required String share,
    required String relPath,
  }) async {
    try {
      if (_smbConnection == null) return [];

      // 如果是浏览共享列表（根目录）
      if (share.isEmpty) {
        try {
          final smbShares = await _smbConnection!.listShares();
          final items = smbShares
              .where((f) => !f.name.trim().endsWith('\$'))
              .map((f) => SmbItem(
                    name: f.name.trim(),
                    path: '',
                    share: f.name.trim().toUpperCase(),
                    isDirectory: true,
                    size: null,
                    modifiedTime: null,
                  ))
              .toList();
          items.sort((a, b) => a.name.compareTo(b.name));
          if (kDebugMode) print('📁 共享列表 => ${items.length} 项');
          return items;
        } catch (e) {
          if (kDebugMode) print('⚠️ listShares 失败: $e');
          return [];
        }
      }

      // 浏览特定共享下的内容
      if (kDebugMode) print('📂 SMB 浏览: share=$share, relPath=$relPath');

      // ─── 使用官方 API: connect.file(path) + listFiles(folder) ──
      // 路径格式: "/share" 或 "/share/subdir"
      // 根据官方示例，file() 接受相对于 share 的路径
      final String smbPath = relPath.isEmpty 
          ? '/$share' 
          : '/$share/$relPath';
      
      if (kDebugMode) print('📂 尝试官方API: file($smbPath)');

      List<SmbFile> smbFiles = [];

      try {
        // 方法1: 使用 connect.file() 标准API
        final folder = await _smbConnection!.file(smbPath);
        smbFiles = await _smbConnection!.listFiles(folder);
        if (kDebugMode) print('✅ 方法1成功: ${smbFiles.length} 项');
      } catch (e) {
        if (kDebugMode) print('⚠️ 方法1失败: $e');

        // 方法2: 尝试不带前导斜杠
        try {
          final altPath = relPath.isEmpty ? share : '$share/$relPath';
          if (kDebugMode) print('📂 方法2: file($altPath)');
          final folder = await _smbConnection!.file(altPath);
          smbFiles = await _smbConnection!.listFiles(folder);
          if (kDebugMode) print('✅ 方法2成功: ${smbFiles.length} 项');
        } catch (e2) {
          if (kDebugMode) print('⚠️ 方法2失败: $e2');

          // 方法3: 共享根目录（空路径或斜杠）
          try {
            if (kDebugMode) print('📂 方法3: 共享根目录');
            final folder = await _smbConnection!.file('/$share');
            smbFiles = await _smbConnection!.listFiles(folder);
            if (kDebugMode) print('✅ 方法3成功: ${smbFiles.length} 项');
          } catch (e3) {
            if (kDebugMode) print('⚠️ 方法3失败: $e3');

            // 方法4: 使用 SmbFile.notExists 作为降级方案
            try {
              if (kDebugMode) print('📂 方法4: SmbFile.notExists 降级');
              final ip = _connectedDevice!.ip;
              final folderRef = SmbFile.notExists(
                relPath.isEmpty ? '' : relPath,
                '//$ip/$share',
                share,
              );
              smbFiles = await _smbConnection!.listFiles(folderRef);
              if (kDebugMode) print('✅ 方法4成功: ${smbFiles.length} 项');
            } catch (e4) {
              if (kDebugMode) print('❌ 所有方法均失败: $e4');
              if (kDebugMode) print('   可能原因: 共享不存在/无权限/SMB协议不兼容');
              return [];
            }
          }
        }
      }

      // ─── 解析文件列表 ────────────────────────────────────────────────────
      final items = smbFiles
          .where((f) {
            final name = f.name;
            if (name == null) return false;
            final cleanName = name.trim();
            return cleanName.isNotEmpty && cleanName != '.' && cleanName != '..';
          })
          .map((f) {
            String fileName = f.name ?? '';
            fileName = fileName.split('/').last.split('\\').last;
            if (fileName.isEmpty) fileName = f.name ?? 'unknown';
            
            final childRel = relPath.isEmpty ? fileName : '$relPath/$fileName';
            
            return SmbItem(
              name: fileName,
              path: childRel,
              share: share,
              isDirectory: f.isDirectory(),
              size: f.size > 0 ? f.size : null,
              modifiedTime: f.lastModified > 0
                  ? DateTime.fromMillisecondsSinceEpoch(f.lastModified)
                  : null,
            );
          })
          .toList();

      // 文件夹在前，按名称排序
      items.sort((a, b) {
        if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
        return a.name.compareTo(b.name);
      });

      if (kDebugMode) print('📁 $share/${relPath.isEmpty ? "" : "$relPath/"} => ${items.length} 项');
      return items;
    } catch (e) {
      if (kDebugMode) print('❌ _fetchItems 异常: $e');
      return [];
    }
  }

  /// 返回上一级
  Future<void> goBack(NasDevice device) async {
    if (_currentRelPath.isNotEmpty) {
      final parts = _currentRelPath.split('/')..removeLast();
      await browseFolder(device, share: _currentShare ?? '', relPath: parts.join('/'));
    } else if ((_currentShare ?? '').isNotEmpty) {
      // 返回到共享列表
      await browseFolder(device);
    }
  }

  Future<List<String>> listShares(NasDevice device) async {
    if (!(_connectedDevice?.isConnected ?? false)) {
      await connect(device);
    }
    return _connectedDevice?.shares ?? [];
  }

  // ─── 内部工具 ─────────────────────────────────────────────────────────────

  void _resetBrowseState() {
    _currentShare = null;
    _currentRelPath = '';
    _currentItems = [];
    _isBrowsing = false;
  }

  Future<void> _disposeConnection() async {
    try {
      await _smbConnection?.close();
    } catch (_) {}
    _smbConnection = null;
  }

  /// 静默关闭连接（与 _disposeConnection 功能相同）
  Future<void> _disposeConnectionQuiet() => _disposeConnection();

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
