import 'package:flutter/foundation.dart';
import '../data/models/lyric_model.dart';

/// 歌词服务状态
enum LyricServiceState {
  idle,       // 空闲
  loading,    // 加载中
  loaded,     // 已加载
  error,      // 错误
}

/// 歌词服务
/// 
/// 负责管理歌词的加载、显示和同步
class LyricService extends ChangeNotifier {
  /// 当前歌词
  LyricData? _currentLyric;
  
  /// 歌词服务状态
  LyricServiceState _state = LyricServiceState.idle;
  
  /// 当前播放位置 (秒)
  double _currentPosition = 0.0;
  
  /// 当前歌词行索引
  int _currentLineIndex = -1;
  
  /// 错误信息
  String? _errorMessage;

  /// 歌词服务状态
  LyricServiceState get state => _state;

  /// 获取当前歌词
  LyricData? get currentLyric => _currentLyric;

  /// 获取当前播放位置
  double get currentPosition => _currentPosition;

  /// 获取当前歌词行索引
  int get currentLineIndex => _currentLineIndex;

  /// 是否正在加载
  bool get isLoading => _state == LyricServiceState.loading;

  /// 是否有歌词
  bool get hasLyric => _currentLyric != null && !_currentLyric!.isEmpty;

  /// 获取当前歌词行
  LyricLine? get currentLine {
    if (_currentLyric == null || _currentLineIndex < 0) return null;
    if (_currentLineIndex >= _currentLyric!.lines.length) return null;
    return _currentLyric!.lines[_currentLineIndex];
  }

  /// 获取上一个歌词行
  LyricLine? get previousLine {
    if (_currentLyric == null || _currentLineIndex <= 0) return null;
    return _currentLyric!.lines[_currentLineIndex - 1];
  }

  /// 获取下一个歌词行
  LyricLine? get nextLine {
    if (_currentLyric == null) return null;
    if (_currentLineIndex >= _currentLyric!.lines.length - 1) return null;
    return _currentLyric!.lines[_currentLineIndex + 1];
  }

  /// 构造函数
  LyricService();

  /// 加载歌词
  /// 
  /// 从 LRC 文本加载歌词
  Future<void> loadLyric(String lrcContent) async {
    try {
      _state = LyricServiceState.loading;
      _errorMessage = null;
      notifyListeners();

      // 模拟加载延迟
      await Future.delayed(const Duration(milliseconds: 100));

      // 解析歌词
      final lyric = LyricParser.parse(lrcContent);
      
      if (lyric.isEmpty) {
        throw Exception('歌词为空');
      }

      _currentLyric = lyric;
      _state = LyricServiceState.loaded;
      
      // 更新当前行索引
      _updateCurrentLineIndex();

      if (kDebugMode) {
        print('✅ 歌词加载完成: ${lyric.length} 行');
      }

      notifyListeners();
    } catch (e) {
      _state = LyricServiceState.error;
      _errorMessage = '加载歌词失败: $e';
      
      if (kDebugMode) {
        print('❌ 歌词加载失败: $e');
      }
      
      notifyListeners();
    }
  }

  /// 从示例歌词加载
  /// 
  /// 用于测试和演示
  Future<void> loadDemoLyric() async {
    const demoLrc = '''
[ti:Demo Song]
[ar:Demo Artist]
[al:Demo Album]
[00:00.00]欢迎使用 吾爱Music
[00:05.00]
[00:10.00]这是一首演示歌曲
[00:15.00]
[00:20.00]歌词同步功能
[00:25.00]
[00:30.00]正在为您播放
[00:35.00]
[00:40.00]液态玻璃界面
[00:45.00]
[00:50.00]带来全新的体验
[00:55.00]
[01:00.00]
[01:05.00]感谢使用
[01:10.00]
[01:15.00]吾爱Music 播放器
[01:20.00]
''';

    await loadLyric(demoLrc);
  }

  /// 更新播放位置
  /// 
  /// [position] 当前播放位置 (秒)
  void updatePosition(double position) {
    if (_currentPosition == position) return;
    
    _currentPosition = position;
    _updateCurrentLineIndex();
    notifyListeners();
  }

  /// 更新当前歌词行索引
  void _updateCurrentLineIndex() {
    if (_currentLyric == null) {
      _currentLineIndex = -1;
      return;
    }

    final newIndex = _currentLyric!.getLineIndexAt(_currentPosition);
    
    // 只有索引变化时才通知
    if (newIndex != _currentLineIndex) {
      _currentLineIndex = newIndex;
    }
  }

  /// 获取进度 (0.0 - 1.0)
  /// 
  /// 基于当前行在整首歌中的位置
  double get progress {
    if (_currentLyric == null || _currentLyric!.lines.isEmpty) {
      return 0.0;
    }

    if (_currentLineIndex < 0) {
      return 0.0;
    }

    if (_currentLineIndex >= _currentLyric!.lines.length - 1) {
      return 1.0;
    }

    // 计算当前行内的进度
    final currentLine = _currentLyric!.lines[_currentLineIndex];
    final nextLine = _currentLyric!.lines[_currentLineIndex + 1];
    
    final lineDuration = nextLine.timestamp - currentLine.timestamp;
    if (lineDuration <= 0) return 0.0;

    final progressInLine = (_currentPosition - currentLine.timestamp) / lineDuration;
    return progressInLine.clamp(0.0, 1.0);
  }

  /// 清除歌词
  void clear() {
    _currentLyric = null;
    _state = LyricServiceState.idle;
    _currentPosition = 0.0;
    _currentLineIndex = -1;
    _errorMessage = null;
    notifyListeners();
  }

  /// 获取错误信息
  String? get errorMessage => _errorMessage;
}
