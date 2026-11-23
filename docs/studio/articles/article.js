/* 研究文章共享脚本：语言切换（沿用工作室页的 localStorage 键）+ 年份 */
(function(){
  "use strict";
  var nodes = document.querySelectorAll("[data-zh][data-en]");
  var buttons = document.querySelectorAll(".langsw button");
  function setLang(lang){
    for (var i=0;i<nodes.length;i++){
      var el = nodes[i];
      var val = (lang === "en") ? el.getAttribute("data-en") : el.getAttribute("data-zh");
      // 文章内容是我们自己静态撰写的（含 <strong>/<code> 富文本），统一按 HTML 注入。
      // 非用户提交，无 XSS 风险。
      if (val != null) el.innerHTML = val;
    }
    document.documentElement.lang = (lang === "en") ? "en" : "zh-CN";
    for (var j=0;j<buttons.length;j++)
      buttons[j].setAttribute("aria-pressed", String(buttons[j].getAttribute("data-lang") === lang));
    try { localStorage.setItem("wuai-studio-lang", lang); } catch(e){}
  }
  for (var k=0;k<buttons.length;k++)
    buttons[k].addEventListener("click", function(){ setLang(this.getAttribute("data-lang")); });
  var saved = null;
  try { saved = localStorage.getItem("wuai-studio-lang"); } catch(e){}
  setLang(saved === "en" ? "en" : "zh");
  var y = document.getElementById("year");
  if (y) y.textContent = new Date().getFullYear();

  // 窄屏宽表：统一包一层可横向滚动的容器。表格按内容自然宽度呈现，
  // 既不会把列压到断字，也不会撑宽移动浏览器的 layout viewport。
  var tables = document.querySelectorAll("table");
  for (var t = 0; t < tables.length; t++) {
    var tb = tables[t], p = tb.parentNode;
    if (p && p.classList && p.classList.contains("table-scroll")) continue;
    var box = document.createElement("div");
    box.className = "table-scroll";
    p.insertBefore(box, tb);
    box.appendChild(tb);
  }
  // 只有真正需要横滑的表才显示提示；窗口尺寸变化后重算。
  function markScrollable() {
    var boxes = document.querySelectorAll(".table-scroll");
    for (var b = 0; b < boxes.length; b++)
      boxes[b].classList.toggle("is-scrollable", boxes[b].scrollWidth > boxes[b].clientWidth + 2);
  }
  markScrollable();
  window.addEventListener("resize", markScrollable);
})();
