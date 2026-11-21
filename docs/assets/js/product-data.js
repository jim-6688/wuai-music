/* =========================================================
   吾爱音乐 · 产品页「最近更新 / 研发成果 / 进度」共享数据脚本
   - 同域读取 ../version.json（与 App OTA、主站共用同一份清单）
   - 最近更新：取 changelog 前 N 条，渲染到 [data-pd="updates"]
   - 版本号角标：所有 [data-pd-ver] 填最新版本号
   - 研发成果：读 ../studio/articles/index.json，渲染到 [data-pd="papers"]
   - 进度：从 version.json 统计，渲染到 [data-pd="progress"]
   - 全部走相对路径，不改托管域名；拿不到数据时静默降级（显示友好占位）
   主题键与主站一致：wuai-theme。
   ========================================================= */
(function () {
  "use strict";

  var BASE = "../"; // 端页都在一级子目录，主站在同级用 ./ 时不引用本脚本

  function $(sel, root) { return (root || document).querySelector(sel); }
  function $all(sel, root) { return Array.prototype.slice.call((root || document).querySelectorAll(sel)); }

  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  // changelog 的 notes 结构：第一行是描述，之后常跟「《诗名》· 作者 + 诗句」。
  // 描述之后的诗词不是更新内容，遇到《》标题即停止，只保留前面的描述。
  function brief(note) {
    var lines = String(note || "").split(/\n/);
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var x = lines[i].trim();
      if (!x) continue;
      if (x.indexOf("《") === 0) break;   // 诗词标题，后面都是诗，停止
      out.push(x);
    }
    var text = out.join(" ") || "本次更新修复了一些问题，增加了一些功能。";
    text = text.replace(/\*\*/g, "");   // 去掉 markdown 粗体标记
    return text.length > 88 ? text.slice(0, 86) + "…" : text;
  }

  function fetchJson(url) {
    return fetch(url, { cache: "no-cache" }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  function fillVersion(ver) {
    $all("[data-pd-ver]").forEach(function (el) { el.textContent = "v" + ver; });
  }

  function renderUpdates(list) {
    var box = $('[data-pd="updates"]');
    if (!box) return;
    var n = parseInt(box.getAttribute("data-pd-count"), 10) || 4;
    var items = (list || []).slice(0, n);
    if (!items.length) { box.innerHTML = '<p class="pd-empty">更新记录整理中。</p>'; return; }
    box.innerHTML = '<div class="timeline">' + items.map(function (it) {
      return '<div class="tl-item">' +
        '<div class="tl-date">' + esc(it.date || "") + ' · v' + esc(it.versionName || "") + '</div>' +
        '<h4>' + (it.versionName === list[0].versionName ? '最新版本 ' : '版本 ') + esc(it.versionName || "") + '</h4>' +
        '<p>' + esc(brief(it.notes)) + '</p>' +
        '</div>';
    }).join("") + '</div>';
  }

  function renderProgress(manifest, changelog) {
    var box = $('[data-pd="progress"]');
    if (!box) return;
    var flavors = (manifest && manifest.releases) || {};
    var keys = Object.keys(flavors);
    var ver = flavors.phone && flavors.phone.versionName || "—";
    var label = { phone: "手机版", hd: "车机 / HD", tv: "TV 版" };
    var rows = keys.map(function (k) {
      var rel = flavors[k];
      var variants = rel && rel.variants ? Object.keys(rel.variants).length : 1;
      return { name: label[k] || k, ver: rel && rel.versionName || "—", v: variants };
    });
    var total = (changelog || []).length;
    var html = '<div class="pd-progress">' +
      '<div class="bar-row">' +
        '<div class="bar-head"><b>发版节奏</b><span>累计 ' + total + ' 个版本</span></div>' +
        '<div class="bar-track"><div class="bar-fill" style="width:' + Math.min(100, 40 + total) + '%"></div></div>' +
      '</div>' +
      rows.map(function (r) {
        return '<div class="bar-row">' +
          '<div class="bar-head"><b>' + esc(r.name) + '</b><span>v' + esc(r.ver) + ' · ' + r.v + ' 架构</span></div>' +
          '<div class="bar-track"><div class="bar-fill" style="width:100%"></div></div>' +
          '</div>';
      }).join("") +
      '</div>';
    box.innerHTML = html;
  }

  function renderPapers(articles) {
    var box = $('[data-pd="papers"]');
    if (!box) return;
    var list = (articles && articles.articles) || [];
    if (!list.length) { box.innerHTML = '<p class="pd-empty">研究文章整理中。</p>'; return; }
    box.innerHTML = '<div class="timeline">' + list.slice(0, 5).map(function (a) {
      var title = (a.title && (a.title.zh || a.title)) || a.title || "未命名";
      var dek = (a.dek && (a.dek.zh || a.dek)) || "";
      var date = a.date || "";
      var href = a.file ? BASE + "studio/articles/" + a.file : BASE + "studio/";
      return '<div class="tl-item">' +
        '<div class="tl-date">' + esc(date) + '</div>' +
        '<h4><a href="' + esc(href) + '">' + esc(title) + ' →</a></h4>' +
        '<p>' + esc(brief(dek)) + '</p>' +
        '</div>';
    }).join("") + '</div>';
  }

  function init() {
    fetchJson(BASE + "version.json").then(function (m) {
      var cl = m.changelog || [];
      var ver = (m.releases && m.releases.phone && m.releases.phone.versionName) || "—";
      fillVersion(ver);
      renderUpdates(cl);
      renderProgress(m, cl);
    }).catch(function () {
      // 清单不可用时，保留 HTML 里的静态占位，不显示假数字
      $all('[data-pd="updates"],[data-pd="progress"]').forEach(function (b) {
        if (!b.innerHTML.trim()) b.innerHTML = '<p class="pd-empty">更新记录整理中。</p>';
      });
    });

    if ($('[data-pd="papers"]')) {
      fetchJson(BASE + "studio/articles/index.json").then(renderPapers).catch(function () {
        var b = $('[data-pd="papers"]');
        if (b && !b.innerHTML.trim()) b.innerHTML = '<p class="pd-empty">研究文章整理中。</p>';
      });
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
