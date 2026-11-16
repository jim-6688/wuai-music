/* ═══════════════════════════════════════════════════════════════════════════
   首屏 3D 背景 —— 悬浮黑胶 + 品牌紫星尘（three.js r149，本地 vendor）

   设计约束（都来自官网现有门面，不要轻易改）：
   · 画布完全透明：hero::before 的紫色辉光和 hero__rule 的网格底纹要透出来；
   · 配色**不硬编码**，实时读 CSS 变量 --brand / --brand-2 —— 官网真源是品牌紫，
     且用户手动切深墨主题时 3D 必须一起变（MutationObserver 监听 data-theme）；
   · 不阻塞首屏：three.min.js 与本文件都 defer，等 window.load 后再延迟初始化；
   · 可降级：WebGL 不可用 / 上下文丢失 / three.js 没加载 → 静默隐藏，官网原样；
   · 可关闭：右下角小胶囊，偏好写 localStorage('wuai-hero3d')；
   · 省电：页面隐藏、hero 滚出视口、reduced-motion 时都停渲染。
   ═══════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  var canvas = document.getElementById('hero3d');
  var hero = document.querySelector('.hero');
  var toggle = document.getElementById('hero3dToggle');
  var toggleLabel = document.getElementById('hero3dToggleLabel');
  if (!canvas || !hero || typeof window.THREE === 'undefined') return;

  var T = window.THREE;
  var KEY = 'wuai-hero3d';
  var enabled = true;
  try { enabled = localStorage.getItem(KEY) !== 'off'; } catch (e) {}

  var reduceMotion = false;
  try {
    reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch (e) {}
  var small = window.innerWidth < 720;

  var renderer, scene, camera, tilt, disc, particles;
  var bodyMat, grooveMat, labelMat, ringMat, pointsMat, keyLight, rimLight;
  var raf = 0, running = false, inView = true, last = 0, started = false;
  var pointerX = 0, pointerY = 0, curX = 0, curY = 0;

  function cssVar(name, fallback) {
    try {
      var v = getComputedStyle(document.documentElement)
        .getPropertyValue(name).trim();
      return v || fallback;
    } catch (e) { return fallback; }
  }

  function palette() {
    var dark = document.documentElement.getAttribute('data-theme') === 'dark';
    return {
      dark: dark,
      brand: cssVar('--brand', dark ? '#c49aee' : '#7b45c9'),
      brand2: cssVar('--brand-2', dark ? '#e0c4f7' : '#5b2c9e'),
      disc: dark ? 0.88 : 0.06,
      groove: dark ? 1.0 : 0.62,
      points: dark ? 0.85 : 0.38,
      label: dark ? 0.92 : 0.20,
      ring: dark ? 0.42 : 0.35
    };
  }

  function color(hex, fallback) {
    try { return new T.Color(hex); } catch (e) { return new T.Color(fallback); }
  }

  // 盘面沟槽用一支 shader 画同心纹：比堆几十个 RingGeometry 少几十个 draw call，
  // 且旋转时高光会顺着纹理走，比贴图更像唱片。
  var GROOVE_VERT = [
    'varying vec2 vUv;',
    'void main() {',
    '  vUv = uv;',
    '  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);',
    '}'
  ].join('\n');

  var GROOVE_FRAG = [
    'varying vec2 vUv;',
    'uniform vec3 uColor;',
    'uniform float uOpacity;',
    'uniform float uTime;',
    'uniform float uLineMode;',
    'void main() {',
    '  vec2 p = vUv - 0.5;',
    '  float r = length(p) * 2.0;',
    '  if (r > 1.0) discard;',
    '  float grooves = 0.5 + 0.5 * sin(r * 245.0);',
    '  float ang = atan(p.y, p.x);',
    '  float sheen = 0.5 + 0.5 * sin(ang * 2.0 + uTime * 0.25);',
    '  float edge = smoothstep(1.0, 0.86, r);',
    '  float inner = smoothstep(0.17, 0.22, r);',
    '  float band = smoothstep(0.86, 0.94, r) * 0.55;',
    // 浅色贝壳白底上实心紫会发脏：把底色调到几乎透明，
    // 只留明暗交替的同心细纹；深墨底仍用原来的实心配方。
    '  float base = mix(0.07, 0.012, uLineMode);',
    '  float amp  = mix(0.13, 0.22, uLineMode);',
    '  float she  = mix(0.10, 0.045, uLineMode);',
    '  float a = (base + grooves * amp + sheen * she + band)',
    '            * edge * inner * uOpacity;',
    '  gl_FragColor = vec4(uColor, a);',
    '}'
  ].join('\n');

  function build() {
    renderer = new T.WebGLRenderer({
      canvas: canvas, alpha: true, antialias: true,
      powerPreference: 'low-power'
    });
    renderer.setClearColor(0x000000, 0);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, small ? 1.25 : 1.75));

    scene = new T.Scene();
    camera = new T.PerspectiveCamera(38, 1, 0.1, 100);
    camera.position.set(0, 0, 10);

    tilt = new T.Group();
    disc = new T.Group();
    tilt.add(disc);
    scene.add(tilt);

    // 盘体（薄圆柱，翻 90° 让圆面正对相机）
    bodyMat = new T.MeshStandardMaterial({
      color: 0x15121a, roughness: 0.46, metalness: 0.5,
      transparent: true, opacity: 0.5
    });
    var body = new T.Mesh(new T.CylinderGeometry(2.35, 2.35, 0.06, 96), bodyMat);
    body.rotation.x = Math.PI / 2;
    disc.add(body);

    grooveMat = new T.ShaderMaterial({
      vertexShader: GROOVE_VERT, fragmentShader: GROOVE_FRAG,
      transparent: true, depthWrite: false, side: T.DoubleSide,
      uniforms: {
        uColor: { value: new T.Color(0x7b45c9) },
        uOpacity: { value: 0.6 },
        uTime: { value: 0 },
        uLineMode: { value: 0 }
      }
    });
    var grooves = new T.Mesh(new T.PlaneGeometry(4.7, 4.7), grooveMat);
    grooves.position.z = 0.042;
    disc.add(grooves);

    labelMat = new T.MeshBasicMaterial({
      color: 0x5b2c9e, transparent: true, opacity: 0.92, side: T.DoubleSide
    });
    var labelDisc = new T.Mesh(new T.CircleGeometry(0.52, 64), labelMat);
    labelDisc.position.z = 0.052;
    disc.add(labelDisc);

    var hole = new T.Mesh(
      new T.CircleGeometry(0.055, 24),
      new T.MeshBasicMaterial({ color: 0xf9f4f0, side: T.DoubleSide })
    );
    hole.position.z = 0.056;
    disc.add(hole);

    ringMat = new T.MeshBasicMaterial({
      color: 0x7b45c9, transparent: true, opacity: 0.42, side: T.DoubleSide
    });
    var ring = new T.Mesh(new T.RingGeometry(2.30, 2.37, 96), ringMat);
    ring.position.z = 0.046;
    disc.add(ring);

    // 星尘：一个 Points，单 draw call
    var count = small ? 72 : 190;
    var pos = new Float32Array(count * 3);
    for (var i = 0; i < count; i++) {
      pos[i * 3] = (Math.random() - 0.5) * 17;
      pos[i * 3 + 1] = (Math.random() - 0.5) * 10;
      pos[i * 3 + 2] = -2.5 + Math.random() * 3.5;
    }
    var geo = new T.BufferGeometry();
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    pointsMat = new T.PointsMaterial({
      color: 0x7b45c9, size: small ? 0.045 : 0.055,
      transparent: true, opacity: 0.5, sizeAttenuation: true,
      depthWrite: false
    });
    particles = new T.Points(geo, pointsMat);
    scene.add(particles);

    scene.add(new T.AmbientLight(0xffffff, 0.85));
    keyLight = new T.DirectionalLight(0x7b45c9, 1.1);
    keyLight.position.set(3, 4, 6);
    scene.add(keyLight);
    rimLight = new T.DirectionalLight(0x5b2c9e, 0.6);
    rimLight.position.set(-4, -2, 3);
    scene.add(rimLight);

    tilt.rotation.x = -0.42;
    tilt.rotation.z = -0.12;
    tilt.position.set(small ? 0 : 3.8, small ? 2.35 : 0.95, 0);
    tilt.scale.setScalar(small ? 0.46 : 0.72);
  }

  function applyTheme() {
    var p = palette();
    var c1 = color(p.brand, '#7b45c9');
    var c2 = color(p.brand2, '#5b2c9e');
    bodyMat.opacity = p.disc;
    grooveMat.uniforms.uColor.value.copy(c1);
    grooveMat.uniforms.uOpacity.value = p.groove;
    grooveMat.uniforms.uLineMode.value = p.dark ? 0 : 1;
    labelMat.color.copy(c2);
    labelMat.opacity = p.label;
    ringMat.color.copy(c1);
    ringMat.opacity = p.ring;
    pointsMat.color.copy(c1);
    pointsMat.opacity = p.points;
    // 加法混合在白色贝壳底上会把粒子"加"成白色而看不见，浅色下走普通混合
    pointsMat.blending = p.dark ? T.AdditiveBlending : T.NormalBlending;
    pointsMat.needsUpdate = true;
    keyLight.color.copy(c1);
    rimLight.color.copy(c2);
  }

  function resize() {
    // ⚠️ 用 canvas 自己的尺寸，不是 hero 的：画布只覆盖首屏上半部，
    //    拿 hero 总高算 aspect 会把唱片放大到盖住正文。
    var w = canvas.clientWidth || hero.clientWidth;
    var h = canvas.clientHeight || hero.clientHeight;
    if (!w || !h) return;
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    renderer.setSize(w, h, false);
  }

  function frame(ts) {
    if (!running) return;
    raf = requestAnimationFrame(frame);
    var dt = last ? Math.min((ts - last) / 1000, 0.05) : 0;
    last = ts;
    disc.rotation.z += dt * 0.16;
    grooveMat.uniforms.uTime.value += dt;
    particles.rotation.z += dt * 0.006;
    particles.position.y = Math.sin(ts * 0.00018) * 0.12;
    curX += (pointerX - curX) * 0.045;
    curY += (pointerY - curY) * 0.045;
    tilt.rotation.y = curX * 0.12;
    tilt.rotation.x = -0.42 + curY * 0.08;
    renderer.render(scene, camera);
  }

  function start() {
    if (!enabled || running || !inView || document.hidden || reduceMotion) return;
    running = true; last = 0;
    raf = requestAnimationFrame(frame);
  }
  function stop() {
    running = false;
    if (raf) cancelAnimationFrame(raf);
    raf = 0;
  }

  function setEnabled(on) {
    enabled = on;
    try { localStorage.setItem(KEY, on ? 'on' : 'off'); } catch (e) {}
    if (toggle) toggle.setAttribute('aria-pressed', on ? 'true' : 'false');
    if (toggleLabel) toggleLabel.textContent = on ? '3D 效果' : '3D 已关';
    canvas.classList.toggle('is-ready', on);
    if (on) {
      if (started) { applyTheme(); renderer.render(scene, camera); start(); }
    } else {
      stop();
    }
  }

  function boot() {
    if (started) return;
    try {
      build();
      applyTheme();
      resize();
      renderer.render(scene, camera); // 先画一帧静态，再淡入，避免闪白
    } catch (e) {
      // WebGL 不可用 / 上下文创建失败：官网保持原样，按钮也不显示
      try { canvas.style.display = 'none'; } catch (e2) {}
      return;
    }
    started = true;

    if (toggle) {
      toggle.classList.add('is-on');
      toggle.addEventListener('click', function () { setEnabled(!enabled); });
    }
    setEnabled(enabled);

    window.addEventListener('resize', function () {
      small = window.innerWidth < 720;
      tilt.position.set(small ? 0 : 3.8, small ? 2.35 : 0.95, 0);
      tilt.scale.setScalar(small ? 0.46 : 0.72);
      resize();
      if (!running) renderer.render(scene, camera);
    });

    if (!reduceMotion) {
      hero.addEventListener('pointermove', function (e) {
        var r = hero.getBoundingClientRect();
        pointerX = ((e.clientX - r.left) / r.width - 0.5) * 2;
        pointerY = ((e.clientY - r.top) / r.height - 0.5) * 2;
      }, { passive: true });
      hero.addEventListener('pointerleave', function () {
        pointerX = 0; pointerY = 0;
      });
    }

    // 主题切换：main.js 只改属性、不派事件，所以这里必须观察属性
    try {
      new MutationObserver(function (muts) {
        for (var i = 0; i < muts.length; i++) {
          if (muts[i].attributeName === 'data-theme') {
            applyTheme();
            if (!running) renderer.render(scene, camera);
            break;
          }
        }
      }).observe(document.documentElement,
        { attributes: true, attributeFilter: ['data-theme'] });
    } catch (e) {}

    // 只在 hero 可见、页面可见时渲染
    document.addEventListener('visibilitychange', function () {
      if (document.hidden) stop(); else start();
    });
    try {
      new IntersectionObserver(function (entries) {
        inView = entries[0].isIntersecting;
        if (inView) start(); else stop();
      }, { threshold: 0 }).observe(hero);
    } catch (e) {}

    canvas.addEventListener('webglcontextlost', function (e) {
      e.preventDefault(); stop();
    });
    canvas.addEventListener('webglcontextrestored', function () {
      if (started) { applyTheme(); renderer.render(scene, camera); start(); }
    });

    start();
  }

  // 首屏内容先渲染完再初始化，别和图片/字体抢带宽
  if (document.readyState === 'complete') {
    setTimeout(boot, 120);
  } else {
    window.addEventListener('load', function () { setTimeout(boot, 120); });
  }
})();
