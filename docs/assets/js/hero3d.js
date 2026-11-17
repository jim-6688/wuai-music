/* ═══════════════════════════════════════════════════════════════════════════
   首屏 3D 背景 —— 四种可视化风格（three.js r149，本地 vendor）

   四种风格与 App 里的 visualize 枚举**一一对应**（真源
   `lib/features/player/widgets/audio_visualizer.dart` 的 VisualizerStyle，
   顺序也照抄：aurora / vinyl / nebula / fountain）：
     · aurora   液态极光 —— 多层流体光带
     · vinyl    黑胶唱片 —— 封面随唱片旋转（默认，也是 App 的默认档）
     · nebula   星云律动 —— 柱状频谱 + 倒影
     · fountain 音乐喷泉 —— 中央水柱 + 喷溅

   这里不是像素级复刻 App 的 CustomPainter：官网是 3D 语境，二维光带平铺
   在透视空间里会很薄。所以四种都在三维里重建，但保留各自的**识别特征**
   （极光=交叠光带、黑胶=同心沟槽、星云=柱阵+倒影、喷泉=粒子抛物），
   让看过 App 的人一眼能对上。

   设计约束（都来自官网现有门面，不要轻易改）：
   · 画布完全透明：hero::before 的紫色辉光和 hero__rule 的网格底纹要透出来；
   · 配色**不硬编码**，实时读 CSS 变量 --brand / --brand-2 —— 官网真源是品牌紫，
     且用户手动切深墨主题时 3D 必须一起变（MutationObserver 监听 data-theme）；
   · 不阻塞首屏：three.min.js 与本文件都 defer，等 window.load 后再延迟初始化；
   · 可降级：WebGL 不可用 / 上下文丢失 / three.js 没加载 → 静默隐藏，官网原样；
   · 可关闭：右下角小胶囊，偏好写 localStorage('wuai-hero3d')；
   · 可切换：左下角四个 chip，偏好写 localStorage('wuai-hero3d-style')，
     也接受 `?viz=aurora` 直达（分享链接 / 截图调试用）；
   · 省电：页面隐藏、hero 滚出视口、reduced-motion 时都停渲染；只更新可见场景，
     非当前风格**不建**（首屏只创建一种，切换时才建下一个）。
   ═══════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  var canvas = document.getElementById('hero3d');
  var hero = document.querySelector('.hero');
  var toggle = document.getElementById('hero3dToggle');
  var toggleLabel = document.getElementById('hero3dToggleLabel');
  var picker = document.getElementById('hero3dPicker');
  if (!canvas || !hero || typeof window.THREE === 'undefined') return;

  var T = window.THREE;
  var KEY = 'wuai-hero3d';
  var STYLE_KEY = 'wuai-hero3d-style';

  /* 顺序 = App 枚举顺序。改这里要同步 visualizer_style_provider 的默认值与
     audio_visualizer.dart 的枚举，否则两端"第几档"对不上。 */
  var STYLES = ['aurora', 'vinyl', 'nebula', 'fountain'];
  var DEFAULT_STYLE = 'vinyl';

  var enabled = true;
  try { enabled = localStorage.getItem(KEY) !== 'off'; } catch (e) {}

  var style = DEFAULT_STYLE;
  try {
    var saved = localStorage.getItem(STYLE_KEY);
    if (saved && STYLES.indexOf(saved) >= 0) style = saved;
  } catch (e) {}
  // ?viz=xxx 优先级最高：分享链接和截图脚本都靠它直达某一档
  try {
    var qs = new URLSearchParams(window.location.search).get('viz');
    if (qs && STYLES.indexOf(qs) >= 0) style = qs;
  } catch (e) {}

  var reduceMotion = false;
  try {
    reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  } catch (e) {}
  var small = window.innerWidth < 720;

  var renderer, scene, camera, pivot;
  var built = {};       // name -> { group, update, theme, layout }
  var active = null;    // 当前风格名
  var raf = 0, running = false, inView = true, last = 0, started = false;
  var pointerX = 0, pointerY = 0, curX = 0, curY = 0;
  var clockT = 0;       // 场景内累计秒数（与 wall clock 解耦，暂停即停）

  function cssVar(name, fallback) {
    try {
      var v = getComputedStyle(document.documentElement)
        .getPropertyValue(name).trim();
      return v || fallback;
    } catch (e) { return fallback; }
  }

  /* 浅色主题下所有发光效果都要收敛：加法混合在贝壳白底上会把粒子"加"成白色，
     等于没画；所以浅色走普通混合，并把整体透明度压下来。dark 这个字段就是
     全站的开关，各场景 theme() 都按它分支。 */
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
      ring: dark ? 0.42 : 0.35,
      // 新场景的整体透明度：浅色下纸面比夜底"吃"光，同样的 alpha 会显脏
      boost: dark ? 1.0 : 0.80
    };
  }

  function color(hex, fallback) {
    try { return new T.Color(hex); } catch (e) { return new T.Color(fallback); }
  }

  function blendFor(dark) {
    return dark ? T.AdditiveBlending : T.NormalBlending;
  }

  /* ── 场景 ① 液态极光 ────────────────────────────────────────────────
     五条沿 X 轴流动的光带。每条都是 1 段 × 110 段的细长面片，顶点着色器
     按三组不同频率的正弦把面片扭成波浪，片元按"距带心的距离"衰减，于是
     看起来是有体积的光，而不是一条纸带。

     为什么必须多条且参数错开：参数一致就是五张平行面片，一眼假；错开后
     交叠处自然叠亮，才是 App 里那种"多层流体光带"。 */
  var AURORA_VERT = [
    'uniform float uTime;',
    'uniform float uPhase;',
    'uniform float uSeed;',
    'uniform float uAmp;',
    'varying vec2 vUv;',
    'void main() {',
    '  vUv = uv;',
    '  vec3 p = position;',
    '  float x = uv.x;',
    '  float w = sin(x * 6.2831 + uTime * 0.36 + uPhase) * 0.55',
    '          + sin(x * 14.46 - uTime * 0.22 + uPhase * 1.7) * 0.26',
    '          + sin(x * 29.53 + uTime * 0.51 + uSeed) * 0.11;',
    '  p.y += w * uAmp;',
    '  p.z += sin(x * 10.68 + uTime * 0.29 + uPhase) * 0.34;',
    '  gl_Position = projectionMatrix * modelViewMatrix * vec4(p, 1.0);',
    '}'
  ].join('\n');

  var AURORA_FRAG = [
    'uniform vec3 uColorA;',
    'uniform vec3 uColorB;',
    'uniform float uTime;',
    'uniform float uAlpha;',
    'varying vec2 vUv;',
    'void main() {',
    // 两端散尽：15 宽的面片不能硬切在画布边上
    '  float ex = smoothstep(0.0, 0.17, vUv.x) * smoothstep(1.0, 0.83, vUv.x);',
    // 纵向：中间实、上下散 → 光带体积感
    '  float d = abs(vUv.y - 0.5) * 2.0;',
    '  float ey = pow(max(0.0, 1.0 - d), 1.7);',
    // 光芯：带子正中叠一道更亮的线。只有软边没有芯，五条叠起来就是一坨雾
    '  float core = pow(max(0.0, 1.0 - d * 3.0), 3.0);',
    // 沿长度方向流动的明暗，让它"在流"而不是"在飘"
    '  float flow = 0.58 + 0.42 * sin(vUv.x * 9.2 - uTime * 1.05);',
    '  vec3 col = mix(uColorA, uColorB, smoothstep(0.1, 0.9, vUv.x));',
    '  float a = (ey * 0.72 + core * 0.62) * ex * flow * uAlpha;',
    '  gl_FragColor = vec4(col + core * 0.10, a);',
    '}'
  ].join('\n');

  function buildAurora() {
    var g = new T.Group();
    g.rotation.z = -0.15;
    g.rotation.x = -0.10;

    // sc 是带子的"厚度"（纵向缩放）。2.0 以上五条必定叠成一团雾 ——
    // 光带要像带子就得薄：1.1~1.6，靠条数而不是靠厚度堆密度。
    var cfg = [
      { y: -1.34, amp: 0.34, sc: 1.15, a: 0.62, sp: 1.00 },
      { y: -0.66, amp: 0.46, sc: 1.45, a: 0.78, sp: 1.18 },
      { y: 0.04, amp: 0.52, sc: 1.62, a: 0.84, sp: 0.86 },
      { y: 0.72, amp: 0.44, sc: 1.38, a: 0.72, sp: 1.34 },
      { y: 1.36, amp: 0.32, sc: 1.10, a: 0.56, sp: 1.10 }
    ];
    var n = small ? 4 : 5;
    var bands = [];
    for (var i = 0; i < n; i++) {
      var c = cfg[i];
      var mat = new T.ShaderMaterial({
        transparent: true, depthWrite: false, depthTest: false,
        side: T.DoubleSide, blending: T.AdditiveBlending,
        uniforms: {
          uTime: { value: 0 },
          uPhase: { value: 1.73 * i + 0.6 },
          uSeed: { value: 0.91 * i },
          uAmp: { value: c.amp },
          uAlpha: { value: c.a },
          uColorA: { value: new T.Color(0x7b45c9) },
          uColorB: { value: new T.Color(0x5b2c9e) }
        },
        vertexShader: AURORA_VERT, fragmentShader: AURORA_FRAG
      });
      var mesh = new T.Mesh(new T.PlaneGeometry(10, 1, 110, 1), mat);
      mesh.position.set(0, c.y, i * 0.16);
      mesh.scale.y = c.sc;
      g.add(mesh);
      bands.push({ mat: mat, sp: c.sp, base: c.a });
    }

    return {
      group: g,
      theme: function (p) {
        var c1 = color(p.brand, '#7b45c9');
        var c2 = color(p.brand2, '#5b2c9e');
        for (var i = 0; i < bands.length; i++) {
          var u = bands[i].mat.uniforms;
          u.uColorA.value.copy(c1);
          u.uColorB.value.copy(c2);
          u.uAlpha.value = bands[i].base * p.boost;
          bands[i].mat.blending = blendFor(p.dark);
          bands[i].mat.needsUpdate = true;
        }
      },
      // 每组带子速度不同：整体一起动会像一张抖动的床单
      update: function (dt) {
        for (var i = 0; i < bands.length; i++) {
          bands[i].mat.uniforms.uTime.value += dt * bands[i].sp;
        }
      },
      layout: function () {
        // 桌面落在正文右侧（正文右边界约 x = +2.2），不要压住段落
        g.position.set(small ? 0 : 4.35, small ? 1.95 : 0.55, 0);
        g.scale.setScalar(small ? 0.50 : 0.66);
      }
    };
  }

  /* ── 场景 ② 黑胶唱片（原有实现，只是搬进场景接口） ───────────────── */

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

  function buildVinyl() {
    var g = new T.Group();
    g.rotation.x = -0.42;
    g.rotation.z = -0.12;

    var disc = new T.Group();
    g.add(disc);

    // 盘体（薄圆柱，翻 90° 让圆面正对相机）
    var bodyMat = new T.MeshStandardMaterial({
      color: 0x15121a, roughness: 0.46, metalness: 0.5,
      transparent: true, opacity: 0.5
    });
    var body = new T.Mesh(new T.CylinderGeometry(2.35, 2.35, 0.06, 96), bodyMat);
    body.rotation.x = Math.PI / 2;
    disc.add(body);

    var grooveMat = new T.ShaderMaterial({
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

    var labelMat = new T.MeshBasicMaterial({
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

    var ringMat = new T.MeshBasicMaterial({
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
    var pointsMat = new T.PointsMaterial({
      color: 0x7b45c9, size: small ? 0.045 : 0.055,
      transparent: true, opacity: 0.5, sizeAttenuation: true,
      depthWrite: false
    });
    var particles = new T.Points(geo, pointsMat);
    // ⚠️ 星尘不进 disc：它不能跟着唱片转。由 extra 挂到 scene 上，
    //    切场景时跟 group 一起显示/隐藏（见 ensure / showScene）。

    var ambient = new T.AmbientLight(0xffffff, 0.85);
    var keyLight = new T.DirectionalLight(0x7b45c9, 1.1);
    keyLight.position.set(3, 4, 6);
    var rimLight = new T.DirectionalLight(0x5b2c9e, 0.6);
    rimLight.position.set(-4, -2, 3);

    return {
      group: g,
      // 星尘与灯要单独持有引用，切场景时跟着可见性走
      extra: [particles, ambient, keyLight, rimLight],
      theme: function (p) {
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
        pointsMat.blending = blendFor(p.dark);
        pointsMat.needsUpdate = true;
        keyLight.color.copy(c1);
        rimLight.color.copy(c2);
      },
      update: function (dt, t) {
        disc.rotation.z += dt * 0.16;
        grooveMat.uniforms.uTime.value += dt;
        particles.rotation.z += dt * 0.006;
        particles.position.y = Math.sin(t * 0.18) * 0.12;
      },
      layout: function () {
        g.position.set(small ? 0 : 3.8, small ? 2.35 : 0.95, 0);
        g.scale.setScalar(small ? 0.46 : 0.72);
      }
    };
  }

  /* ── 场景 ③ 星云律动 ────────────────────────────────────────────────
     一排柱子沿弧线排开、朝向相机，底部固定、顶部按伪频谱上下跳；下方是
     同一组柱子的镜像（低透明度），就是 App 里"柱状频谱 + 倒影"的 3D 版。

     用 InstancedMesh 而不是 40 个 Mesh：一次 draw call，每帧只改矩阵。
     ⚠️ 自定义 ShaderMaterial 配 InstancedMesh 时，必须在顶点着色器里自己
        乘 instanceMatrix —— three 只给内置材质自动加这一步。 */
  var NEBULA_VERT = [
    'varying vec2 vUv;',
    'void main() {',
    '  vUv = uv;',
    '  vec4 mv = vec4(position, 1.0);',
    '  #ifdef USE_INSTANCING',
    '    mv = instanceMatrix * mv;',
    '  #endif',
    '  gl_Position = projectionMatrix * modelViewMatrix * mv;',
    '}'
  ].join('\n');

  var NEBULA_FRAG = [
    'uniform vec3 uColor;',
    'uniform vec3 uColor2;',
    'uniform float uOpacity;',
    'varying vec2 vUv;',
    'void main() {',
    '  float y = clamp(vUv.y, 0.0, 1.0);',
    // 底部实、顶端虚；再给柱头一道高光，才有"被点亮"的感觉
    '  float a = 0.10 + 0.90 * pow(y, 0.70);',
    '  float tip = smoothstep(0.88, 1.0, y) * 0.45;',
    '  vec3 col = mix(uColor2, uColor, y) + tip;',
    '  gl_FragColor = vec4(col, a * uOpacity);',
    '}'
  ].join('\n');

  function buildNebula() {
    var g = new T.Group();
    var count = small ? 20 : 34;
    var R = 5.6;          // 弧半径
    var span = 1.52;      // 弧度跨度（±0.76）
    var baseY = -1.55;

    var geo = new T.PlaneGeometry(0.175, 1.0);
    // 原点挪到底部：这样 scale.y = h 就是"从地面往上长到 h"
    geo.translate(0, 0.5, 0);

    var seeds = [];
    for (var i = 0; i < count; i++) seeds.push(Math.random() * 6.2832);

    function makeBars(opacity) {
      var mat = new T.ShaderMaterial({
        transparent: true, depthWrite: false, side: T.DoubleSide,
        blending: T.AdditiveBlending,
        uniforms: {
          uColor: { value: new T.Color(0x9c74e8) },
          uColor2: { value: new T.Color(0x4a1a96) },
          uOpacity: { value: opacity }
        },
        vertexShader: NEBULA_VERT, fragmentShader: NEBULA_FRAG
      });
      var m = new T.InstancedMesh(geo, mat, count);
      m.instanceMatrix.setUsage(T.DynamicDrawUsage);
      m.frustumCulled = false;   // 矩阵每帧变，包围盒不可信
      return m;
    }

    var bars = makeBars(0.95);
    var refl = makeBars(0.22);
    g.add(bars);
    g.add(refl);

    var dummy = new T.Object3D();

    function place(mesh, i, a, h, mirror) {
      var x = Math.sin(a) * R;
      var z = (Math.cos(a) - 1) * R;
      dummy.position.set(x, mirror ? baseY - 0.012 : baseY, z);
      dummy.rotation.set(0, -a, 0);
      // 倒影用负 scale.y：几何翻到地面以下，uv.y 也跟着翻，
      // 于是"靠水面的一端亮"这个渐变自动成立
      dummy.scale.set(1, mirror ? -h * 0.86 : h, 1);
      dummy.updateMatrix();
      mesh.setMatrixAt(i, dummy.matrix);
    }

    return {
      group: g,
      theme: function (p) {
        var mats = [bars.material, refl.material];
        for (var i = 0; i < mats.length; i++) {
          mats[i].uniforms.uColor.value.copy(color(p.brand, '#7b45c9'));
          mats[i].uniforms.uColor2.value.copy(color(p.brand2, '#5b2c9e'));
          mats[i].blending = blendFor(p.dark);
          mats[i].needsUpdate = true;
        }
        bars.material.uniforms.uOpacity.value = 0.95 * p.boost;
        refl.material.uniforms.uOpacity.value = 0.24 * p.boost;
      },
      update: function (dt, t) {
        for (var i = 0; i < count; i++) {
          var u = count > 1 ? i / (count - 1) : 0.5;
          var a = (u - 0.5) * span;
          // 包络：中间高两端低，跟真实频谱的能量分布一致
          var env = 0.30 + 0.70 * Math.cos((u - 0.5) * Math.PI * 1.06);
          // 三组不同频率的正弦叠加 = 平滑但不规律的跳动（不需要真频谱）
          var s = 0.5 +
            0.28 * Math.sin(t * 1.7 + seeds[i]) +
            0.18 * Math.sin(t * 3.3 + seeds[i] * 2.1) +
            0.09 * Math.sin(t * 6.1 + seeds[i] * 3.7);
          var h = Math.max(0.07, (0.16 + s * 0.84) * env * 2.0);
          place(bars, i, a, h, false);
          place(refl, i, a, h, true);
        }
        bars.instanceMatrix.needsUpdate = true;
        refl.instanceMatrix.needsUpdate = true;
      },
      layout: function () {
        // 弧宽 7.6 × 0.50 = 3.8，落在正文右侧；倒影最深处约 y=-0.97，
        // 正好停在下方统计数字之上（不压 16 种 / 22 套 那一排）
        g.position.set(small ? 0 : 4.8, small ? 1.30 : 0.55, 0);
        g.scale.setScalar(small ? 0.44 : 0.50);
      }
    };
  }

  /* ── 场景 ④ 音乐喷泉 ────────────────────────────────────────────────
     一根中央水柱 + 一圈抛物线粒子 + 地面涟漪。粒子走真物理（初速 + 重力），
     不像"上下平移的点阵"；每颗粒子有独立寿命，落回池底就重发，密度才会
     随时间自然起伏。 */
  var POINT_VERT = [
    'uniform float uPR;',
    'attribute float aAlpha;',
    'attribute float aSize;',
    'varying float vAlpha;',
    'void main() {',
    '  vAlpha = aAlpha;',
    '  vec4 mv = modelViewMatrix * vec4(position, 1.0);',
    '  gl_PointSize = aSize * uPR * (120.0 / max(0.001, -mv.z));',
    '  gl_Position = projectionMatrix * mv;',
    '}'
  ].join('\n');

  var POINT_FRAG = [
    'uniform vec3 uColor;',
    'uniform float uOpacity;',
    'varying float vAlpha;',
    'void main() {',
    // 圆形软点：不用贴图，省一次纹理加载
    '  vec2 d = gl_PointCoord - 0.5;',
    '  float r = length(d) * 2.0;',
    '  if (r > 1.0) discard;',
    '  gl_FragColor = vec4(uColor, pow(1.0 - r, 1.8) * vAlpha * uOpacity);',
    '}'
  ].join('\n');

  var COLUMN_VERT = [
    'varying vec2 vUv;',
    'void main() {',
    '  vUv = uv;',
    '  gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);',
    '}'
  ].join('\n');

  var COLUMN_FRAG = [
    'uniform vec3 uColor;',
    'uniform float uTime;',
    'uniform float uOpacity;',
    'varying vec2 vUv;',
    'void main() {',
    // 竖直流动的亮纹：水柱在"走"，不是一根静止的柱子
    '  float s = 0.5 + 0.5 * sin(vUv.y * 26.0 - uTime * 5.2);',
    // 侧面正对相机处最亮（uv.x 绕一圈，取两倍频的余弦）
    '  float side = 0.55 + 0.45 * cos((vUv.x - 0.5) * 12.566);',
    '  float fade = smoothstep(0.0, 0.08, vUv.y) *',
    '               (1.0 - smoothstep(0.82, 1.0, vUv.y) * 0.90);',
    '  gl_FragColor = vec4(uColor, (0.34 + 0.42 * s) * side * fade * uOpacity);',
    '}'
  ].join('\n');

  function buildFountain() {
    var g = new T.Group();
    var PCOUNT = small ? 150 : 340;
    var GRAV = 6.4;
    var FLOOR = -1.78;

    var pos = new Float32Array(PCOUNT * 3);
    var vel = new Float32Array(PCOUNT * 3);
    var alpha = new Float32Array(PCOUNT);
    var size = new Float32Array(PCOUNT);
    var life = new Float32Array(PCOUNT);
    var span = new Float32Array(PCOUNT);   // 生命总长（算淡入淡出用）

    function spawn(i) {
      // 出发点聚在中心附近：柱心喷得高、外圈散，靠初速差异自然分层
      var r = Math.pow(Math.random(), 0.55) * 0.42;
      var ang = Math.random() * 6.2832;
      pos[i * 3] = Math.cos(ang) * r;
      pos[i * 3 + 1] = FLOOR;
      pos[i * 3 + 2] = Math.sin(ang) * r;
      var spread = 1.15 + r * 2.6;
      vel[i * 3] = Math.cos(ang) * spread * (0.5 + Math.random() * 0.6);
      vel[i * 3 + 1] = 4.2 + Math.random() * 1.6 - r * 1.2;
      vel[i * 3 + 2] = Math.sin(ang) * spread * (0.5 + Math.random() * 0.6);
      span[i] = 0.85 + Math.random() * 0.85;
      // 初始寿命 0 = 第一帧就重发，粒子从底部陆续升空（不会开局全堆在池底）
      life[i] = 0;
      alpha[i] = 0;
      size[i] = 0.85 + Math.random() * 0.85;
    }
    for (var i = 0; i < PCOUNT; i++) spawn(i);

    var geo = new T.BufferGeometry();
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    geo.setAttribute('aAlpha', new T.BufferAttribute(alpha, 1));
    geo.setAttribute('aSize', new T.BufferAttribute(size, 1));
    geo.boundingSphere = new T.Sphere(new T.Vector3(0, 0, 0), 12);

    var pointMat = new T.ShaderMaterial({
      transparent: true, depthWrite: false, blending: T.AdditiveBlending,
      uniforms: {
        uPR: { value: 1 },
        uColor: { value: new T.Color(0x9c74e8) },
        uOpacity: { value: 0.9 }
      },
      vertexShader: POINT_VERT, fragmentShader: POINT_FRAG
    });
    var points = new T.Points(geo, pointMat);

    var colMat = new T.ShaderMaterial({
      transparent: true, depthWrite: false, side: T.DoubleSide,
      uniforms: {
        uTime: { value: 0 },
        uColor: { value: new T.Color(0x7b45c9) },
        uOpacity: { value: 0.85 }
      },
      vertexShader: COLUMN_VERT, fragmentShader: COLUMN_FRAG
    });
    var column = new T.Mesh(
      new T.CylinderGeometry(0.11, 0.19, 2.60, 22, 1, true), colMat
    );
    column.position.y = FLOOR + 1.30;
    g.add(column);
    g.add(points);

    // 地面涟漪：三圈错相位的环，一起呼吸不会像呼吸灯那样呆
    var ripples = [];
    for (var k = 0; k < 3; k++) {
      var rm = new T.MeshBasicMaterial({
        color: 0x7b45c9, transparent: true, opacity: 0.2,
        side: T.DoubleSide, depthWrite: false
      });
      var mesh = new T.Mesh(new T.RingGeometry(0.52, 0.60, 56), rm);
      mesh.rotation.x = -Math.PI / 2;
      mesh.position.y = FLOOR + 0.01;
      g.add(mesh);
      ripples.push({ mesh: mesh, mat: rm, phase: k / 3 });
    }

    function step(dt, t) {
      colMat.uniforms.uTime.value += dt;
      for (var i = 0; i < PCOUNT; i++) {
        var j = i * 3;
        life[i] -= dt;
        if (life[i] <= 0 || pos[j + 1] < FLOOR) { spawn(i); life[i] = span[i]; continue; }
        vel[j + 1] -= GRAV * dt;
        pos[j] += vel[j] * dt;
        pos[j + 1] += vel[j + 1] * dt;
        pos[j + 2] += vel[j + 2] * dt;
        // 淡入 12% / 淡出 40%：硬弹出会像雪花飘
        var u = 1 - life[i] / span[i];
        alpha[i] = Math.min(u / 0.12, 1) * Math.min((1 - u) / 0.40, 1) * 0.95;
      }
      geo.attributes.position.needsUpdate = true;
      geo.attributes.aAlpha.needsUpdate = true;

      for (var r = 0; r < ripples.length; r++) {
        var rp = ripples[r];
        var ph = ((t * 0.42 + rp.phase) % 1);
        var sc = 0.5 + ph * 2.9;
        rp.mesh.scale.set(sc, sc, sc);
        rp.mat.opacity = Math.pow(1 - ph, 2.0) * 0.30 * pointMat.uniforms.uOpacity.value;
      }
    }

    // 预热 2 秒。不预热的话首屏刚打开时粒子全在池底，要两三秒才"喷起来"，
    // 而且静态截图永远抓不到成型的伞状 —— 预热后第一帧就是稳态。
    for (var w = 0; w < 120; w++) step(1 / 60, w / 60);

    return {
      group: g,
      theme: function (p) {
        var c = color(p.brand, '#7b45c9');
        var c2 = color(p.brand2, '#5b2c9e');
        pointMat.uniforms.uColor.value.copy(c);
        pointMat.uniforms.uOpacity.value = 0.95 * p.boost;
        pointMat.blending = blendFor(p.dark);
        pointMat.needsUpdate = true;
        colMat.uniforms.uColor.value.copy(c2);
        colMat.uniforms.uOpacity.value = 0.9 * p.boost;
        for (var i = 0; i < ripples.length; i++) {
          ripples[i].mat.color.copy(c);
          ripples[i].mat.opacity = 0.22 * p.boost;
          ripples[i].mat.blending = blendFor(p.dark);
          ripples[i].mat.needsUpdate = true;
        }
      },
      update: step,
      layout: function () {
        g.position.set(small ? 0 : 4.15, small ? 2.10 : 0.15, 0);
        g.scale.setScalar(small ? 0.46 : 0.85);
        pointMat.uniforms.uPR.value = Math.min(window.devicePixelRatio || 1, 2);
      }
    };
  }

  var BUILDERS = {
    aurora: buildAurora,
    vinyl: buildVinyl,
    nebula: buildNebula,
    fountain: buildFountain
  };

  /* ── 场景管理 ─────────────────────────────────────────────────────── */

  function ensure(name) {
    if (built[name]) return built[name];
    var s = BUILDERS[name]();
    s.group.visible = false;
    pivot.add(s.group);
    // 星尘 / 灯光这类不属于 group 的部件，用各自的 visible 跟着切
    if (s.extra) {
      for (var i = 0; i < s.extra.length; i++) {
        s.extra[i].visible = false;
        scene.add(s.extra[i]);
      }
    }
    s.theme(palette());
    s.layout();
    built[name] = s;
    return s;
  }

  function showScene(name, vis) {
    var s = built[name];
    if (!s) return;
    s.group.visible = vis;
    if (s.extra) {
      for (var i = 0; i < s.extra.length; i++) s.extra[i].visible = vis;
    }
  }

  function paint() {
    if (started) renderer.render(scene, camera);
  }

  function syncChips() {
    if (!picker) return;
    var chips = picker.querySelectorAll('[data-viz]');
    for (var i = 0; i < chips.length; i++) {
      var on = chips[i].getAttribute('data-viz') === active;
      chips[i].classList.toggle('is-active', on);
      chips[i].setAttribute('aria-pressed', on ? 'true' : 'false');
    }
  }

  function setStyle(name, opts) {
    if (STYLES.indexOf(name) < 0) name = DEFAULT_STYLE;
    if (name === active) { syncChips(); paint(); return; }
    var s = ensure(name);
    if (active) showScene(active, false);
    showScene(name, true);
    active = name;
    s.theme(palette());
    s.layout();
    syncChips();
    try { localStorage.setItem(STYLE_KEY, name); } catch (e) {}
    // 停着的时候切换也要立刻看到结果（否则要等下一次 start）
    if (!running) paint();
    if (opts && opts.announce) {
      // 只在用户点击时更新，初始化不算"操作"
    }
  }

  /* ── 初始化 ───────────────────────────────────────────────────────── */

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

    // pivot 只吃鼠标视差；各场景自己的基础倾角写在 scene.group 里，
    // 免得柱阵 / 喷泉被唱片的 -0.42 弧度带着一起歪。
    pivot = new T.Group();
    scene.add(pivot);
  }

  function applyTheme() {
    var p = palette();
    for (var k in built) {
      if (built.hasOwnProperty(k)) built[k].theme(p);
    }
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
    if (small !== (window.innerWidth < 720)) {
      small = window.innerWidth < 720;
      for (var k in built) {
        if (built.hasOwnProperty(k)) built[k].layout();
      }
    }
  }

  function frame(ts) {
    if (!running) return;
    raf = requestAnimationFrame(frame);
    var dt = last ? Math.min((ts - last) / 1000, 0.05) : 0;
    last = ts;
    clockT += dt;
    var s = built[active];
    if (s) s.update(dt, clockT);
    curX += (pointerX - curX) * 0.045;
    curY += (pointerY - curY) * 0.045;
    pivot.rotation.y = curX * 0.12;
    pivot.rotation.x = curY * 0.08;
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
    // 关掉 3D 时风格选择器必须一起收起，否则点了没反应像是坏了
    if (picker) picker.hidden = !on;
    if (on) {
      if (started) { applyTheme(); paint(); start(); }
    } else {
      stop();
    }
  }

  function bindPicker() {
    if (!picker) return;
    picker.addEventListener('click', function (e) {
      var btn = e.target.closest ? e.target.closest('[data-viz]') : null;
      if (!btn) return;
      setStyle(btn.getAttribute('data-viz'), { announce: true });
      start();
    });
    // 键盘左右键在 chip 之间移动（遥控器 / 无鼠标场景也能用）
    picker.addEventListener('keydown', function (e) {
      var key = e.key;
      if (key !== 'ArrowLeft' && key !== 'ArrowRight') return;
      var chips = Array.prototype.slice.call(picker.querySelectorAll('[data-viz]'));
      var at = chips.indexOf(document.activeElement);
      if (at < 0) return;
      e.preventDefault();
      var next = chips[(at + (key === 'ArrowRight' ? 1 : chips.length - 1)) % chips.length];
      next.focus();
      setStyle(next.getAttribute('data-viz'), { announce: true });
    });
  }

  function boot() {
    if (started) return;
    try {
      build();
      ensure(style);
      showScene(style, true);
      active = style;
      applyTheme();
      resize();
      renderer.render(scene, camera); // 先画一帧静态，再淡入，避免闪白
    } catch (e) {
      // WebGL 不可用 / 上下文创建失败：官网保持原样，按钮也不显示
      try { canvas.style.display = 'none'; } catch (e2) {}
      try { if (toggle) toggle.remove(); } catch (e3) {}
      try { if (picker) picker.remove(); } catch (e4) {}
      return;
    }
    started = true;

    if (toggle) {
      toggle.classList.add('is-on');
      toggle.addEventListener('click', function () { setEnabled(!enabled); });
    }
    syncChips();
    bindPicker();
    setEnabled(enabled);

    window.addEventListener('resize', resize);

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
            paint();
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
      if (started) { applyTheme(); paint(); start(); }
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
