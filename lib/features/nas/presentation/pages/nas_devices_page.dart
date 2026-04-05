import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../../../shared/widgets/glass_widgets.dart';
import '../../service/nas_service.dart';
import '../providers/nas_provider.dart';
import '../../providers/nas_playlist_provider.dart';
import '../../../player/presentation/providers/player_provider.dart';
import '../../../files/data/models/track.dart';

class NasDevicesPage extends ConsumerStatefulWidget {
  const NasDevicesPage({super.key});

  @override
  ConsumerState<NasDevicesPage> createState() => _NasDevicesPageState();
}

class _NasDevicesPageState extends ConsumerState<NasDevicesPage> {
  String? _selectedDeviceId;
  bool _isLoading = false;
  String? _lastBrowseError;
  bool _isNasScanRunning = false;
  int _nasScanFound = 0;

  static const _audioExts = {
    '.mp3', '.m4a', '.aac', '.flac', '.wav', '.wma', '.ogg', '.opus',
    '.aiff', '.alac', '.ape', '.mpc', '.wv', '.tta',
  };

  bool _isAudioFile(String name) {
    final ext = name.toLowerCase();
    return _audioExts.any((e) => ext.endsWith(e));
  }

  // ─── 设备点击 → 认证 + 浏览 ───────────────────────────────────────────────

  Future<void> _onDeviceTap(NasDevice device) async {
    setState(() {
      _selectedDeviceId = device.id;
      _isLoading = false;
      _lastBrowseError = null;
    });

    // 已连接 → 直接浏览
    if (device.isConnected) {
      await _browseFolder(device);
      return;
    }

    // 未连接 → 弹出认证框
    final authResult = await _showAuthDialog(device);
    if (authResult == null) {
      // 用户取消
      if (mounted) setState(() => _selectedDeviceId = null);
      return;
    }

    final nasService = ref.read(nasServiceProvider);
    final deviceWithAuth = device.copyWith(
      username: authResult['username'],
      password: authResult['password'],
    );

    // 显示"连接中"状态
    setState(() => _isLoading = true);
    _updateDeviceInList(deviceWithAuth.copyWith(
      state: NasConnectionState.connecting,
    ));

    final ok = await nasService.connect(deviceWithAuth);

    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(nasService.errorMessage ?? '连接失败，请检查用户名密码'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        _updateDeviceInList(deviceWithAuth.copyWith(
          state: NasConnectionState.error,
        ));
        setState(() {
          _selectedDeviceId = null;
          _isLoading = false;
        });
      }
      return;
    }

    // 连接成功 → 更新 selectedDeviceId，然后浏览共享列表（根目录）
    if (mounted) {
      setState(() {
        _selectedDeviceId = nasService.connectedDevice?.id ?? deviceWithAuth.id;
        _isLoading = false;
      });
    }
    // 浏览根目录（share 为空 = 显示共享列表）
    await _browseFolder(
      nasService.connectedDevice ?? deviceWithAuth,
      share: '',
      relPath: '',
    );
  }

  /// 将设备更新到 _devices 列表（临时显示连接状态）
  void _updateDeviceInList(NasDevice updated) {
    final nasService = ref.read(nasServiceProvider);
    final idx = nasService.devices.indexWhere((d) => d.id == updated.id);
    if (idx >= 0) {
      // 通过 addDevice/remove 再 add 的方式触发通知
      nasService.removeDevice(updated.id);
      nasService.addDevice(updated);
    }
  }

  // ─── 认证对话框 ───────────────────────────────────────────────────────────

  Future<Map<String, String>?> _showAuthDialog(NasDevice device) async {
    final userCtrl = TextEditingController(text: device.username ?? '');
    final passCtrl = TextEditingController(text: device.password ?? '');
    String selectedBrand = device.brand ?? 'custom';

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(ctx).primaryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.lock_outline_rounded,
                          color: Theme.of(ctx).primaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('连接 NAS',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(device.ip,
                              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, null)),
                  ],
                ),
                const SizedBox(height: 20),

                // 品牌选择
                Text('选择品牌（自动填充默认账号）',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: nasBrands.entries.map((e) {
                    final sel = selectedBrand == e.key;
                    return ChoiceChip(
                      avatar: Text(e.value.logo, style: const TextStyle(fontSize: 14)),
                      label: Text(e.value.name, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      onSelected: (_) {
                        setModalState(() {
                          selectedBrand = e.key;
                          // WD 默认 admin，其他默认 guest
                          userCtrl.text = e.key == 'wd' ? 'admin' : 'guest';
                          passCtrl.text = '';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // 用户名
                TextField(
                  controller: userCtrl,
                  decoration: InputDecoration(
                    labelText: '用户名',
                    hintText: '留空为 guest',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 14),

                // 密码
                TextField(
                  controller: passCtrl,
                  decoration: InputDecoration(
                    labelText: '密码',
                    hintText: '留空为无密码',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx, {
                      'username': userCtrl.text.trim(),
                      'password': passCtrl.text,
                    }),
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('连接'),
                  ),
                ),
                const SizedBox(height: 10),
                Center(child: TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('取消'),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── 连接设备 ────────────────────────────────────────────────────────────
  
  Future<void> _connectDevice(NasDevice device) async {
    setState(() => _isLoading = true);
    
    final nasService = ref.read(nasServiceProvider);
    final success = await nasService.connect(device);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // 连接成功后自动浏览第一个共享
        final share = nasService.connectedDevice?.shares.firstOrNull;
        if (share != null) {
          await _browseFolder(nasService.connectedDevice!, share: share);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连接失败: ${nasService.errorMessage ?? "请检查用户名密码"}'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ─── 浏览文件夹 ────────────────────────────────────────────────────────────

  Future<void> _browseFolder(NasDevice device, {String? share, String? relPath}) async {
    setState(() {
      _isLoading = true;
      _lastBrowseError = null;
    });

    try {
      final nasService = ref.read(nasServiceProvider);
      
      // 确保使用正确的share和路径
      final targetShare = share ?? nasService.currentShare;
      final targetPath = relPath ?? nasService.currentPath;
      
      // 打印调试信息
      debugPrint('📂 NAS 浏览: share=$targetShare, path=$targetPath');
      
      final items = await nasService.browseFolder(
        device,
        share: targetShare,
        relPath: targetPath,
      );
      
      debugPrint('📁 获取到 ${items.length} 个项目');
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ NAS 浏览失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastBrowseError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('浏览失败: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
  
  // ─── 进入子文件夹 ─────────────────────────────────────────────────────────
  
  Future<void> _enterFolder(NasDevice device, SmbItem item) async {
    setState(() {
      _isLoading = true;
      _lastBrowseError = null;
    });

    try {
      final nasService = ref.read(nasServiceProvider);
      
      // 确定目标share和路径
      String targetShare;
      String targetPath;
      
      if (nasService.currentShare.isEmpty) {
        // 当前在共享列表，点击某个共享进入
        targetShare = item.name;
        targetPath = '';
      } else {
        // 已在某个共享内
        targetShare = nasService.currentShare;
        targetPath = item.path;
      }
      
      debugPrint('📂 NAS 进入文件夹: share=$targetShare, path=$targetPath');
      
      await nasService.browseFolder(
        device,
        share: targetShare,
        relPath: targetPath,
      );
      
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ NAS 进入文件夹失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastBrowseError = e.toString();
        });
      }
    }
  }

  // ─── 返回 ──────────────────────────────────────────────────────────────────

  Future<void> _goBack() async {
    final nasService = ref.read(nasServiceProvider);

    // 已在设备根 → 返回设备列表
    if (nasService.currentShare.isEmpty && nasService.currentPath.isEmpty) {
      setState(() => _selectedDeviceId = null);
      return;
    }

    setState(() => _isLoading = true);
    await nasService.goBack(nasService.connectedDevice!);
    if (mounted) setState(() => _isLoading = false);
  }

  // ─── 扫描当前目录为 NAS 歌单 ──────────────────────────────────────────────

  Future<void> _scanCurrentFolderAsPlaylist() async {
    final nasService = ref.read(nasServiceProvider);
    final device = nasService.connectedDevice;
    if (device == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先连接 NAS 设备'), backgroundColor: Colors.red),
      );
      return;
    }

    final share = nasService.currentShare;
    if (share.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先进入某个共享目录再扫描'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isNasScanRunning = true;
      _nasScanFound = 0;
    });

    try {
      final playlistService = ref.read(nasPlaylistServiceProvider);
      final tracks = await playlistService.scanNasMusic(
        device: device,
        share: share,
        relPath: nasService.currentPath.isEmpty ? null : nasService.currentPath,
        recursive: true,
      );

      if (mounted) {
        final count = tracks.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ 扫描完成！共发现 $count 首 NAS 音乐'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ 扫描失败: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNasScanRunning = false;
        });
      }
    }
  }

  // ─── 播放 NAS 音频文件 ──────────────────────────────────────────────────────

  Future<void> _playAudioFile(SmbItem item, NasDevice device) async {
    try {
      setState(() {
        _isLoading = true;
        _lastBrowseError = null;
      });

      final nasService = ref.read(nasServiceProvider);
      
      if (kDebugMode) {
        print('🎵 准备播放 NAS 文件: ${item.name}');
        print('   Share: ${item.share}');
        print('   Path: ${item.path}');
      }
      
      // 获取SMB连接
      final smb = nasService.smbConnection;
      if (smb == null) {
        throw Exception('SMB连接未建立，请先连接设备');
      }
      
      // 从NAS下载文件到本地临时目录
      final tempDir = await Directory.systemTemp.createTemp('nas_music_');
      final localFile = File('${tempDir.path}/${item.name}');
      
      if (kDebugMode) {
        print('📥 从NAS下载文件到: ${localFile.path}');
      }
      
      // 使用SMB库下载文件
      // 注意: smb_connect库需要实现文件下载功能
      // 这里暂时使用文件流复制的方式
      try {
        // 尝试获取文件流 (假设SMB库支持)
        // final stream = await smb.readFile(item.share, item.path);
        // await stream.pipe(localFile.openWrite());
        
        // 临时方案: 使用本地文件路径
        // 如果smb_connect不支持文件下载,需要等待库更新或使用其他方案
        
        // 创建Track对象
        final track = Track(
          id: 'nas_${item.name.hashCode}_${DateTime.now().millisecondsSinceEpoch}',
          filePath: localFile.path, // 使用本地文件路径
          title: item.name.replaceAll(RegExp(r'\.[^.]+$'), ''), // 去除扩展名
          artist: 'NAS - ${device.name}',
          album: item.share,
          duration: null,
        );
        
        // 获取播放服务并播放
        final audioService = ref.read(audioPlayerServiceProvider);
        
        // 显示下载提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16, 
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('正在下载: ${item.name}'),
                ],
              ),
              backgroundColor: Colors.blue.shade700,
              duration: const Duration(seconds: 30),
            ),
          );
        }
        
        // TODO: 实现实际的SMB文件下载
        // 这里需要等待smb_connect库支持文件下载,或使用其他SMB库
        
        // 暂时提示用户
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ SMB文件下载功能待实现\n当前SMB库不支持直接文件下载'),
              backgroundColor: Colors.orange.shade700,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '了解更多',
                textColor: Colors.white,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('NAS文件播放'),
                      content: Text(
                        '当前使用的SMB库(smb_connect)不支持文件下载功能。\n\n'
                        '解决方案:\n'
                        '1. 等待库更新支持文件下载\n'
                        '2. 使用其他SMB库(如dart_smbclient)\n'
                        '3. 通过WebDAV或HTTP方式访问NAS文件',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('知道了'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
        
        setState(() {
          _isLoading = false;
        });
        
      } catch (downloadError) {
        if (kDebugMode) {
          print('❌ SMB文件下载失败: $downloadError');
        }
        throw Exception('文件下载失败: $downloadError');
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ 播放NAS文件失败: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastBrowseError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('播放失败: $e'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ─── 添加设备 ───────────────────────────────────────────────────────────────

  void _showAddDeviceDialog() {
    final nameCtrl = TextEditingController();
    final ipCtrl   = TextEditingController();
    final portCtrl = TextEditingController(text: '445');
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedBrand = 'custom';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: BoxDecoration(
          color: Theme.of(ctx).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('添加 NAS 设备',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Text('快速选择品牌',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: nasBrands.entries.map((e) {
                    final sel = selectedBrand == e.key;
                    return ChoiceChip(
                      avatar: Text(e.value.logo, style: const TextStyle(fontSize: 14)),
                      label: Text(e.value.name, style: const TextStyle(fontSize: 12)),
                      selected: sel,
                      onSelected: (_) {
                        setModalState(() {
                          selectedBrand = e.key;
                          portCtrl.text = e.value.defaultPort ?? '445';
                          userCtrl.text = e.key == 'wd' ? 'admin' : '';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: '设备名称', hintText: '例如: 我的群晖'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ipCtrl,
                  decoration: const InputDecoration(
                      labelText: 'IP地址', hintText: '例如: 192.168.1.100'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                      labelText: '端口', hintText: '445'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  decoration: const InputDecoration(
                      labelText: '用户名（选填）', hintText: '留空为 guest'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(
                      labelText: '密码（选填）', hintText: '留空为无密码'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      if (nameCtrl.text.isEmpty || ipCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请填写设备名称和IP')));
                        return;
                      }
                      final device = NasDevice(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text,
                        ip: ipCtrl.text,
                        port: int.tryParse(portCtrl.text) ?? 445,
                        username: userCtrl.text.isEmpty ? null : userCtrl.text,
                        password: passCtrl.text.isEmpty ? null : passCtrl.text,
                        brand: selectedBrand,
                      );
                      ref.read(nasServiceProvider).addDevice(device);
                      Navigator.pop(ctx);
                      
                      // 添加后自动连接
                      _connectDevice(device);
                    },
                    child: const Text('添加并连接'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(NasDevice device) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除设备'),
        content: Text('确定要删除 "${device.name}" 吗？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(nasServiceProvider).removeDevice(device.id);
              Navigator.pop(ctx);
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  设备列表页
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildDeviceList(NasService nasService) {
    return LiquidBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('NAS 设备',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_rounded),
                    tooltip: '添加设备',
                    onPressed: _showAddDeviceDialog,
                  ),
                ],
              ),
            ),

            // 手动扫描按钮（默认不自动扫描）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GlassButton(
                onPressed: nasService.isScanning
                    ? null
                    : () => nasService.scanDevices(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (nasService.isScanning)
                      const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      const Icon(Icons.wifi_find_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(nasService.isScanning ? '扫描中...' : '扫描局域网'),
                  ],
                ),
              ),
            ),

            // 扫描错误提示
            if (nasService.errorMessage != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(nasService.errorMessage!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade300)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            Expanded(
              child: nasService.devices.isEmpty
                  ? _buildEmptyDevices()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: nasService.devices.length,
                      itemBuilder: (ctx, idx) {
                        final device = nasService.devices[idx];
                        return _DeviceCard(
                          device: device,
                          onTap: () => _onDeviceTap(device),
                          onDelete: () => _showDeleteConfirmDialog(device),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDevices() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          Text('暂无 NAS 设备',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text('点击右上角「+」添加设备',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  文件浏览页
  // ════════════════════════════════════════════════════════════════════════════

  Widget _buildFileBrowser(NasService nasService) {
    final device = nasService.connectedDevice ??
        nasService.devices.firstWhere(
          (d) => d.id == _selectedDeviceId,
          orElse: () => const NasDevice(id: '', name: '', ip: ''),
        );
    final breadcrumbs = nasService.breadcrumbs;
    // 直接从服务读取 items（browseFolder 已更新它）
    final items = nasService.currentItems;

    return LiquidBackground(
      child: SafeArea(
        child: Column(
          children: [
            // 顶部导航
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _goBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        if (breadcrumbs.length > 1) ...[
                          const SizedBox(height: 2),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (int i = 0; i < breadcrumbs.length; i++) ...[
                                  if (i > 0)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 1),
                                      child: Icon(Icons.chevron_right,
                                          size: 13, color: Colors.grey.shade500),
                                    ),
                                  GestureDetector(
                                    onTap: i == breadcrumbs.length - 1
                                        ? null
                                        : () => _browseFolder(
                                              device,
                                              share: breadcrumbs[i].share.isEmpty
                                                  ? null
                                                  : breadcrumbs[i].share,
                                              relPath: breadcrumbs[i].relPath,
                                            ),
                                    child: Text(
                                      breadcrumbs[i].label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: i == breadcrumbs.length - 1
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey.shade600,
                                        fontWeight: i == breadcrumbs.length - 1
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: device.isConnected
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_done_rounded,
                            size: 14,
                            color: device.isConnected ? Colors.green : Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          device.isConnected ? '已连接' : '离线',
                          style: TextStyle(
                            fontSize: 12,
                            color: device.isConnected ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // UNC 路径
            if (nasService.displayPath.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Row(
                  children: [
                    Icon(Icons.storage_rounded,
                        size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        nasService.displayPath,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // 操作栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  GlassButton(
                    onPressed: _isLoading ? null : () => _browseFolder(
                          device,
                          share: nasService.currentShare.isEmpty
                              ? null : nasService.currentShare,
                          relPath: nasService.currentPath.isEmpty
                              ? null : nasService.currentPath,
                        ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isLoading)
                          const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          const Icon(Icons.refresh_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(_isLoading ? '加载中...' : '刷新'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 扫描为歌单按钮
                  GlassButton(
                    onPressed: (_isNasScanRunning || nasService.currentShare.isEmpty)
                        ? null
                        : _scanCurrentFolderAsPlaylist,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isNasScanRunning)
                          const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          const Icon(Icons.library_music_rounded, size: 16),
                        const SizedBox(width: 6),
                        Text(_isNasScanRunning ? '扫描中...' : '扫描为歌单'),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} 个项目',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

            // 错误提示
            if (_lastBrowseError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                child: GlassContainer(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade400, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_lastBrowseError!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade300)),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // 文件列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.folder_open_rounded,
                                  size: 64, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text('该目录为空',
                                  style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: items.length,
                          itemBuilder: (ctx, idx) {
                            final item = items[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: GlassCard(
                                onTap: item.isDirectory
                                    ? () => _enterFolder(device, item)
                                    : (_isAudioFile(item.name)
                                        ? () => _playAudioFile(item, device)
                                        : null),
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: BoxDecoration(
                                        color: item.isDirectory
                                            ? Colors.amber.withValues(alpha: 0.2)
                                            : _isAudioFile(item.name)
                                                ? Colors.purple.withValues(alpha: 0.2)
                                                : Colors.grey.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        item.isDirectory
                                            ? Icons.folder_rounded
                                            : (_isAudioFile(item.name)
                                                ? Icons.music_note_rounded
                                                : Icons.insert_drive_file_rounded),
                                        color: item.isDirectory
                                            ? Colors.amber
                                            : (_isAudioFile(item.name)
                                                ? Colors.purple
                                                : Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (!item.isDirectory &&
                                              item.size != null)
                                            Text(
                                              _formatSize(item.size!),
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (item.isDirectory)
                                      Icon(Icons.chevron_right_rounded,
                                          size: 18, color: Colors.grey.shade400),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  主 build
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final nasService = ref.watch(nasServiceProvider);

    // 监听服务状态变化，同步 _selectedDeviceId
    ref.listen<NasService>(nasServiceProvider, (prev, next) {
      if (prev != null && prev.connectedDevice?.id != next.connectedDevice?.id) {
        if (next.connectedDevice != null && _selectedDeviceId != next.connectedDevice!.id) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedDeviceId = next.connectedDevice!.id);
          });
        }
      }
    });

    return _selectedDeviceId != null
        ? _buildFileBrowser(nasService)
        : _buildDeviceList(nasService);
  }
}

// ─── 设备卡片组件 ─────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final NasDevice device;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _DeviceCard({
    required this.device,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color sc; String st; Color sb;
    if (device.isConnected) {
      sc = Colors.green; st = '已连接'; sb = Colors.green.withValues(alpha: 0.2);
    } else if (device.isConnecting) {
      sc = Colors.orange; st = '连接中...'; sb = Colors.orange.withValues(alpha: 0.2);
    } else {
      sc = Colors.grey; st = '离线'; sb = Colors.grey.withValues(alpha: 0.2);
    }

    final brand = device.brand != null ? nasBrands[device.brand] : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        onTap: device.isConnecting ? null : onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color: sb, borderRadius: BorderRadius.circular(10)),
              child: Center(
                  child: Text(brand?.logo ?? '🏠',
                      style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(device.name,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      if (brand != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: sb, borderRadius: BorderRadius.circular(6)),
                          child: Text(brand.name,
                              style: TextStyle(
                                  fontSize: 9,
                                  color: sc,
                                  fontWeight: FontWeight.w500)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(device.ip,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                            color: sb, borderRadius: BorderRadius.circular(4)),
                        child: Text(st,
                            style: TextStyle(
                                fontSize: 9,
                                color: sc,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  if (device.hasCredentials)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          Icon(Icons.person_outline,
                              size: 10, color: Colors.grey.shade500),
                          const SizedBox(width: 2),
                          Text('已保存账号',
                              style: TextStyle(
                                  fontSize: 9, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 删除按钮和箭头图标
            if (!device.isConnecting) ...[
              IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: Colors.red.shade300),
                onPressed: onDelete,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
