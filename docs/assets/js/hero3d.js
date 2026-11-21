/* ═══════════════════════════════════════════════════════════════════════════
   首屏 3D 背景 —— 官网展示三种可视化（three.js r149，本地 vendor）

   官网只展示 aurora / vinyl / nebula 三种：
     · aurora   液态极光 —— 多层流体光带，压在标题下方
     · vinyl    黑胶唱片 —— 单独旋转的唱片，放在右侧（默认）
     · nebula   星云律动 —— 柱状频谱 + 倒影，压在标题下方

   App 里仍有四档（另有音乐喷泉），但官网首屏不再复刻喷泉。这里不是像素级
   复刻 App 的 CustomPainter：官网是 3D 语境，二维光带平铺在透视空间里会很薄。
   三种都在三维里重建，但保留各自的识别特征（极光=交叠光带、黑胶=同心沟槽、
   星云=柱阵+倒影），让看过 App 的人一眼能对上。

   设计约束（都来自官网现有门面，不要轻易改）：
   · 画布完全透明：hero::before 的紫色辉光和 hero__rule 的网格底纹要透出来；
   · 配色**不硬编码**，实时读 CSS 变量 --brand / --brand-2 —— 官网真源是品牌紫，
     且用户手动切深墨主题时 3D 必须一起变（MutationObserver 监听 data-theme）；
   · 不阻塞首屏：three.min.js 与本文件都 defer，等 window.load 后再延迟初始化；
   · 可降级：WebGL 不可用 / 上下文丢失 / three.js 没加载 → 静默隐藏，官网原样；
   · 可关闭：右下角小胶囊，偏好写 localStorage('wuai-hero3d')；
   · 可切换：下方三个 chip，偏好写 localStorage('wuai-hero3d-style')，
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
  var STYLES = ['aurora', 'vinyl', 'nebula'];
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
        // 极光横向拉宽、上移到标题一带，作为更宽的标题底光
        g.position.set(0, small ? -0.10 : -0.22, -0.6);
        g.scale.set(small ? 0.62 : 0.92, small ? 0.34 : 0.52, small ? 0.34 : 0.52);
      }
    };
  }

  /* ── 场景 ② 黑胶唱片：只留唱片本体 ──────────────────────────────────
     App 的黑胶核心是深色盘面 + 细密同心沟槽 + 随转高光 + 盘心纸标。
     官网首屏不摆唱机底座与唱臂：只保留唱片本体，旋转更干净，也和另外
     三档抽象可视化保持同一层视觉语言。盘面用 CanvasTexture 一次画完。 */

  function makeDiscTexture(p) {
    var c = document.createElement('canvas');
    c.width = c.height = 1024;
    var x = c.getContext('2d');
    if (!x) return null;
    var cx = 512, cy = 512, R = 512;

    // 盘面底色：不是纯黑（纯黑在白底上是个洞），而是压暗的暖黑
    var g = x.createRadialGradient(cx, cy, 40, cx, cy, R);
    g.addColorStop(0, '#2b211f');
    g.addColorStop(0.55, '#1a1413');
    g.addColorStop(1, '#0c0908');
    x.fillStyle = g;
    x.fillRect(0, 0, c.width, c.height);

    x.save();
    x.beginPath();
    x.arc(cx, cy, R - 1, 0, Math.PI * 2);
    x.clip();

    // 沟槽：明暗交替的亚像素细线，外圈更密；数量多但每条很淡
    for (var i = 0; i < 88; i++) {
      var t = i / 87;
      var rr = 226 + (500 - 226) * Math.pow(t, 0.86);
      x.beginPath();
      x.arc(cx, cy, rr, 0, Math.PI * 2);
      x.strokeStyle = (i % 2 === 0)
        ? 'rgba(255,255,255,' + (0.13 - t * 0.05).toFixed(3) + ')'
        : 'rgba(0,0,0,' + (0.30 - t * 0.10).toFixed(3) + ')';
      x.lineWidth = (i % 2 === 0) ? 1.6 : 2.2;
      x.stroke();
    }

    // 随盘面一起转的一道柔和反光
    x.save();
    x.translate(cx, cy);
    x.rotate(-0.42);
    var sg = x.createLinearGradient(0, -R, 0, R);
    sg.addColorStop(0, 'rgba(255,255,255,0)');
    sg.addColorStop(0.34, 'rgba(255,255,255,0.05)');
    sg.addColorStop(0.50, 'rgba(255,255,255,0.18)');
    sg.addColorStop(0.66, 'rgba(255,255,255,0.05)');
    sg.addColorStop(1, 'rgba(255,255,255,0)');
    x.fillStyle = sg;
    x.beginPath();
    x.moveTo(0, 0);
    x.arc(0, 0, R, -0.52, 0.52);
    x.closePath();
    x.fill();
    x.restore();
    x.restore();

    // 盘心纸标：品牌色渐变 + 金边，不再画方形封面
    var labelR = 195;
    var lg = x.createRadialGradient(cx - 30, cy - 40, 10, cx, cy, labelR);
    lg.addColorStop(0, p.brand2 || '#5b2c9e');
    lg.addColorStop(1, p.brand || '#7b45c9');
    x.fillStyle = lg;
    x.beginPath();
    x.arc(cx, cy, labelR, 0, Math.PI * 2);
    x.fill();
    x.strokeStyle = 'rgba(255,226,168,0.72)';
    x.lineWidth = 4;
    x.stroke();

    // 盘心只留圆形纸标：两道细环 + 主轴孔，不放方形封面
    x.strokeStyle = 'rgba(255,255,255,0.22)';
    x.lineWidth = 2;
    x.beginPath();
    x.arc(cx, cy, labelR * 0.66, 0, Math.PI * 2);
    x.stroke();
    x.strokeStyle = 'rgba(255,226,168,0.30)';
    x.lineWidth = 1.5;
    x.beginPath();
    x.arc(cx, cy, labelR * 0.42, 0, Math.PI * 2);
    x.stroke();

    // 主轴孔
    x.fillStyle = '#f7f3ee';
    x.beginPath();
    x.arc(cx, cy, 17, 0, Math.PI * 2);
    x.fill();
    x.strokeStyle = 'rgba(0,0,0,0.35)';
    x.lineWidth = 2;
    x.stroke();

    var tex = new T.CanvasTexture(c);
    if (T.SRGBColorSpace && 'colorSpace' in tex) tex.colorSpace = T.SRGBColorSpace;
    else if (T.sRGBEncoding) tex.encoding = T.sRGBEncoding;
    tex.anisotropy = 4;
    return tex;
  }

  function buildVinyl() {
    var g = new T.Group();
    g.rotation.x = -0.55;
    g.rotation.z = -0.16;

    var p = palette();
    var discMat = new T.MeshBasicMaterial({
      map: makeDiscTexture(p), transparent: true, side: T.DoubleSide
    });
    var disc = new T.Mesh(new T.CircleGeometry(2.30, 128), discMat);
    g.add(disc);

    // 细沟槽环：只做微弱反光，不画成一圈圈明显的靶环
    for (var i = 0; i < 12; i++) {
      var r = 0.74 + i * 0.13;
      var rm = new T.MeshBasicMaterial({
        color: 0xf0e5d6, transparent: true,
        opacity: 0.040 + (i % 3) * 0.008,
        side: T.DoubleSide, depthWrite: false
      });
      var ring = new T.Mesh(new T.RingGeometry(r, r + 0.006, 128), rm);
      ring.position.z = 0.003;
      disc.add(ring);
    }

    // 盘缘一道很细的高光，让唱片与纸白背景分开
    var rim = new T.Mesh(
      new T.RingGeometry(2.28, 2.315, 128),
      new T.MeshBasicMaterial({
        color: 0xf3e9dd, transparent: true, opacity: 0.10,
        side: T.DoubleSide, depthWrite: false
      })
    );
    rim.position.z = 0.005;
    disc.add(rim);

    // 星尘：一个 Points，单 draw call；它不跟唱片转
    var count = small ? 72 : 190;
    var pos = new Float32Array(count * 3);
    for (var j = 0; j < count; j++) {
      pos[j * 3] = (Math.random() - 0.5) * 17;
      pos[j * 3 + 1] = (Math.random() - 0.5) * 10;
      pos[j * 3 + 2] = -2.5 + Math.random() * 3.5;
    }
    var geo = new T.BufferGeometry();
    geo.setAttribute('position', new T.BufferAttribute(pos, 3));
    var pointsMat = new T.PointsMaterial({
      color: p.brand, size: small ? 0.045 : 0.055,
      transparent: true, opacity: 0.5, sizeAttenuation: true,
      depthWrite: false
    });
    var particles = new T.Points(geo, pointsMat);

    var lastDark = null;
    return {
      group: g,
      extra: [particles],
      theme: function (p) {
        if (lastDark !== p.dark) {
          lastDark = p.dark;
          if (discMat.map) discMat.map.dispose();
          discMat.map = makeDiscTexture(p);
          discMat.needsUpdate = true;
        }
        pointsMat.color.copy(color(p.brand, '#7b45c9'));
        pointsMat.opacity = p.points;
        pointsMat.blending = blendFor(p.dark);
        pointsMat.needsUpdate = true;
      },
      update: function (dt, t) {
        // 约 9 秒一圈：比原来的 39 秒明显，但不晃眼
        disc.rotation.z += dt * 0.72;
        particles.rotation.z += dt * 0.006;
        particles.position.y = Math.sin(t * 0.18) * 0.12;
      },
      layout: function () {
        // 唱片单独放右侧，稍高、稍小，留出标题下方的极光 / 律动空间
        g.position.set(small ? 0 : 4.60, small ? 1.35 : 0.70, 0);
        g.scale.setScalar(small ? 0.40 : 0.62);
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
        bars.material.uniforms.uOpacity.value = 0.55 * p.boost;
        refl.material.uniforms.uOpacity.value = 0.15 * p.boost;
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
        // 星云律动同样加宽上移；柱阵铺得更开，倒影仍在正文之前
        g.position.set(0, small ? -0.10 : -0.18, -0.8);
        g.scale.set(small ? 0.46 : 0.64, small ? 0.28 : 0.36, small ? 0.28 : 0.36);
      }
    };
  }

  var BUILDERS = {
    aurora: buildAurora,
    vinyl: buildVinyl,
    nebula: buildNebula
  };

  /* ── 场景管理 ─────────────────────────────────────────────────────── */

  function ensure(name) {
    if (built[name]) return built[name];
    var s = BUILDERS[name]();
    s.group.visible = false;
    pivot.add(s.group);
    // 星尘这类不属于 group 的部件，用 visible 跟着切
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
