# 第三方组件声明

本项目主体源码采用 **MIT License**（见 [LICENSE](LICENSE)）。
本文件只记录**以二进制形式随应用分发、且许可证不是 MIT** 的第三方组件。

## FFmpeg（经 ffmpeg-kit 分发）

| 项 | 值 |
|---|---|
| 组件 | FFmpeg |
| Flutter 插件 | `ffmpeg_kit_flutter_new_min` **3.6.2**（`pubspec.lock`） |
| 实际原生产物 | **`com.antonkarpenko:ffmpeg-kit-min:2.2.2`** |
| 许可证 | **GNU Lesser General Public License v3.0（LGPL 3.0）** |
| 插件源码 | <https://github.com/sk3llo/ffmpeg_kit_flutter> |
| FFmpeg 源码 | <https://ffmpeg.org/download.html> |

> ⚠️ **原生产物是 `com.antonkarpenko`，不是 `com.arthenica`。**
> 插件的 `android/build.gradle` 里写死了
> `implementation("com.antonkarpenko:ffmpeg-kit-min:2.2.2")` —— 它是
> [arthenica/ffmpeg-kit](https://github.com/arthenica/ffmpeg-kit) 的一个 fork。
> **别拿 pub 包名去猜上游 AAR**，猜错会让体积估算和许可证核查全部跑偏
> （本项目第一版体积估算就是这么错的，见 `docs/APE_DSF_播放方案评估.md` §4.1）。
> 原生侧 AAR 实测：盘上 38.9 MB，jni 未压缩 **75.9 MB / 4 ABI（44 个 `.so`）**。

### 用途

播放 APE / WavPack / TTA 等 ExoPlayer 无法解封装的格式前，先转成 FLAC
再交给播放器。产物写入临时目录缓存，LRU 淘汰，上限 2 GB。
实现见 `lib/features/player/service/transcode/`
（方案背景：`docs/APE_DSF_播放方案评估.md`）。

### 为什么是 `_min` 变体（重要）

ffmpeg-kit 有两个分发变体：

- **不带后缀的主包（`ffmpeg_kit_flutter_new`）** = `full-gpl`，含
  x264 / x265 / xvidcore / vid.stab 等 **GPL** 组件。用它会把整个应用
  拖成 GPL，与本项目 MIT 冲突。
- **`_min`** = 仅 LGPL 组件，不含上述库。本项目只用音频解码/编码，不需要它们。

**任何情况下都不要把它换成不带后缀的主包。**

### LGPL 3.0 的三项义务与落实方式

以二进制形式分发 LGPL 库，必须同时满足：

1. **告知使用者本应用使用了该库**
   → 应用内「设置 → 版本 → 关于」底部有 FFmpeg 声明行
   （`lib/shared/widgets/app_about.dart` 的 `_FfmpegNotice`，手机 / HD / TV 三端共用同一份文案）。

2. **说明该库采用 LGPL**
   → 同上，文案里直接写了「LGPL v3」。

3. **提供获取其源码（含编译脚本）的渠道**
   → 同上，声明行可点击，跳转到
   <https://github.com/sk3llo/ffmpeg_kit_flutter>（即 `pubspec.yaml` 里
   声明的 `repository` / `homepage`），该仓库内有构建脚本与上游指向；
   FFmpeg 自身源码见 <https://ffmpeg.org/download.html>。

⚠️ 第 3 项**不能**指向本项目官网 —— 官网没有 FFmpeg 源码，用户点进去拿不到东西，
等于未提供。

### 换版本 / 换包时要同步改的地方

| 改动 | 要改 |
|---|---|
| 换 ffmpeg-kit 版本 | `pubspec.yaml` → `flutter pub get` |
| 换变体（如改用 full-gpl） | `pubspec.yaml` + **本文件「为什么是 `_min` 变体」一节** + 关于页文案里的许可证名称 |
| 换上游仓库 / 用自建 fork | 关于页 `AppAboutPanel.ffmpegSourceUrl`（唯一真源）+ 本文件链接 |

---

*本文件随应用一起分发，不在 App 内展示；App 内展示的是上面第 1~3 项对应的那一行声明。*
