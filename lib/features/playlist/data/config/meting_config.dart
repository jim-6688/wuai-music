/// Meting API 配置
/// 
/// 管理 Meting API 的配置参数

class MetingConfig {
  /// 默认 API 基础 URL
  static const String defaultApiUrl = 'https://music.meijiecao.top/lydata.php';
  
  /// 备用 API URL 列表
  static const List<String> backupApiUrls = [
    'https://music.meijiecao.top/lydata.php',  // meijiecao.top - 支持网易云搜索/歌单/播放
    'https://api.injahow.cn/meting',    // injahow - 仅支持通过 ID 获取
  ];
  
  /// 请求超时时间（秒）
  static const int requestTimeout = 10;
  
  /// 默认平台
  static const String defaultPlatform = 'netease';
  
  /// 每次搜索返回的最大结果数
  static const int searchLimit = 30;
  
  /// 歌单加载最大数量
  static const int playlistLimit = 100;
  
  /// 是否启用缓存
  static const bool enableCache = true;
  
  /// 缓存有效期（分钟）
  static const int cacheExpiryMinutes = 30;
}
