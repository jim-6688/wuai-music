/* device-recommend.js — 按访问设备推荐对应端版本
 * 复用主站 main.js 的 detectDevice 判定规则（含 UA-CH、电视优先、手机/平板区分），
 * 供新主页与六个端页共用。只做「检测 + 映射」，UI 由各页自行渲染。
 */
(function (global) {
  'use strict';

  // 判定访问设备。返回值：phone | hd | tv | windows | apple | null
  // ⚠️ Android 分支必须排在 Windows 嗅探之前：部分 Android WebView 在桌面模式
  //    下会把 navigator.platform 报成 Win32，先判 Win 会把手机认成 PC。
  function detectDevice() {
    var ua = (navigator.userAgent || '').toLowerCase();
    var plat = (navigator.platform || '').toLowerCase();

    var ch = navigator.userAgentData || null;
    var chPlat = (ch && ch.platform) ? String(ch.platform).toLowerCase() : '';
    var chMobile = (ch && typeof ch.mobile === 'boolean') ? ch.mobile : null;

    var isAndroid = /android/i.test(ua) || chPlat === 'android';
    if (isAndroid) {
      // 电视 / 盒子：只认 UA，排在手机/平板之前（UA-CH 看不出 TV）
      if (/(tv|googletv|google tv|firetv|fire tv|mibox|mi box|shield|androidsdk|ehome|crkey|opera tv|tizen|web0s|viera|smarttv|hbbtv)/i.test(ua)) return 'tv';
      // 显式平板型号
      if (/(tablet|\bpad\b|sm-t\d|kftt|kfthwi|gt-p\d|sch-i\d)/i.test(ua)) return 'hd';
      if (chMobile === true) return 'phone';
      if (/mobile/i.test(ua)) return 'phone';
      // 兜底量屏幕短边（screen 是硬件尺寸，不随桌面模式漂移），按 sw600dp
      var sw = (window.screen && window.screen.width) || 0;
      var sh = (window.screen && window.screen.height) || 0;
      return (sw && sh && Math.min(sw, sh) >= 600) ? 'hd' : 'phone';
    }

    if (chPlat === 'windows' || /windows nt/i.test(ua) || /win/i.test(plat)) return 'windows';
    // iOS / macOS 暂无客户端
    if (chPlat === 'macos' || /iphone|ipad|ipod|macintosh|mac os x/i.test(ua)) return 'apple';
    return null; // 桌面 Linux 等：不强行匹配
  }

  // 设备 → 端信息。key 对应主页分类卡的 data-key；href 指向该端下载区。
  // apple 无对应客户端，单独给出中性提示（不误导去下 Windows 包）。
  var MAP = {
    phone:   { key: 'phone', name: '手机版', dev: 'Android 手机', href: 'phone/#download', flavor: 'phone' },
    hd:      { key: 'car',   name: '车机版', dev: '平板 / 车机',   href: 'car/#download',   flavor: 'hd' },
    tv:      { key: 'tv',    name: '电视版', dev: '电视 / 机顶盒', href: 'tv/#download',    flavor: 'tv' },
    windows: { key: 'pc',    name: '桌面版', dev: 'Windows 电脑',  href: 'pc/#download',    flavor: null }
  };

  var DEV_LABEL = {
    phone: 'Android 手机', hd: '平板 / 车机', tv: '电视 / 机顶盒',
    windows: 'Windows 电脑', apple: 'iPhone / Mac'
  };

  function recommend() {
    var d = detectDevice();
    return { device: d, info: MAP[d] || null, label: DEV_LABEL[d] || '你的设备' };
  }

  global.WuAiDeviceRecommend = {
    detect: detectDevice,
    recommend: recommend,
    MAP: MAP,
    DEV_LABEL: DEV_LABEL
  };
})(window);
