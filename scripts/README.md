# 本地检查与打包

从任意目录调用脚本均可；脚本自动定位仓库。支持 Windows PowerShell 5.1 / PowerShell 7，含中文的 `.ps1` 保持 UTF-8 BOM。

## 一键生成两个平台的测试包

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package_tests.ps1
```

按顺序执行依赖解析、代码生成、只读格式检查、静态分析、四个 Dart 包与 Flutter 应用测试，然后构建 Windows release 和 Android universal release APK。共用一次依赖解析和代码生成，平台构建串行执行，避免 Flutter/Gradle 缓存竞争。任一步骤失败即停止，不使用旧包冒充新产物。

产物位于 `build/dist/`：

- `zerotv-<version>-test-windows-x64.zip`：解压后运行 `zerotv_player.exe`。
- `zerotv-<version>-test-android-universal.apk`：支持 ARMv7、ARM64、x86_64。
- `SHA256SUMS-windows-test.txt` / `SHA256SUMS-android-test.txt`。

Android release 优先使用已有 `android/key.properties` 或签名环境变量；没有时沿用项目的 debug 签名回退，仅作开发测试。`-TestPackage` 仅改变文件名，不改变服务器、包名或签名。没有后端环境配置。

## 单独运行

| 脚本 | 参数 | 行为 |
| --- | --- | --- |
| `run_tests.ps1` | `-SkipCodegen`、`-Fast` | 质量检查；Fast 仅跳过格式/分析 |
| `precheck_builtin_sources.ps1` | `-TimeoutSec` | 检查内置订阅地址是否可达且返回 M3U 内容 |
| `build_windows.ps1` | `-Mode release/debug`、`-SkipPreparation` | 编译并检查原生播放器库与资源 |
| `build_android.ps1` | `-Target apk/aab`、`-Mode release/debug`、`-SkipPreparation` | 按指定模式编译并检查产物存在；release APK 按 ABI 拆分并混淆（符号存于 `build/app/symbols`） |
| `package_windows.ps1` | `-Mode`、`-TestPackage`、`-SkipBuild`、`-SkipPreparation` | 完整目录打 ZIP，补齐 VC++ x64 运行库、LICENSE，生成 SHA256 |
| `package_android.ps1` | `-Mode`、`-TestPackage`、`-UniversalOnly`、`-SkipBuild`、`-SkipPreparation` | 默认分 ABI + universal；可仅生成 universal |
| `package_tests.ps1` | `-Mode release/debug`、`-AndroidDeviceId` | 质量检查后串行构建双平台测试包；可指定 Android 设备执行视频回归 |
| `gen_app_icon.py` | 无 | 从品牌源图重新生成图标 |

`-SkipPreparation` 仅在当前依赖和生成代码已就绪时使用。`-SkipBuild` 明确复用已有构建，不保证与当前源码一致，也不运行 SDK 检查。默认始终重新构建。

Windows release/profile 安装规则排除此前测试构建遗留的调试快照，release 打包会拒绝残留的调试内核。Windows ZIP 包含完整 Flutter 资源、libmpv/ANGLE 库与 VC++ 运行库；独立 EXE 不能运行。release 用于分发测试；debug 用于有开发环境的机器。暂存文件保留在 `build/package-staging/<unique-id>/`，每次使用新目录，避免混入上次构建残留。

## 前置条件与验证

- Flutter 3.44.x / Dart 3.12.x；各包独立解析依赖。
- Windows：VS2022 的 C++ 桌面开发工作负荷及 x64 VC++ redistributable 文件。
- Android：Android SDK 与 Flutter 可用的 JDK（以 `flutter doctor -v` 为准）。
- 首次构建需要下载 media_kit 原生库；必须能访问其 GitHub Releases 下载地址。Android 脚本将已有 Windows HTTP 系统代理传递给当前 Java 构建进程；显式 Java 代理配置优先，不修改用户的全局 Gradle 配置。
- 脚本保留已有 NO_PROXY 设置并追加 localhost、127.0.0.1、::1。
- 格式检查使用 `--output=none`，不会修改源码。

原生播放冒烟测试（在 `apps/player` 目录）：

```powershell
flutter test integration_test/playback_smoke_test.dart -d windows
flutter test integration_test/playback_smoke_test.dart -d emulator-5554
```

使用本地生成的 PCM WAV 验证 libmpv 加载、解码和播放进度，不依赖公网直播源。完整直播视频、长时播放及 Android 后台任务还需真机验收。

Android 直播视频回归（在 `apps/player` 目录）：

```powershell
flutter test integration_test/live_video_test.dart -d emulator-5554
```

测试使用本地 H.264 MPEG-TS 流，验证截图中的真实视频像素，并检查不可 seek 直播流的提示不会引起报错或切源。视频输出使用应用默认配置；测试会向指定设备安装测试应用。本机 Android 16/17 模拟器默认输出仍存在 EGL 初始化失败，此项测试会如实失败，不能用音频测试通过代替视频验收。详细排查见 `docs/TEST_REPORT_2026-09-25.md`。

也可以在仓库根目录将视频回归纳入打包门禁：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\package_tests.ps1 -AndroidDeviceId emulator-5554
```
