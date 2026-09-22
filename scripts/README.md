# scripts/ — 本地开发脚本

仓库各包 standalone 解析依赖（不用 melos / Pub Workspaces），日常操作有固定
顺序要求，统一收口到本目录的 PowerShell 脚本（Windows 开发机原生环境）。

| 脚本 | 用途 | 常用参数 |
| --- | --- | --- |
| `run_tests.ps1` | 一键质量门：依赖检查 → 逐包 pub get → drift 代码生成 → 格式检查 → 静态分析 → 全部测试（与 CI 同构） | `-SkipCodegen`、`-Fast` |
| `build_windows.ps1` | Windows 桌面端构建 | `-Mode debug|release`（默认 release） |
| `build_android.ps1` | Android 构建（APK/AAB） | `-Target apk|aab`、`-Mode debug|release` |
| `common.ps1` | 共享函数库，被上述脚本 dot-source，勿直接运行 | — |

## 运行方式

在仓库根目录的 PowerShell 中执行（Windows 默认执行策略可能拦截本地脚本，
必要时先 `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`）：

```powershell
powershell -File scripts\run_tests.ps1        # 提交前跑一遍，预判 CI
powershell -File scripts\build_windows.ps1    # 产出 Windows release
powershell -File scripts\build_android.ps1    # 产出 Android release APK
```

## 前置要求

- Flutter SDK（stable，工程基于 3.44.x 开发）+ 自带 Dart
- Android 构建：JDK17 + Android SDK（cmdline-tools）
- Windows 构建：VS2022「使用 C++ 的桌面开发」工作负荷
- 所有脚本以**仓库根目录**为定位基准（内部自动推导，不依赖调用时所在目录）

## 关键行为说明

- **代理绕过**：脚本会设置 `NO_PROXY=localhost,127.0.0.1`。本机开系统代理时
  不设它，`flutter test` 会因 localhost WebSocket 被代理劫持而失败。
- **代码生成**：`*.g.dart`（drift）不入库，任何 analyze/test/build 前必须先跑
  build_runner，三个脚本默认都会执行（`run_tests.ps1` 可用 `-SkipCodegen` 跳过）。
- **Windows 符号链接**：本机未开开发者模式时，flutter 创建插件符号链接可能
  崩溃。`build_windows.ps1` 会预建 `ephemeral\.plugin_symlinks` 目录缓解；
  仍失败请开开发者模式或用管理员身份跑首次构建（环境问题，与代码无关）。
- **失败即停**：任一步骤失败脚本立即以非零码退出，与 CI fail-fast 行为一致。
