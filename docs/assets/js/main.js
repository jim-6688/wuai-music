/* =========================================================
   吾爱音乐 官网脚本
   - 同域读取 /version.json（与 App OTA 共用同一份清单）
   - 同域读取 /stats.json（下载统计 + 码云镜像现状快照），统计部分再用实时接口刷新
   - 动态填充各端下载链接 / 版本号 / 更新日志
   - 清单与快照不可用时优雅降级（不显示假数字、不显示会 404 的链接）
   ========================================================= */
(function () {
  "use strict";

  // ⚠️ 2026-10-10 删除了一个 `var DOMAIN = "https://music.52ta.top"` —— 它
  // **全文件零使用**（死变量）。本站所有数据都走**相对路径**读取
  // （`/version.json` / `/stats.json`），所以站点天然与「托管在哪个源」无关：
  // 以后若做国内镜像（换域名 / 换主机），同一份代码直接可用，不必改这里。
  // 别把域名写回来 —— 硬编码会让镜像站读错源。

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
    // 与线上清单顶层 `changelog` **同形状**（真源见 `scripts/deploy_release.py`
    // 的 `load_changelog_history()`）。有它，预览态（清单未部署 / 拉取失败）
    // 也能看到新版更新日志的真实排版与筛选效果；只放两条 —— 这是兜底数据，
    // 不该伪装成完整历史。
    changelog: [
      { versionName: "1.0.0", date: "", notes: "吾爱音乐 1.0.0 首个正式版本。" },
      { versionName: "0.9.0", date: "", notes: "预览数据：清单未部署时显示这两条，用于确认排版。" },
    ],
  };

  // 码云（Gitee）国内镜像仓库。
  // 用 `/releases/download/latest/<文件名>` 形式指向**最新** Release：
  // 实测码云支持 latest（三渠道均 HTTP 200、体积与 GitHub 资产一致，不存在的文件名返回真 404），
  // 所以这里**不用写死版本号** —— 以后发新版，只要在码云传同样文件名的包，链接自动跟上。
  //
  // ⚠️ 这是一条**三方硬契约**，改任何一处都要同步改另两处：
  //      ① scripts/deploy_release.py   GITEE_* / gitee_mirror_url()  ← 唯一真源
  //                                    （清单里的 urlMirror 由它生成，即 App 的回退下载地址）
  //      ② scripts/deploy_gitee.py     ASSET_PRIMARY / ASSET_SECONDARY（上传名，import 自 ①）
  //      ③ 本文件                       GITEE_REPO / GITEE_ASSET_TPL（下面这两个）
  //    一致性由 scripts/deploy_selftest.py 断言；漂移不会报错，只会让按钮静默 404：
  //      app-<渠道>-release.apk        主包（arm64-v8a）
  //      app-<渠道>-release-v7a.apk    32 位包（armeabi-v7a）
  var GITEE_REPO = "https://gitee.com/jinghe-net/wuai-music";
  var GITEE_ASSET_TPL = {
    primary: "app-%s-release.apk",
    v7a: "app-%s-release-v7a.apk"
  };
  function giteeUrl(flavor, kind) {
    var tpl = GITEE_ASSET_TPL[kind || "primary"];
    return tpl && flavor
      ? GITEE_REPO + "/releases/download/latest/" + tpl.replace("%s", flavor)
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

  // 文本转义：清单里的更新说明是 Markdown 风格的多行文本，插进 innerHTML 前必须转义。
  // 只转义不解析 —— 官网刻意不引入 Markdown 解析器，说明里本来就是纯文本 + `**粗体**`。
  function esc(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  }

  // ── 更新日志：全量历史 + 按设备类型筛选 ──────────────────────────────────
  //
  // 【为什么要筛】
  // `CHANGELOG.md` 是**全项目一份**（三端共用同一份版本记录），而清单里每个
  // 渠道各有一条 `notes`。改前这里直接「按渠道列三块最新说明」—— 三块内容
  // 一模一样，看起来像页面坏了。
  //
  // 现在改成一份**按版本排列**的历史列表（清单顶层 `changelog`，由
  // `scripts/deploy_release.py` 从 CHANGELOG.md 全量解析产出），上面加一排
  // 设备类型筛选项。选中某端时：只显示「不晚于该端当前版本」的条目，
  // 并标出**该端的构建号**（三端构建号各自递增，这是筛选项真正带来的信息）。
  //
  // ⚠️ 清单没有 `changelog`（老清单 / 老服务器）时**退回改前的行为**
  //    （按渠道列 notes），保证这一块永远不会变空。

  /** 当前选中的设备类型：`"all"` 或渠道名 */
  var logFilter = "all";

  /** 筛选项（顺序即展示顺序） */
  var LOG_FILTERS = [
    { key: "all", label: "全部" },
    { key: "phone", label: "手机" },
    { key: "hd", label: "HD · 车机" },
    { key: "tv", label: "电视" }
  ];

  /** 版本号 → 数字段数组；解析不出来返回 [] */
  function parseVer(v) {
    var s = String(v == null ? "" : v).trim().replace(/^v/i, "");
    if (!s) return [];
    var out = [];
    var segs = s.split(".");
    for (var i = 0; i < segs.length; i++) {
      var m = /^\d+/.exec(segs[i]);
      if (!m) break;              // 某段没有数字 ⇒ 到此为止，不猜
      out.push(parseInt(m[0], 10));
    }
    return out;
  }

  /** 数字段逐个比较：<0 / 0 / >0。缺的段按 0 补（`1.1` == `1.1.0`）。
   *  ⚠️ 绝不能用字符串比较 —— `"1.0.10" < "1.0.9"` 在字符串序里成立，
   *     会把真正的升级判成降级，整段历史被裁掉。 */
  function cmpVer(a, b) {
    var n = Math.max(a.length, b.length);
    for (var i = 0; i < n; i++) {
      var x = i < a.length ? a[i] : 0;
      var y = i < b.length ? b[i] : 0;
      if (x !== y) return x < y ? -1 : 1;
    }
    return 0;
  }

  /** 清单顶层 `changelog` → 规范化条目（新 → 旧）。
   *  形状不对 / 某条缺版本号或缺说明一律跳过：老清单没有这个键，
   *  **不能**因此让整个「更新中心」挂掉。 */
  function changelogEntries(manifest) {
    var raw = manifest && manifest.changelog;
    if (!Array.isArray(raw)) return [];
    var out = [];
    raw.forEach(function (e) {
      if (!e || typeof e !== "object") return;
      var v = String(e.versionName || "").trim();
      var notes = String(e.notes || "").trim();
      if (!v || !notes) return;
      out.push({ versionName: v, date: String(e.date || "").trim(), notes: notes });
    });
    out.sort(function (a, b) { return cmpVer(parseVer(b.versionName), parseVer(a.versionName)); });
    return out;
  }

  /** 某渠道在该版本上的构建号；不是该渠道的当前版本则返回 null */
  function buildOf(manifest, flavor, versionName) {
    var rel = getRelease(manifest, flavor);
    if (!rel || String(rel.versionName || "") !== String(versionName)) return null;
    return rel.versionCode || null;
  }

  /** 把一条更新说明渲染成列表。
   *
   *  `notes` 的真源是 `CHANGELOG.md` 里 `notes:begin/end` 之间那段 —— 逐行
   *  `- **标题**：说明`。改前整段 `esc()` 后塞进一个 `<p>`：行首的 `-` 与
   *  包标题的 `**` 都会**原样显示**，一屏看下来像没渲染完的源码。
   *  现在按行拆成 `<li>`，并还原标题加粗。
   *
   *  ⚠️ 顺序不能反：先 `esc()` 整行，再把 `**…**` 换成 `<strong>`。
   *  反过来等于把清单里的内容（它来自仓库文件与远端 JSON）当 HTML 执行。
   */
  function notesHtml(notes) {
    var items = [];
    String(notes || "").split("\n").forEach(function (ln) {
      var t = ln.trim().replace(/^[-*]\s+/, "");
      if (!t) return;
      items.push(
        "<li>" + esc(t).replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>") + "</li>"
      );
    });
    if (!items.length) return "";
    return '<ul class="ci-list">' + items.join("") + "</ul>";
  }

  /** 渲染筛选按钮行 */
  function renderLogFilter(manifest) {
    var box = $("#changelogFilter");
    if (!box) return;
    box.innerHTML = "";
    LOG_FILTERS.forEach(function (opt) {
      var b = document.createElement("button");
      b.type = "button";
      b.className = "logfilter__chip" + (logFilter === opt.key ? " is-active" : "");
      b.textContent = opt.label;
      b.setAttribute("aria-pressed", logFilter === opt.key ? "true" : "false");
      b.addEventListener("click", function () {
        if (logFilter === opt.key) return;
        logFilter = opt.key;
        renderLogFilter(manifest);
        renderChangelog(manifest);
      });
      box.appendChild(b);
    });
  }

  /** 渲染更新日志列表（已按当前筛选项过滤） */
  function renderChangelog(manifest) {
    var logEl = $("#changelog");
    if (!logEl) return;

    var entries = changelogEntries(manifest);
    if (!entries.length) {
      // 兜底：老清单没有 `changelog` ⇒ 退回「按渠道列 notes」（改前的行为）。
      // 条目自带渠道，过滤时按渠道筛。
      SITE_FLAVORS.forEach(function (f) {
        var rel = getRelease(manifest, f);
        if (!rel) return;
        var notes = String(rel.notes || "").trim();
        if (!notes) return;
        entries.push({
          versionName: String(rel.versionName || ""),
          date: "",
          notes: notes,
          legacyFlavor: f
        });
      });
      if (!entries.length) {
        logEl.innerHTML = '<p class="changelog__empty">暂无更新记录。</p>';
        return;
      }
    }

    var shown = entries;
    if (logFilter !== "all") {
      var rel = getRelease(manifest, logFilter);
      var cur = rel ? parseVer(rel.versionName) : [];
      var filtered = entries.filter(function (e) {
        // 兜底路径的条目自带渠道，直接按渠道筛
        if (e.legacyFlavor) return e.legacyFlavor === logFilter;
        // 历史条目是全项目共用的：只留「不晚于该端当前版本」的
        if (!cur.length) return true;
        var v = parseVer(e.versionName);
        return v.length === 0 || cmpVer(v, cur) <= 0;
      });
      // 一条都没留下时不硬筛（版本号解析不出来 / 清单版本比历史都新）——
      // 空列表比「多显示几条」糟得多。
      if (filtered.length) shown = filtered;
    }

    logEl.innerHTML = "";
    shown.forEach(function (e) {
      var item = document.createElement("div");
      item.className = "changelog__item";

      var chips = [];
      if (e.legacyFlavor) {
        chips.push('<span class="ci-chip">' + esc(FLAVOR_LABEL[e.legacyFlavor] || e.legacyFlavor) + "</span>");
      } else {
        var targets = logFilter === "all" ? SITE_FLAVORS : [logFilter];
        targets.forEach(function (f) {
          var code = buildOf(manifest, f, e.versionName);
          if (code) {
            chips.push('<span class="ci-chip">' + esc(FLAVOR_LABEL[f] || f) + " build " + code + "</span>");
          }
        });
      }

      item.innerHTML =
        '<div class="ci-head">' +
          '<span class="ci-ver">v' + esc(e.versionName) + "</span>" +
          '<span class="ci-meta">' +
            (e.date ? '<span class="ci-date">' + esc(e.date) + "</span>" : "") +
            chips.join("") +
          "</span>" +
        "</div>" +
        notesHtml(e.notes);
      logEl.appendChild(item);
    });
  }

  // 主下载按钮下方渲染「其它架构」的独立包链接
  //   ① 国际（GitHub）：清单 variants 里除顶层兜底包之外的架构
  //   ② 国内（码云）：32 位包 —— **只在码云上真的有这个附件时才出现**
  // 码云没有 GitHub 那种"按本机 ABI 自动分发"的 variants，页面只能摆链接让用户自己选；
  // 而"本地构建出了 v7a" ≠ "已经传到码云"，点了 404 比不显示更糟 ⇒ 由 /stats.json
  // 里发布时探测的 mirrors（真实存在性与体积）决定，不靠猜。
  var lastManifest = null;
  var mirrorState = null;      // { flavor: { primary: {size}, v7a: {size} } }

  function renderAlts(flavor) {
    var box = document.querySelector('.platform__alts[data-alts="' + flavor + '"]');
    if (!box) return;
    var rel = getRelease(lastManifest, flavor);
    var variants = (rel && rel.variants) || {};
    // 主按钮指向的那一份（顶层兜底包，通常是 arm64）不在这里再列一遍：
    // 清单里顶层 url 与 variants 里的 arm64 是同一个文件。
    var keys = variantKeys(rel).filter(function (k) {
      return variants[k].url !== (rel && rel.url);
    });

    var html = "";
    if (keys.length) {
      // 标签与它的链接包成一组：卡片窄，不包的话「标签留在上一行、链接掉到下一行」
      html += '<span class="alts__group"><span class="alts__label">其它架构</span>';
      keys.forEach(function (k) {
        var v = variants[k];
        var s = sizeLabel(v.size);
        html += '<a class="alts__link" href="' + attr(v.url) + '">' +
                k + (s ? " · " + s : "") + "</a>";
      });
      html += "</span>";
    }

    var m = mirrorState && mirrorState[flavor] && mirrorState[flavor].v7a;
    if (m && m.size > 0) {
      // 故意**不加 data-flavor**：initMirrors() 会挑 .mirror-link[data-flavor] 填主包直链，
      // 加上就会把这条 32 位包的链接覆盖成主包。
      html += '<span class="alts__group alts__group--mirror">' +
              '<span class="alts__label">国内镜像</span>' +
              '<a class="alts__link mirror-link" href="' +
              attr(giteeUrl(flavor, "v7a")) + '">32 位包 · ' +
              sizeLabel(m.size) + "</a></span>";
    }

    box.innerHTML = html;
    box.hidden = !html;
  }

  // 把清单渲染到页面
  function render(manifest, live) {
    lastManifest = manifest;        // renderAlts 要用（快照后到时会再触发一次刷新）
    var statusEl = $("#updateStatus");
    var statusText = $("#updateStatusText");
    var latestEl = $("#updateLatest");
    var tableEl = $("#versionTable");
    // 注意：`#changelog` 由 renderChangelog() 自己取，这里不要再留一个局部变量 ——
    // 那是改前遗留的，删掉逻辑后就成了没人读的死变量。

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

    // 各端的「其它架构 / 国内镜像 32 位包」（分别由清单与快照决定是否显示）
    SITE_FLAVORS.forEach(function (f) { renderAlts(f); });

    // ── Windows 桌面版 ──────────────────────────────────────────────
    // 安装包是 `WuAiMusic-<ver>-setup.exe`，**文件名带版本号**，所以套不进
    // `releases/download/latest/<固定文件名>` 那套机制 —— 版本号必须现拼。
    // 版本号取 hd：两者是同一次 pubspec 构建出的产物（见 scripts/build_all.sh），
    // 清单里没有独立的 windows 渠道，也不该有（它不参与 APK 的 OTA 分发）。
    (function fillWindows() {
      var card = $('.platform[data-flavor="windows"]');
      if (!card) return;
      var hdRel = getRelease(manifest, "hd");
      var ver = hdRel && hdRel.versionName;
      var verEl = $("[data-ver]", card);
      if (verEl) verEl.textContent = "v" + (ver || "—");
      if (!ver) return;
      var file = "WuAiMusic-" + ver + "-setup.exe";
      var dl = $(".win-download", card);
      if (dl) {
        dl.setAttribute("href", "https://github.com/jim-6688/wuai-music/releases/download/v" +
          ver + "/" + file);
      }
      var mirror = $(".win-mirror", card);
      if (mirror) mirror.setAttribute("href", GITEE_REPO + "/releases/download/latest/" + file);
    })();

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

    // 更新日志（全量历史 + 按设备类型筛选，见 renderChangelog）
    renderLogFilter(manifest);
    renderChangelog(manifest);

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
        // ⚠️ 顶层 changelog（全量更新历史）**必须显式透传**：上面是从零新建的
        // 规整对象，只认 releases / minRequiredCode。漏了这一句，`changelog`
        // 就在这一层被静默丢掉 —— 症状是更新日志永远退回「按渠道列三条相同
        // 的 notes」兜底分支，看起来像筛选功能没做（页面不报任何错）。
        // 形状校验交给 changelogEntries()，这里原样透传即可。
        if (json.changelog != null) manifest.changelog = json.changelog;
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

  // 统一带超时：这几个实时刷新接口都在境外（api.github.com / countapi），
  // 部分地区会长时间挂起。没有超时的话请求会一直吊着 —— 虽然都不阻塞渲染，
  // 但会占着连接、让统计块迟迟无法落定。超时后走各自的 .catch 静默降级，
  // 页面继续用 /stats.json 的快照值（拿不到就隐藏整块，不显示假数字）。
  var FETCH_TIMEOUT_MS = 6000;

  function fetchJson(url) {
    var ctrl = (typeof AbortController === "function") ? new AbortController() : null;
    var opts = { cache: "no-cache" };
    var timer = null;
    if (ctrl) {
      opts.signal = ctrl.signal;
      timer = setTimeout(function () { ctrl.abort(); }, FETCH_TIMEOUT_MS);
    }
    function done() { if (timer) { clearTimeout(timer); timer = null; } }
    return fetch(url, opts).then(function (r) {
      done();
      if (!r.ok) throw new Error("HTTP " + r.status);
      return r.json();
    }, function (e) {
      done();
      throw e;
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

  // 快照：一次读 /stats.json，两处消费 —— ① 下载数字垫底 ② 码云镜像现状。
  // 拿不到就静默放弃：统计块保持隐藏、32 位包入口不显示（都不显示假的）。
  function initSnapshot() {
    fetchJson("/stats.json")
      .then(function (s) {
        if (!s) return;
        if (typeof s.githubDownloads === "number") dlState.github = s.githubDownloads;
        if (typeof s.siteClicks === "number") dlState.site = s.siteClicks;
        paintDownloads();

        var g = s.mirrors && s.mirrors.gitee;
        if (g) {
          mirrorState = g;
          SITE_FLAVORS.forEach(function (f) { renderAlts(f); });
        }
      })
      .catch(function () {});
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

  function initTvGallery() {
    var roots = Array.prototype.slice.call(document.querySelectorAll("[data-tv-gallery], [data-phone-gallery]"));
    roots.forEach(function (root) {
      var slides = Array.prototype.slice.call(root.querySelectorAll(".tv-gallery__slide"));
      if (slides.length < 2) return;
      var dotsWrap = root.querySelector(".tv-gallery__dots");
      var prevBtn = root.querySelector(".tv-gallery__nav--prev");
      var nextBtn = root.querySelector(".tv-gallery__nav--next");
      var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
      var DELAY = 4500;
      var idx = 0, timer = null;

      var dots = slides.map(function (s, i) {
        var b = document.createElement("button");
        b.type = "button";
        b.className = "tv-gallery__dot" + (i === 0 ? " is-active" : "");
        b.setAttribute("role", "tab");
        b.setAttribute("aria-label", "第 " + (i + 1) + " 张，共 " + slides.length + " 张");
        b.addEventListener("click", function () { show(i); restart(); });
        dotsWrap.appendChild(b);
        return b;
      });

      function show(n) {
        idx = (n + slides.length) % slides.length;
        slides.forEach(function (s, i) {
          var on = i === idx;
          s.classList.toggle("is-active", on);
          s.setAttribute("aria-hidden", on ? "false" : "true");
        });
        dots.forEach(function (d, i) { d.classList.toggle("is-active", i === idx); });
      }
      function next() { show(idx + 1); }
      function prev() { show(idx - 1); }
      function start() { if (!reduce && !timer) timer = window.setInterval(next, DELAY); }
      function stop() { if (timer) { window.clearInterval(timer); timer = null; } }
      function restart() { stop(); start(); }

      if (prevBtn) prevBtn.addEventListener("click", function () { prev(); restart(); });
      if (nextBtn) nextBtn.addEventListener("click", function () { next(); restart(); });
      root.addEventListener("mouseenter", stop);
      root.addEventListener("mouseleave", start);
      root.addEventListener("focusin", stop);
      root.addEventListener("focusout", start);
      root.setAttribute("tabindex", "0");
      root.addEventListener("keydown", function (e) {
        if (e.key === "ArrowLeft") { prev(); restart(); }
        else if (e.key === "ArrowRight") { next(); restart(); }
      });

      show(0);
      start();
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    initTheme();
    initNav();
    initReveal();
    initYear();
    initMirrors();
    fetchManifest();
    initSnapshot();
    initDownloads();
    initTvGallery();
  });
})();
