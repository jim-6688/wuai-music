/* =========================================================
   吾爱Music 数播 · 产品页动态数据（数播专属，不读 App 的 version.json）
   - 最近更新：数播参考机的真实迭代节点（来自数播工作日志 / 提交）
   - 研发成果：读 ../studio/articles/index.json（音频白皮书，数播与工作室共用）
   - 进度：数播功能落地状态（真机已跑通的能力）
   - 全部走相对路径，拿不到数据时静默降级显示占位
   ========================================================= */
(function () {
  "use strict";
  var BASE = "../";
  function $(s, r) { return (r || document).querySelector(s); }
  function $all(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }
  function brief(note) {
    var lines = String(note || "").split(/\n/), out = [];
    for (var i = 0; i < lines.length; i++) {
      var x = lines[i].trim();
      if (!x) continue;
      if (x.indexOf("《") === 0) break;
      out.push(x);
    }
    var t = out.join(" ").replace(/\*\*/g, "");
    return t.length > 88 ? t.slice(0, 86) + "…" : t;
  }
  function fetchJson(url) {
    return fetch(url, { cache: "no-cache" }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  // 数播参考机真实迭代节点（与 Gitee 提交 / 工作日志一致）
  var UPDATES = [
    { date: "2026-11-22", title: "专业技术参数公开",
      note: "官网新增专业技术专区：十境逐段频点 / Q / 增益、DSP 处理链、重采样档位、ALSA 实测与 EDID/ELD 自检全部摊开；整站数据按真机实测校正。" },
    { date: "2026-11-22", title: "本地声纹索引 + 大模型生成歌词",
      note: "Chromaprint 指纹库接入小光歌名核对，全程本机不联网；大模型生成歌词自带 API Key、只传曲目信息、不上传音频、只写本地缓存。" },
    { date: "2026-11-22", title: "十境全调节与反馈成长",
      note: "本地神经网络 v2 给出连续十境增益，一键应用 + 满意/不满意反馈，命中率可见；链路不支持的能力自动规避，DSD 后端硬拦。" },
    { date: "2026-11-22", title: "沉浸舞台与小光陪伴",
      note: "星环与动态背景、5 档亮度、自动全屏、逐字歌词效果；小光播放陪伴动作、歌名核对提醒、歌词审核与本地 LRC 逐字升级。" },
    { date: "2026-11-21", title: "数播登录页与多语言",
      note: "品牌化登录页、五语界面（简中/繁中/英/日/韩）即时切换；NAS 导入优化、输出链路自检、队列与封面显示修复。" },
    { date: "2026-11-20", title: "十境调音与 bit-perfect 白皮书",
      note: "TENSCAPE 听感语义参量均衡落地数播端；发布把 bit-perfect 从声明变成证据、中文曲库刮削目标错配两篇白皮书。" }
  ];

  // 数播能力落地状态（真机已跑通，非 App 发版节奏）
  var CAPABILITY = [
    { name: "本地曲库 · 播放链路", pct: 100, note: "886 首实测 · mixer_type none 直出" },
    { name: "十境调音 · 神经网络", pct: 100, note: "10 段语义 EQ + 连续增益 + 反馈" },
    { name: "小光管家 · 声纹核对", pct: 100, note: "本地 Chromaprint + SQLite 侧车" },
    { name: "歌词封面 · 大模型生成", pct: 100, note: "逐字高亮 + 自带 Key" },
    { name: "五语界面 · 沉浸舞台", pct: 100, note: "725 词条 + 动态背景 / 亮度" },
    { name: "流媒体订阅接入", pct: 0, note: "不做：定位本地曲库方案" }
  ];

  function renderUpdates() {
    var box = $('[data-pd="updates"]');
    if (!box) return;
    var n = parseInt(box.getAttribute("data-pd-count"), 10) || 4;
    box.innerHTML = '<div class="timeline">' + UPDATES.slice(0, n).map(function (it, i) {
      return '<div class="tl-item">' +
        '<div class="tl-date">' + esc(it.date) + ' · 数播参考机</div>' +
        '<h4>' + (i === 0 ? '最近 ' : '') + esc(it.title) + '</h4>' +
        '<p>' + esc(brief(it.note)) + '</p>' +
        '</div>';
    }).join("") + '</div>';
  }

  function renderProgress() {
    var box = $('[data-pd="progress"]');
    if (!box) return;
    box.innerHTML = '<div class="pd-progress">' + CAPABILITY.map(function (r) {
      return '<div class="bar-row">' +
        '<div class="bar-head"><b>' + esc(r.name) + '</b><span>' + esc(r.note) + '</span></div>' +
        '<div class="bar-track"><div class="bar-fill" style="width:' + r.pct + '%"></div></div>' +
        '</div>';
    }).join("") + '</div><p class="tech-note">以上为参考机当前已跑通的能力；进度描述的是功能落地状态，不是版本号或发版节奏。</p>';
  }

  function renderPapers(articles) {
    var box = $('[data-pd="papers"]');
    if (!box) return;
    var list = (articles && articles.articles) || [];
    if (!list.length) { box.innerHTML = '<p class="pd-empty">研究文章整理中。</p>'; return; }
    box.innerHTML = '<div class="timeline">' + list.slice(0, 5).map(function (a) {
      var title = (a.title && (a.title.zh || a.title)) || a.title || "未命名";
      var dek = (a.dek && (a.dek.zh || a.dek)) || "";
      var href = a.file ? BASE + "studio/articles/" + a.file : BASE + "studio/";
      return '<div class="tl-item">' +
        '<div class="tl-date">' + esc(a.date || "") + ' · 工作室白皮书</div>' +
        '<h4><a href="' + esc(href) + '">' + esc(title) + ' →</a></h4>' +
        '<p>' + esc(brief(dek)) + '</p>' +
        '</div>';
    }).join("") + '</div>';
  }

  function init() {
    renderUpdates();
    renderProgress();
    if ($('[data-pd="papers"]')) {
      fetchJson(BASE + "studio/articles/index.json").then(renderPapers).catch(function () {
        var b = $('[data-pd="papers"]');
        if (b && !b.innerHTML.trim()) b.innerHTML = '<p class="pd-empty">研究文章整理中。</p>';
      });
    }
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
