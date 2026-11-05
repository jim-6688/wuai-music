/**
 * 下载统计 —— EdgeOne 边缘函数（V8）+ KV
 *
 * ── 为什么要有它 ─────────────────────────────────────────────────────────
 * 页面原来只有一条链路：跨域打 `countapi.mileshilliard.com`。那是个人维护的
 * 免费服务，实测单次 GET 要 1.1s 左右，且没有任何可用性承诺 —— 它挂掉的那天，
 * 「本站已下载 N 次」就永久停在旧数字上。换成同域边缘函数后，这个数字从
 * 「跨国一次往返」变成「边缘节点读一次 KV」，顺带也不再受第三方配额摆布。
 *
 * ── 路由 ────────────────────────────────────────────────────────────────
 *   GET  /api/downloads   读取 { site, github, updatedAt }
 *   POST /api/downloads   本站按钮点击 +1，返回 { site }
 *
 * ── 部署前提（缺一不可，见 README/交接说明）──────────────────────────────
 *   1. EdgeOne 控制台 → KV Storage → 开通（免费额度 1GB）
 *   2. 建一个 namespace（建议 `wuaimusic`）
 *   3. 绑定到项目 `wuaimusic-site`，**变量名必须是 `wuai_kv`**
 *      （代码里按这个名字取全局变量，改名就得改这里的 KV 引用）
 *
 * ── 没绑 KV 时会怎样 ─────────────────────────────────────────────────────
 *   函数返回 503，前端 `main.js` 自动降级回第三方计数 / `/stats.json` 快照。
 *   也就是说：**这段代码部署上去但 KV 没配好，页面不会坏，只是数字回到老路子。**
 *
 * ── 为什么计数会「丢」而不修 ─────────────────────────────────────────────
 *   KV 是最终一致（全球同步 ≤60s）且**没有原子自增**：两个访客同一秒点下载，
 *   可能都读到 106、都写 107，净增 1 而不是 2。这是刻意的取舍 ——
 *   「下载点击数」是个虚荣指标，为它引入强一致存储（Blob / 外部 DB）不划算。
 *   真要精确统计，正确做法是每次点击落一行明细、总数用聚合算，而不是加法计数。
 */

// KV 是控制台绑定时设的**全局变量**（不在 context.env 上）
const KV_NAME = "wuai_kv";

const KEY_SITE = "dl:site:clicks";

// 历史计数种子。老链路（countapi）切走前的最后一次读数是 107。
// KV 里 `dl:site:clicks` 从 0 起算，不补这笔，页面上的「本站按钮点击」
// 就会从三位数掉回个位数（0 是个假数字，不是"清零重来"）。
// 这里取 106 而不是 107：上线验证写路径时我们会真发一次 POST，
// 那次会让 KV 变成 1 ⇒ 106 + 1 = 107，与切换瞬间的真实值一致。
const SITE_SEED = 106;
const KEY_GH = "dl:github:count";
const KEY_GH_AT = "dl:github:at";

// GitHub 匿名接口限 60 次/小时/IP。官网访客共享同一个出口 IP 段时很容易撞墙，
// 所以这里缓存 10 分钟：一小时最多 6 次真实请求，远低于限流线。
const GH_TTL_MS = 10 * 60 * 1000;
const GH_API = "https://api.github.com/repos/jim-6688/wuai-music/releases?per_page=100";

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      // 计数必须实时，不能被任何一层缓存住
      "cache-control": "no-store",
      "access-control-allow-origin": "*",
    },
  });

/** 取 KV 全局变量。未绑定时不抛错、返回 null —— 才有机会给出 503 而不是 500。 */
function store() {
  try {
    return typeof wuai_kv !== "undefined" ? wuai_kv : null;
  } catch (e) {
    return null;
  }
}

const num = (v) => {
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? n : null;
};

/** 只统计 .apk：Release 里还挂过截图 png，算进去数字会虚高 */
async function fetchGithubTotal() {
  const r = await fetch(GH_API, {
    headers: {
      accept: "application/vnd.github+json",
      // GitHub 要求带 UA，否则 403
      "user-agent": "wuai-music-site",
    },
  });
  if (!r.ok) throw new Error("github " + r.status);
  const rels = await r.json();
  if (!Array.isArray(rels)) throw new Error("github payload");

  let sum = 0;
  let seen = false;
  for (const rel of rels) {
    for (const a of rel.assets || []) {
      if (/\.apk$/i.test(a.name || "")) {
        sum += a.download_count || 0;
        seen = true;
      }
    }
  }
  // 一个 apk 都没找到 ⇒ 多半接口返回了意料外的东西，别把 0 写进缓存
  if (!seen) throw new Error("github empty");
  return sum;
}

export async function onRequestGet() {
  const kv = store();
  if (!kv) return json({ ok: false, error: "kv_not_bound" }, 503);

  try {
    const [siteRaw, ghRaw, ghAtRaw] = await Promise.all([
      kv.get(KEY_SITE),
      kv.get(KEY_GH),
      kv.get(KEY_GH_AT),
    ]);

    // KV 里还没有值（刚开通）时返回 null，让前端继续用 /stats.json 的快照，
    // 而不是把「本站点击 0 次」显示出来 —— 0 是一个假数字，null 才表示"不知道"。
    const site =
      siteRaw === null || siteRaw === undefined
        ? (SITE_SEED || null)   // 有种子就报种子值，没有就报 null 让前端用快照
        : (num(siteRaw) || 0) + SITE_SEED;
    let github = num(ghRaw);
    const ghAt = num(ghAtRaw) || 0;

    // 缓存过期才回源。失败就继续用手上的旧值 —— 统计块宁可显示旧数字，
    // 也不该因为 GitHub 一时抽风而整块消失。
    if (github === null || Date.now() - ghAt >= GH_TTL_MS) {
      try {
        github = await fetchGithubTotal();
        await Promise.all([
          kv.put(KEY_GH, String(github)),
          kv.put(KEY_GH_AT, String(Date.now())),
        ]);
      } catch (e) {
        /* 保留 github 的旧值（可能仍是 null） */
      }
    }

    return json({ ok: true, site, github, updatedAt: new Date().toISOString() });
  } catch (e) {
    return json({ ok: false, error: "kv_read_failed" }, 500);
  }
}

export async function onRequestPost() {
  const kv = store();
  if (!kv) return json({ ok: false, error: "kv_not_bound" }, 503);

  try {
    const cur = num(await kv.get(KEY_SITE)) || 0;
    const next = cur + 1;
    await kv.put(KEY_SITE, String(next));
    return json({ ok: true, site: next + SITE_SEED });
  } catch (e) {
    return json({ ok: false, error: "kv_write_failed" }, 500);
  }
}

export function onRequest() {
  return json({ ok: false, error: "method_not_allowed" }, 405);
}

// KV 变量名写进响应头，方便部署后一眼确认绑定名对得上（名字错了会 503）
export function onRequestOptions() {
  return new Response(null, {
    status: 204,
    headers: {
      "access-control-allow-origin": "*",
      "access-control-allow-methods": "GET,POST,OPTIONS",
      "x-kv-name": KV_NAME,
    },
  });
}
