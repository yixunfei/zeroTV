# zeroTV

开源、免费、跨平台的 IPTV 播放器。本地优先：无账号、无遥测、无云依赖。

> **免责声明**：本项目仅是一个播放与订阅管理工具，不存储、不分发任何流媒体内容，
> 无账号、无遥测。频道源由用户自行添加，内容的可用性与合法性由源提供方与使用者负责。
> 内置默认源只是一条指向公开播放列表的地址，可随时停用或删除。

## 状态

M3 已完成（订阅、频道、播放、EPG、录制、设置）。正在打磨 M4。计划见 [docs/PLAN.md](docs/PLAN.md)。

## 仓库结构

```
apps/player            Flutter 应用（Android / Windows 优先）
packages/iptv_core     领域模型与仓库、插件接口（纯 Dart）
packages/m3u_parser    M3U/M3U8 播放列表解析（纯 Dart）
packages/xmltv_parser  XMLTV EPG 解析（纯 Dart）
packages/stream_probe  流可用性检测引擎（纯 Dart）
```

各包独立解析依赖（不用 melos / Pub Workspaces：`flutter_test` 钉死的 `test_api`
版本没有对应的 `test` 发行版，共享解析必然冲突）。

## 开发

Windows 本机一键脚本见 [scripts/README.md](scripts/README.md)：

```powershell
powershell -File scripts\run_tests.ps1     # 一键质量门（与 CI 同构）
powershell -File scripts\build_windows.ps1 # Windows 打包
powershell -File scripts\build_android.ps1 # Android 打包
```

手动等价命令：

```bash
# 解析依赖（每个目录各一次）
dart pub get && for d in packages/* apps/player; do (cd $d && dart pub get); done

dart run build_runner build -d   # 代码生成（apps/player 目录下）
flutter analyze                  # 静态检查（根目录覆盖全部包）
dart test                        # 各 packages 下执行
flutter test                     # apps/player 下执行
```

## 许可证

GPL-3.0。播放器内核 media_kit/libmpv 为 LGPL，动态链接使用。
