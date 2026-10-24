/* =========================================================
   吾爱音乐 官网 — 设计语言：液态玻璃交互演示
   与 App 内同一套交互语言（水光纹理 + 流动扫光 + 弹簧回弹）。
   弹簧参数：低刚度 + 低阻尼 + 深按压 = 大而不快的弹跳（与玻璃弹性预览定稿一致）。
   菜单指示条用温和过冲，避免滑飞。
   不依赖 main.js：本文件独立加载，出错不影响站点其它逻辑。
   ========================================================= */
(function () {
  "use strict";

  var reduce =
    window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  // 每实例独立的弹簧（rAF 积分器，结构与 Flutter SpringSimulation 同构）
  function spring(onUpdate, opt) {
    opt = opt || {};
    var cur = 1, vel = 0, target = 1, raf = null, last = 0;
    var k = opt.stiffness || 180, c = opt.damp || 14;
    function step(ts) {
      if (!last) last = ts;
      var dt = Math.min((ts - last) / 1000, 0.032);
      last = ts;
      var f = -k * (cur - target) - c * vel;
      vel += f * dt;
      cur += vel * dt;
      if (Math.abs(cur - target) < 0.001 && Math.abs(vel) < 0.02) {
        cur = target; vel = 0; raf = null; onUpdate(cur); return;
      }
      onUpdate(cur);
      raf = requestAnimationFrame(step);
    }
    return {
      to: function (t) { target = t; last = 0; if (raf) cancelAnimationFrame(raf); raf = requestAnimationFrame(step); },
      set: function (x) { cur = x; vel = 0; onUpdate(x); }
    };
  }

  function $(s, c) { return (c || document).querySelector(s); }

  // 来自预览定稿：大而不快
  var STIFF = 120, DAMP = 4, PRESS = 0.80;

  // ① 玻璃按钮 · 水光 + 弹性（自动演示 + 可点击）
  (function () {
    var btn = $("#dBtn"); if (!btn) return;
    var sp = spring(function (v) { btn.style.transform = "scale(" + Math.max(0.5, v) + ")"; });
    function down(e) { if (e) e.preventDefault(); sp.to(PRESS); btn.classList.add("pressed", "hot"); }
    function up(e) {
      if (e) e.preventDefault();
      sp.to(1); btn.classList.remove("pressed");
      setTimeout(function () { btn.classList.remove("hot"); }, 650);
    }
    ["pointerdown", "mousedown", "touchstart"].forEach(function (ev) { btn.addEventListener(ev, down, { passive: false }); });
    ["pointerup", "mouseup", "touchend", "pointercancel"].forEach(function (ev) { btn.addEventListener(ev, up, { passive: false }); });
    btn.addEventListener("mouseleave", function () { sp.to(1); btn.classList.remove("pressed"); });
    if (!reduce) {
      var t = setInterval(function () { down(); setTimeout(up, 380); }, 1900);
      btn.addEventListener("pointerdown", function () { clearInterval(t); }, { once: true });
    }
  })();

  // ② 图标切换 · 左右滑动（▶ / ⏸）
  (function () {
    var btn = $("#dSwap"), ico = $("#dSwapIco"); if (!btn || !ico) return;
    var sp = spring(function (v) { btn.style.transform = "scale(" + Math.max(0.5, v) + ")"; });
    var play = '<svg viewBox="0 0 24 24" fill="#fff"><path d="M8 5v14l11-7z"/></svg>';
    var pause = '<svg viewBox="0 0 24 24" fill="#fff"><rect x="7" y="5" width="4" height="14" rx="1"/><rect x="13" y="5" width="4" height="14" rx="1"/></svg>';
    var playing = false;
    function toggle() {
      playing = !playing;
      ico.style.transition = "opacity .18s, transform .18s";
      ico.style.opacity = "0"; ico.style.transform = "translateX(-26px) scale(.7)";
      setTimeout(function () {
        ico.innerHTML = playing ? pause : play;
        ico.style.transition = "none";
        ico.style.transform = "translateX(26px) scale(.7)"; ico.style.opacity = "0";
        void ico.offsetWidth;
        ico.style.transition = "opacity .18s, transform .18s";
        ico.style.transform = "translateX(0) scale(1)"; ico.style.opacity = "1";
      }, 160);
    }
    function down(e) { if (e) e.preventDefault(); sp.to(PRESS); btn.classList.add("pressed"); }
    function up(e) { if (e) e.preventDefault(); sp.to(1); btn.classList.remove("pressed"); toggle(); }
    ["pointerdown", "mousedown", "touchstart"].forEach(function (ev) { btn.addEventListener(ev, down, { passive: false }); });
    ["pointerup", "mouseup", "touchend", "pointercancel"].forEach(function (ev) { btn.addEventListener(ev, up, { passive: false }); });
    if (!reduce) {
      var t = setInterval(function () { down(); setTimeout(up, 380); }, 2600);
      btn.addEventListener("pointerdown", function () { clearInterval(t); }, { once: true });
    }
  })();

  // ③ 可拖拽开关 · 弹起 + 左右过冲
  (function () {
    var sw = $("#dToggle"), knob = $("#dKnob"); if (!sw || !knob) return;
    var on = false, prog = 0, lift = 0, scale = 1, dragging = false, rect = null, startX = 0, moved = 0, demoTimer = null;
    var posS = spring(function (p) { prog = p; render(); }, { stiffness: STIFF, damp: DAMP });
    var scaleS = spring(function (s) { scale = s; render(); }, { stiffness: STIFF, damp: DAMP });
    var liftS = spring(function (l) { lift = l; render(); }, { stiffness: STIFF, damp: DAMP });
    function render() {
      var x = Math.max(-4, Math.min(52, prog * 46));
      knob.style.transform = "translate(" + x + "px," + lift + "px) scale(" + scale + ")";
    }
    function setOn(v) { on = v; sw.classList.toggle("on", on); }
    function flip() { setOn(!on); posS.to(on ? 1 : 0); scaleS.to(0.84); setTimeout(function () { scaleS.to(1); }, 130); }
    function down(e) {
      e.preventDefault(); dragging = true;
      if (demoTimer) { clearInterval(demoTimer); demoTimer = null; }
      try { sw.setPointerCapture(e.pointerId); } catch (_) {}
      rect = sw.getBoundingClientRect(); startX = e.clientX; moved = 0;
      knob.classList.add("dragging"); liftS.to(-12); scaleS.to(1.12);
    }
    function move(e) {
      if (!dragging) return; e.preventDefault();
      moved = Math.max(moved, Math.abs(e.clientX - startX));
      var p = (e.clientX - rect.left - 25) / 46;
      p = Math.max(0, Math.min(1, p));
      prog = p; posS.set(p);
    }
    function up(e) {
      if (!dragging) return; e.preventDefault(); dragging = false;
      knob.classList.remove("dragging");
      if (moved < 6) { on = !on; setOn(on); } else { on = prog > 0.5; setOn(on); }
      liftS.to(0); scaleS.to(1); posS.to(on ? 1 : 0);
    }
    sw.addEventListener("pointerdown", down);
    sw.addEventListener("pointermove", move);
    sw.addEventListener("pointerup", up);
    sw.addEventListener("pointercancel", up);
    if (!reduce) demoTimer = setInterval(flip, 2400);
  })();

  // ④ 两图标联动切换 · 收藏 ⇄ 星标
  (function () {
    var btn = $("#dLink"), a = $("#dLinkA"), b = $("#dLinkB"); if (!btn || !a || !b) return;
    var heart = '<svg viewBox="0 0 24 24" fill="#FF6B8A"><path d="M12 21l-1.45-1.32C5.4 14.97 2 11.9 2 7.94 2 5.08 4.14 3 6.97 3c1.6 0 3.14.76 4.03 1.96C11.89 3.76 13.43 3 15.03 3 17.86 3 20 5.08 20 7.94c0 3.96-3.4 7.03-8.55 11.74L12 21z"/></svg>';
    var star = '<svg viewBox="0 0 24 24" fill="#FFD24A"><path d="M12 2l2.9 6.26 6.6.74-4.95 4.5 1.35 6.5L12 17.1 6.1 20.5l1.35-6.5L2.5 9.5l6.6-.74L12 2z"/></svg>';
    var sp = spring(function (v) { btn.style.transform = "scale(" + Math.max(0.5, v) + ")"; });
    a.innerHTML = heart; b.innerHTML = star;
    b.style.transform = "translateX(30px)"; b.style.opacity = "0";
    var on = false;
    function swap() {
      on = !on;
      var inc = on ? b : a, out = on ? a : b;
      inc.style.transition = "none";
      inc.style.transform = "translateX(30px)"; inc.style.opacity = "0";
      void inc.offsetWidth;
      inc.style.transition = "transform .22s ease, opacity .22s ease";
      inc.style.transform = "translateX(0)"; inc.style.opacity = "1";
      out.style.transition = "transform .22s ease, opacity .22s ease";
      out.style.transform = "translateX(-30px)"; out.style.opacity = "0";
    }
    function down(e) { if (e) e.preventDefault(); sp.to(PRESS); btn.classList.add("pressed"); }
    function up(e) { if (e) e.preventDefault(); sp.to(1); btn.classList.remove("pressed"); swap(); }
    ["pointerdown", "mousedown", "touchstart"].forEach(function (ev) { btn.addEventListener(ev, down, { passive: false }); });
    ["pointerup", "mouseup", "touchend", "pointercancel"].forEach(function (ev) { btn.addEventListener(ev, up, { passive: false }); });
    if (!reduce) {
      var t = setInterval(swap, 2600);
      btn.addEventListener("pointerdown", function () { clearInterval(t); }, { once: true });
    }
  })();

  // ⑤ 菜单切换 · 玻璃指示条弹簧滑过
  (function () {
    var menu = $("#dMenu"), ind = $("#dInd"); if (!menu || !ind) return;
    var items = Array.prototype.slice.call(menu.querySelectorAll(".d-mitem"));
    var cur = 0, demoTimer = null;
    var indS = spring(function (x) { ind.style.transform = "translateX(" + x + "px)"; }, { stiffness: 300, damp: 20 });
    function setMenu(i, animate) {
      cur = i;
      items.forEach(function (m, j) { m.classList.toggle("active", j === i); });
      var it = items[i];
      var tx = it.offsetLeft + 4;
      ind.style.width = (it.offsetWidth - 8) + "px";
      if (animate) indS.to(tx); else ind.style.transform = "translateX(" + tx + "px)";
    }
    items.forEach(function (m, i) {
      m.addEventListener("pointerdown", function (e) {
        e.preventDefault();
        if (demoTimer) { clearInterval(demoTimer); demoTimer = null; }
        setMenu(i, true);
      });
    });
    setMenu(0, false);
    if (!reduce) demoTimer = setInterval(function () { setMenu((cur + 1) % items.length, true); }, 2600);
  })();
})();
