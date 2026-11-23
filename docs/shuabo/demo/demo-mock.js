/* 吾爱数播 · 官网交互演示数据层
 * ---------------------------------------------------------------------------
 * 纯前端打桩：接管 window.fetch / EventSource，把终端 UI 的全部 /api/* 请求
 * 拦在浏览器里，用「生成的虚构样例」应答。零后端、零真实曲库、零设备数据。
 *
 * 约定：生成脚本会把 index.html 里的 /api/ 前缀改写成 demo-api/，
 *       因此即使有漏网请求也只会落到本站相对路径，绝不会打到官网真实接口。
 * 本文件是手工维护的真源，build_shuabo_demo.py 不会覆盖它。
 */
(function () {
  "use strict";

  var PREFIX = "demo-api/";

  /* ── 全部为虚构样例：曲目 / 艺人 / 专辑 / 路径 / 歌词 ─────────────────── */
  var ALBUM_SEED = [
    { album: "雾中来信",         artist: "云间示例乐团", date: "2026", cover: "c01.svg", fmt: "FLAC", spec: "24bit / 96 kHz" },
    { album: "午后的第七级台阶", artist: "北屿",         date: "2026", cover: "c02.svg", fmt: "FLAC", spec: "24bit / 96 kHz" },
    { album: "铜色黄昏",         artist: "拾光小组",     date: "2025", cover: "c03.svg", fmt: "WAV",  spec: "16bit / 44.1 kHz" },
    { album: "雨的形状",         artist: "空白电台",     date: "2025", cover: "c04.svg", fmt: "DSD",  spec: "DSD64 / 2.8 MHz" },
    { album: "纸上的海",         artist: "沈砚",         date: "2026", cover: "c05.svg", fmt: "FLAC", spec: "24bit / 192 kHz" },
    { album: "慢速星图",         artist: "浮标乐队",     date: "2024", cover: "c06.svg", fmt: "WAV",  spec: "24bit / 96 kHz" },
    { album: "回声标本",         artist: "青屿",         date: "2025", cover: "c07.svg", fmt: "FLAC", spec: "16bit / 44.1 kHz" },
    { album: "寂静实验",         artist: "归来者",       date: "2026", cover: "c08.svg", fmt: "MP3",  spec: "320 kbps" },
    { album: "北纬三十度",       artist: "云间示例乐团", date: "2024", cover: "c09.svg", fmt: "FLAC", spec: "24bit / 48 kHz" }
  ];

  var TRACK_SEED = [
    { title: "晨雾里的第一辆车", artist: "云间示例乐团", album: "雾中来信",         time: 252, lines: ["晨雾漫过窗台", "街灯还没有醒来", "我把唱针轻轻放下", "让一整个下午慢下来", "风从远处带来回信"] },
    { title: "第七级台阶",       artist: "北屿",         album: "午后的第七级台阶", time: 228, lines: ["数到第七级就停下", "影子比人先到家", "门缝里漏出一点光", "像谁留的一句晚安", "午后就这样过去了"] },
    { title: "铜色黄昏",         artist: "拾光小组",     album: "铜色黄昏",         time: 306, lines: ["天色慢慢转成铜", "屋檐收留最后的光", "旧唱片转过一整圈", "我们谁都没有说话", "黄昏比想象中长"] },
    { title: "雨落在旧磁带上",   artist: "空白电台",     album: "雨的形状",         time: 273, lines: ["雨点敲着窗台", "磁带转得很慢", "没录完的那一句", "被留白轻轻盖住", "电台整夜没有关机"] },
    { title: "纸上的海",         artist: "沈砚",         album: "纸上的海",         time: 237, lines: ["把海画在纸上", "浪就不会弄湿鞋", "折起来放进口袋", "走到哪里都听着", "一片很小的蓝"] },
    { title: "慢速星图",         artist: "浮标乐队",     album: "慢速星图",         time: 381, lines: ["星星走得比我们慢", "所以才看得见路", "把地图折成船", "顺着夜色放出去", "等一个不急的清晨"] },
    { title: "回声标本",         artist: "青屿",         album: "回声标本",         time: 248, lines: ["把回声收进玻璃瓶", "贴上日期和天气", "很多年后再打开", "还听得见那天的风", "只是没有人应声"] },
    { title: "夜航船",           artist: "归来者",       album: "寂静实验",         time: 344, lines: ["灯一盏一盏往后退", "水面把城市折起来", "不急着靠岸", "也不急着回答", "就这样慢慢地走"] },
    { title: "北纬三十度",       artist: "云间示例乐团", album: "北纬三十度",       time: 266, lines: ["沿着这条线往东", "气候忽然变温柔", "把外套留在车上", "让风替我们决定", "今天要去哪里"] }
  ];

  function albumOf(name) {
    for (var i = 0; i < ALBUM_SEED.length; i++) if (ALBUM_SEED[i].album === name) return ALBUM_SEED[i];
    return null;
  }
  function coverOf(name) {
    var a = albumOf(name);
    if (a) return "./covers/" + a.cover;
    var h = 0, s = String(name || "");
    for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
    return "./covers/c" + String((h % 9) + 1).padStart(2, "0") + ".svg";
  }

  var TRACKS = TRACK_SEED.map(function (t, i) {
    var a = albumOf(t.album) || ALBUM_SEED[0];
    return {
      uri: "样例曲库/" + t.album + "/" + String(i + 1).padStart(2, "0") + " " + t.title + "." + a.fmt.toLowerCase(),
      title: t.title, artist: t.artist, album: t.album,
      time: t.time, ext: a.fmt, spec: a.spec, cover: "./covers/" + a.cover,
      lines: t.lines
    };
  });

  var ALBUMS = ALBUM_SEED.map(function (a, i) {
    return {
      uri: "样例曲库/" + a.album, dir: "样例曲库/" + a.album,
      album: a.album, artist: a.artist, date: a.date,
      tracks: (i % 4) + 6, formats: [a.fmt],
      source: "样例曲库", addedAt: "2026-11-" + String((i % 20) + 1).padStart(2, "0"),
      kind: "album", cover: "./covers/" + a.cover
    };
  });

  function lyricLines(t) {
    return (t.lines || []).map(function (text, i) {
      var start = 4 + i * 7, chars = Array.from(text), span = 6 / Math.max(1, chars.length);
      return {
        t: start, text: text,
        words: chars.map(function (c, j) { return { t: start + j * span, text: c }; })
      };
    });
  }

  /* ── 演示播放状态机 ──────────────────────────────────────────────────── */
  var ST = { idx: 0, playing: true, elapsed: 18, at: Date.now(), volume: 60, random: "0", repeat: "0", single: "0" };

  function dur() { return TRACKS[ST.idx].time; }
  function elapsed() {
    if (!ST.playing) return ST.elapsed;
    return Math.min(dur() - 0.5, ST.elapsed + (Date.now() - ST.at) / 1000);
  }
  function freeze() { ST.elapsed = elapsed(); ST.at = Date.now(); }
  function goto(i) {
    ST.idx = ((i % TRACKS.length) + TRACKS.length) % TRACKS.length;
    ST.elapsed = 0; ST.at = Date.now();
  }

  function playback() {
    var t = TRACKS[ST.idx];
    return {
      available: true,
      source: { ext: "." + t.ext.toLowerCase(), spec: t.spec, detail: "样例音源", kind: "pcm", hires: false },
      path: { kind: "bitperfect", label: "直通示意（样例）", detail: "演示数据，非真实信号链", output: { rate: 96000, rate_label: "96 kHz", format: "S32_LE", family_good: true } },
      bitrate: { label: "4608 kbps" },
      output_max: { rate: 96000, at_max: false },
      active_outputs: [{ name: "演示输出", short: "演示", model: "DEMO OUT" }]
    };
  }

  function statePayload() {
    var t = TRACKS[ST.idx];
    return {
      ok: true,
      status: {
        state: ST.playing ? "play" : "pause",
        elapsed: elapsed(), duration: t.time,
        song: ST.idx, playlistlength: TRACKS.length,
        volume: ST.volume, random: ST.random, repeat: ST.repeat, single: ST.single,
        error: ""
      },
      current: {
        Title: t.title, Artist: t.artist, Album: t.album,
        file: t.uri, duration: t.time, Time: t.time, Track: String(ST.idx + 1)
      },
      queue: TRACKS.map(function (x, i) {
        return { pos: i, file: x.uri, title: x.title, artist: x.artist, album: x.album, time: x.time };
      }),
      playback: playback()
    };
  }

  var SETTINGS = {
    ok: true,
    settings: {
      ui: { lang: "zh", lyric_effect: "word", star_effect: true, auto_fx: true, buddy_tune: false },
      play: { gapless: true, crossfade: 0 },
      device: { hostname: "演示设备" }
    },
    caps: {}, version: "DEMO"
  };

  var SYS = {
    ok: true,
    hw: { rate_num: 96000, format: "S32_LE", state: "demo" },
    tools: {},
    disk: { percent: 42, free: 640 * 1073741824, total: 1100 * 1073741824 }
  };

  /* ── SSE 替身：只借用 UI 原本的 onmessage 通道推状态 ─────────────────── */
  var _es = null;
  function pushState() {
    if (_es && typeof _es.onmessage === "function") {
      try { _es.onmessage({ data: JSON.stringify(statePayload()) }); } catch (e) {}
    }
  }
  function FakeEventSource() {
    var self = this;
    _es = self;
    self.onopen = null; self.onmessage = null; self.onerror = null;
    self._t = setTimeout(function () {
      if (typeof self.onopen === "function") self.onopen({});
    }, 60);
  }
  FakeEventSource.prototype.close = function () { clearTimeout(this._t); if (_es === this) _es = null; };
  window.EventSource = FakeEventSource;

  /* ── 命令：让播放 / 暂停 / 切歌 / 拖动进度真正有反馈 ─────────────────── */
  function handleCmd(body) {
    var name = String((body && body.cmd) || ""), args = (body && body.args) || [];
    switch (name) {
      case "play":      ST.at = Date.now(); ST.playing = true; break;
      case "pause":     freeze(); ST.playing = false; break;
      case "stop":      freeze(); ST.playing = false; ST.elapsed = 0; break;
      case "next":      goto(ST.idx + 1); break;
      case "previous":
      case "prev":      goto(ST.idx - 1); break;
      case "seekcur":
      case "seek":      ST.elapsed = Math.max(0, Number(args[0]) || 0); ST.at = Date.now(); break;
      case "setvol":
      case "volume":    ST.volume = Math.max(0, Math.min(100, Number(args[0]) || 0)); break;
      case "repeat":    ST.repeat = String(args[0] || "0"); break;
      case "single":    ST.single = String(args[0] || "0"); break;
      case "random":    ST.random = String(args[0] || "0"); break;
      case "playid":
      case "addid": {
        var u = args.find(function (x) { return typeof x === "string" && x.indexOf("样例曲库/") === 0; });
        if (u) { for (var i = 0; i < TRACKS.length; i++) if (TRACKS[i].uri === u) { goto(i); break; } }
        break;
      }
      default: break;
    }
    setTimeout(pushState, 30);
    return { ok: true };
  }

  /* ── 各端点应答 ──────────────────────────────────────────────────────── */
  function browse(path) {
    var p = String(path || "/").replace(/^\/+|\/+$/g, "");
    if (!p) {
      return {
        ok: true,
        dirs: ALBUMS.map(function (a) { return { path: a.dir, name: a.album }; }),
        // 根目录另列几首散曲，让首屏既有专辑也有曲目
        files: TRACKS.slice(0, 3).map(function (t) {
          return { path: t.uri, title: t.title, artist: t.artist, album: t.album, time: t.time };
        })
      };
    }
    var a = albumOf(p.split("/").pop());
    if (!a) return { ok: true, dirs: [], files: [] };
    return {
      ok: true, dirs: [],
      files: TRACKS.filter(function (t) { return t.album === a.album; }).map(function (t) {
        return { path: t.uri, title: t.title, artist: t.artist, album: t.album, time: t.time };
      })
    };
  }

  function search(q) {
    var k = String(q || "").trim().toLowerCase();
    return {
      ok: true,
      files: TRACKS.filter(function (t) {
        return !k || (t.title + t.artist + t.album).toLowerCase().indexOf(k) >= 0;
      }).map(function (t) {
        return { path: t.uri, title: t.title, artist: t.artist, album: t.album, time: t.time };
      })
    };
  }

  function lyrics(uri) {
    var t = TRACKS.filter(function (x) { return x.uri === uri; })[0] || TRACKS[ST.idx];
    return {
      ok: true, found: true, kind: "lrc", word_level: true,
      source: "local", encoding: "local",
      lrc: { lines: lyricLines(t), offset_ms: 0, wave: null },
      meta: { title: t.title, artist: t.artist, album: t.album }
    };
  }

  var READ = {
    "state": function () { return statePayload(); },
    "settings": function () { return SETTINGS; },
    "sys": function () { return SYS; },
    "albums": function () {
      return { ok: true, albums: ALBUMS, formatGroups: ["FLAC", "WAV", "DSD", "MP3"] };
    },
    "browse": function (url) { return browse(param(url, "path")); },
    "search": function (url) { return search(param(url, "q")); },
    "lyrics": function (url) { return lyrics(param(url, "uri")); },
    "memory": function () { return { ok: true, progress: {}, history: [], queue: { uris: [], lastUri: "", savedAt: 0 } }; },
    "trash": function () { return { ok: true, items: [] }; },
    "nas/config": function () { return { ok: true, configured: false }; },
    "sleep": function () { return { ok: true, active: false, minutes: 0, end_ts: 0 }; },
    "volume": function () { return { ok: true, available: true, percent: ST.volume, muted: false }; },
    "butler/state": function () {
      return { ok: true, state: { task: "", name: "待命中", stage: "idle", progress: 0, desc: "演示模式 · 管家待命", source: "管家", mood: "calm", act: "idle", ts: Date.now() / 1000 } };
    },
    "butler/log": function () { return { ok: true, lines: [] }; },
    "files": function () { return { ok: true, files: [] }; },
    "playlists": function () { return { ok: true, playlists: [] }; },
    "playlist/songs": function () { return { ok: true, songs: [] }; },
    "firstboot/status": function () { return { ok: true, pending: false }; },
    "license/status": function () { return { ok: true, enrolled: false }; },
    "update/status": function () { return { ok: true, configured: false, restart_required: false }; },
    "lyrics/ai/status": function () { return { ok: true, enabled: false }; },
    "dsp": function () { return { ok: true, state: {} }; },
    "outputs": function () { return { ok: true, outputs: [] }; },
    "output/profiles": function () { return { ok: true, profiles: [] }; },
    "audio/caps": function () { return { ok: true, caps: {} }; },
    "audio/devices": function () { return { ok: true, devices: [] }; },
    "capabilities": function () { return { ok: true, caps: {} }; },
    "health": function () { return { ok: true, healthy: true }; },
    "resources": function () { return { ok: true, cpu: 0, mem: 0 }; },
    "album/groups": function () { return { ok: true, groups: [] }; },
    "artist/index": function () { return { ok: true, index: {} }; },
    "encoding/rules": function () { return { ok: true, rules: {} }; },
    "artist/rules": function () { return { ok: true, rules: {} }; },
    "fingerprint/status": function () { return { ok: true, available: false, count: 0 }; },
    "brain/status": function () { return { ok: true, state: {} }; },
    "neural/status": function () { return { ok: true, state: {} }; },
    "mood/status": function () { return { ok: true, state: {} }; },
    "audit/status": function () { return { ok: true, state: {} }; },
    "format/status": function () { return { ok: true, state: {} }; },
    "transcode/status": function () { return { ok: true, native: true, cached: false }; },
    "disk": function () { return { ok: true, disk: SYS.disk }; },
    "tags": function () { return { ok: true, tags: {} }; },
    "meta/album": function (url) {
      var name = param(url, "album");
      var a = albumOf(name) || ALBUM_SEED[0];
      return { ok: true, meta: { album: a.album, artist: a.artist, date: a.date, cover: "./covers/" + a.cover }, tracks: [] };
    },
    "cover": function () { return { ok: true }; }
  };

  function param(url, key) {
    var s = String(url || ""), i = s.indexOf("?");
    if (i < 0) return "";
    try { return new URLSearchParams(s.slice(i)).get(key) || ""; } catch (e) { return ""; }
  }

  var DEMO_ERR = { ok: false, error: "演示模式 · 只读展示" };
  var EMPTY_OK = { ok: true, items: [], files: [], dirs: [], albums: [], lines: [], state: {}, entries: [] };

  function respond(url, init) {
    var s = String(url || ""), i = s.indexOf(PREFIX);
    if (i < 0) return Promise.resolve(EMPTY_OK);
    var rest = s.slice(i + PREFIX.length), q = rest.indexOf("?");
    var path = (q >= 0 ? rest.slice(0, q) : rest).replace(/^\/+/, "").replace(/\/+$/, "");
    var isPost = String((init && init.method) || "GET").toUpperCase() === "POST";

    if (path === "cmd" && isPost) {
      var body = {};
      try { body = JSON.parse((init && init.body) || "{}"); } catch (e) {}
      return Promise.resolve(handleCmd(body));
    }
    if (path === "settings" && isPost) return Promise.resolve(DEMO_ERR);
    if (READ[path]) {
      try { return Promise.resolve(READ[path](s, init)); } catch (e) { return Promise.resolve(EMPTY_OK); }
    }
    // 未列入展示面的写操作一律哑火；其余读取给空结构，避免白屏。
    return Promise.resolve(isPost ? DEMY_ERR : EMPTY_OK);
  }

  function reply(data) {
    // 不依赖 Response 构造，兼容各种宿主；UI 只用到 ok/status/json/text。
    var text = JSON.stringify(data);
    return { ok: true, status: 200, statusText: "OK", headers: { get: function () { return "application/json"; } },
      json: function () { return Promise.resolve(data); },
      text: function () { return Promise.resolve(text); } };
  }

  window.fetch = function (input, init) {
    return respond(input, init).then(reply);
  };

  /* ── 封面：把 demo-api/cover?... 换成本地生成的 SVG 填充图 ───────────── */
  function coverFromUrl(src) {
    var album = param(src, "album");
    if (album) return coverOf(album);
    var uri = param(src, "uri");
    for (var i = 0; i < ALBUM_SEED.length; i++) {
      if (uri.indexOf(ALBUM_SEED[i].album) >= 0) return coverOf(ALBUM_SEED[i].album);
    }
    return coverOf(uri);
  }
  function fixImg(img) {
    var src = img.getAttribute && img.getAttribute("src");
    if (!src || src.indexOf(PREFIX + "cover") < 0) return;
    img.setAttribute("src", coverFromUrl(src));
  }
  function scan(node) {
    if (!node || node.nodeType !== 1) return;
    if (node.tagName === "IMG") fixImg(node);
    if (node.querySelectorAll) {
      var list = node.querySelectorAll("img[src*='" + PREFIX + "cover']");
      for (var i = 0; i < list.length; i++) fixImg(list[i]);
    }
  }
  if (window.MutationObserver) {
    var mo = new MutationObserver(function (muts) {
      for (var m = 0; m < muts.length; m++) {
        var mu = muts[m];
        if (mu.type === "attributes") { fixImg(mu.target); continue; }
        for (var n = 0; n < mu.addedNodes.length; n++) scan(mu.addedNodes[n]);
      }
    });
    mo.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ["src"] });
  }

  /* ── 演示态自走：到曲尾自动切下一首，让页面一直「活着」 ──────────────── */
  setInterval(function () {
    if (!ST.playing) return;
    if (elapsed() < dur() - 0.6) return;
    goto(ST.idx + 1);
    pushState();
  }, 1000);

  window.WUAI_DEMO = { tracks: TRACKS, albums: ALBUMS, state: ST, push: pushState };

  /* 官网可用 ?demo=wall 直接落在音乐墙（封面展示面），默认仍是播放页 */
  if (param(location.search, "demo") === "wall") {
    document.addEventListener("DOMContentLoaded", function () {
      setTimeout(function () {
        var b = document.querySelector('.rail .navItem[data-view="wall"]');
        if (b) b.click();
      }, 900);
    });
  }
})();
