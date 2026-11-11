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
    windows: "Windows 版",
  };

  // 站点展示顺序：手机 / 车机平板(hd) / 电视
  var SITE_FLAVORS = ["phone", "hd", "tv"];

  // 兜底清单：清单未部署时站点仍可完整呈现（下载按钮置为“敬请期待”）
  var FALLBACK = {
    releases: {
      phone: { versionName: "1.5.1", versionCode: 73, flavor: "phone", notes: "吾爱音乐 1.5.1 版本。", url: "", size: 0, sha256: "" },
      hd: { versionName: "1.5.1", versionCode: 73, flavor: "hd", notes: "吾爱音乐 1.5.1 版本（车机/平板）。", url: "", size: 0, sha256: "" },
      tv: { versionName: "1.5.1", versionCode: 73, flavor: "tv", notes: "吾爱音乐 1.5.1 版本（电视）。", url: "", size: 0, sha256: "" },
    },
    minRequiredCode: { phone: 1, hd: 1, tv: 1 },
    // 与线上清单顶层 `changelog` **同形状**（真源见 `scripts/deploy_release.py`
    // 的 `load_changelog_history()`）。有它，预览态（清单未部署 / 拉取失败）
    // 也能看到新版更新日志的真实排版与筛选效果；只放两条 —— 这是兜底数据，
    // 不该伪装成完整历史。
    changelog: [
      { versionName: "1.5.1", date: "", notes: "吾爱音乐 1.5.1 版本。" },
      { versionName: "1.5.0", date: "", notes: "预览数据：清单未部署时显示这两条，用于确认排版。" },
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

  // ── 多吉云（https://download.52ta.top）第三条下载链路 ──────────────────
  //
  // 与另两条链路最大的不同：**文件名就是 dist/ 里的产物原名**，不是
  // `app-<渠道>-release.apk` 那种固定名 —— 多吉云上是按构建产物原名上传的：
  //     Android  wuai-music-<版本>+<构建号>-<渠道>-<ABI>-release.apk
  //     Windows  WuAiMusic-<版本>-setup.exe
  // 名字里带版本号与构建号 ⇒ **没法用 latest 之类免版本号的形式**，只能逐版写死。
  // 所以这里按渠道列一张表：表里有哪个渠道，那个渠道才显示按钮。
  //
  // ⚠️ 发新版时必须回来改这张表（每端换文件名）—— 这是整条链路唯一的手工步骤。
  //    漏改的症状是「按钮还在、点开 404」，所以每次改完跑一遍：
  //        python scripts/probe_duoji_assets.py
  //    它会真的 HEAD 一遍每个已配置的地址（表里写了但文件没传，立刻报红）。
  //
  // ⚠️ 另一个坑：文件名里的 `+` 必须编码成 `%2B`。所以 URL 一律用
  //    encodeURIComponent 拼，不能字符串直接相加（`+` 在部分网关会被解成空格 ⇒ 404）。
  var DUOJI_BASE = "https://download.52ta.top/";

  // 已上传到多吉云的包（只有列在这里的渠道才会显示按钮）。
  // 每端可放**主包**一个字符串，或 [主包, 32位包, ...] 数组（主包之外的会
  // 克隆出「32 位」按钮）。文件名里的 `+` 在 duojiUrlFor 里被 encodeURIComponent
  // 编成 %2B（部分网关把裸 `+` 解成空格 ⇒ 404）。
  //
  // ⚠️ 数组顺序 = 按钮顺序，**第一个必须是 64 位包（arm64-v8a）**：官网把首位
  //    做成金色主按钮（绝大多数机型是 arm64），32 位只给较早的纯 32 位设备兜底。
  //    数组里有几个文件，官网就渲染几个按钮，文字按 ABI 自动标「64 位 / 32 位」。
  var DUOJI_FILES = {
    phone: [
      "wuai-music-2.1.0+118-phone-arm64-v8a-release.apk",
      "wuai-music-2.1.0+118-phone-armeabi-v7a-release.apk",
    ],
    hd: [
      "wuai-music-2.1.0+118-hd-arm64-v8a-release.apk",
      "wuai-music-2.1.0+118-hd-armeabi-v7a-release.apk",
    ],
    tv: [
      "wuai-music-2.1.0+118-tv-arm64-v8a-release.apk",
      "wuai-music-2.1.0+118-tv-armeabi-v7a-release.apk",
    ],
    windows: "WuAiMusic-2.1.0-setup.exe",
  };

  /** 某渠道在 DUOJI_FILES 里的文件列表（统一成数组便于处理） */
  function duojiFiles(flavor) {
    var f = DUOJI_FILES[flavor];
    if (!f) return [];
    return Array.isArray(f) ? f : [f];
  }

  /** 单个文件名 → 多吉云直链（空串或没配时返回 ""） */
  function duojiUrlFor(file) {
    if (!DUOJI_BASE || !file) return "";
    return DUOJI_BASE.replace(/\/+$/, "") + "/" + encodeURIComponent(file);
  }

  // 包名里的 ABI 段 → 人话。官网只区分 64 / 32 位这两种，其它架构返回 ""。
  //   形如 wuai-music-1.5.1+73-phone-arm64-v8a-release.apk
  function abiLabel(file) {
    var f = (file || "").toLowerCase();
    if (f.indexOf("arm64-v8a") >= 0) return "64 位";
    if (f.indexOf("armeabi-v7a") >= 0) return "32 位";
    return "";
  }

  /** 揭开**已配置**渠道的按钮与说明文字；一个都没配时全部保持收起 */
  function initDuoji() {
    var shown = 0;

    // ⚠️ 幂等：这个函数可能被重复调用（浏览器只会触发一次 DOMContentLoaded，
    //    但测试环境 / 某些 WebView 会再派发一次），而「克隆架构按钮」是**追加**
    //    操作 —— 不先摘下上一轮的克隆，调两次就变成两个「32 位」按钮。
    $all(".duoji-link[data-duoji-extra]").forEach(function (n) {
      if (n.parentNode) n.parentNode.removeChild(n);
    });
    $all(".platform__btns.is-abi-split").forEach(function (n) {
      n.classList.remove("is-abi-split");
    });

    $all(".duoji-link[data-flavor]").forEach(function (a) {
      var flavor = a.getAttribute("data-flavor");
      var files = duojiFiles(flavor);
      if (!files.length) return;          // 没传 = 不显示，绝不留死链

      // 一个渠道可能有多个架构的包（64 位 + 32 位）。HTML 里只写一个占位按钮，
      // 其余就地克隆接在后面 —— 多架构由配置表决定，不必在四张卡里各写两遍。
      var prev = null;
      files.forEach(function (file, i) {
        var btn = (i === 0) ? a : a.cloneNode(true);
        if (i > 0) {
          btn.removeAttribute("data-flavor");      // 防止被再次选中
          btn.setAttribute("data-duoji-extra", "1"); // 下一轮幂等清理的标记
          btn.classList.remove("btn--gold");
          btn.classList.add("btn--gold-line");     // 32 位用金色描边：弱化但不丢可点性
          a.parentNode.insertBefore(btn, prev.nextSibling);
        }
        var abi = abiLabel(file);
        var hint = abi === "64 位" ? "arm64-v8a，适配绝大多数机型"
                 : abi === "32 位" ? "armeabi-v7a，仅供较早的纯 32 位设备"
                 : "";
        btn.textContent = "多吉云 · " + (abi || "下载");
        btn.setAttribute("href", duojiUrlFor(file));
        if (hint) btn.title = "多吉云高速下载（" + hint + "）";
        btn.hidden = false;
        prev = btn;
        shown++;
      });

      // 两个以上（多架构）⇒ 按钮改并排半宽，否则整行独占（见 style.css）
      if (files.length > 1) a.parentNode.classList.add("is-abi-split");
    });
    // Windows 卡没挂 data-flavor（它跟 APK 不是同一套版本规则），单独取主包
    var win = $(".duoji-win");
    if (win) {
      var winUrl = duojiUrlFor(DUOJI_FILES.windows);
      if (winUrl) {
        win.setAttribute("href", winUrl);
        win.title = "多吉云高速下载（Windows 安装包）";
        win.hidden = false;
        shown++;
      }
    }
    if (shown) {
      var note = $("[data-duoji-note]");
      if (note) note.hidden = false;
    }
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

  // 更新日志会随每次发版一直增长（现在 52 条 ≈ 11000px）。默认只铺开最近
  // LOG_PREVIEW 条，其余折起来 —— 否则访客要滚过一万多像素才能到下一节。
  /** 默认展示的历史条数 */
  var LOG_PREVIEW = 10;
  /** 用户是否点过「查看全部」（切筛选时保持展开） */
  var logExpanded = false;

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

    // 折叠只改 CSS，不减少 DOM 节点：scripts/check_site_dom.js 的 F 组按
    // `.changelog__item` 的**个数**与顺序断言，真少渲染会让那组变红。
    if (!logExpanded && shown.length > LOG_PREVIEW) {
      [].slice.call(logEl.children, LOG_PREVIEW).forEach(function (el) {
        el.classList.add("is-folded");
      });
      var more = document.createElement("button");
      more.type = "button";
      more.className = "changelog__more";
      more.textContent = "查看全部 " + shown.length + " 个版本";
      more.setAttribute("aria-expanded", "false");
      more.addEventListener("click", function () {
        logExpanded = true;
        [].forEach.call(logEl.querySelectorAll(".changelog__item.is-folded"), function (el) {
          el.classList.remove("is-folded");
        });
        more.setAttribute("aria-expanded", "true");
        if (more.parentNode) more.parentNode.removeChild(more);
      });
      logEl.appendChild(more);
    }
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
        // 首屏下载条对应端也同步显示版本号（见 .hdev__ver）
        var heroVer = $('.hdev[data-flavor="' + flavor + '"] [data-ver]');
        if (heroVer) heroVer.textContent = "v" + (rel.versionName || "—");
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
      var heroWin = $('.hdev[data-flavor="windows"] [data-ver]');
      if (heroWin) heroWin.textContent = "v" + (ver || "—");
      if (!ver) return;
      var file = "WuAiMusic-" + ver + "-setup.exe";
      var dl = $(".win-download", card);
      if (dl) {
        dl.setAttribute("href", "https://github.com/jim-6688/wuai-music/releases/download/v" +
          ver + "/" + file);
      }
      var mirror = $(".win-mirror", card);
      if (mirror) mirror.setAttribute("href", GITEE_REPO + "/releases/download/latest/" + file);
      // ⚠️ 多吉云那颗按钮**不在这里填** —— 它的文件名是多吉云上的实际上传名
      //    （`WuAiMusic-<版本>-setup.exe`，版本号以发布时为准，未必等于清单里的
      //    hd 版本），统一由 initDuoji() 按 DUOJI_FILES 表处理。
      //    两边都写会互相覆盖，谁后跑谁生效 —— 那是排查起来最费劲的一类 bug。
    })();

    // 首屏下载条每个图标 → 对应平台主下载链接（卡片链接此时已填好）
    wireHeroDownloads();

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
    // ⚠️ 阈值必须是 0，不能用比例阈值。原本写的是 threshold: 0.12，
    // 但「更新中心」这类容器会随更新日志增长 —— 52 个版本把面板撑到 11000px 高，
    // 在 1080px 视口里最多只能露出 9.7% < 12% ⇒ 永远不触发，
    // 整块停在 opacity: 0，用户看到的就是「更新中心是空的」。
    // 用 rootMargin 把视口下沿抬高 10% 来达到「进来一点再淡入」的效果，
    // 这个判据与元素自身高度无关，再高的容器也能触发。
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add("is-visible"); io.unobserve(e.target); }
      });
    }, { threshold: 0, rootMargin: "0px 0px -10% 0px" });
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

  // ── 设备类型识别 + 首屏下载推荐 ──────────────────────────────────────
  //
  // 用户打开官网首屏时，按 UA / 平台识别当前设备，高亮对应平台卡片与
  // 首屏下载按钮，并给出「适合当前设备」的提示。识别不到（如 Linux 桌面、
  // iOS / macOS 暂无客户端）时降级为「请选择平台」，不强行命中。
  //
  // ⚠️ 这是**纯前端启发式**，只影响高亮与文案，不影响下载链路本身：
  //    所有下载链接仍由 version.json / 码云 latest 决定，识别错了也顶多
  //    高亮偏了，不会给出 404 或错误包。
  function detectDevice() {
    var ua = (navigator.userAgent || "").toLowerCase();
    var plat = (navigator.platform || "").toLowerCase();

    // UA-CH（Chromium 的 Client Hints）。`mobile` 只当**正向**信号用：
    // 手机开「请求桌面版网站」时 Chrome 会把 Sec-CH-UA-Mobile 置 0 ⇒ 这时
    // mobile === false 并不代表设备是平板，拿它判 hd 又会把手机判错。
    var ch = navigator.userAgentData || null;
    var chPlat = (ch && ch.platform) ? String(ch.platform).toLowerCase() : "";
    var chMobile = (ch && typeof ch.mobile === "boolean") ? ch.mobile : null;

    // Android 判定：UA 带 android，**或** UA-CH 报 Android。
    // 两条都看的原因是桌面模式会把 UA 换成桌面 UA（丢掉 android 字样），
    // 但 UA-CH 的 platform 依旧如实报 Android。
    var isAndroid = /android/i.test(ua) || chPlat === "android";

    // ⚠️ Android 分支**必须排在 Windows 嗅探之前**：部分 Android WebView
    //    在「桌面模式」下会把 navigator.platform 报成 `Win32`，先判 Win
    //    就会把手机认成 PC 版。
    if (isAndroid) {
      // 电视 / 盒子：只认 UA。UA-CH 看不出 TV（它们 platform 也是 Android、
      // mobile=false，会掉进 hd），所以这条必须排在所有手机/平板判定之前。
      if (/(tv|googletv|google tv|firetv|fire tv|mibox|mi box|shield|androidsdk|ehome|crkey|opera tv|tizen|web0s|viera|smarttv|hbbtv)/i.test(ua)) return "tv";

      // ── 手机 vs 平板/车机：**先看 UA / UA-CH，最后才看屏幕尺寸** ──────────
      // ⚠️ 老实现「视口短边 ≥600 就当平板」把手机判成了平板。根因是它量的是
      //    `innerWidth`（布局视口）：桌面模式、部分国产浏览器、忽略 viewport
      //    meta 的内嵌 WebView 都会把它撑到 980 上下，短边立刻过 600。
      //    而 Android 的约定很干净 —— **手机 UA 里必有 Mobile，平板没有**，
      //    Chromium 还额外给出 UA-CH 的 `mobile`。所以按可信度排序：
      //      ① UA 里显式的平板型号（tablet / pad / sm-t…）
      //      ② UA-CH `mobile === true`（受 UA 精简影响最小）
      //      ③ UA 的 Mobile 标记
      //      ④ 兜底才量**屏幕**短边（screen 是硬件尺寸，不随缩放 / 桌面模式漂移），
      //         按 Android 自己的 sw600dp 定义：短边 ≥600 视为平板。
      //    这样手机在任何浏览器 / 缩放 / 桌面模式下都稳定判成 phone。
      if (/(tablet|\bpad\b|sm-t\d|kftt|kfthwi|gt-p\d|sch-i\d)/i.test(ua)) return "hd";

      if (chMobile === true) return "phone";
      if (/mobile/i.test(ua)) return "phone";

      var sw = (window.screen && window.screen.width) || 0;
      var sh = (window.screen && window.screen.height) || 0;
      return (sw && sh && Math.min(sw, sh) >= 600) ? "hd" : "phone";
    }

    if (chPlat === "windows" || /windows nt/i.test(ua) || /win/i.test(plat)) return "windows";
    // iOS / macOS 暂无客户端：返回 apple 让文案单独提示，不命中任何端
    if (chPlat === "macos" || /iphone|ipad|ipod|macintosh|mac os x/i.test(ua)) return "apple";
    return null;   // 桌面 Linux / 其它：不强行匹配
  }

  // 首屏主图：每个端一张「当前版本」实拍，键名 = 平台 data-flavor。
  // ⚠️ 只换 src / 标题 / 宽高属性，**不改 DOM 结构** —— 框体形态由 CSS 按
  //    `[data-flavor]` 决定：手机是竖图，走窄机身；其余三端共用窗口框。
  // ⚠️ 换图时宽高属性必须跟着改（不然首屏会按旧比例先占位再跳一下）。
  var HERO_SHOTS = {
    phone: {
      src: "assets/img/phone/phone-03.webp", w: 1080, h: 2376,
      title: "吾爱Music · 手机端",
      alt: "吾爱音乐手机端界面：黑胶唱片、实时歌词与播放控制",
    },
    hd: {
      src: "assets/img/car/car-03.webp", w: 1591, h: 1439,
      title: "吾爱Music · 车机 / 平板",
      alt: "吾爱音乐车机 / 平板界面：横屏三栏与正在播放",
    },
    tv: {
      src: "assets/img/tv/tv-04-nowplaying.webp", w: 1920, h: 1080,
      title: "吾爱Music · 电视端",
      alt: "吾爱音乐电视端界面：大字号焦点与正在播放",
    },
    windows: {
      src: "assets/img/windows/win-01.webp", w: 1600, h: 900,
      title: "吾爱Music · Windows 桌面版",
      alt: "吾爱音乐 Windows 桌面版界面（矢车菊蓝主题）：本地音乐库，文件管理器侧栏、专辑墙与 609 首全部歌曲、右侧收藏与最近播放、底部播放条",
    },
  };

  // 首屏主图跟随识别结果。识别不到（桌面 Linux）或 apple 时回落 Windows ——
  // 与改造前一致，不留空图（静态 HTML 的兜底也是它）。
  function applyHeroShot(d) {
    var fig = $("#heroShot");
    if (!fig) return;
    var key = HERO_SHOTS[d] ? d : "windows";
    var shot = HERO_SHOTS[key];
    fig.setAttribute("data-flavor", key);

    var img = $("#heroShotImg", fig);
    if (img) {
      // 同端重复调用时不重设 src：避免浏览器把已加载的图再下一次
      var cur = img.getAttribute("src") || "";
      if (cur.indexOf(shot.src) < 0) img.setAttribute("src", shot.src);
      img.setAttribute("width", shot.w);
      img.setAttribute("height", shot.h);
      img.setAttribute("alt", shot.alt);
    }
    var title = $("#heroShotTitle", fig);
    if (title) title.textContent = shot.title;
  }

  // 把识别结果落到首屏下载条 + 平台卡片上（纯视图层，不碰下载链接）
  function applyDeviceHighlight() {
    var d = detectDevice();

    // 首屏主图换成当前端的实拍
    applyHeroShot(d);

    // 首屏下载条：高亮命中的端
    $all(".hdev").forEach(function (el) {
      el.classList.toggle("is-current", el.getAttribute("data-flavor") === d);
    });

    // 平台卡片：命中端加 is-current + 显示「适合当前设备」角标
    $all(".platform").forEach(function (card) {
      var on = card.getAttribute("data-flavor") === d;
      card.classList.toggle("is-current", on);
      var ribbon = $(".platform__current", card);
      if (ribbon) ribbon.hidden = !on;
    });

    // 文案
    var label = $("#heroDeviceLabel");
    if (label) {
      if (d === "apple") {
        label.innerHTML = "暂未发布 iOS / macOS 版本，可选择下方 Android 或 Windows 版本";
      } else if (d) {
        label.innerHTML = "检测到你正在使用 <strong>" + (FLAVOR_LABEL[d] || d) +
          "</strong>，已为你推荐对应版本";
      } else {
        label.textContent = "选择你的平台下载";
      }
    }
  }

  // 首屏下载条每个图标 → 对应平台的**主**下载链接
  //   优先级：多吉云（主推，且配好 64 位直链时）→ 国内镜像（码云 latest）。
  //   多吉云按钮由 initDuoji 提前点亮（配置驱动），没配就自动退回国内镜像，
  //   所以这里只看「有没有可见的多吉云按钮」，不存在死链风险。
  function wireHeroDownloads() {
    $all(".hdev").forEach(function (el) {
      var f = el.getAttribute("data-flavor");
      var card = $('.platform[data-flavor="' + f + '"]');
      if (!card) return;
      var duoji = (f === "windows")
        ? $(".duoji-win", card)
        : $('.duoji-link[data-flavor="' + f + '"]', card);
      var primary = (duoji && !duoji.hidden && duoji.getAttribute("href"))
        ? duoji
        : ((f === "windows") ? $(".win-mirror", card)
                              : $('.mirror-link[data-flavor="' + f + '"]', card));
      if (primary) {
        var href = primary.getAttribute("href");
        if (href) el.setAttribute("href", href);
      }
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
  // 首选：同域边缘函数（EdgeOne 边缘节点 + KV）。一次请求同时拿到
  // 「本站点击」与「GitHub 总数」，不再跨国往返，也不再受第三方服务生死影响。
  var COUNT_LOCAL = "/api/downloads";
  // 降级：老的跨域第三方计数（边缘函数未部署 / KV 未绑定时仍能计数）
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

  function fetchJson(url, extra) {
    var ctrl = (typeof AbortController === "function") ? new AbortController() : null;
    var opts = { cache: "no-cache" };
    if (extra) {
      for (var k in extra) {
        if (Object.prototype.hasOwnProperty.call(extra, k)) opts[k] = extra[k];
      }
    }
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

    function settle(n) {
      dlState.site = n;
      try { localStorage.setItem(COUNTED_FLAG, "1"); } catch (e) {}
      paintDownloads();
    }

    // ① 同域边缘函数 +1
    fetchJson(COUNT_LOCAL, { method: "POST" })
      .then(function (d) {
        if (!d || !d.ok || typeof d.site !== "number") throw new Error("local");
        settle(d.site);
      })
      .catch(function () {
        // ② 降级：老第三方计数
        fetchJson(COUNT_API + "/hit/" + COUNT_KEY)
          .then(function (d) {
            if (!d || typeof d.value !== "number") return;
            settle(d.value);
          })
          .catch(function () { /* 计数失败不影响下载本身 */ });
      });
  }

  function initDownloads() {
    var box = $("#dlStats");
    if (!box) return;

    // ② 实时：优先同域边缘函数，一次拿齐两个数字。
    //    它内部已把 GitHub 总数缓存 10 分钟 —— 直接打 api.github.com 的话，
    //    匿名限额只有 60 次/小时/IP，国内访客共享出口 IP 时很容易整片失效。
    fetchJson(COUNT_LOCAL)
      .then(function (d) {
        if (!d || !d.ok) throw new Error("local_unavailable");
        return d;
      })
      .catch(function () {
        // ③ 降级：老的跨域链路，两路各取各的（一个挂了另一个还能成）
        var out = { site: null, github: null };
        return Promise.all([
          fetchJson(COUNT_API + "/get/" + COUNT_KEY)
            .then(function (d) {
              if (d && typeof d.value === "number") out.site = d.value;
            })
            .catch(function () {}),
          fetchJson(GH_RELEASES_API)
            .then(function (rels) {
              var n = sumGithubDownloads(rels);
              if (n !== null) out.github = n;
            })
            .catch(function () {}),
        ]).then(function () { return out; });
      })
      .then(function (d) {
        if (typeof d.site === "number") dlState.site = d.site;
        if (typeof d.github === "number") dlState.github = d.github;
        paintDownloads();
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
        // 多吉云两个类名：href 指向第三方云存储，不匹配下面的 /releases/ 正则，
        // 只能靠类名认 —— 否则这条链路点了不计入「本站下载」。
        a.classList.contains("duoji-link") ||
        a.classList.contains("duoji-win") ||
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

  // 深浅色主题切换（默认贝壳白，切换后记忆；不跟随系统偏好）
  function initTheme() {
    var KEY = "wuai-theme";
    var root = document.documentElement;
    var btn = $("#themeToggle");
    var SUN = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><circle cx="12" cy="12" r="4.6" fill="currentColor"/><g stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><line x1="12" y1="2.6" x2="12" y2="5"/><line x1="12" y1="19" x2="12" y2="21.4"/><line x1="2.6" y1="12" x2="5" y2="12"/><line x1="19" y1="12" x2="21.4" y2="12"/><line x1="4.9" y1="4.9" x2="6.7" y2="6.7"/><line x1="17.3" y1="17.3" x2="19.1" y2="19.1"/><line x1="4.9" y1="19.1" x2="6.7" y2="17.3"/><line x1="17.3" y1="6.7" x2="19.1" y2="4.9"/></g></svg>';
    var MOON = '<svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path d="M20 14.6A8 8 0 0 1 9.4 4a7 7 0 1 0 10.6 10.6z" fill="currentColor"/></svg>';

    function paint() {
      var t = root.getAttribute("data-theme") || "light";
      if (btn) {
        // 当前为浅色时显示月亮（点击切到深色），当前深色显示太阳
        btn.innerHTML = t === "light" ? MOON : SUN;
      }
      // 地址栏底色跟着站内主题走（与 <head> 里的首屏脚本同一套规则）
      var meta = document.querySelector('meta[name="theme-color"]');
      if (meta) meta.setAttribute("content", t === "dark" ? "#08090b" : "#f9f4f0");
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
    var roots = Array.prototype.slice.call(document.querySelectorAll("[data-tv-gallery], [data-phone-gallery], [data-car-gallery], [data-win-gallery]"));
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

  function initLightbox() {
    var lb = document.getElementById("shotLightbox");
    if (!lb) return;
    var track = document.getElementById("shotLightboxTrack");
    var dotsWrap = document.getElementById("shotLightboxDots");
    var navPrev = lb.querySelector(".shot-lightbox__nav--prev");
    var navNext = lb.querySelector(".shot-lightbox__nav--next");
    var closeBtn = lb.querySelector(".shot-lightbox__close");
    var reduce = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    var data = [], idx = 0, timer = null, DELAY = 4500;

    function show(n) {
      idx = (n + data.length) % data.length;
      var ss = track.children;
      for (var i = 0; i < ss.length; i++) {
        var on = i === idx;
        ss[i].classList.toggle("is-active", on);
        ss[i].setAttribute("aria-hidden", on ? "false" : "true");
      }
      var ds = dotsWrap.children;
      for (var j = 0; j < ds.length; j++) ds[j].classList.toggle("is-active", j === idx);
    }
    function next() { show(idx + 1); }
    function prev() { show(idx - 1); }
    function start() { if (!reduce && !timer) timer = window.setInterval(next, DELAY); }
    function stop() { if (timer) { window.clearInterval(timer); timer = null; } }
    function restart() { stop(); start(); }

    function build(src) {
      track.innerHTML = "";
      dotsWrap.innerHTML = "";
      data = src;
      src.forEach(function (d, i) {
        var fig = document.createElement("figure");
        fig.className = "tv-gallery__slide" + (i === 0 ? " is-active" : "");
        var img = document.createElement("img");
        img.src = d.src;
        img.alt = d.alt || "";
        img.decoding = "async";
        var fc = document.createElement("figcaption");
        fc.className = "tv-gallery__cap";
        fc.textContent = d.cap || "";
        fig.appendChild(img);
        fig.appendChild(fc);
        track.appendChild(fig);
        var b = document.createElement("button");
        b.type = "button";
        b.className = "tv-gallery__dot" + (i === 0 ? " is-active" : "");
        b.setAttribute("role", "tab");
        b.setAttribute("aria-label", "第 " + (i + 1) + " 张，共 " + src.length + " 张");
        b.addEventListener("click", function (e) { e.stopPropagation(); show(i); restart(); });
        dotsWrap.appendChild(b);
      });
    }

    function open(fig) {
      var g = fig.querySelector(".tv-gallery") || fig;
      var slides = Array.prototype.slice.call(g.querySelectorAll(".tv-gallery__slide"));
      var src = slides.map(function (s) {
        var im = s.querySelector("img");
        var cap = s.querySelector(".tv-gallery__cap");
        return {
          src: im ? im.getAttribute("src") : "",
          alt: im ? im.getAttribute("alt") : "",
          cap: cap ? cap.textContent : ""
        };
      });
      var cur = 0;
      slides.forEach(function (s, i) { if (s.classList.contains("is-active")) cur = i; });
      build(src);
      if (g.classList.contains("tv-gallery--portrait")) lb.classList.add("is-portrait");
      else lb.classList.remove("is-portrait");
      show(cur);
      lb.classList.add("is-open");
      lb.setAttribute("aria-hidden", "false");
      document.body.style.overflow = "hidden";
      start();
    }
    function close() {
      stop();
      lb.classList.remove("is-open");
      lb.setAttribute("aria-hidden", "true");
      document.body.style.overflow = "";
    }

    if (navPrev) navPrev.addEventListener("click", function (e) { e.stopPropagation(); prev(); restart(); });
    if (navNext) navNext.addEventListener("click", function (e) { e.stopPropagation(); next(); restart(); });
    if (closeBtn) closeBtn.addEventListener("click", function (e) { e.stopPropagation(); close(); });
    lb.addEventListener("click", function (e) { if (e.target === lb) close(); });
    document.addEventListener("keydown", function (e) {
      if (!lb.classList.contains("is-open")) return;
      if (e.key === "Escape") close();
      else if (e.key === "ArrowLeft") { prev(); restart(); }
      else if (e.key === "ArrowRight") { next(); restart(); }
    });

    Array.prototype.slice.call(document.querySelectorAll(".shot--gallery, [data-win-gallery]")).forEach(function (fig) {
      var frame = fig.querySelector(".shot__frame") || fig;
      frame.addEventListener("click", function () { open(fig); });
    });
  }

  document.addEventListener("DOMContentLoaded", function () {
    initTheme();
    initNav();
    initReveal();
    initYear();
    initMirrors();
    initDuoji();   // 多吉云是配置驱动：前缀为空时这里什么都不做（按钮保持 hidden）
    applyDeviceHighlight();   // 立即按 UA 高亮首屏下载条与对应平台卡片，不等清单
    fetchManifest();
    initSnapshot();
    initDownloads();
    initTvGallery();
    initLightbox();
  });
})();
