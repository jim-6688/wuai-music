/* =========================================================
   吾爱音乐 官网脚本
   - 同域读取 /version.json（与 App OTA 共用同一份清单）
   - 同域读取 /stats.json（下载统计快照），再用 GitHub / 计数服务实时刷新
   - 动态填充各端下载链接 / 版本号 / 更新日志
   - 清单与统计不可用时优雅降级（不显示假数字）
   ========================================================= */
(function () {
  "use strict";

  var DOMAIN = "https://music.52ta.top";

  // 渠道展示名（与 App 的 flavor 对应）
  var FLAVOR_LABEL = {
    phone: "手机端",
    hd: "车机 / 平板",
    tv: "电视端",
  };

  // 站点展示顺序：手机 / 车机平板(hd) / 电视
  var SITE_FLAVORS = ["phone", "hd", "tv"];

  // 兜底清单：清单未部署时站点仍可完整呈现（下载按钮置为“敬请期待”）
  var FALLBACK = {
    releases: {
      phone: { versionName: "1.0.0", versionCode: 1, flavor: "phone", notes: "吾爱音乐 1.0.0 首个正式版本。", url: "", size: 0, sha256: "" },
      hd: { versionName: "1.0.0", versionCode: 1, flavor: "hd", notes: "吾爱音乐 1.0.0 首个正式版本（车机/平板）。", url: "", size: 0, sha256: "" },
      tv: { versionName: "1.0.0", versionCode: 1, flavor: "tv", notes: "吾爱音乐 1.0.0 首个正式版本（电视）。", url: "", size: 0, sha256: "" },
    },
    minRequiredCode: { phone: 1, hd: 1, tv: 1 },
  };

  // 码云（Gitee）国内镜像仓库。
  // 用 `/releases/download/latest/<文件名>` 形式指向**最新** Release：
  // 实测码云支持 latest（三渠道均 HTTP 200、体积与 GitHub 资产一致，不存在的文件名返回真 404），
  // 所以这里**不用写死版本号** —— 以后发新版，只要在码云传同样文件名的包，链接自动跟上。
  var GITEE_REPO = "https://gitee.com/jinghe-net/wuai-music";
  var GITEE_ASSETS = {
    phone: "app-phone-release.apk",
    hd: "app-hd-release.apk",
    tv: "app-tv-release.apk",
  };
  function giteeUrl(flavor) {
    var asset = GITEE_ASSETS[flavor];
    return asset
      ? GITEE_REPO + "/releases/download/latest/" + asset
      : GITEE_REPO + "/releases";
  }

  function $(sel, ctx) { return (ctx || document).querySelector(sel); }
  function $all(sel, ctx) { return Array.prototype.slice.call((ctx || document).querySelectorAll(sel)); }

  function sizeLabel(bytes) {
    if (!bytes || bytes <= 0) return "";
    var mb = bytes / (1024 * 1024);
    if (mb >= 1024) return (mb / 1024).toFixed(2) + " GB";
    return mb.toFixed(1) + " MB";
  }

  function getRelease(manifest, flavor) {
    var r = manifest && manifest.releases;
    return (r && r[flavor]) || null;
  }

  // 清单里该渠道的 variants（按 ABI 分组的独立包）→ 有效键数组；无则返回 []
  function variantKeys(rel) {
    var v = rel && rel.variants;
    if (!v || typeof v !== "object") return [];
    return Object.keys(v).filter(function (k) { return v[k] && v[k].url; });
  }

  // 属性值转义：URL 来自清单，插入 href 前做最小防护
  function attr(s) {
    return String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;");
  }

  // 主下载按钮下方渲染「其它架构」的独立包链接（仅在清单带 variants 时出现）
  function renderAlts(manifest, flavor) {
    var box = document.querySelector('.platform__alts[data-alts="' + flavor + '"]');
    if (!box) return;
    var rel = getRelease(manifest, flavor);
    var variants = (rel && rel.variants) || {};
    // 主按钮指向的那一份（顶层兜底包，通常是 arm64）不在这里再列一遍：
    // 清单里顶层 url 与 variants 里的 arm64 是同一个文件。
    // 单 ABI 渠道（手机/车机）只有这一个包，排除后「其它架构」整行就该隐藏；
    // 双架构渠道（TV）则只剩 armeabi-v7a 一个真正不同的包。
    var keys = variantKeys(rel).filter(function (k) {
      return variants[k].url !== (rel && rel.url);
    });
    if (!keys.length) {
      box.hidden = true;
      box.innerHTML = "";
      return;
    }
    var html = '<span class="alts__label">其它架构</span>';
    keys.forEach(function (k) {
      var v = variants[k];
      var s = sizeLabel(v.size);
      html += '<a class="alts__link" href="' + attr(v.url) + '">' +
              k + (s ? " · " + s : "") + "</a>";
    });
    box.innerHTML = html;
    box.hidden = false;
  }

  // 把清单渲染到页面
  function render(manifest, live) {
    var statusEl = $("#updateStatus");
    var statusText = $("#updateStatusText");
    var latestEl = $("#updateLatest");
    var tableEl = $("#versionTable");
    var logEl = $("#changelog");

    // 最新版本号（取三端最高 versionCode 对应的 versionName）
    var maxCode = 0, maxName = "—";
    SITE_FLAVORS.forEach(function (f) {
      var rel = getRelease(manifest, f);
      if (rel && rel.versionCode > maxCode) { maxCode = rel.versionCode; maxName = rel.versionName || maxName; }
    });
    latestEl.textContent = "v" + maxName;

    // 各端下载按钮 + 版本角标
    $all(".platform").forEach(function (card) {
      var flavor = card.getAttribute("data-flavor");
      var rel = getRelease(manifest, flavor);
      var link = $('.download-link[data-flavor="' + flavor + '"]', card) ||
                 $('.download-link[data-flavor="' + flavor + '"]');
      var verEl = $("[data-ver]", card);
      if (rel) {
        if (verEl) verEl.textContent = "v" + (rel.versionName || "—");
        if (link) {
          if (rel.url) {
            link.setAttribute("href", rel.url);
            // 这是「国际下载」（GitHub）按钮的文案，别写成「下载 APK」——
            // 卡片里国内的码云按钮由 initMirrors 单独填 href，两者并列显示。
            link.textContent = "国际下载";
            link.classList.remove("is-disabled");
            link.removeAttribute("disabled");
          } else {
            link.textContent = "敬请期待";
            link.classList.add("is-disabled");
            link.setAttribute("disabled", "disabled");
          }
        }
      }
    });

    // 各端的「其它架构」独立包链接（清单带 variants 时才显示）
    SITE_FLAVORS.forEach(function (f) { renderAlts(manifest, f); });

    // 顶栏/英雄区下载 CTA 也指向手机端
    var phoneRel = getRelease(manifest, "phone");
    $all('.download-link[data-flavor="phone"]').forEach(function (l) {
      if (phoneRel && phoneRel.url) l.setAttribute("href", phoneRel.url);
    });

    // 版本表
    tableEl.innerHTML = "";
    SITE_FLAVORS.forEach(function (f) {
      var rel = getRelease(manifest, f);
      var row = document.createElement("div");
      row.className = "vrow";
      var ver = rel ? (rel.versionName || "—") : "—";
      var meta = rel ? sizeLabel(rel.size) : "尚未发布";
      // 只有**真的分了多个架构**才标「多架构」。单 ABI 渠道（手机/车机）虽然
      // 清单里也带 variants（只有 arm64 一项），但实际只有一个包，标上去会让
      // 用户以为还有别的可下。
      if (rel && variantKeys(rel).length > 1) {
        meta = (meta ? meta + " · " : "") + "多架构";
      }
      row.innerHTML =
        '<div class="vrow__name">' + (FLAVOR_LABEL[f] || f) + "</div>" +
        '<div class="vrow__ver">v' + ver + "</div>" +
        '<div class="vrow__meta">' + meta + "</div>";
      tableEl.appendChild(row);
    });

    // 更新日志（按 flavor 列出最新说明）
    logEl.innerHTML = "";
    var hasLog = false;
    SITE_FLAVORS.forEach(function (f) {
      var rel = getRelease(manifest, f);
      if (!rel) return;
      var notes = (rel.notes || "").trim();
      if (!notes) return;
      hasLog = true;
      var item = document.createElement("div");
      item.className = "changelog__item";
      item.innerHTML =
        '<div class="ci-head"><span class="ci-flavor">' + (FLAVOR_LABEL[f] || f) +
        '</span><span class="ci-ver">v' + (rel.versionName || "") + "</span></div>" +
        "<p>" + notes.replace(/</g, "&lt;") + "</p>";
      logEl.appendChild(item);
    });
    if (!hasLog) {
      logEl.innerHTML = '<p class="changelog__empty">暂无更新记录。</p>';
    }

    // 状态
    if (statusEl) statusEl.classList.add(live ? "is-ok" : "is-err");
    if (statusText) statusText.textContent = live
      ? "已连接到更新服务器"
      : "当前为预览数据，部署后将显示真实版本";
  }

  function fetchManifest() {
    var done = false;
    var timer = setTimeout(function () {
      if (!done) { done = true; render(FALLBACK, false); }
    }, 6000);

    fetch("/version.json", { cache: "no-cache" })
      .then(function (res) {
        if (!res.ok) throw new Error("HTTP " + res.status);
        return res.json();
      })
      .then(function (json) {
        if (done) return;
        done = true;
        clearTimeout(timer);
        // 规整：兼容单条 latest 旧格式
        var manifest = { releases: {}, minRequiredCode: {} };
        if (json.releases && typeof json.releases === "object") {
          manifest.releases = json.releases;
        } else if (json.latest && typeof json.latest === "object") {
          var fl = json.latest.flavor || "phone";
          manifest.releases[fl] = json.latest;
        }
        var mr = json.minRequiredCode;
        if (typeof mr === "object" && mr) manifest.minRequiredCode = mr;
        else if (typeof mr === "number") {
          SITE_FLAVORS.forEach(function (f) { manifest.minRequiredCode[f] = mr; });
        }
        render(manifest, true);
      })
      .catch(function () {
        if (done) return;
        done = true;
        clearTimeout(timer);
        render(FALLBACK, false);
      });
  }

  // 导航：滚动加背景
  function initNav() {
    var nav = $("#nav");
    // 没有 #nav 就直接跳过。否则下面 onScroll() 在 nav 为 null 时抛 TypeError，
    // 而 DOMContentLoaded 里 initNav 排在 initMirrors/fetchManifest **之前**，
    // 一处抛错会让后面所有初始化静默失效（下载链接、版本号全都不填）。
    if (!nav) return;
    var onScroll = function () {
      if (window.scrollY > 20) nav.classList.add("is-scrolled");
      else nav.classList.remove("is-scrolled");
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    onScroll();

    var toggle = $("#navToggle");
    var links = $(".nav__links");
    if (toggle && links) {
      toggle.addEventListener("click", function () {
        var open = links.classList.toggle("is-open");
        toggle.setAttribute("aria-expanded", open ? "true" : "false");
      });
      $all("a", links).forEach(function (a) {
        a.addEventListener("click", function () { links.classList.remove("is-open"); });
      });
    }
  }

  // 滚动入场动画
  function initReveal() {
    var els = $all(".reveal");
    if (!("IntersectionObserver" in window)) {
      els.forEach(function (el) { el.classList.add("is-visible"); });
      return;
    }
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("is-visible"); io.unobserve(e.target); }
      });
    }, { threshold: 0.12 });
    els.forEach(function (el) { io.observe(el); });
  }

  function initYear() {
    var y = $("#year");
    if (y) y.textContent = new Date().getFullYear();
  }

  // 国内镜像直链。**不依赖 version.json**，DOM 就绪即填好 —— 清单加载失败时
  // 仍指向码云 Releases（HTML 里写死的兜底 href），不会出现空链。
  function initMirrors() {
    $all(".mirror-link[data-flavor]").forEach(function (a) {
      a.setAttribute("href", giteeUrl(a.getAttribute("data-flavor")));
    });
  }

  /* =========================================================
     下载统计：「本站已下载 N 次」
     两个口径叠加，页面上分开讲清楚，不混成一个含糊的数字：
       ① GitHub 官方 download_count —— 平台自己统计的，改不了、刷不动，
          而且 App 内 OTA 更新时的下载也算在里面；但**码云（国内）那条链路不计入**。
       ② 本站按钮点击计数 —— 码云侧没有公开计数（页面和 API 都不给），只能自己数。
     数据来源与降级：
       - `/stats.json`（发布时生成的快照，同域读取）先把数字垫上，页面不空等；
       - 再用 api.github.com / 计数服务**实时刷新**一次，成功即覆盖；
       - 两个都拿不到时整块保持隐藏 —— 宁可不显示，也不显示假数字。
     ========================================================= */
  var COUNT_API = "https://countapi.mileshilliard.com/api/v1";
  // 计数键：单层 key（这服务不支持 namespace/key 两级，两级路径会 404）
  var COUNT_KEY = "wuai-music-site-dl-2026";
  // 同一浏览器只计一次：否则刷新页面、连点两个按钮都能灌水，数字立刻失去意义
  var COUNTED_FLAG = "wuai-download-counted";
  var GH_RELEASES_API =
    "https://api.github.com/repos/jim-6688/wuai-music/releases?per_page=100";

  var dlState = { github: null, site: null };

  // 只统计安装包：Release 里还挂过截图 png，算进去会让数字虚高
  function sumGithubDownloads(rels) {
    if (!rels || !rels.length) return null;
    var sum = 0, seen = false;
    rels.forEach(function (rel) {
      (rel.assets || []).forEach(function (a) {
        if (/\.apk$/i.test(a.name || "")) {
          sum += a.download_count || 0;
          seen = true;
        }
      });
    });
    return seen ? sum : null;
  }

  function fmtNum(n) {
    try { return n.toLocaleString("zh-CN"); } catch (e) { return String(n); }
  }

  function paintDownloads() {
    var box = $("#dlStats");
    if (!box) return;
    if (dlState.github === null && dlState.site === null) return;
    var total = (dlState.github || 0) + (dlState.site || 0);
    $("#dlTotal").textContent = fmtNum(total);
    var parts = [];
    if (dlState.github !== null) parts.push("GitHub 官方统计 " + fmtNum(dlState.github) + " 次");
    if (dlState.site !== null) parts.push("本站按钮点击 " + fmtNum(dlState.site) + " 次");
    $("#dlBreak").textContent = parts.join(" · ");
    box.classList.remove("is-pending");
  }

  function fetchJson(url) {
    return fetch(url, { cache: "no-cache" }).then(function (r) {
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    });
  }

  // 点下载按钮 +1。同浏览器只贡献一次；失败则不记标记，下次点击会重试。
  function bumpDownloads() {
    try { if (localStorage.getItem(COUNTED_FLAG)) return; } catch (e) {}
    fetchJson(COUNT_API + "/hit/" + COUNT_KEY)
      .then(function (d) {
        if (!d || typeof d.value !== "number") return;
        dlState.site = d.value;
        try { localStorage.setItem(COUNTED_FLAG, "1"); } catch (e) {}
        paintDownloads();
      })
      .catch(function () { /* 计数失败不影响下载本身 */ });
  }

  function initDownloads() {
    var box = $("#dlStats");
    if (!box) return;

    // ① 快照：让数字立刻可见（实时接口在国内未必每次都能连上）
    fetchJson("/stats.json")
      .then(function (s) {
        if (!s) return;
        if (typeof s.githubDownloads === "number") dlState.github = s.githubDownloads;
        if (typeof s.siteClicks === "number") dlState.site = s.siteClicks;
        paintDownloads();
      })
      .catch(function () {});

    // ② 实时：GitHub 匿名接口限 60 次/小时/IP，失败就继续用快照
    fetchJson(GH_RELEASES_API)
      .then(function (rels) {
        var n = sumGithubDownloads(rels);
        if (n !== null) { dlState.github = n; paintDownloads(); }
      })
      .catch(function () {});

    // ③ 实时：本站点击数（只读，不 +1）
    fetchJson(COUNT_API + "/get/" + COUNT_KEY)
      .then(function (d) {
        if (d && typeof d.value === "number") { dlState.site = d.value; paintDownloads(); }
      })
      .catch(function () {});

    // ④ 点击任意下载入口 ⇒ +1（用事件委托，动态渲染的「其它架构」链接也覆盖）
    document.addEventListener("click", function (e) {
      var el = e.target;
      if (!el || !el.closest) return;
      var a = el.closest("a[href]");
      if (!a) return;
      var href = a.getAttribute("href") || "";
      var isDownload =
        a.classList.contains("download-link") ||
        a.classList.contains("mirror-link") ||
        a.classList.contains("alts__link") ||
        /\/releases\/(download|latest)/i.test(href);
      if (isDownload) bumpDownloads();
    });
  }

  // 深浅色主题切换（默认跟随系统，选择后记忆）
  function initTheme() {
    var KEY = "wuai-theme";
    var root = document.documentElement;
    var btn = $("#themeToggle");
    var SUN = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><circle cx="12" cy="12" r="4.6" fill="currentColor"/><g stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><line x1="12" y1="2.6" x2="12" y2="5"/><line x1="12" y1="19" x2="12" y2="21.4"/><line x1="2.6" y1="12" x2="5" y2="12"/><line x1="19" y1="12" x2="21.4" y2="12"/><line x1="4.9" y1="4.9" x2="6.7" y2="6.7"/><line x1="17.3" y1="17.3" x2="19.1" y2="19.1"/><line x1="4.9" y1="19.1" x2="6.7" y2="17.3"/><line x1="17.3" y1="6.7" x2="19.1" y2="4.9"/></g></svg>';
    var MOON = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d="M20 14.6A8 8 0 0 1 9.4 4a7 7 0 1 0 10.6 10.6z" fill="currentColor"/></svg>';

    function paint() {
      var t = root.getAttribute("data-theme") || "dark";
      if (btn) {
        // 当前为浅色时显示月亮（点击切到深色），当前深色显示太阳
        btn.innerHTML = t === "light" ? MOON : SUN;
      }
    }
    paint();

    if (btn) {
      btn.addEventListener("click", function () {
        var next = root.getAttribute("data-theme") === "light" ? "dark" : "light";
        root.setAttribute("data-theme", next);
        try { localStorage.setItem(KEY, next); } catch (e) {}
        paint();
      });
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    initTheme();
    initNav();
    initReveal();
    initYear();
    initMirrors();
    fetchManifest();
    initDownloads();
  });
})();
