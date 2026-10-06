# zeroTV

zeroTV 是一个开源、免费、跨平台的 IPTV 播放器。它把订阅、频道筛选、EPG、播放、
收藏、历史、可用性检测和本地录制放在一个本地优先的 Flutter 应用中。项目不要求账号，
不部署后端，也不收集遥测数据。

![zeroTV logo](assets/brand/logo.jpg)

> **内容与合规声明**：zeroTV 只提供播放器和订阅管理能力，不托管、上传或分发频道内容。
> 用户自行添加的频道源必须来自合法授权的提供方，并遵守所在地法律及源提供方的使用条款。
> 内置源只是可删除的公开播放列表地址，不代表 zeroTV 对其内容作任何背书。

## 功能

- Android 与 Windows 播放，基于 media_kit/libmpv，支持常见直播协议和音视频轨道。
- M3U/M3U8 订阅：远程 URL、本地文件、粘贴文本；多个镜像并发获取，失败时保留旧频道。
- 分组、搜索、收藏、观看历史、失效频道隐藏与恢复，以及频道 Logo。
- XMLTV EPG：当前节目、后续节目、回看入口和基于节目名的搜索。
- HTTP(S) 直连录制和 EPG 定时录制；录制文件始终保存在本机。
- 流可用性检测、过期结果清理和自动同步；中英文界面。
- SQLite 本地存储，无账号、无云端数据库、无遥测。

## 仓库结构

```text
apps/player            Flutter 应用（Android / Windows）
packages/iptv_core     领域模型、仓库接口和插件接口（纯 Dart）
packages/m3u_parser    M3U/M3U8 播放列表解析（纯 Dart）
packages/xmltv_parser  XMLTV EPG 解析（纯 Dart）
packages/stream_probe  流可用性检测引擎（纯 Dart）
scripts                Windows 检查、构建和打包脚本
.github/workflows      CI 与 tag Release 工作流
```

各 Dart 包独立解析依赖，未使用 melos 或 Pub Workspaces，以避免 Flutter 测试框架的版本
约束互相冲突。应用代码按 `core`、`features/<feature>/{presentation,application,data}`
分层，领域接口位于 `packages/iptv_core`。

## 快速开始

要求：Flutter 3.44.x、Dart 3.12.x；Windows 构建还需要 Visual Studio 2022 的 C++ 桌面
开发工作负荷，Android 构建需要 Android SDK 和 Flutter 支持的 JDK。

```powershell
# 在仓库根目录执行
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run_tests.ps1

# 构建 Windows release
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_windows.ps1

# 构建 Android APK（默认按 ABI 拆分）
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build_android.ps1

# 检查并生成 Windows / Android 测试包
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package_tests.ps1
```

首次使用前，脚本会为根项目、四个纯 Dart 包和 `apps/player` 分别执行依赖解析，随后运行
Drift 代码生成和 Flutter 本地化生成。完整脚本参数及原生播放冒烟测试见
[`scripts/README.md`](scripts/README.md)。

手动运行质量检查：

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
for pkg in packages/*; do (cd "$pkg" && dart test); done
(cd apps/player && flutter test)
```

## 发布

推送形如 `v1.0.0` 的 tag 会触发 `.github/workflows/release.yaml`，构建 Android 分 ABI APK、
Universal APK 和 Windows x64 便携 ZIP，生成 SHA-256 校验文件并直接发布 GitHub Release。
Android 签名可通过仓库 Secrets `ZEROTV_KEYSTORE_B64`、`ZEROTV_KEYSTORE_PASSWORD`、
`ZEROTV_KEY_ALIAS`、`ZEROTV_KEY_PASSWORD` 提供；未配置时只适合开发测试。

## 贡献

欢迎提交 PR 与 issue；提交前的质量门、代码约定与测试期望见
[CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

zeroTV 自有代码以 [MIT License](LICENSE) 发布。第三方依赖保留各自许可证；其中
media_kit 使用 LGPL 授权的 libmpv 动态库。分发构建时请同时遵守这些依赖的通知和许可证要求。
