<div align="center">

# 吾爱音乐

**跨手机、车机 / 平板、电视三端的本地音乐播放器**

[官网](https://music.52ta.top) · [更新日志](https://music.52ta.top/#changelog) · [常见问题](https://music.52ta.top/#faq) · [问题反馈](https://github.com/jim-6688/wuai-music/issues)

[![Release](https://img.shields.io/github/v/release/jim-6688/wuai-music?style=flat-square)](https://github.com/jim-6688/wuai-music/releases/latest)
[![License](https://img.shields.io/github/license/jim-6688/wuai-music?style=flat-square)](https://github.com/jim-6688/wuai-music/blob/main/LICENSE)
[![Downloads](https://img.shields.io/github/downloads/jim-6688/wuai-music/total?style=flat-square)](https://github.com/jim-6688/wuai-music/releases/latest)
[![Platform](https://img.shields.io/badge/Platform-Android-green?style=flat-square&logo=android)](https://github.com/jim-6688/wuai-music/releases/latest)

</div>

> **本仓库是发布页。** 只提供安装包、更新日志与问题反馈，**不包含源码**。
> 功能说明、截图与常见问题以[官网](https://music.52ta.top)为准。

## 下载

三个构建分别对应三种设备，文件名里的 `phone` / `hd` / `tv` 就是它，**别装错端**：

| 设备 | 构建 | 国际（GitHub） | 国内（码云） |
|:---|:---|:---|:---|
| 手机 | `phone` | [前往下载](https://github.com/jim-6688/wuai-music/releases/latest) | [arm64](https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-phone-release.apk) · [32 位](https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-phone-release-v7a.apk) |
| 车机 / 平板 | `hd` | [前往下载](https://github.com/jim-6688/wuai-music/releases/latest) | [arm64](https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-hd-release.apk) · [32 位](https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-hd-release-v7a.apk) |
| 电视 | `tv` | [前往下载](https://github.com/jim-6688/wuai-music/releases/latest) | [arm64](https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-tv-release.apk) · [32 位](https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-tv-release-v7a.apk) |

- 系统要求：**Android 7.0（API 24）及以上**。
- 国内链路由码云托管，指向最新版，不需要翻页找版本号；国际链路在 GitHub Releases 里按版本挑选。
- `32 位` 那份是给较老的 `armeabi-v7a` 设备准备的，体积反而更大。近几年的手机、电视盒子装 **arm64** 即可。
- **应用内自带更新检查**，装好之后新版本会自己提示，新用户只需要下载这一次。

## 功能

- **播放**：支持 16 种音频格式；APE / WavPack / TTA 等播放器无法直接解封装的格式会先转成 FLAC 再播；支持无缝续播、后台播放与通知栏控制。
- **音效与可视化**：10 段均衡器与 15 组预设；4 款可视化效果。
- **曲库与整理**：本机曲库扫描；通过 SMB 接入 NAS 并缓存到本地；CUE 分轨专辑按曲目拆开；批量修复标签与内嵌封面。
- **歌词**：优先读取音频同目录的 `.lrc`；支持自行添加多个歌词服务器，多路交叉比对后取最匹配的一份；滚动歌词与整体偏移微调。
- **跨端**：手机、车机 / 平板、电视三种构建；电视端全程遥控器方向键操作、超大焦点与字号；22 套主题配色，明暗各一套。
- **无账号、无广告**，打开就能听。

## 截图

| 播放 | 可视化 | 均衡器 |
|:---:|:---:|:---:|
| ![播放](screenshots/phone-player.webp) | ![可视化](screenshots/phone-visualizer.webp) | ![均衡器](screenshots/phone-equalizer.webp) |

| 车机 / 平板 | 电视端 |
|:---:|:---:|
| ![车机 / 平板](screenshots/car-player.webp) | ![电视端](screenshots/tv-player.webp) |

## 隐私

曲库扫描、标签与封面读取、播放解码全部在本机完成，**音频文件不会离开你的设备**。

联网只发生在你主动触发的地方：在线找歌词、在线找封面、检查更新。此外还有一条**只在出错时才走**的诊断上报，用于定位崩溃：默认开启，可在「设置 → 日志与诊断」里一键关闭并清空队列。上报内容经脱敏处理，只包含错误类型、堆栈与出错前后的若干行日志 —— 不含音频文件、不含听歌记录、也不含任何设备唯一标识。

## 问题反馈

- 遇到问题或想提建议：请开一个 [Issue](https://github.com/jim-6688/wuai-music/issues)。
- 提问前可以先看一眼[常见问题](https://music.52ta.top/#faq)，答案可能就在里面。
- 崩溃类问题如果能在「设置 → 日志与诊断」里把日志一并附上，排查会快很多。

## 更新日志

每个版本的改动都写在[官网的更新中心](https://music.52ta.top/#changelog)。App 内的更新弹窗与页面展示的是同一份内容。

## 第三方组件与许可

以二进制形式随应用分发的第三方组件及其许可证，见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 许可证

[MIT License](LICENSE)

## ☕ 支持与赞助

如果这个应用对你有帮助，欢迎请作者喝杯咖啡 ☕

| 支付宝 | 微信 |
|:---:|:---:|
| ![支付宝](screenshots/alipay.jpg) | ![微信](screenshots/wechat.png) |

## 致谢

本程序在 **[QCLaw](https://github.com/nicepkg/qclaw)** 与 **[WorkBuddy](https://www.codebuddy.cn)** 的协助下开发完成。感谢以下开源项目：

- [Flutter](https://flutter.dev)
- [just_audio](https://pub.dev/packages/just_audio)
- [Riverpod](https://riverpod.dev)
- [Phosphor Icons](https://phosphoricons.com)
