# 吾爱Music TV 安装说明（给 AI Agent）

你在帮用户把**吾爱Music TV 版**（本地音乐播放器，https://github.com/jim-6688/wuai-music ）装到 Android 电视或电视盒子上。整个过程通过电脑上的 adb 完成，电视不需要 root。

它不是电视桌面，**不会替换系统桌面、不动任何系统设置** —— 只是一个普通音乐 App，装完在「我的应用」里打开即可。

当前版本以官网清单为准：`https://music.52ta.top/version.json`（具体版本号随发版变化，下面所有命令都从这份清单动态读取，不在此写死）。

## 规则

1. **亲自在用户电脑上运行命令**，不要只把步骤列给用户。如果你不能执行命令（比如你是手机版或网页版聊天），直接告诉用户：请换成能执行命令的电脑版 Agent（WorkBuddy、豆包电脑版或豆包工作版、千问电脑版、Trae、Claude Code、Codex 等），并在第一次运行命令时允许它执行命令、访问网络。豆包手机版、网页版只会把步骤告诉用户，不会执行。
2. **不要假装成功。** 每一步都看命令的真实输出；最后必须完成「验收」，把原始输出原样贴给用户。没有看到这些输出，就不能说装好了。
3. **不要卸载、停用任何系统应用**，不要删除电视上的任何文件，不要恢复出厂设置。只能删掉这次安装自己下载到电脑上的 APK。
4. **不要让用户恢复出厂、刷机、删系统桌面。** 遇到装不上的情况，按下面的「常见情况」处理，处理不了就如实告诉用户。
5. 重启电视（`adb reboot`）前先征得用户同意。
6. 需要用户在电视上操作时（允许调试、同意安装、授权存储），明确告诉用户按遥控器的哪个键。
7. 失败时把命令和输出原样给用户看，再对照「常见情况」处理。

## 第 1 步：准备 adb

先运行 `adb version`。有输出就跳到第 2 步。

没有 adb 时，下载 Google 的 platform-tools（`dl.google.com` 在国内可以访问），解压后用里面的 adb：

- **Windows**（PowerShell）：
  ```powershell
  cd $env:USERPROFILE
  curl.exe -fL -o platform-tools.zip https://dl.google.com/android/repository/platform-tools-latest-windows.zip
  Expand-Archive -Force platform-tools.zip .
  $env:Path = "$env:USERPROFILE\platform-tools;$env:Path"
  adb version
  ```
- **macOS**：`brew install android-platform-tools`；没有 Homebrew 时也可以跳过，第 3 步的命令会自己用 `curl` 下载，但**仍然需要 adb**，所以建议还是装上。
- **Linux**：用系统的包管理器装 `adb` 或 `android-tools`。

## 第 2 步：连接电视

电脑和电视要在同一个网络。用户给你的电视 IP 记为 `<IP>`。

```
adb connect <IP>:5555
adb devices
```

`adb devices` 里这台电视后面是 `device` 才算连上。

- **`unauthorized`**：电视上弹出了「允许 USB 调试吗？」，请用户选「允许」并勾选「始终允许」，再运行一次 `adb devices`。
- **`failed to connect` / `Connection refused` / 超时**：电视的 ADB 调试没打开，或 IP 不对。让用户按下表打开，再试：

| 电视 | 怎么打开 ADB |
|---|---|
| 小米 / Redmi | 设置 → 关于 → **产品型号**，连续按确认键，直到提示进入开发者模式。再到 设置 → 账号与安全，打开 **ADB 调试** 和 **安装未知来源的应用** |
| TCL / 雷鸟 | 设置 → 关于 → **本机信息**，依次按遥控器 **上、下、左、右**（间隔不超过 1 秒），底部出现「更多」，在里面打开 **ADB** |
| OPPO 电视（含 S1） | 设置 → 系统 → 关于本机 → **设备型号**，依次按 **上、上、右、右**，再按确认；然后到 设置 → 系统 → **开发者选项**，打开 **USB 调试**（有的机型叫 ADB 调试） |
| 海尔 / 模卡（MOOKA） | 按**电视机身**上的信号源键，弹出信号源菜单后，用遥控器依次按 **左、左、上、右**，进入「海尔工厂菜单」，把 **ADB 调试开关** 设为开。只改这一项，别动其他选项，尤其不要选「工厂复位」 |
| 索尼 / 海信 / 原生 Android TV / Google TV | 设置 → 设备偏好设置 → 关于 → 连续按 **内部版本号**（Build）7 次，再到开发者选项打开 **USB 调试**（也可能叫「网络调试」） |

电视的 IP 一般在 设置 → 网络 → 已连接的网络 里。

**打不开 ADB 的机型**：极米 H3、老乐视、荣耀智慧屏、老康佳（看不到版本号）等，目前没有办法，直接告诉用户不支持，不要反复尝试。

**用户没有电脑**：可以让用户照本说明第 2、3 步在手机上用「甲壳虫 ADB 助手」等工具操作，装好后尽量再用电脑跑一遍「验收」。

## 第 3 步：确认架构（arm64 还是 32 位）

先看电视支持哪种，避免装了跑不起来：

```
adb shell getprop ro.product.cpu.abi
```

- 输出 `arm64-v8a` → 用 **arm64 包**（绝大多数 2016 年后的电视和盒子）
- 输出 `armeabi-v7a` 或 `armeabi` → 用 **32 位包**
- 输出别的（如 `x86`）→ 告诉用户这台设备暂不支持，不要硬装

## 第 4 步：安装

### macOS / Linux：一条命令

把 `<IP>` 换成第 2 步的电视 IP；32 位电视把文件名里的 `app-tv-release.apk` 改成 `app-tv-release-v7a.apk`（见第 3 步）：

```bash
PKG=app-tv-release.apk
curl -fL -o "$PKG" "https://gitee.com/jinghe-net/wuai-music/releases/download/latest/$PKG"
adb install -r "$PKG"
```

Gitee 是国内镜像，**地址固定、不随版本变化**，永远是最新版，无需写版本号。国际网络可以改用 GitHub，但 GitHub 资产名带版本号，所以**从官网清单动态读取当前地址**（升级不会失效）：

```bash
TV_URL=$(curl -fsSL https://music.52ta.top/version.json | python3 -c "import sys,json;print(json.load(sys.stdin)['releases']['tv']['url'])")
# 32 位电视：把上一行的 ['tv']['url'] 换成 ['tv']['variants']['armeabi-v7a']['url']
curl -fL -o wuai-tv.apk "$TV_URL"
adb install -r wuai-tv.apk
```

> ⚠️ `adb install` **只能装本地文件，不接受 URL**。必须先下载再安装。
> 任意渠道的当前下载地址都在 `https://music.52ta.top/version.json` 里（`releases.tv.url` 为 GitHub 直链，`releases.tv.urlMirror` 为 Gitee 镜像），随发版自动更新，本说明不再写死版本号。

输出 `Success` 继续。失败时看「常见情况」。

### Windows：逐条运行

1. 下载（PowerShell，Gitee 国内镜像，地址固定）：
   ```powershell
   curl.exe -fL -o wuai-tv.apk https://gitee.com/jinghe-net/wuai-music/releases/download/latest/app-tv-release.apk
   ```
   32 位电视把上面地址里的 `app-tv-release.apk` 换成 `app-tv-release-v7a.apk`。
   国际网络可改用 GitHub，**从官网清单动态读取当前地址**（PowerShell 自带 JSON 解析，升级不会失效）：
   ```powershell
   $TV_URL = (Invoke-RestMethod https://music.52ta.top/version.json).releases.tv.url
   # 32 位电视：把 .releases.tv.url 改成 .releases.tv.variants.'armeabi-v7a'.url
   curl.exe -fL -o wuai-tv.apk $TV_URL
   ```
   （不想用 PowerShell 的 JSON 解析时，也可直接打开 `https://music.52ta.top/version.json`，复制 `releases.tv.url` 字段的值。）

2. 安装：
   ```
   adb install -r wuai-tv.apk
   ```
   输出 `Success` 继续。失败时看「常见情况」。

## 第 5 步：授予存储权限（关键，决定能不能扫到歌）

吾爱Music 是**本地播放器**，没有存储权限就看不到你电视 / U 盘 / TF 卡里的歌。装完必须授权。

先启动一次 App，让系统建好权限记录：

```
adb shell am start -W -n com.wuaimusic.app.tv/com.wuaimusic.app.MainActivity
```

然后授权（某条报错可以忽略——老系统没有 `READ_MEDIA_AUDIO`，新系统没有 `READ_EXTERNAL_STORAGE`，有一条成功就行）：

```
adb shell pm grant com.wuaimusic.app.tv android.permission.READ_MEDIA_AUDIO
adb shell pm grant com.wuaimusic.app.tv android.permission.READ_EXTERNAL_STORAGE
```

如果 App 弹出了「允许访问设备上的照片和媒体」这类对话框，请用户用遥控器选**允许**。

> 权限授予后 App 会自动扫描一次；电视上音乐多时要等十几秒到一两分钟，进度在「本地音乐」页能看到。

## 第 6 步：让 App 以后能自己升级（可选，建议）

吾爱Music 内置 OTA，会自己从官网拉新版。授予安装权限后，以后有新版本在电视上点一下就升级，不用再连 adb：

```
adb shell appops set com.wuaimusic.app.tv REQUEST_INSTALL_PACKAGES allow
```

用户不想让它自己升级时，把 `allow` 改成 `default` 即可。

## 验收（必须做）

逐条运行，把**原始输出**贴给用户：

```
adb shell "dumpsys package com.wuaimusic.app.tv | grep -E 'versionName|versionCode'"
adb shell am start -W -n com.wuaimusic.app.tv/com.wuaimusic.app.MainActivity
adb shell "dumpsys package com.wuaimusic.app.tv | grep -c 'android.permission.READ'"
adb shell "dumpsys window | grep mCurrentFocus"
```

- 第 1 条有 `versionName=1.3.3`（或更高）：已安装。
- 第 2 条有 `Status: ok`：能正常启动，没有闪退。
- 第 3 条**大于 0**：存储权限已授予，能扫到本地音乐。是 `0` 时回第 5 步。
- 第 4 条包含 `com.wuaimusic.app.tv/com.wuaimusic.app.MainActivity`：App 现在就在前台。**这一条不满足，就不能告诉用户装好了。**

第 4 条不是 `com.wuaimusic.app.tv/...` 时，等 3 秒再运行一次第 2、4 条。还不是，看「常见情况」。

都通过后，如果用户希望重启后确认能正常起来，**征得用户同意**再 `adb reboot`，等电视开机后重新 `adb connect <IP>:5555`，再运行一次第 2、4 条。

## 常见情况

- **`INSTALL_FAILED_VERIFICATION_FAILURE`**：TCL 等固件拒绝一切 adb 安装。改用电视自带的「多屏互动」或当贝市场的「本地安装」：`adb push wuai-tv.apk /sdcard/Download/wuai-tv.apk`，再请用户在电视上打开它安装。
- **`INSTALL_FAILED_USER_RESTRICTED`**（创维等）：固件在校验 adb 安装。先 `adb shell settings get global verifier_verify_adb_installs` 记下原值，再 `adb shell settings put global verifier_verify_adb_installs 0`，重新安装。装好后把原值写回去（原值是 `null` 时用 `adb shell settings delete global verifier_verify_adb_installs`）。
- **`INSTALL_FAILED_NO_MATCHING_ABIS`**：装错架构了。回第 3 步确认，换另一个包。
- **`INSTALL_FAILED_UPDATE_INCOMPATIBLE`**：电视上已有一个签名不同的旧版。先 `adb uninstall com.wuaimusic.app.tv`（会清掉 App 内数据，先问用户），再装。
- **装上了但扫描不到歌**：回第 5 步确认权限；再确认电视 / U 盘 / TF 卡确实插着，并且音乐文件在卡里（不是只在 NAS 上）。
- **能装但一打开就退**：把 `adb shell am start -W -n com.wuaimusic.app.tv/com.wuaimusic.app.MainActivity` 的完整输出贴给用户，并附上电视型号（`adb shell getprop ro.product.model`），去 https://github.com/jim-6688/wuai-music/issues 反馈。
- **小米 / TCL 待机后 App 被强停**：这是固件行为，不是安装问题。重新打开即可。
- **LG webOS、三星 Tizen、华为智慧屏（鸿蒙）**：不是 Android 系统，装不了，直接告诉用户。
- **Android 7.0 以下**：最低支持 Android 7.0（minSdk 24），更老的系统装不了。

## 还原

只卸载 App，不动别的：

```
adb uninstall com.wuaimusic.app.tv
```

这会删掉 App 内的数据（收藏、播放统计、自定义设置）。想保留数据就不卸载，直接在电视上「清除数据」或停用即可。

电视上的音乐文件、系统设置、其他 App 都不受影响。

## 用户常问

- **会换掉我的电视桌面吗？** 不会。它只是个音乐 App，和系统桌面无关。
- **能放本地音乐吗？U 盘、TF 卡、NAS 都行吗？** 本地文件、U 盘 / TF 卡、局域网 NAS / SMB 都可以，不依赖云端曲库。
- **手机上能当遥控器吗？** 可以。在电视上进入配对，用手机扫码后就能用手机控制播放和队列。
- **以后怎么升级？** App 会自己检查官网更新（第 6 步授权过的话），电视上点确认就能升级；没授权就用同样的安装命令重跑一遍第 4 步，数据都会保留。
- **支持哪些音频格式？** MP3 / M4A / AAC / FLAC / WAV / WMA / OGG / OPUS / AIFF / ALAC / APE / MPC / WV / TTA / DSF 等 16 种，含 CUE 分轨。
  - ⚠️ DSD 只支持 `.dsf`，**不支持 `.dff`**（DSDIFF）。用户手里是 `.dff` 时直接说明，别让对方反复试。
  - `.cue` 是分轨清单不是音频本身，App 会按它拆成单曲，不会把 `.cue` 当成一首歌收进曲库。
- **出问题去哪反馈？** https://github.com/jim-6688/wuai-music/issues ，附上电视型号（`adb shell getprop ro.product.model`）和命令输出。

---

## 给 Agent 的安装提示语（可直接整段复制给任何电脑版 AI Agent）

> 请帮我把吾爱Music TV 版装到我的 Android 电视上。完整说明在 https://music.52ta.top/agent.md （GitHub 镜像：https://raw.githubusercontent.com/jim-6688/wuai-music/main/docs/agent.md ），请先读它再动手。
>
> 我的电视 IP 是 `<IP>`。请你**亲自在电脑上运行命令**，不要把步骤列给我。**整体顺序必须按下面来**：
>
> 1. **第一步：读取设备端信息，判断架构**。连上电视后用 `adb shell getprop ro.product.cpu.abi` 看输出：`arm64-v8a` 用 arm64 包，`armeabi-v7a` / `armeabi` 用 32 位包，其它（如 x86）直接告诉我不支持、别硬装。
> 2. **第二步：按判断出的架构下载对应的安装包**。arm64 用 `app-tv-release.apk`，32 位用 `app-tv-release-v7a.apk`；地址从 `https://music.52ta.top/version.json` 的 `releases.tv.url`（GitHub 直链）/ `urlMirror`（Gitee 镜像）动态取，不要写死版本号。
> 3. **第三步：推送安装**。`adb install -r <刚下载的包>` 看到 `Success` 再继续；装错架构会报 `INSTALL_FAILED_NO_MATCHING_ABIS`，回第一步重判。
> 4. **第四步：授权与验收**。装完授予存储权限并确认能扫到本地音乐（能不能听到歌的关键），再跑「验收」四条把原始输出贴给我。
>
> 每一步都要看真实输出，没看到输出就不要说装好了。不要卸载或停用电视上的任何系统应用，不要删电视上的文件，不要恢复出厂；重启电视前先问我；卡在哪一步就把命令和输出原样发我。
