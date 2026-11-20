/* =========================================================
   吾爱音乐 · 产品页共享行为 (product.js)
   主题键与主站一致：wuai-theme（light/dark），不跟随系统。
   ========================================================= */
(function () {
  "use strict";

  /* 主题启动：默认贝壳白，只有用户手动点过才用记忆值 */
  var root = document.documentElement;
  var t = "light";
  try {
    var saved = localStorage.getItem("wuai-theme");
    if (saved === "dark" || saved === "light") t = saved;
  } catch (e) {}
  root.setAttribute("data-theme", t);
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute("content", t === "dark" ? "#08090b" : "#f9f4f0");

  document.addEventListener("DOMContentLoaded", function () {
    /* 主题切换 */
    var tt = document.querySelector(".theme-toggle");
    if (tt) {
      var paint = function () {
        tt.textContent = root.getAttribute("data-theme") === "dark" ? "☀" : "◐";
        tt.setAttribute("aria-label", "切换深浅色主题");
      };
      paint();
      tt.addEventListener("click", function () {
        var next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
        root.setAttribute("data-theme", next);
        try { localStorage.setItem("wuai-theme", next); } catch (e) {}
        if (meta) meta.setAttribute("content", next === "dark" ? "#08090b" : "#f9f4f0");
        paint();
      });
    }

    /* 移动端产品导航展开 */
    var navToggle = document.querySelector(".nav-toggle");
    var prodnav = document.querySelector(".prodnav");
    if (navToggle && prodnav) {
      navToggle.addEventListener("click", function () {
        var open = prodnav.classList.toggle("is-open");
        navToggle.setAttribute("aria-expanded", open ? "true" : "false");
      });
    }

    /* 动态区 Tab 切换：data-dyn-tab -> #dyn-<key> */
    var tabs = document.querySelectorAll(".dyn-tab");
    if (tabs.length) {
      var activate = function (key) {
        tabs.forEach(function (b) {
          b.classList.toggle("is-active", b.getAttribute("data-dyn-tab") === key);
        });
        document.querySelectorAll(".dyn-panel").forEach(function (p) {
          p.classList.toggle("is-active", p.id === "dyn-" + key);
        });
      };
      tabs.forEach(function (b) {
        b.addEventListener("click", function () {
          activate(b.getAttribute("data-dyn-tab"));
        });
      });
      if (!document.querySelector(".dyn-panel.is-active")) {
        var first = tabs[0].getAttribute("data-dyn-tab");
        if (first) activate(first);
      }
    }
  });
})();
