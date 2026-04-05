import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

/// 歌词行数据类
/// 
/// 表示单行歌词及其时间信息
class LyricLine extends Equatable {
  /// 时间戳 (秒)
  final double timestamp;
  
  /// 歌词内容
  final String text;
  
  /// 结束时间 (秒)，用于计算持续时间
  final double? endTime;

  const LyricLine({
    required this.timestamp,
    required this.text,
    this.endTime,
  });

  /// 获取持续时间
  Duration get duration {
    if (endTime == null) return Duration.zero;
    return Duration(milliseconds: ((endTime! - timestamp) * 1000).toInt());
  }

  /// 复制并修改
  LyricLine copyWith({
    double? timestamp,
    String? text,
    double? endTime,
  }) {
    return LyricLine(
      timestamp: timestamp ?? this.timestamp,
      text: text ?? this.text,
      endTime: endTime ?? this.endTime,
    );
  }

  @override
  List<Object?> get props => [timestamp, text, endTime];
}

/// 歌词数据类
/// 
/// 表示完整歌词文件的内容
class LyricData extends Equatable {
  /// 歌曲标题
  final String? title;
  
  /// 艺术家
  final String? artist;
  
  /// 专辑
  final String? album;
  
  /// 歌词作者
  final String? author;
  
  /// 偏移量 (毫秒)
  final int? offset;
  
  /// 歌词行列表
  final List<LyricLine> lines;
  
  /// 原始 LRC 内容
  final String? rawLrc;

  const LyricData({
    this.title,
    this.artist,
    this.album,
    this.author,
    this.offset,
    this.lines = const [],
    this.rawLrc,
  });

  /// 是否为空
  bool get isEmpty => lines.isEmpty;

  /// 行数
  int get length => lines.length;

  /// 获取指定时间对应的歌词行索引
  int getLineIndexAt(double time) {
    if (lines.isEmpty) return -1;
    
    for (int i = lines.length - 1; i >= 0; i--) {
      if (time >= lines[i].timestamp) {
        return i;
      }
    }
    return -1;
  }

  /// 获取指定时间对应的歌词行
  LyricLine? getLineAt(double time) {
    final index = getLineIndexAt(time);
    return index >= 0 ? lines[index] : null;
  }

  /// 复制并修改
  LyricData copyWith({
    String? title,
    String? artist,
    String? album,
    String? author,
    int? offset,
    List<LyricLine>? lines,
    String? rawLrc,
  }) {
    return LyricData(
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      author: author ?? this.author,
      offset: offset ?? this.offset,
      lines: lines ?? this.lines,
      rawLrc: rawLrc ?? this.rawLrc,
    );
  }

  @override
  List<Object?> get props => [title, artist, album, author, offset, lines, rawLrc];
}

/// 歌词解析服务
/// 
/// 负责解析 LRC 格式歌词文件
class LyricParser {
  /// 解析 LRC 格式歌词
  /// 
  /// [lrcContent] LRC 格式的歌词文本
  /// 返回解析后的 LyricData 对象
  static LyricData parse(String lrcContent) {
    try {
      String? title;
      String? artist;
      String? album;
      String? author;
      int? offset;
      final lines = <LyricLine>[];

      // 解析每一行
      final lrcLines = lrcContent.split('\n');
      
      for (final line in lrcLines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        // 解析元数据标签
        if (trimmedLine.startsWith('[ti:')) {
          title = _parseMetadata(trimmedLine);
        } else if (trimmedLine.startsWith('[ar:')) {
          artist = _parseMetadata(trimmedLine);
        } else if (trimmedLine.startsWith('[al:')) {
          album = _parseMetadata(trimmedLine);
        } else if (trimmedLine.startsWith('[au:')) {
          author = _parseMetadata(trimmedLine);
        } else if (trimmedLine.startsWith('[offset:')) {
          offset = _parseOffset(trimmedLine);
        } else if (trimmedLine.startsWith('[') && trimmedLine.contains(']')) {
          // 解析歌词行
          final lyricLine = _parseLyricLine(trimmedLine);
          if (lyricLine != null) {
            lines.add(lyricLine);
          }
        }
      }

      // 按时间排序
      lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 计算每行的结束时间
      final processedLines = <LyricLine>[];
      for (int i = 0; i < lines.length; i++) {
        final current = lines[i];
        double? endTime;
        
        // 如果不是最后一行，使用下一行的时间作为结束时间
        if (i < lines.length - 1) {
          endTime = lines[i + 1].timestamp;
        }
        
        processedLines.add(current.copyWith(endTime: endTime));
      }

      // 应用偏移量
      final adjustedLines = processedLines.map((line) {
        if (offset != null) {
          final adjustedTimestamp = line.timestamp + (offset / 1000);
          return line.copyWith(timestamp: adjustedTimestamp);
        }
        return line;
      }).toList();

      if (kDebugMode) {
        print('✅ 歌词解析完成: ${adjustedLines.length} 行');
      }

      return LyricData(
        title: title,
        artist: artist,
        album: album,
        author: author,
        offset: offset,
        lines: adjustedLines,
        rawLrc: lrcContent,
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ 歌词解析失败: $e');
      }
      return const LyricData();
    }
  }

  /// 解析元数据标签
  static String _parseMetadata(String line) {
    final match = RegExp(r'\[(\w+):(.+)\]').firstMatch(line);
    if (match != null) {
      return match.group(2)?.trim() ?? '';
    }
    return '';
  }

  /// 解析偏移量
  static int? _parseOffset(String line) {
    final match = RegExp(r'\[offset:(-?\d+)\]').firstMatch(line);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    return null;
  }

  /// 解析歌词行
  /// 
  /// 支持多种时间戳格式：
  /// - [mm:ss.xx] 或 [mm:ss.xxx] (标准格式)
  /// - [mm:ss] (无毫秒)
  /// - [hh:mm:ss.xx] (带小时)
  static LyricLine? _parseLyricLine(String line) {
    try {
      // 匹配时间戳: [mm:ss.xx] 或 [mm:ss.xxx] 或 [hh:mm:ss.xx]
      final pattern = RegExp(
        r'\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]',
        caseSensitive: false,
      );

      final matches = pattern.allMatches(line);
      if (matches.isEmpty) return null;

      // 获取最后一个时间戳和歌词文本
      final lastMatch = matches.last;
      final minutes = int.parse(lastMatch.group(1) ?? '0');
      final seconds = int.parse(lastMatch.group(2) ?? '0');
      final milliseconds = int.parse(lastMatch.group(3) ?? '0');
      
      // 处理毫秒 (如果是2位需要乘以10)
      final ms = lastMatch.group(3)?.length == 2 ? milliseconds * 10 : milliseconds;
      
      // 计算时间戳 (秒)
      final timestamp = (minutes * 60.0) + seconds + (ms / 1000.0);

      // 提取歌词文本
      String text = line.substring(lastMatch.end).trim();
      
      // 移除可能的时间戳
      text = text.replaceAll(RegExp(r'\[\d{1,2}:\d{2}(?:\.\d{2,3})?\]'), '');
      text = text.trim();

      if (text.isEmpty) return null;

      return LyricLine(
        timestamp: timestamp,
        text: text,
      );
    } catch (e) {
      return null;
    }
  }

  /// 生成 LRC 格式文本
  static String generateLrc(LyricData data) {
    final buffer = StringBuffer();

    // 写入元数据
    if (data.title != null) {
      buffer.writeln('[ti:${data.title}]');
    }
    if (data.artist != null) {
      buffer.writeln('[ar:${data.artist}]');
    }
    if (data.album != null) {
      buffer.writeln('[al:${data.album}]');
    }
    if (data.author != null) {
      buffer.writeln('[au:${data.author}]');
    }
    if (data.offset != null && data.offset != 0) {
      buffer.writeln('[offset:${data.offset}]');
    }

    // 写入歌词行
    for (final line in data.lines) {
      final minutes = (line.timestamp ~/ 60).toString().padLeft(2, '0');
      final seconds = (line.timestamp % 60).floor();
      final ms = ((line.timestamp % 1) * 100).toInt().toString().padLeft(2, '0');
      
      buffer.writeln('[$minutes:$seconds.$ms]${line.text}');
    }

    return buffer.toString();
  }
}
