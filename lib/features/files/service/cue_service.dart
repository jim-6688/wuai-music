import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../data/models/track.dart';

/// CUE 分轨信息
class CueTrackInfo {
  final int index;
  final String title;
  final String? artist;
  final String? performer;
  final Duration? startTime;
  final Duration? endTime;

  const CueTrackInfo({
    required this.index,
    required this.title,
    this.artist,
    this.performer,
    this.startTime,
    this.endTime,
  });
}

/// CUE 文件信息
class CueFileInfo {
  final String filePath;
  final String title;
  final String? artist;
  final String? performer;
  final String? genre;
  final String? date;
  final String audioFile;
  final List<CueTrackInfo> tracks;

  const CueFileInfo({
    required this.filePath,
    required this.title,
    this.artist,
    this.performer,
    this.genre,
    this.date,
    required this.audioFile,
    required this.tracks,
  });
}

/// CUE 文件解析和管理服务
class CueService {
  /// 解析 CUE 文件
  static Future<CueFileInfo?> parseCueFile(File cueFile) async {
    try {
      final content = await cueFile.readAsString();
      return _parseCueContent(content, cueFile.path);
    } catch (e) {
      if (kDebugMode) print('❌ 解析CUE文件失败: ${cueFile.path} - $e');
      return null;
    }
  }

  /// 解析 CUE 内容
  static CueFileInfo? _parseCueContent(String content, String cueFilePath) {
    try {
      final lines = content.split('\n');
      
      String albumTitle = '未知专辑';
      String? albumArtist;
      String? albumPerformer;
      String? genre;
      String? date;
      String? currentAudioFile;
      final tracks = <CueTrackInfo>[];
      
      int trackIndex = 0;
      String? currentTrackTitle;
      String? currentTrackArtist;
      String? currentTrackPerformer;
      Duration? currentTrackStart;
      
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        // 全局信息 (TRACK 之前)
        if (trackIndex == 0) {
          if (line.startsWith('TITLE ')) {
            albumTitle = _extractValue(line);
          } else if (line.startsWith('PERFORMER ')) {
            albumPerformer = _extractValue(line);
          } else if (line.startsWith('GENRE ')) {
            genre = _extractValue(line);
          } else if (line.startsWith('DATE ')) {
            date = _extractValue(line);
          } else if (line.startsWith('FILE ')) {
            final filename = _extractValue(line);
            if (filename.isNotEmpty) {
              final cueDir = p.dirname(cueFilePath);
              currentAudioFile = p.join(cueDir, filename);
            }
          }
        }
        
        // 音轨信息
        if (line.startsWith('TRACK ')) {
          // 保存前一个音轨
          if (currentTrackTitle != null && trackIndex > 0) {
            tracks.add(CueTrackInfo(
              index: trackIndex,
              title: currentTrackTitle,
              artist: currentTrackArtist,
              performer: currentTrackPerformer,
              startTime: currentTrackStart,
            ));
          }
          
          trackIndex++;
          currentTrackTitle = null;
          currentTrackArtist = null;
          currentTrackPerformer = null;
          currentTrackStart = null;
        }
        
        if (trackIndex > 0) {
          if (line.startsWith('TITLE ')) {
            currentTrackTitle = _extractValue(line);
          } else if (line.startsWith('PERFORMER ')) {
            currentTrackPerformer = _extractValue(line);
          } else if (line.startsWith('ARTIST ')) {
            currentTrackArtist = _extractValue(line);
          } else if (line.startsWith('INDEX ')) {
            // 解析时间码 INDEX 01 MM:SS:FF
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 3) {
              currentTrackStart = _parseTimeCode(parts[2]);
            }
          }
        }
      }
      
      // 保存最后一个音轨
      if (currentTrackTitle != null && trackIndex > 0) {
        tracks.add(CueTrackInfo(
          index: trackIndex,
          title: currentTrackTitle,
          artist: currentTrackArtist,
          performer: currentTrackPerformer,
          startTime: currentTrackStart,
        ));
      }
      
      if (currentAudioFile == null || !File(currentAudioFile).existsSync()) {
        if (kDebugMode) print('⚠️ CUE 引用的音频文件不存在或未指定');
        return null;
      }
      
      return CueFileInfo(
        filePath: cueFilePath,
        title: albumTitle,
        artist: albumArtist,
        performer: albumPerformer,
        genre: genre,
        date: date,
        audioFile: currentAudioFile,
        tracks: tracks,
      );
    } catch (e) {
      if (kDebugMode) print('❌ 解析CUE内容失败: $e');
      return null;
    }
  }

  /// 从 CUE 文件生成 Track 列表
  static Future<List<Track>> generateTracksFromCue(File cueFile) async {
    final cueInfo = await parseCueFile(cueFile);
    if (cueInfo == null) return [];
    
    return cueInfo.tracks.map((cueTrack) {
      return Track(
        id: '${cueFile.path}_${cueTrack.index}',
        filePath: cueInfo.audioFile,
        title: cueTrack.title,
        artist: cueTrack.performer ?? cueTrack.artist ?? cueInfo.performer ?? '未知艺术家',
        album: cueInfo.title,
        duration: null,
      );
    }).toList();
  }

  /// 提取 CUE 行的值
  static String _extractValue(String line) {
    // 处理 TITLE "value" 格式
    final quoteStart = line.indexOf('"');
    final quoteEnd = line.lastIndexOf('"');
    
    if (quoteStart >= 0 && quoteEnd > quoteStart) {
      return line.substring(quoteStart + 1, quoteEnd);
    }
    
    // 处理没有引号的格式
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return parts.sublist(1).join(' ');
    }
    
    return '';
  }

  /// 解析时间码 MM:SS:FF (分:秒:帧)
  static Duration? _parseTimeCode(String timeCode) {
    try {
      final parts = timeCode.split(':');
      if (parts.length >= 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        final frames = parts.length > 2 ? int.parse(parts[2]) : 0;
        
        // CD 帧率是 75 fps
        final totalSeconds = minutes * 60 + seconds + (frames / 75.0);
        return Duration(milliseconds: (totalSeconds * 1000).toInt());
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ 解析时间码失败: $timeCode - $e');
    }
    return null;
  }

  /// 验证 CUE 文件
  static Future<bool> validateCueFile(File cueFile) async {
    try {
      final cueInfo = await parseCueFile(cueFile);
      if (cueInfo == null) return false;
      
      // 检查是否有有效的音轨
      if (cueInfo.tracks.isEmpty) {
        if (kDebugMode) print('⚠️ CUE文件没有音轨信息');
        return false;
      }
      
      // 检查音频文件是否存在
      if (!File(cueInfo.audioFile).existsSync()) {
        if (kDebugMode) print('⚠️ CUE引用的音频文件不存在: ${cueInfo.audioFile}');
        return false;
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ 验证CUE文件失败: $e');
      return false;
    }
  }

  /// 获取 CUE 文件的摘要信息
  static Future<String?> getCueSummary(File cueFile) async {
    try {
      final cueInfo = await parseCueFile(cueFile);
      if (cueInfo == null) return null;
      
      return '''
CUE 文件: ${p.basename(cueFile.path)}
专辑: ${cueInfo.title}
艺术家: ${cueInfo.performer ?? cueInfo.artist ?? '未知'}
音轨数: ${cueInfo.tracks.length}
音频文件: ${p.basename(cueInfo.audioFile)}
''';
    } catch (e) {
      if (kDebugMode) print('❌ 获取CUE摘要失败: $e');
      return null;
    }
  }
}
