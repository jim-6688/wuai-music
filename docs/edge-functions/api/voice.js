/**
 * 小爱语音信箱 —— EdgeOne 边缘函数（V8）+ KV
 *
 * ── 为什么是"信箱"而不是直连 ─────────────────────────────────────────────
 * 数播在局域网里，没有公网 IP；小爱技能只能回调公网 HTTPS。
 * 所以让小爱写、数播取（数播主动出网轮询），路由器不用开端口、不用内网穿透。
 *
 * ── 路由（同一文件，按方法/参数分流）──────────────────────────────────────
 *   POST /api/voice?action=setup   首次注入密钥（header x-bootstrap 必须等于默认值）
 *   POST /api/voice?k=<secret>     小爱技能回调：body 里带 query/slots，入队
 *   GET  /api/voice?k=<secret>     数播取命令：返回并清空队列
 *
 * ── 部署前提 ─────────────────────────────────────────────────────────────
 *   项目已绑定 KV，变量名 `wuai_kv`（与 downloads.js 同一个）。
 *
 * ── 安全边界 ─────────────────────────────────────────────────────────────
 *   密钥存 KV（`voice:secret`），不在仓库里。setup 只在 KV 为空时生效：
 *   部署后**立刻**用数播跑一次 setup，之后默认密钥失效。
 *   队列只放播放类命令，关机/改网络这类危险动作服务端直接拒绝。
 */

const KV_NAME = "wuai_kv";
const KEY_SECRET = "voice:secret";
const KEY_QUEUE = "voice:queue";
const MAX_QUEUE = 20;
const MAX_AGE_MS = 60 * 1000;

// 仅用于"首次注入"，KV 里写入真密钥后即失效
const BOOTSTRAP = "w7f3q2xk9m4v8p1s";

function json(data, status) {
  return new Response(JSON.stringify(data), {
    status: status || 200,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

function kv() {
  try {
    return globalThis[KV_NAME] || null;
  } catch (e) {
    return null;
  }
}

function sameSecret(a, b) {
  if (typeof a !== "string" || typeof b !== "string" || a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function readSecret(store) {
  const v = await store.get(KEY_SECRET);
  return typeof v === "string" && v.length >= 16 ? v : "";
}

async function readQueue(store) {
  const raw = await store.get(KEY_QUEUE);
  if (!raw) return [];
  try {
    const arr = JSON.parse(raw);
    return Array.isArray(arr) ? arr : [];
  } catch (e) {
    return [];
  }
}

export async function onRequestPost(context) {
  const store = kv();
  if (!store) return json({ ok: false, error: "kv_not_bound" }, 503);

  const url = new URL(context.request.url);
  const action = url.searchParams.get("action") || "";

  // ── 首次注入密钥 ──
  if (action === "setup") {
    const boot = context.request.headers.get("x-bootstrap") || "";
    if (!sameSecret(boot, BOOTSTRAP)) return json({ ok: false, error: "bad_bootstrap" }, 403);
    const exist = await readSecret(store);
    if (exist) return json({ ok: false, error: "already_initialized" }, 409);
    let body = {};
    try {
      body = await context.request.json();
    } catch (e) {}
    const secret = String(body.secret || "");
    if (secret.length < 24) return json({ ok: false, error: "secret_too_short" }, 400);
    await store.put(KEY_SECRET, secret);
    return json({ ok: true, initialized: true });
  }

  // ── 小爱技能回调 ──
  const secret = await readSecret(store);
  if (!secret) return json({ ok: false, error: "not_initialized" }, 409);
  if (!sameSecret(url.searchParams.get("k") || "", secret)) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  let body = {};
  try {
    body = await context.request.json();
  } catch (e) {
    return json({ ok: false, error: "bad_json" }, 400);
  }

  // 小爱技能请求：query 在 body.query / body.request.query，
  // 意图与槽位在 request.slot_info（不是 request.intent）
  const isSkill = !!(body.request || body.version);
  const req = body.request || {};
  const slotInfo = req.slot_info || body.slot_info || {};
  const slots = Array.isArray(slotInfo.slots) ? slotInfo.slots : [];
  const query = String(body.query || req.query || "").trim();
  const slotText = slots
    .map((s) => String((s && (s.value || s.raw_value)) || ""))
    .filter(Boolean)
    .join(" ");

  const text = query || slotText;
  if (!text) {
    if (isSkill) return skillSay("没听清，请再说一次", true);
    return json({ ok: false, error: "empty_text" }, 400);
  }

  const now = Date.now();
  const queue = (await readQueue(store)).filter((c) => now - (c.ts || 0) < MAX_AGE_MS);
  const cmd = {
    id: now.toString(36) + Math.random().toString(36).slice(2, 6),
    text,
    intent: slotInfo.intent_name || "",
    slots,
    source: "xiaoai",
    ts: now,
  };
  queue.push(cmd);
  while (queue.length > MAX_QUEUE) queue.shift();
  await store.put(KEY_QUEUE, JSON.stringify(queue));

  if (isSkill) return skillSay("好的，已交给数播", false);
  return json({ ok: true, queued: queue.length, id: cmd.id });
}

// 小爱技能的响应必须是这个结构；缺 to_speak 会被平台判为「无效动作、没声音」
function skillSay(text, notUnderstand) {
  return new Response(
    JSON.stringify({
      is_session_end: true,
      version: "1.0",
      response: {
        to_speak: { type: 0, text },
        to_display: { type: 0, text },
        open_mic: false,
        not_understand: notUnderstand === true,
        confidence: 1,
      },
      session_attributes: {},
    }),
    { status: 200, headers: { "Content-Type": "application/json; charset=utf-8" } }
  );
}

export async function onRequestGet(context) {
  const store = kv();
  if (!store) return json({ ok: false, error: "kv_not_bound" }, 503);

  const url = new URL(context.request.url);
  const secret = await readSecret(store);
  if (!secret) return json({ ok: false, error: "not_initialized" }, 409);
  if (!sameSecret(url.searchParams.get("k") || "", secret)) {
    return json({ ok: false, error: "unauthorized" }, 401);
  }

  const now = Date.now();
  const queue = await readQueue(store);
  const fresh = queue.filter((c) => now - (c.ts || 0) < MAX_AGE_MS);
  if (queue.length) await store.put(KEY_QUEUE, "[]");
  return json({ ok: true, cmds: fresh });
}

export function onRequest() {
  return json({ ok: false, error: "method_not_allowed" }, 405);
}
